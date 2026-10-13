import 'package:flutter/material.dart';
import 'package:note123/filesync/record_tree.dart';
import 'package:note123/filesync/repository.dart';
import 'package:note123/filesync/tag_tree.dart';
import 'package:note123/ui/files/record_item_widget.dart';
import 'package:note123/utils/utils.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';

/// Displays tags as expandable tiles, each revealing the records that carry
/// the tag. All tiles are expanded by default.
class TagFilesControl extends StatefulWidget {
  final bool shrink;
  final ValueCallback2<BuildContext, TreeContentFile> openRecordCallback;

  const TagFilesControl({super.key, required this.shrink, required this.openRecordCallback});

  @override
  State<TagFilesControl> createState() => _TagFilesControlState();
}

class _TagFilesControlState extends State<TagFilesControl> {
  final recordTree = Repository.get().recordTree;
  final TreeViewController _treeController = TreeViewController();

  /// Stable tree nodes. Created once in initState with all tags expanded.
  /// Subsequent refreshes only update children (records), never replace nodes,
  /// so expanded state is preserved.
  List<TreeViewNode<TreeContent>> _tagNodes = const [];

  /// Map of tag name → TreeViewNode, used to find the right node when
  /// refreshing so we can update children in place.
  final Map<String, TreeViewNode<TreeContent>> _nodeByName = {};

  @override
  void initState() {
    super.initState();
    _buildInitialTree();
    recordTree.refreshNotifier.addListener(_onRefresh);
  }

  @override
  void dispose() {
    recordTree.refreshNotifier.removeListener(_onRefresh);
    super.dispose();
  }

  void _onRefresh() {
    _syncChildren();
    if (mounted) setState(() {});
  }

  /// Build the tag tree once. All tags start expanded.
  void _buildInitialTree() {
    final tags = recordTree.tagTree.tags;
    final nodes = <TreeViewNode<TreeContent>>[];
    for (final tag in tags) {
      final node = _buildTagNode(tag, expanded: true);
      _nodeByName[tag.name] = node;
      nodes.add(node);
    }
    _tagNodes = nodes;
  }

  /// Build a single tag node. Children are looked up from findFile so we reuse
  /// the same TreeContentFile instances that RecordTree already maintains.
  TreeViewNode<TreeContent> _buildTagNode(Tag tag, {required bool expanded}) {
    final tagChildren = <TreeViewNode<TreeContent>>[];
    for (final entry in tag.records) {
      final file = recordTree.findFile(entry.uuid);
      if (file != null) {
        tagChildren.add(TreeNode(file));
      }
    }
    return TreeViewNode<TreeContent>(
      TreeContentFolder('tag:${tag.name}/', tag.name),
      children: tagChildren,
      expanded: expanded,
    );
  }

  /// Refresh children in place for existing tags, add new tags, remove deleted tags.
  void _syncChildren() {
    final tags = recordTree.tagTree.tags;
    final newNames = <String>{};
    for (final tag in tags) {
      newNames.add(tag.name);
      final existing = _nodeByName[tag.name];
      if (existing != null) {
        // Update children in place; preserve expanded state.
        final expanded = existing.isExpanded;
        existing.children
          ..clear()
          ..addAll(_buildTagNode(tag, expanded: expanded).children);
      } else {
        final node = _buildTagNode(tag, expanded: true);
        _nodeByName[tag.name] = node;
        _tagNodes.add(node);
      }
    }
    // Remove tags that no longer exist.
    _nodeByName.removeWhere((name, node) {
      if (!newNames.contains(name)) {
        _tagNodes.remove(node);
        return true;
      }
      return false;
    });
  }

  void _onContentPressed(TreeContent content) {
    if (content is TreeContentFile) {
      widget.openRecordCallback(context, content);
      return;
    }
    // Tag folder: resolve the actual TreeViewNode from the controller.
    // RecordFilesTreeControl uses the same pattern — the InkWell wraps
    // around a TreeContent, not the TreeViewNode, so we must look it up.
    final node = _treeController.getNodeFor(content);
    if (node != null) {
      _treeController.toggleNode(node);
    }
  }

  @override
  Widget build(BuildContext context) {
    final verticalPadding = widget.shrink ? 2.0 : 8.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        return TreeView<TreeContent>(
          tree: _tagNodes,
          controller: _treeController,
          indentation: TreeViewIndentationType.none,
          diagonalDragBehavior: DiagonalDragBehavior.none,
          horizontalDetails: const ScrollableDetails.horizontal(physics: NeverScrollableScrollPhysics()),
          treeNodeBuilder: (context, node, animationStyle) {
            final content = node.content;
            final isFile = content is TreeContentFile;
            Widget child;
            if (isFile) {
              child = TreeFileWidget(
                node: node,
                showIcon: false,
                leftPadding: 8.0,
                rightPadding: 12.0,
                verticalPadding: verticalPadding,
                isSelected: false,
                onContentPressed: _onContentPressed,
              );
            } else {
              child = TreeFolderWidget(
                node: node,
                leftPadding: 12.0,
                rightPadding: 12.0,
                verticalPadding: verticalPadding,
                isSelected: false,
                onContentPressed: _onContentPressed,
                folderIcon: Text('#', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              );
            }
            return SizedBox(
              key: ValueKey('${isFile ? 'file' : 'tag'}:${content.key}'),
              width: constraints.maxWidth,
              child: child,
            );
          },
          treeRowBuilder: (node) => TreeRow(extent: FixedTreeRowExtent(24.0 + verticalPadding * 2)),
        );
      },
    );
  }
}
