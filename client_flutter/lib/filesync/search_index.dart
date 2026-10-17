import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:note123/filesync/file_store.dart';
import 'package:note123/utils/app_logger.dart';

/// Signature for extracting plain text from a record's content file.
/// Returns null to skip (e.g. encrypted or unreadable).
typedef TextExtractor = String? Function(String path);

class _SearchIndexUser implements QueryExecutorUser {
  @override
  int get schemaVersion => 1;
  @override
  Future<void> beforeOpen(QueryExecutor executor, OpeningDetails details) async {}
}

/// FTS5 full-text search index for note content.
///
/// One virtual table [notes_idx] with two columns:
///   - content : tokenized plain text body extracted from work/base file
///   - uuid    : record identifier for result mapping (not indexed)
class SearchIndex {
  final File file;
  final FileStore fileStore;
  TextExtractor? extractText;
  late final QueryExecutor _db;

  SearchIndex(this.file, this.fileStore, [this.extractText]);

  void setExtractor(TextExtractor extractor) => extractText = extractor;

  Future<void> open() async {
    _db = NativeDatabase.createInBackground(
      file,
      setup: (rawDb) {
        rawDb.execute('PRAGMA journal_mode=WAL;');
        rawDb.execute('PRAGMA synchronous=NORMAL;');
        rawDb.execute('PRAGMA busy_timeout = 5000;');
        rawDb.execute('''
          CREATE VIRTUAL TABLE IF NOT EXISTS notes_idx USING fts5(
            content,
            uuid UNINDEXED,
            tokenize='unicode61'
          );
        ''');
      },
    );
    await _db.ensureOpen(_SearchIndexUser());
    AppLogger.i("[SearchIndex] opened ${file.path} extractor=${extractText != null}");
  }

  Future<void> close() async {
    await _db.close();
  }

  Future<void> _upsert(String uuid, String content) async {
    await _db.runCustom('DELETE FROM notes_idx WHERE uuid = ?;', [uuid]);
    await _db.runCustom(
      'INSERT INTO notes_idx(content, uuid) VALUES (?, ?);', [content, uuid],
    );
  }

  Future<void> _remove(String uuid) async {
    await _db.runCustom('DELETE FROM notes_idx WHERE uuid = ?;', [uuid]);
  }

  /// FTS5 MATCH query. Returns rows ordered by BM25 rank (best first).
  /// Each row is [uuid, snippet] where snippet is a short excerpt around the
  /// match: U+0001/U+0002 mark highlight start/end, '...' marks truncation.
  Future<List<List<String>>> search(String query, {int limit = 50}) async {
    if (query.trim().isEmpty) return [];
    final q = _normalizeQuery(query);
    try {
      // Over-fetch by token count (CJK is one token per char); the excerpt
      // is re-windowed by character count in [_windowSnippet] so the match
      // always lands on the first visible line.
      final rows = await _db.runSelect(
        '''
        SELECT uuid,
               snippet(notes_idx, 0, ?, ?, '...', 120) AS snippet
        FROM notes_idx
        WHERE notes_idx MATCH ?
        ORDER BY bm25(notes_idx)
        LIMIT ?;
        ''',
        ['\u0001', '\u0002', q, limit],
      );
      return rows.map((row) {
        return [
          row['uuid'] as String,
          _windowSnippet(_restoreCjk(row['snippet'] as String)),
        ];
      }).toList();
    } catch (e) {
      AppLogger.e('[SearchIndex] search failed query=$query: $e');
      return [];
    }
  }

  /// Re-index a single record: resolve content file (work → base), extract text,
  /// upsert or remove. File absence or extractor null both result in remove.
  Future<void> refresh(String uuid) async {
    final extractor = extractText;
    if (extractor == null) {
      AppLogger.d("[SearchIndex] refresh skipped: extractor is null");
      return;
    }
    final contentPath = _resolveContentPath(uuid);
    if (contentPath == null) {
      await _remove(uuid);
      return;
    }
    final text = extractor(contentPath);
    if (text == null || text.isEmpty) {
      await _remove(uuid);
      return;
    }
    final normalized = text.replaceAll(RegExp(r'[\r\n]+'), ' ');
    final tokenized = _tokenizeCjk(normalized);
    AppLogger.d("[SearchIndex] refresh uuid=$uuid len=${normalized.length}");
    await _upsert(uuid, tokenized);
  }

  String? _resolveContentPath(String uuid) {
    if (fileStore.isWorkFileExist(uuid)) return fileStore.getWorkFile(uuid);
    if (fileStore.isBaseFileExist(uuid)) return fileStore.getBaseFile(uuid);
    return null;
  }

  /// Insert a space between every pair of consecutive CJK characters so
  /// that unicode61 treats each CJK char as an independent token.
  String _tokenizeCjk(String input) {
    return input.replaceAllMapped(RegExp('[\\u4e00-\\u9fff\\u3400-\\u4dbf]+'), (m) => m[0]!.split('').join(' '));
  }

  /// Remove the spaces inserted between adjacent CJK characters by
  /// [_tokenizeCjk]. U+0001/U+0002 highlight markers may sit on either
  /// side of such a space, so they are skipped inside the match/lookahead.
  String _restoreCjk(String input) {
    return input.replaceAllMapped(
      RegExp('[\\u4e00-\\u9fff\\u3400-\\u4dbf][\\u0001\\u0002]* (?=[\\u0001\\u0002]*[\\u4e00-\\u9fff\\u3400-\\u4dbf])'),
      (m) => m[0]!.substring(0, m[0]!.length - 1),
    );
  }

  /// Re-window an FTS snippet around the first highlight by character count.
  /// The FTS window is token-based and far too wide for latin text, which
  /// pushes the match past the two-line UI clamp. [input] uses U+0001/U+0002
  /// as highlight markers and leading/trailing '...' to mark FTS truncation.
  String _windowSnippet(String input, {int before = 40, int after = 80}) {
    final ftsPrefix = input.startsWith('...');
    final ftsSuffix = input.endsWith('...');
    var body = input;
    if (ftsPrefix) body = body.substring(3);
    if (ftsSuffix) body = body.substring(0, body.length - 3);

    final plain = StringBuffer();
    final hits = <_Range>[];
    int? markStart;
    for (final cu in body.codeUnits) {
      if (cu == 0x01) {
        markStart = plain.length;
      } else if (cu == 0x02) {
        if (markStart != null) {
          hits.add(_Range(markStart, plain.length));
          markStart = null;
        }
      } else {
        plain.writeCharCode(cu);
      }
    }
    final text = plain.toString();
    if (hits.isEmpty) return text;

    final first = hits.first;
    final start = (first.start - before).clamp(0, text.length);
    final end = (first.end + after).clamp(start, text.length);

    final opens = <int>{};
    final closes = <int>{};
    for (final h in hits) {
      if (h.start < end && h.end > start) {
        final s = h.start < start ? start : h.start;
        final e = h.end > end ? end : h.end;
        if (s < e) {
          opens.add(s);
          closes.add(e);
        }
      }
    }

    final out = StringBuffer();
    if (ftsPrefix || start > 0) out.write('...');
    for (int i = start; i < end; i++) {
      if (opens.contains(i)) out.write('\u0001');
      if (closes.contains(i)) out.write('\u0002');
      out.write(text[i]);
    }
    if (closes.contains(end)) out.write('\u0002');
    if (ftsSuffix || end < text.length) out.write('...');
    return out.toString();
  }

  /// Normalize query into an FTS5 phrase search: tokens must appear
  /// consecutively and in the same order (unlike AND which is order-free).
  String _normalizeQuery(String input) {
    final tokenized = _tokenizeCjk(input.trim());
    final terms = tokenized.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (terms.isEmpty) return '';
    return '"${terms.join(' ')}"';
  }
}

class _Range {
  final int start;
  final int end;
  _Range(this.start, this.end);
}
