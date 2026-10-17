import 'package:flutter/material.dart';
import 'package:note123/filesync/database.dart';
import 'package:note123/filesync/repository.dart';
import 'package:note123/filesync/table_record.dart';
import 'package:note123/ui/common/platform_app_bar.dart';
import 'package:note123/utils/utils.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';

import '../../config/language_manager.dart';

/// Excel-like grid over the operates log table: pinned index column and header
/// row, horizontal scrolling body. Tapping a cell shows the full value.
class RecordOperatesPage extends StatefulWidget {
  const RecordOperatesPage({super.key});

  @override
  State<RecordOperatesPage> createState() => _RecordOperatesPageState();
}

class _RecordOperatesPageState extends State<RecordOperatesPage> {
  static const double _indexColWidth = 48;
  static const double _rowHeight = 26;
  static const _cellPadding = EdgeInsets.symmetric(horizontal: 8);
  static const _cellStyle = TextStyle(fontSize: 11, height: 1.2);

  List<Operate> _items = [];
  bool _loading = true;

  late final List<({String label, double width, String Function(Operate) get})> _columns = [
    (label: 'type', width: 80, get: (r) => r.type),
    (label: 'time', width: 140, get: (r) => Utils.formatTime(r.time)),
    (label: 'value', width: 400, get: (r) => r.value),
  ];

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

  Color _getRowColor(Operate item) {
    if (item.type == Operates.typeLocal) return Colors.blue.shade500;
    if (item.type == Operates.typeDownload) return Colors.orange;
    if (item.type == Operates.typeUpload) return Colors.green;
    if (item.type == Operates.typeError) return Colors.red;
    return Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87;
  }

  void _showCell(String label, String value) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(label, style: const TextStyle(fontSize: 13)),
        content: SingleChildScrollView(child: SelectableText(value, style: _cellStyle)),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.cancel))],
      ),
    );
  }

  Widget _cell(String label, String text, {Color? color, Color? bgColor, bool bold = false}) {
    return InkWell(
      onTap: () => _showCell(label, text),
      child: Container(
        padding: _cellPadding,
        alignment: Alignment.centerLeft,
        color: bgColor,
        child: Text(
          text,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: bold ? _cellStyle.copyWith(fontWeight: FontWeight.w600) : _cellStyle.copyWith(color: color),
        ),
      ),
    );
  }

  TableViewCell _buildCell(BuildContext context, TableVicinity vicinity) {
    final theme = Theme.of(context);
    final headerBg = theme.colorScheme.surfaceContainerHighest.withAlpha(120);

    if (vicinity.row == 0) {
      final label = vicinity.column == 0 ? 'id' : _columns[vicinity.column - 1].label;
      return TableViewCell(child: _cell(label, label, bgColor: headerBg, bold: true));
    }
    final item = _items[vicinity.row - 1];
    if (vicinity.column == 0) {
      return TableViewCell(child: _cell('id', '${item.id}', color: _getRowColor(item)));
    }
    final col = _columns[vicinity.column - 1];
    return TableViewCell(child: _cell(col.label, col.get(item), color: _getRowColor(item)));
  }

  TableSpan _buildColumnSpan(int index) {
    return TableSpan(
      extent: FixedTableSpanExtent(index == 0 ? _indexColWidth : _columns[index - 1].width),
      foregroundDecoration: TableSpanDecoration(
        border: TableSpanBorder(trailing: BorderSide(color: Theme.of(context).dividerColor.withAlpha(40), width: 0.5)),
      ),
    );
  }

  TableSpan _buildRowSpan(int index) {
    return TableSpan(
      extent: const FixedTableSpanExtent(_rowHeight),
      foregroundDecoration: TableSpanDecoration(
        border: TableSpanBorder(trailing: BorderSide(color: Theme.of(context).dividerColor.withAlpha(40), width: 0.5)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: createPlatformAppBar(title: '${l10n.operates} ${_items.length}'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? Center(child: Text(l10n.noData))
          : TableView.builder(
              pinnedRowCount: 1,
              pinnedColumnCount: 1,
              columnCount: _columns.length + 1,
              rowCount: _items.length + 1,
              columnBuilder: _buildColumnSpan,
              rowBuilder: _buildRowSpan,
              cellBuilder: _buildCell,
            ),
    );
  }
}
