import 'package:flutter/material.dart';
import 'package:note123/filesync/record_tree.dart';
import 'package:note123/model/record_opened_state.dart';
import 'package:note123/ui/phone/phone_record_detail_page.dart';
import 'package:note123/config/language_manager.dart';
import 'package:note123/config/theme.dart';

class PadRecordDetailPage extends StatefulWidget {
  const PadRecordDetailPage({super.key});

  @override
  PadRecordDetailPageState createState() => PadRecordDetailPageState();
}

class PadRecordDetailPageState extends State<PadRecordDetailPage> {
  TreeContentFile? _record;

  void setRecord(TreeContentFile? record) {
    _record = record;
    final uuid = record?.uuid;
    if (uuid != null && uuid.isNotEmpty) {
      RecordOpenedState.get().openFile(uuid);
    } else {
      RecordOpenedState.get().closeFile(RecordOpenedState.get().openedFileNotifier.value);
    }
    setState(() {});
  }

  void onClickClose() {
    setRecord(null);
  }

  @override
  Widget build(BuildContext context) {
    if (_record == null) {
      return Container(
        color: gAppTheme.data.colorScheme.surface,
        child: Center(
          child: Text(
            l10n.pleaseSelectRecord,
            style: TextStyle(color: gAppTheme.data.colorScheme.onSurface.withAlpha(180), fontSize: 16),
          ),
        ),
      );
    }
    return _PadRecordEditPage(key: Key(_record!.uuid), record: _record!, onClickClose: onClickClose);
  }
}

class _PadRecordEditPage extends PhoneRecordDetailPage {
  final VoidCallback onClickClose;
  const _PadRecordEditPage({super.key, required super.record, required this.onClickClose});

  @override
  PhoneRecordDetailPageState createState() => _PadRecordEditPageState();
}

class _PadRecordEditPageState extends PhoneRecordDetailPageState<_PadRecordEditPage> {
  @override
  void onClickClose() {
    widget.onClickClose();
  }

  @override
  void didUpdateWidget(_PadRecordEditPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When widget updates, ensure record parameter changes are handled correctly
    if (oldWidget.record.uuid != widget.record.uuid) {
      // Force rebuild of child widget
      setState(() {});
    }
  }
}
