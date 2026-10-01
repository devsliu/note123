import 'package:note123/filesync/record_tree.dart';
import 'package:note123/filesync/local_record_ext.dart';
import 'package:note123/filesync/repository.dart';
import 'package:note123/filesync/table_record.dart';
import 'package:note123/ui/files/record_context_menu.dart';
import 'package:flutter/material.dart';
import 'package:note123/utils/utils.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';

abstract class _BaseItemWidget extends StatelessWidget {
  final TreeContent content;
  final bool isSelected;
  final ValueCallback<TreeContent> onContentPressed;
  final RecordTree recordTree = Repository.get().recordTree;
  final double horizontalPadding;
  final double verticalPadding;
  _BaseItemWidget({
    super.key,
    required this.content,
    required this.isSelected,
    required this.onContentPressed,
    required this.horizontalPadding,
    required this.verticalPadding,
  });

  void onLongPressFile(BuildContext context, TreeContent file, Offset position) async {
    // Preserve mobile long-press behavior
    await showRecordContextMenu(context, file, position, onContentPressed);
  }

  final arrowSize = 12.0;
  final iconSize = 16.0;
  final nameSize = 16.0;
  final infoSize = 12.0;

  Widget buildContentWidget(BuildContext context);

  @override
  Widget build(BuildContext context) {
    final TreeContent file = content;
    Offset? lastTapPosition;
    var theme = Theme.of(context);
    return InkWell(
      onTapDown: (details) {
        lastTapPosition = details.globalPosition;
      },
      onTap: () {
        // Handle tap selection logic
        // Execute click event with 200ms delay
        if (file is TreeContentFolder) {
          Future.delayed(const Duration(milliseconds: 180), () {
            onContentPressed(file);
          });
        } else {
          onContentPressed(file);
        }
      },
      // Use onSecondaryTap to respond to right mouse button clicks
      onSecondaryTapDown: (details) {
        onLongPressFile(context, file, details.globalPosition);
      },
      // Also trigger on mobile long-press
      onLongPress: () {
        onLongPressFile(context, file, lastTapPosition ?? Offset.zero);
      },
      hoverColor: theme.colorScheme.primary.withAlpha(50),
      child: Container(
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
        color: isSelected ? theme.colorScheme.primary.withAlpha(70) : Colors.transparent,
        child: buildContentWidget(context),
      ),
    );
  }
}

class FolderWidget extends _BaseItemWidget {
  final TreeViewNode<TreeContent> node;

  FolderWidget({
    super.key,
    required super.isSelected,
    required super.onContentPressed,
    required this.node,
    required super.horizontalPadding,
    required super.verticalPadding,
  }) : super(content: node.content);

  @override
  Widget buildContentWidget(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: buildFolderWidgets(node));
  }

  List<Widget> buildFolderWidgets(TreeViewNode<TreeContent> node) {
    return [
      Icon(node.isExpanded ? Icons.folder_open_outlined : Icons.folder_outlined, size: iconSize),
      const SizedBox(width: 4.0),
      Expanded(
        child: Text(
          content.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: nameSize, textBaseline: TextBaseline.ideographic),
        ),
      ),
      const SizedBox(width: 2.0),

      Opacity(
        opacity: 0.6, // Set 60% opacity
        child: Text("${node.children.length}", style: TextStyle(fontSize: infoSize)),
      ),
    ];
  }
}

class TreeFolderWidget extends FolderWidget {
  TreeFolderWidget({
    super.key,
    required super.isSelected,
    required super.onContentPressed,
    required super.node,
    required super.horizontalPadding,
    required super.verticalPadding,
  });

  @override
  Widget buildContentWidget(BuildContext context) {
    final folderWidgets = buildFolderWidgets(node);
    folderWidgets.insert(
      0,
      AnimatedRotation(
        turns: node.isExpanded ? 0.25 : 0.0,
        // Rotate clockwise 90 degrees when expanded (0.25 turns), back to 0 when collapsed
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        child: Icon(
          Icons.chevron_right, // Pure Windows-style right-pointing arrow
          size: arrowSize,
        ),
      ),
    );
    int depth = node.depth ?? 0;
    double intent = depth * iconSize;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(width: intent),
        ...folderWidgets,
      ],
    );
  }
}

class FileWidget extends _BaseItemWidget {
  final bool showIcon;

  FileWidget({
    super.key,
    required this.showIcon,
    required super.isSelected,
    required super.onContentPressed,
    required super.horizontalPadding,
    required super.verticalPadding,
    required super.content,
  });

  @override
  Widget buildContentWidget(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: buildFileWidgets(content as TreeContentFile, showIcon),
    );
  }

  List<Widget> buildFileWidgets(TreeContentFile file, bool showIcon) {
    return [
      if (showIcon) Icon(Icons.text_snippet_outlined, size: iconSize),
      if (showIcon) const SizedBox(width: 4.0),
      Expanded(
        child: Text(
          file.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: nameSize, textBaseline: TextBaseline.ideographic),
        ),
      ),
      if (file.locked != 0) ...[const SizedBox(width: 4.0), Icon(Icons.lock, size: 12, color: Colors.amber)],
      if (file.record.syncConflict) ...[const SizedBox(width: 4.0), Icon(Icons.warning, size: 14, color: Colors.red)],
      if (file.record.localEditType == LocalEditType.edit && !file.record.syncConflict) ...[
        const SizedBox(width: 4.0),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle),
        ),
      ],
      const SizedBox(width: 4.0),
      Opacity(
        opacity: 0.4,
        child: Text(Utils.formatShortTime(file.editAt), style: TextStyle(fontSize: infoSize)),
      ),
    ];
  }
}

class TreeFileWidget extends FileWidget {
  final TreeViewNode<TreeContent> node;

  TreeFileWidget({
    super.key,
    required super.isSelected,
    required super.onContentPressed,
    required super.horizontalPadding,
    required super.verticalPadding,
    required this.node,
    required super.showIcon,
  }) : super(content: node.content);

  @override
  Widget buildContentWidget(BuildContext context) {
    final widgets = buildFileWidgets(content as TreeContentFile, showIcon);
    int depth = node.depth ?? 0;
    double intent = depth * iconSize + arrowSize;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(width: intent),
        ...widgets,
      ],
    );
  }
}
