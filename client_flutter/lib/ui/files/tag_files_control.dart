import 'dart:async';

import 'package:flutter/material.dart';
import 'package:note123/filesync/record_tree.dart';
import 'package:note123/filesync/repository.dart';
import 'package:note123/filesync/tag_tree.dart';
import 'package:note123/model/record_opened_state.dart';
import 'package:note123/ui/files/record_item_widget.dart';
import 'package:note123/utils/utils.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';

/// Displays tags as expandable tiles, each revealing the records that carry
/// the tag. All tiles are expanded by default.
class TagFilesControl extends StatefulWidget {
  final bool shrink;
  final ValueCallback2<BuildContext, String> openRecordCallback;

  const TagFilesControl({super.key, required this.shrink, required this.openRecordCallback});

  @override
  State<TagFilesControl> createState() => _TagFilesControlState();
}

/// Tag folder row — same as TreeFolderWidget but suppresses right-click and
/// long-press context menus, since tags are virtual grouping nodes.
class _TagFolderWidget extends TreeFolderWidget {
  _TagFolderWidget({
    required super.node,
    required super.leftPadding,
    required super.rightPadding,
    required super.verticalPadding,
    required super.isSelected,
    required super.onContentPressed,
    super.folderIcon,
  });

  @override
  void onLongPressFile(BuildContext context, TreeContent file, Offset position) {
    // Tag folders don't have context menus.
  }
}

class _TagFilesControlState extends State<TagFilesControl> {
  final recordTree = Repository.get().recordTree;
  final TreeViewController _treeController = TreeViewController();
  StreamSubscription<TagTreeEvent>? _tagSub;

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
    _tagSub = Repository.get().tagTree.onEvent.listen(_onTagEvent);
    RecordOpenedState.get().openedFileNotifier.addListener(_onFileChanged);
  }

  @override
  void dispose() {
    _tagSub?.cancel();
    RecordOpenedState.get().openedFileNotifier.removeListener(_onFileChanged);
    super.dispose();
  }

  void _onTagEvent(TagTreeEvent event) {
    switch (event.type) {
      case TagTreeEvent.typeRebuild:
        _buildInitialTree();
        break;
      case TagTreeEvent.typeUpsert:
      case TagTreeEvent.typeRemove:
        _syncChildren();
        break;
    }
    if (mounted) setState(() {});
  }

  void _onFileChanged() {
    if (mounted) setState(() {});
  }

  /// Build the tag tree once. Each tag starts at the expanded state stored on
  /// the Tag object, so state survives State recreation (tab switches etc.).
  void _buildInitialTree() {
    final tags = Repository.get().tagTree.tags;
    final nodes = <TreeViewNode<TreeContent>>[];
    for (final tag in tags) {
      final node = _buildTagNode(tag, expanded: tag.expanded);
      _nodeByName[tag.name] = node;
      nodes.add(node);
    }
    _tagNodes = nodes;
  }

  /// Build a single tag node. Children are freshly created from each RecordEntry
  /// so TagFilesControl doesn't depend on RecordTree's internal TreeContentFile instances.
  TreeViewNode<TreeContent> _buildTagNode(Tag tag, {required bool expanded}) {
    final tagChildren = <TreeViewNode<TreeContent>>[];
    for (final entry in tag.records) {
      tagChildren.add(TreeNode(TreeContentFile(entry)));
    }
    return TreeViewNode<TreeContent>(
      TreeContentFolder('tag:${tag.name}/', tag.name),
      children: tagChildren,
      expanded: expanded,
    );
  }

  /// Refresh children in place for existing tags, add new tags, remove deleted tags.
  void _syncChildren() {
    final tags = Repository.get().tagTree.tags;
    final newNames = <String>{};
    for (final tag in tags) {
      newNames.add(tag.name);
      final existing = _nodeByName[tag.name];
      if (existing != null) {
        // Update children in place; pull expanded state from the live TreeView
        // node so in-flight toggle animations aren't clobbered, and sync it
        // back to Tag for consistency.
        final expanded = existing.isExpanded;
        Repository.get().tagTree.setExpanded(tag.name, expanded);
        existing.children
          ..clear()
          ..addAll(_buildTagNode(tag, expanded: expanded).children);
      } else {
        final node = _buildTagNode(tag, expanded: tag.expanded);
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
      widget.openRecordCallback(context, content.uuid);
      return;
    }
    // Tag folder: resolve the actual TreeViewNode from the controller.
    final node = _treeController.getNodeFor(content);
    if (node != null) {
      _treeController.toggleNode(node);
      // Persist expanded state back to TagTree so it survives tab switches.
      Repository.get().tagTree.setExpanded(content.name, node.isExpanded);
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
            final isSelected = RecordOpenedState.get().openedFile?.key == content.key;
            Widget child;
            if (isFile) {
              child = TreeFileWidget(
                node: node,
                showIcon: true,
                leftPadding: 8.0,
                rightPadding: 12.0,
                verticalPadding: verticalPadding,
                isSelected: isSelected,
                onContentPressed: _onContentPressed,
              );
            } else {
              child = _TagFolderWidget(
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
