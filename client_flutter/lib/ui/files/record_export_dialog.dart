import 'dart:convert';
import 'dart:io';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:note123/config/language_manager.dart';
import 'package:note123/filesync/file_store.dart';
import 'package:note123/filesync/record_tree.dart';
import 'package:note123/filesync/repository.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../utils/app_logger.dart';
import '../../utils/utils.dart';

/// Markdown export entry. Exports all records under [folderPath] (recursive),
/// recreating the note path/name structure as real directories and .md files
/// inside the user-selected destination folder.
class RecordExport {
  /// Start export: pick destination folder, then show the progress dialog.
  static Future<void> start(BuildContext context, String folderPath) async {
    final root = folderPath.endsWith('/') ? folderPath : '$folderPath/';
    final files = Repository.get().recordTree.sortedFiles.where((f) => f.path.startsWith(root)).toList();
    if (files.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.exportNoRecords)));
      return;
    }

    String? picked = await FilePicker.platform.getDirectoryPath(dialogTitle: l10n.exportSelectFolder);
    if (picked == null) return; // user cancelled the picker

    String resolvedTarget;
    // Android returns a SAF content URI which dart:io cannot write to;
    // fall back to an app-specific external folder.
    if (picked.startsWith('content://')) {
      final base = await getExternalStorageDirectory() ?? await getApplicationSupportDirectory();
      final now = DateTime.now();
      final stamp =
          '${now.year}${_two(now.month)}${_two(now.day)}_${_two(now.hour)}${_two(now.minute)}${_two(now.second)}';
      resolvedTarget = p.join(base.path, 'note123_export', stamp);
    } else {
      resolvedTarget = picked;
    }
    final targetDir = Directory(resolvedTarget);
    try {
      await targetDir.create(recursive: true);
    } catch (e) {
      AppLogger.e("[RecordExport] cannot create target dir $resolvedTarget: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l10n.exportFailed}: $e')));
      }
      return;
    }
    if (!context.mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ExportProgressDialog(files: files, rootPath: root, targetDir: resolvedTarget),
    );
  }

  static String _two(int v) => v.toString().padLeft(2, '0');
}

class _ExportProgressDialog extends StatefulWidget {
  final List<TreeContentFile> files;
  final String rootPath;
  final String targetDir;

  const _ExportProgressDialog({required this.files, required this.rootPath, required this.targetDir});

  @override
  State<_ExportProgressDialog> createState() => _ExportProgressDialogState();
}

class _ExportProgressDialogState extends State<_ExportProgressDialog> {
  final Set<String> _writtenFiles = {};

  bool _finished = false;
  bool _cancelled = false;
  int _done = 0;
  int _success = 0;
  int _skipped = 0;
  TreeContentFile? _current;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    for (final file in widget.files) {
      if (_cancelled) break;
      setState(() => _current = file);

      String? content = await _readRecordFile(file);
      if (content == null || content.isEmpty) {
        _skipped++;
        _advance();
        continue;
      }

      String? plain;
      if (file.locked != 0) {
        if (!mounted) break;
        // Password dialog resolves with decrypted plaintext on confirm,
        // null when the record is skipped.
        plain = await showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (_) => _PasswordDialog(file: file, encryptedRaw: content),
        );
        if (!mounted || plain == null) {
          _skipped++;
          _advance();
          continue;
        }
      } else {
        plain = content;
      }

      try {
        final markdown = _contentToMarkdown(plain);
        await _writeFile(file, markdown);
        _success++;
      } catch (e) {
        AppLogger.e("[RecordExport] failed to export ${file.path}${file.name}: $e");
        _skipped++;
      }
      _advance();
    }

    if (mounted) setState(() => _finished = true);
  }

  void _advance() {
    _done++;
    if (mounted) setState(() {});
  }

  void _cancel() {
    setState(() => _cancelled = true);
  }

  /// Read work file, fall back to base file (downloading it if necessary).
  Future<String?> _readRecordFile(TreeContentFile record) async {
    final FileStore? fileStore = Repository.get().fileStore;
    if (fileStore == null) return null;
    File file = File(fileStore.getWorkFile(record.uuid));
    if (record.version > 0 && !file.existsSync()) {
      file = File(fileStore.getBaseFile(record.uuid));
      if (!file.existsSync()) {
        await fileStore.downloadBaseFile(record.uuid);
      }
    }
    if (!file.existsSync()) return null;
    try {
      return await file.readAsString();
    } catch (e) {
      AppLogger.e("[RecordExport] read failed uuid=${record.uuid}: $e");
      return null;
    }
  }

  /// Work files store appflowy document JSON; legacy plaintext is exported as-is.
  String _contentToMarkdown(String raw) {
    final trimmed = raw.trim();
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      try {
        final map = jsonDecode(trimmed) as Map<String, dynamic>;
        return documentToMarkdown(Document.fromJson(map));
      } catch (e) {
        AppLogger.w("[RecordExport] content is not valid document JSON, exporting as plain text: $e");
      }
    }
    return raw;
  }

  Future<void> _writeFile(TreeContentFile file, String markdown) async {
    final relative = file.path.substring(widget.rootPath.length); // no leading slash
    final segments = relative.split('/').where((s) => s.isNotEmpty).map(_sanitizeSegment).toList();
    final baseName = _sanitizeSegment(file.name.isEmpty ? 'untitled' : file.name);

    var candidate = p.joinAll([widget.targetDir, ...segments, '$baseName.md']);
    var n = 1;
    while (_writtenFiles.contains(candidate.toLowerCase()) || await File(candidate).exists()) {
      candidate = p.joinAll([widget.targetDir, ...segments, '$baseName ($n).md']);
      n++;
    }
    final out = File(candidate);
    await out.parent.create(recursive: true);
    await out.writeAsString(markdown);
    _writtenFiles.add(candidate.toLowerCase());
  }

  /// Remove path-illegal characters so the tree can be recreated on disk.
  String _sanitizeSegment(String name) {
    var result = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    result = result.replaceAll(RegExp(r'^\.+|\.+$'), '');
    return result.isEmpty ? 'untitled' : result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = widget.files.length;

    return PopScope(
      canPop: _finished,
      child: AlertDialog(
        title: Text(l10n.exportMarkdown),
        content: SizedBox(width: 400, child: _buildContent(theme, total)),
        actions: _buildActions(),
      ),
    );
  }

  Widget _buildContent(ThemeData theme, int total) {
    if (_finished) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.green),
              const SizedBox(width: 8),
              Expanded(child: Text(l10n.exportCompleted(_success, _skipped))),
            ],
          ),
          const SizedBox(height: 8),
          Text(widget.targetDir, style: TextStyle(fontSize: 12, color: theme.colorScheme.outline)),
        ],
      );
    }

    final current = _current;
    final progress = total == 0 ? 0.0 : _done / total;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.exportingProgress(_done, total), style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 10),
        LinearProgressIndicator(value: progress),
        const SizedBox(height: 10),
        if (current != null)
          Text(
            '${current.path}${current.name}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
          ),
        if (_cancelled) ...[
          const SizedBox(height: 8),
          Text(l10n.exportCancelled, style: TextStyle(fontSize: 12, color: theme.colorScheme.error)),
        ],
      ],
    );
  }

  List<Widget> _buildActions() {
    if (_finished) {
      return [
        TextButton(onPressed: () => OpenFilex.open(widget.targetDir), child: Text(l10n.exportOpenFolder)),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.close)),
      ];
    }
    return [TextButton(onPressed: _cancel, child: Text(l10n.cancel))];
  }
}

/// Password prompt for one encrypted record during export. Pops with the
/// decrypted plaintext on confirm, or null when the record is skipped.
class _PasswordDialog extends StatefulWidget {
  final TreeContentFile file;
  final String encryptedRaw;

  const _PasswordDialog({required this.file, required this.encryptedRaw});

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final password = _controller.text.trim();
    if (password.isEmpty) return;
    final decrypted = Utils.decryptContent(widget.encryptedRaw, password);
    if (decrypted == null) {
      setState(() => _error = l10n.passwordIncorrect);
      return;
    }
    Navigator.of(context).pop(decrypted);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      title: Row(
        children: [
          const Icon(Icons.lock_outline, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(l10n.exportEncryptedTitle, style: const TextStyle(fontSize: 15))),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.file.path}${widget.file.name}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _controller,
            obscureText: true,
            autofocus: true,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              isDense: true,
              border: const OutlineInputBorder(),
              labelText: l10n.enterUnlockPassword,
              errorText: _error,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.exportSkip)),
        TextButton(onPressed: _submit, child: Text(l10n.confirm)),
      ],
    );
  }
}
