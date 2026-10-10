import 'package:flutter/material.dart';
import 'package:note123/filesync/database.dart';
import 'package:note123/filesync/table_operate.dart';
import 'package:note123/filesync/repository.dart';
import 'package:note123/ui/common/platform_app_bar.dart';
import 'package:note123/utils/utils.dart';
import 'package:note123/config/app_config.dart';

import '../../config/language_manager.dart';

class RecordOperatesPage extends StatefulWidget {
  const RecordOperatesPage({super.key});

  @override
  State<RecordOperatesPage> createState() => _RecordOperatesPageState();
}

class _RecordOperatesPageState extends State<RecordOperatesPage> {
  List<Operate> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    try {
      _items = await Repository.get().db?.getAllOperates() ?? [];
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l10n.loadFailed}: $e')));
      }
    }

    setState(() => _loading = false);
  }

  String _getTitle(BuildContext context) {
    return '${l10n.operates} ${_items.length}';
  }

  // Return color based on type/status
  Color _getItemColor(Operate item) {
    if (item.type == Operates.typeLocal) return Colors.blue.shade500;
    if (item.type == Operates.typeDownload) return Colors.orange;
    if (item.type == Operates.typeUpload) return Colors.green;
    return Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87;
  }

  Widget _buildRecordTile(Operate record, int index) {
    return ListTile(
      dense: true,
      visualDensity: VisualDensity(horizontal: 0, vertical: -4),
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      title: Text(
        "${record.type}  ${Utils.formatTime(record.time)}",
        style: TextStyle(fontSize: 12, color: _getItemColor(record)),
      ),
      subtitle: Text(record.value, maxLines: 10, softWrap: true),
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
