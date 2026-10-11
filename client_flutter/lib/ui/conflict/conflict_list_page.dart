import 'dart:io';

import 'package:flutter/material.dart';
import 'package:note123/filesync/database.dart';
import 'package:note123/filesync/repository.dart';
import 'package:note123/ui/common/platform_app_bar.dart';
import 'package:note123/ui/conflict/conflict_diff_page.dart';
import 'package:note123/config/language_manager.dart';

/// Determine true file conflict:
/// - remoteFileVersion > localFileVersion (remote file version is indeed newer than last local alignment)
/// - workfile truly exists (local has actually edited the file)
/// localFileEditAt timestamp is not reliable, workfile existence is the authority
bool _isFileConflict(LocalRecord record) {
  final fs = Repository.get().fileStore;
  if (fs == null) return false;
  final workFile = File(fs.getWorkFile(record.uuid));
  return record.remoteFileVersion > record.localFileVersion && workFile.existsSync();
}

/// Conflict list page: list all sync-conflicted records.
class ConflictListPage extends StatefulWidget {
  const ConflictListPage({super.key});

  /// Whether conflict list page is currently showing. Used to prevent duplicate popups.
  static bool isShowing = false;

  @override
  State<ConflictListPage> createState() => _ConflictListPageState();

  static Future<void> open(BuildContext context) async {
    isShowing = true;
    try {
      final list = await Repository.get().getConflictRecords();
      if (list.length == 1 && context.mounted) {
        // Only one conflict: go directly to diff page, skip list
        await Navigator.of(
          context,
          rootNavigator: true,
        ).push(MaterialPageRoute(builder: (_) => ConflictDiffPage(record: list.first)));
      } else if (context.mounted) {
        await Navigator.of(
          context,
          rootNavigator: true,
        ).push(MaterialPageRoute(builder: (_) => const ConflictListPage()));
      }
    } finally {
      isShowing = false;
    }
  }
}

class _ConflictListPageState extends State<ConflictListPage> {
  List<LocalRecord> _conflicts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadConflicts();
  }

  Future<void> _loadConflicts() async {
    final list = await Repository.get().getConflictRecords();
    if (!mounted) return;
    setState(() {
      _conflicts = list;
      _loading = false;
    });
  }

  Future<void> _resolve(LocalRecord record) async {
    final resolved = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => ConflictDiffPage(record: record)));
    if (resolved == true && mounted) {
      await _loadConflicts();
      if (_conflicts.isEmpty && mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: createPlatformAppBar(title: l10n.syncConflictTitle(_conflicts.length)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _conflicts.isEmpty
          ? Center(child: Text(l10n.noConflicts))
          : ListView.builder(
              itemCount: _conflicts.length,
              itemBuilder: (context, index) => _buildItem(_conflicts[index]),
            ),
    );
  }

  Widget _buildItem(LocalRecord record) {
    final fileConflict = _isFileConflict(record);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: Icon(
          fileConflict ? Icons.difference : Icons.info_outline,
          color: fileConflict ? Colors.red : Colors.orange,
        ),
        title: Text(
          "${record.localPath}${record.localName}",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        trailing: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: fileConflict ? Colors.red.withAlpha(20) : Colors.orange.withAlpha(20),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                fileConflict ? l10n.fileConflict : l10n.metaConflict,
                style: TextStyle(fontSize: 11, color: fileConflict ? Colors.red : Colors.orange),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () => _resolve(record),
      ),
    );
  }
}
