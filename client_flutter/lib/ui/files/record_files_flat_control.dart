import 'package:note123/filesync/record_tree.dart';
import 'package:note123/filesync/repository.dart';
import 'package:note123/model/record_opened_state.dart';
import 'package:flutter/material.dart';
import 'package:note123/ui/files/record_item_widget.dart';
import 'package:note123/config/language_manager.dart';
import 'package:note123/utils/utils.dart';
import 'package:note123/config/app_config.dart';
import 'package:note123/filesync/record_ext.dart';

class RecordFilesFlatControl extends StatefulWidget {
  final bool shrink;
  final ValueCallback2<BuildContext, TreeContentFile> openRecordCallback;

  const RecordFilesFlatControl({super.key, required this.shrink, required this.openRecordCallback});
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

  void onClickFile(BuildContext context, TreeContentFile record) {
    widget.openRecordCallback(context, record);
  }

  @override
  Widget build(BuildContext context) {
    final folder = RecordOpenedState.get().openedFolder;
    final node = recordTree.findFolder(folder.path);
    final children = node?.children ?? [];
    final count = children.length;
    final isRoot = folder.path == "/";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isRoot) _buildPathRow(context, folder.path),
        if (!isRoot) AppConfig.listViewDivider(context),
        Expanded(
          child: ListView.separated(
            itemCount: count,
            itemBuilder: (BuildContext context, int index) {
              if (count <= index) {
                return Text("${l10n.outOfBounds}$index");
              }
              return buildItemWidget(context, index, children[index] as TreeNode);
            },
            separatorBuilder: (_, i) => AppConfig.listViewDivider(context),
          ),
        ),
      ],
    );
  }

  Widget _buildPathRow(BuildContext context, String path) {
    return InkWell(
      onTap: () => RecordOpenedState.get().setOpenedFolder(dirname(path)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            Icon(Icons.arrow_upward, size: 16),
            SizedBox(width: 6),
            Expanded(child: Text(path, overflow: TextOverflow.fade, maxLines: 1)),
          ],
        ),
      ),
    );
  }

  Widget buildItemWidget(BuildContext context, int index, TreeNode node) {
    TreeContent file = node.content;
    if (file is TreeContentFile) {
      return FileWidget(
        showIcon: true,
        leftPadding: 12.0,
        rightPadding: 12.0,
        verticalPadding: widget.shrink ? 4.0 : 12.0,
        content: file,
        isSelected: RecordOpenedState.get().openedFile?.key == file.key,
        onContentPressed: (content) {
          onClickFile(context, content as TreeContentFile);
        },
      );
    } else {
      return FolderWidget(
        leftPadding: 12.0,
        rightPadding: 12.0,
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
