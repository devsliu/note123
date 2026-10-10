import 'package:note123/filesync/record_tree.dart';
import 'package:note123/filesync/repository.dart';
import 'package:note123/model/record_opened_state.dart';
import 'package:flutter/material.dart';
import 'package:note123/ui/files/record_item_widget.dart';
import 'package:note123/config/language_manager.dart';
import 'package:note123/utils/utils.dart';
import 'package:note123/config/app_config.dart';

class RecordFilesFlatControl extends StatefulWidget {
  final bool shrink;
  final ValueCallback2<BuildContext, TreeContentFile> onClickRecordAction;

  const RecordFilesFlatControl({super.key, required this.shrink, required this.onClickRecordAction});
  @override
  State<RecordFilesFlatControl> createState() => _RecordFilesFlatControlState();
}

class _RecordFilesFlatControlState extends State<RecordFilesFlatControl> {
  final RecordTree recordTree = Repository.get().recordTree;
  @override
  void initState() {
    super.initState();
    recordTree.refreshNotifier.addListener(onRefreshChanged);
    RecordOpenedState.get().openedFileNotifier.addListener(onRefreshChanged);
    RecordOpenedState.get().openedFolderNotifier.addListener(onOpenedFolderChanged);
  }

  @override
  void dispose() {
    recordTree.refreshNotifier.removeListener(onRefreshChanged);
    RecordOpenedState.get().openedFileNotifier.removeListener(onRefreshChanged);
    RecordOpenedState.get().openedFolderNotifier.removeListener(onOpenedFolderChanged);
    super.dispose();
  }

  void onOpenedFolderChanged() {
    // Update UI when the opened folder changes
    setState(() {});
  }

  void onRefreshChanged() {
    setState(() {});
  }

  void onClickFolder(int index, TreeContentFolder folder) {
    RecordOpenedState.get().setOpenedFolder(folder.path);
  }

  void onClickFile(TreeContentFile record) {
    RecordOpenedState.get().openFile(record.path);
    widget.onClickRecordAction(context, record);
  }

  @override
  Widget build(BuildContext context) {
    final folder = RecordOpenedState.get().openedFolder;
    final node = recordTree.findFolder(folder.path);
    final count = node?.children.length ?? 0;

    return ListView.separated(
      itemCount: count,
      itemBuilder: (BuildContext context, int index) {
        if (count <= index) {
          return Text("${l10n.outOfBounds}$index");
        }
        return buildItemWidget(context, index, node!.children[index] as TreeNode);
      },
      separatorBuilder: (_, i) => AppConfig.listViewDivider(context),
    );
  }

  Widget buildItemWidget(BuildContext context, int index, TreeNode node) {
    TreeContent file = node.content;
    if (file is TreeContentFile) {
      return FileWidget(
        showIcon: true,
        horizontalPadding: 16.0,
        verticalPadding: widget.shrink ? 4.0 : 12.0,
        content: file,
        isSelected: RecordOpenedState.get().openedFile?.key == file.key,
        onContentPressed: (content) {
          onClickFile(content as TreeContentFile);
        },
      );
    } else {
      return FolderWidget(
        horizontalPadding: 16.0,
        verticalPadding: widget.shrink ? 4.0 : 12.0,
        node: node,
        isSelected: false,
        onContentPressed: (content) {
          onClickFolder(index, content as TreeContentFolder);
        },
      );
    }
  }
}
