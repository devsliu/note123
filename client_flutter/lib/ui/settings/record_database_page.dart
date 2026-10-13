import 'dart:io';

import 'package:flutter/material.dart';
import 'package:note123/filesync/file_store.dart';
import 'package:note123/filesync/record_ext.dart';
import 'package:note123/filesync/repository.dart';
import 'package:note123/filesync/table_record.dart';
import 'package:note123/ui/common/platform_app_bar.dart';
import 'package:note123/utils/utils.dart';
import 'package:note123/config/app_config.dart';

import '../../config/language_manager.dart';

class RecordDatabasePage extends StatefulWidget {
  const RecordDatabasePage({super.key});

  @override
  State<RecordDatabasePage> createState() => _RecordDatabasePageState();
}

class _RecordDatabasePageState extends State<RecordDatabasePage> {
  List<RecordEntry> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    try {
      _items = await Repository.get().db?.getAllRecords() ?? [];
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l10n.loadFailed}: $e')));
      }
    }

    setState(() => _loading = false);
  }

  String _getTitle(BuildContext context) {
    return '${l10n.database} ${_items.length}';
  }

  // Return color based on type/status
  Color _getItemColor(RecordEntry item) {
    if (item.local.editType == LocalEditType.delete) return Colors.red;
    if (item.local.locked != 0) return Colors.orange;
    return Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87;
  }

  Widget _buildRecordTile(RecordEntry record, int index) {
    // Check if file exists and its size
    String fileInfo = l10n.notExists;
    FileStore? fileStore = Repository.get().fileStore;

    final baseFile = File(fileStore?.getBaseFile(record.uuid) ?? '');
    final workFile = File(fileStore?.getWorkFile(record.uuid) ?? '');

    final file = workFile.existsSync()
        ? workFile
        : baseFile.existsSync()
        ? baseFile
        : null;
    if (file != null) {
      final stat = file.statSync();
      final sizeKB = (stat.size / 1024).toStringAsFixed(1);
      fileInfo = '${sizeKB}KB';
    }

    // After building complete file path
    String fullPath = '${record.local.path}${record.local.name} $fileInfo';
    Color textColor = _getItemColor(record);

    return ListTile(
      dense: true,
      visualDensity: VisualDensity(horizontal: 0, vertical: -4),
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      title: Text(
        "UUID: ${record.uuid}  ${record.local.editType == LocalEditType.delete ? l10n.isDeleted : fullPath}",
        style: TextStyle(fontSize: 12, color: textColor),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(record.uuid),
          Row(
            children: [
              // Time info
              if (record.remote.createAt > 0)
                Text(
                  '${l10n.created}:${Utils.formatTime(record.remote.createAt)}    ',
                  style: TextStyle(fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                ),
              if (record.local.editType == LocalEditType.edit)
                Text(
                  '${l10n.modified}:${Utils.formatTime(record.local.editAt)}    ',
                  style: TextStyle(fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                ),
              if (record.local.editType == LocalEditType.delete)
                Text(
                  '${l10n.deleted}:${Utils.formatTime(record.local.editAt)}    ',
                  style: TextStyle(fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: createPlatformAppBar(title: _getTitle(context)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? Center(child: Text(l10n.noData))
          : ListView.separated(
              itemCount: _items.length,
              separatorBuilder: (context, index) => AppConfig.listViewDivider(context),
              itemBuilder: (context, index) => _buildRecordTile(_items[index], index),
            ),
    );
  }
}
