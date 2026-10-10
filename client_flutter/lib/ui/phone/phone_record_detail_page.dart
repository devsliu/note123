import 'package:note123/filesync/record_tree.dart';
import 'package:note123/model/record_opened_state.dart';
import 'package:flutter/material.dart';
import 'package:note123/ui/editor/record_flow_editor_page.dart';

class PhoneRecordDetailPage extends RecordFlowEditorPage {
  const PhoneRecordDetailPage({super.key, required super.record});

  @override
  State<PhoneRecordDetailPage> createState() => PhoneRecordDetailPageState();
}

class PhoneRecordDetailPageState<T extends PhoneRecordDetailPage> extends RecordFlowEditorPageState<T> {
  @override
  void initState() {
    super.initState();
    RecordOpenedState.get().openFile(widget.record.uuid);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      RecordOpenedState.get().closeFile(widget.record.uuid);
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: buildAppBar(context, widget.record, this), body: super.build(context));
  }

  void onClickClose() {
    Navigator.pop(context);
  }

  AppBar buildAppBar(BuildContext context, TreeContentFile record, RecordFlowEditorPageState state) {
    return AppBar(
      leading: IconButton(onPressed: onClickClose, icon: Icon(Icons.close_outlined)),
      titleSpacing: 0,
      title: ValueListenableBuilder<List<RecordEvent>>(
        valueListenable: recordTree.refreshNotifier,
        builder: (context, value, child) =>
            Text(record.path + record.name, overflow: TextOverflow.fade, style: TextStyle(fontSize: 16.0)),
      ),
      actions: [
        if (pageState.isNormal) IconButton(onPressed: () => {state.saveRecord()}, icon: Icon(Icons.done_outlined)),
        SizedBox(width: 8),
      ],
    );
  }
}
