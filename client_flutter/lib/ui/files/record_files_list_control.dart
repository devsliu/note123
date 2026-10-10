import 'package:note123/filesync/record_tree.dart';
import 'package:note123/filesync/repository.dart';
import 'package:note123/model/record_opened_state.dart';
import 'package:flutter/material.dart';
import 'package:note123/ui/files/record_item_widget.dart';
import 'package:note123/config/language_manager.dart';
import 'package:note123/utils/utils.dart';
import 'package:note123/config/app_config.dart';

class RecordFilesListControl extends StatefulWidget {
  final ValueCallback2<BuildContext, TreeContentFile>? onClickRecordAction;
  final bool showDivider;
  final bool shrink;

  const RecordFilesListControl({super.key, required this.shrink, this.onClickRecordAction, this.showDivider = false});
  @override
  State<RecordFilesListControl> createState() => _RecordFilesListControlState();
}

class _RecordFilesListControlState extends State<RecordFilesListControl> {
  final RecordTree recordTree = Repository.get().recordTree;
  @override
  void initState() {
    super.initState();
    recordTree.refreshNotifier.addListener(onRefreshChanged);
    RecordOpenedState.instance.openedFileNotifier.addListener(onRefreshChanged);
  }

  @override
  void dispose() {
    recordTree.refreshNotifier.removeListener(onRefreshChanged);
    RecordOpenedState.instance.openedFileNotifier.removeListener(onRefreshChanged);
    super.dispose();
  }

  void onRefreshChanged() {
    setState(() {});
  }

  void onClickFile(BuildContext context, TreeContentFile record) {
    if (widget.onClickRecordAction != null) {
      widget.onClickRecordAction!(context, record);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = recordTree.sortedFiles;
    final count = list.length;

    return ListView.separated(
      itemCount: count,
      itemBuilder: (BuildContext context, int index) {
        if (count <= index) {
          return Text("${l10n.outOfBounds}$index");
        }
        TreeContentFile file = list[index];

        return FileWidget(
          showIcon: false,
          horizontalPadding: 16.0,
          verticalPadding: widget.shrink ? 4.0 : 10.0,
          content: list[index],
          isSelected: recordTree.openedFile?.key == file.key,
          onContentPressed: (content) {
            onClickFile(context, content as TreeContentFile);
          },
        );
      },
      separatorBuilder: (_, i) => widget.showDivider ? AppConfig.listViewDivider(context) : SizedBox.shrink(),
    );
  }
}
