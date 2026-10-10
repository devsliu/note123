import 'package:note123/filesync/record_tree.dart';
import 'package:note123/filesync/repository.dart';
import 'package:flutter/material.dart';
import 'package:note123/ui/files/record_item_widget.dart';
import 'package:note123/utils/app_logger.dart';
import 'package:note123/utils/utils.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';

class RecordFilesTreeControl extends StatefulWidget {
  static final ValueNotifier<int> collapseAll = ValueNotifier<int>(0);

  final bool shrink;
  final ValueCallback2<BuildContext, TreeContentFile>? onClickRecordAction;

  const RecordFilesTreeControl({super.key, required this.shrink, this.onClickRecordAction});

  @override
  State<RecordFilesTreeControl> createState() => _RecordFilesTreeControlState();

  double get verticalPadding2 => shrink ? 2.00 : 8.0;
}

class _RecordFilesTreeControlState extends State<RecordFilesTreeControl> {
  final RecordTree recordTree = Repository.get().recordTree;

  final TreeViewController _treeController = TreeViewController();

  /// Convert RecordTree to recursive TreeViewNode structure

  void onEventChanged() {
    setState(() {});
  }

  void onFolderChanged() {
    final folder = recordTree.openedFolder;
    final treeViewNode = _treeController.getNodeFor(folder);
    if (treeViewNode != null) {
      if (!_treeController.isExpanded(treeViewNode) && _treeController.isActive(treeViewNode)) {
        //isActive prevents expanding child nodes when parent isn't expanded
        _treeController.expandNode(treeViewNode);
        AppLogger.i('expand folder: $folder');
      }
    }
  }

  void onFileChanged() {
    setState(() {});
  }

  void onCollapseAll() {
    _treeController.collapseAll();
  }

  @override
  void initState() {
    super.initState();
    recordTree.refreshNotifier.addListener(onEventChanged);
    recordTree.openedFolderNotifier.addListener(onFolderChanged);
    recordTree.openedFileNotifier.addListener(onFileChanged);
    RecordFilesTreeControl.collapseAll.addListener(onCollapseAll);
  }

  @override
  void dispose() {
    recordTree.refreshNotifier.removeListener(onEventChanged);
    recordTree.openedFolderNotifier.removeListener(onFolderChanged);
    recordTree.openedFileNotifier.removeListener(onFileChanged);
    RecordFilesTreeControl.collapseAll.removeListener(onCollapseAll);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return TreeView<TreeContent>(
          tree: recordTree.children,
          controller: _treeController,
          indentation: TreeViewIndentationType.none,
          diagonalDragBehavior: DiagonalDragBehavior.none,
          horizontalDetails: const ScrollableDetails.horizontal(physics: NeverScrollableScrollPhysics()),
          onNodeToggle: (TreeViewNode<TreeContent> node) {
            if (node.content is TreeContentFolder) {
              // _treeController.toggleNode(node);
              // node.isExpanded = node.isExpanded;
            }
          },
          treeNodeBuilder: (context, node, animationStyle) {
            return buildItemWidget(context, node, constraints.maxWidth);
          },
          treeRowBuilder: (node) => TreeRow(extent: FixedTreeRowExtent(24.0 + widget.verticalPadding2 * 2)),
        );
      },
    );
  }

  void onClickFolder(TreeContentFolder node) {
    final treeViewNode = _treeController.getNodeFor(node);
    if (treeViewNode != null) {
      _treeController.toggleNode(treeViewNode);
      if (!treeViewNode.isExpanded) {
        recordTree.setOpenedFolder(node.dir);
      } else {
        recordTree.setOpenedFolder(node.path);
      }
    }
  }

  void onClickFile(TreeContentFile record) {
    if (widget.onClickRecordAction != null) {
      Repository.get().recordTree.setOpenedFile(record.path);
      widget.onClickRecordAction!(context, record);
    }
  }

  Widget buildItemWidget(BuildContext context, TreeViewNode<TreeContent> node, double width) {
    final TreeContent file = node.content;
    final isSelected = recordTree.openedFile?.key == file.key;
    Widget child = (file is TreeContentFile)
        ? TreeFileWidget(
            node: node,
            horizontalPadding: 8.0,
            verticalPadding: widget.verticalPadding2,
            showIcon: true,
            isSelected: isSelected,
            onContentPressed: (content) {
              if (content is TreeContentFile) {
                onClickFile(content);
              } else {
                onClickFolder(content as TreeContentFolder);
              }
            },
          )
        : TreeFolderWidget(
            node: node,
            horizontalPadding: 8.0,
            verticalPadding: widget.verticalPadding2,
            isSelected: isSelected,
            onContentPressed: (content) {
              if (content is TreeContentFile) {
                onClickFile(content);
              } else {
                onClickFolder(content as TreeContentFolder);
              }
            },
          ); // 👈 Don't forget to add semicolon at the end!

    return SizedBox(
      key: file is TreeContentFile ? ValueKey("file:${file.key}${file.editAt}") : ValueKey("folder:${file.key}"),
      width: width,
      child: child,
    );
  }
}
