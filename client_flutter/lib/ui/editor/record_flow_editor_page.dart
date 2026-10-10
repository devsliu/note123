import 'dart:async';
import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:note123/filesync/repository.dart';
import 'package:note123/filesync/record_tree.dart';
import 'package:note123/filesync/local_record_ext.dart';
import 'package:note123/model/record_utils.dart';
import 'package:note123/ui/editor/flow_editor/flow_fixed_toolbar.dart';
import 'package:note123/ui/editor/base_record_edit_page.dart';
import 'package:note123/ui/editor/flow_editor/flow_context_menu.dart';
import 'package:note123/utils/app_logger.dart';
import 'package:note123/config/language_manager.dart';
import 'package:note123/utils/utils.dart';
import 'package:note123/ui/editor/flow_editor/code_block_component.dart';
import 'package:note123/ui/editor/flow_editor/code_block_toolbar_item.dart';
import 'package:note123/ui/editor/flow_editor/code_block_newline.dart';
import 'package:note123/ui/editor/reminder_panel.dart';

/// Shared text style configuration (edit page + diff page).
TextStyleConfiguration buildEditorTextStyle(ThemeData theme) {
  return TextStyleConfiguration(
    text: TextStyle(fontSize: 16, color: theme.colorScheme.onSurface),
    lineHeight: 1,
    applyHeightToFirstAscent: true,
    applyHeightToLastDescent: true,
    leadingDistribution: TextLeadingDistribution.proportional,
  );
}

/// Shared block component builders — paragraph padding zeroed, todo with custom icon, code block.
Map<String, BlockComponentBuilder> buildEditorBlockBuilders(ThemeData theme) {
  return <String, BlockComponentBuilder>{
    ...standardBlockComponentBuilderMap,
    TodoListBlockKeys.type: TodoListBlockComponentBuilder(
      configuration: standardBlockComponentConfiguration.copyWith(
        placeholderText: (_) => AppFlowyEditorL10n.current.toDoPlaceholder,
      ),
      textStyleBuilder: (checked) {
        final baseColor = theme.colorScheme.onSurface;
        if (!checked) return TextStyle(color: baseColor);
        return TextStyle(decoration: TextDecoration.lineThrough, color: theme.colorScheme.onSurfaceVariant);
      },
      iconBuilder: (context, node, onCheck) {
        final checked = node.attributes[TodoListBlockKeys.checked] ?? false;
        final iconColor = checked ? theme.colorScheme.primary : theme.colorScheme.onSurface;
        return Transform.translate(
          offset: const Offset(0, -3),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onCheck,
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(checked ? Icons.check_box : Icons.check_box_outline_blank, size: 22, color: iconColor),
              ),
            ),
          ),
        );
      },
      toggleChildrenTriggers: [LogicalKeyboardKey.shift, LogicalKeyboardKey.shiftLeft, LogicalKeyboardKey.shiftRight],
    ),
    ParagraphBlockKeys.type: ParagraphBlockComponentBuilder(
      configuration: BlockComponentConfiguration(padding: (_) => EdgeInsets.zero),
    ),
    CodeBlockKeys.type: CodeBlockComponentBuilder(),
  };
}

/// Shared editor style (desktop/mobile switch + dark-mode-aware selection color).
EditorStyle buildEditorStyle(ThemeData theme, TextStyleConfiguration textStyleConfiguration) {
  final isDesktop = Utils.isDesktop();
  final isDark = theme.brightness == Brightness.dark;
  final selectionColor = isDark
      ? theme.colorScheme.onSurfaceVariant.withAlpha(200)
      : theme.colorScheme.primary.withAlpha(100);
  return isDesktop
      ? EditorStyle.desktop(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          cursorColor: theme.colorScheme.primary,
          selectionColor: selectionColor,
          textStyleConfiguration: textStyleConfiguration,
        )
      : EditorStyle.mobile(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          cursorColor: theme.colorScheme.primary,
          selectionColor: selectionColor,
          textStyleConfiguration: textStyleConfiguration,
        );
}

class RecordFlowEditorPage extends BaseRecordEditPage {
  const RecordFlowEditorPage({super.key, required super.record, super.closePageCallback});

  @override
  State<RecordFlowEditorPage> createState() => RecordFlowEditorPageState();
}

class RecordFlowEditorPageState<T extends RecordFlowEditorPage> extends BaseRecordEditPageState<T> {
  EditorState editorState = EditorState.blank();
  final FocusNode _focusNode = FocusNode();
  EditorScrollController? editorScrollController;
  Selection? _savedSelection;
  final recordTree = Repository.get().recordTree;
  final GlobalKey<ReminderPanelState> _reminderPanelKey = GlobalKey<ReminderPanelState>();

  StreamSubscription<EditorTransactionValue>? _subscription;

  // Style caches (theme-dependent; rebuilt when theme changes via didChangeDependencies)
  late TextStyleConfiguration _textStyleConfiguration;
  late Map<String, BlockComponentBuilder> _blockComponentBuilders;

  void _rebuildStyleCache() {
    final theme = Theme.of(context);
    _textStyleConfiguration = buildEditorTextStyle(theme);
    _blockComponentBuilders = buildEditorBlockBuilders(theme);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _rebuildStyleCache();
  }

  List<ToolbarItem> get _toolbarItems => [
    undoToolbarItem,
    redoToolbarItem,
    todoListItem,
    codeBlockItem,
    quoteItem,
    bulletedListItem,
    numberedListItem,
    buildTextColorItem(),
    ...markdownFormatItems,
    ...headingItems,
    linkItem,
    // timeToolbarItem,
    // copyToolbarItem,
    // cutToolbarItem,
    // pasteToolbarItem,
    _buildReminderToolbarItem(),
    createInfoToolbarItem(widget.record.uuid),
  ];

  ToolbarItem _buildReminderToolbarItem() {
    return ToolbarItem(
      id: 'editor.reminder',
      group: 0,
      isActive: (_) => true,
      builder: (context, editorState, highlightColor, iconColor, tooltipBuilder) {
        final child = SVGIconItemWidget(
          iconBuilder: (_) => Icon(Icons.notifications_active_outlined, color: iconColor, size: 18),
          isHighlight: false,
          highlightColor: highlightColor,
          iconColor: iconColor,
          onPressed: () => _reminderPanelKey.currentState?.showAddDialog(),
        );
        if (tooltipBuilder != null) {
          return tooltipBuilder(context, 'editor.reminder', l10n.addReminder, child);
        }
        return child;
      },
    );
  }

  void listenContentChange() {
    _subscription?.cancel();
    _subscription = editorState.transactionStream.listen((event) {
      final (time, transaction, options) = event;
      if (time != TransactionTime.after) return;
      if (transaction.operations.isEmpty) return;
      if (options.resolvedSource == TransactionSource.none) return;
      isContentChanged = true;
    });
  }

  void _initDocumentFromContent(String plaintext) {
    Document? document;

    bool isNewRecord = plaintext.isEmpty;
    if (isNewRecord) {
      final title = widget.record.name.isNotEmpty ? widget.record.name : RecordUtils.generateRecordName();

      document = Document.blank()
        ..root.insert(headingNode(level: 1, delta: Delta()..insert(title)), index: 0)
        ..root.insert(dividerNode(), index: 1)
        ..root.insert(paragraphNode(), index: 3);
    } else {
      final trimmed = plaintext.trim();
      if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
        try {
          final map = jsonDecode(trimmed) as Map<String, dynamic>;
          document = Document.fromJson(map);
        } catch (e) {
          AppLogger.e("Failed to parse JSON: $e");
        }
      }

      document ??= Document.blank()..root.insert(paragraphNode(delta: Delta()..insert(plaintext)), index: 0);
    }

    // Preserve selection across document reload (e.g. remote sync refresh)
    final savedSelection = editorState.selection;

    editorState.dispose();
    editorState = EditorState(document: document);
    editorScrollController?.dispose();
    editorScrollController = EditorScrollController(editorState: editorState);
    listenContentChange();

    if (isNewRecord) {
      // New document: place cursor at heading end
      final nodes = document.root.children;
      if (nodes.isNotEmpty) {
        final node = nodes.first;
        final delta = node.delta;
        final len = delta?.toPlainText().length ?? 0;
        editorState.updateSelectionWithReason(
          Selection(
            start: Position(path: [0], offset: len),
            end: Position(path: [0], offset: len),
          ),
        );
      }
      _focusNode.requestFocus();
    } else if (savedSelection != null) {
      // Existing document: restore previous cursor position (clamped to valid range)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        editorState.updateSelectionWithReason(savedSelection);
      });
      if (Utils.isDesktop()) {
        _focusNode.requestFocus();
      }
    }
  }

  @override
  void undo() {
    editorState.undoManager.undo();
  }

  @override
  void redo() {
    editorState.undoManager.redo();
  }

  @override
  void onPageFocusChanged(bool hasFocus) {
    super.onPageFocusChanged(hasFocus);
    if (hasFocus) {
      // Mobile: don't auto-focus when document has content (user taps to edit); empty doc or desktop focuses.
      final hasContent = editorState.document.root.children.any((node) => (node.delta?.toPlainText().length ?? 0) > 0);
      if (Utils.isDesktop() || !hasContent) {
        _focusNode.requestFocus();
      }
      _restoreSelection();
    } else {
      _saveSelection();
    }
  }

  void _saveSelection() {
    final selection = editorState.selection;
    if (selection != null) {
      _savedSelection = selection;
    }
  }

  void _restoreSelection() {
    if (_savedSelection == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (editorState.selection == null) {
        editorState.updateSelectionWithReason(_savedSelection!);
      }
    });
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      _restoreSelection();
    } else {
      _saveSelection();
    }
  }

  @override
  (String content, String name) formatContent() {
    final docJson = editorState.document.toJson();
    final String jsonString = jsonEncode(docJson);
    String name = RecordUtils.getTitleFromDelta(editorState.document);
    if (name.isEmpty) {
      name = RecordUtils.generateRecordName();
    }
    return (jsonString, name);
  }

  @override
  Widget buildContentWidget(String plaintext, bool reload) {
    // First build after state change → (re)initialize document with fresh plaintext
    if (reload) {
      _initDocumentFromContent(plaintext);
    }

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FixedToolbar(
          scrollable: true,
          items: _toolbarItems,
          editorState: editorState,
          toolbarHeight: 30,
          iconColor: theme.colorScheme.onSurface,
          activeColor: theme.colorScheme.primary,
        ),
        Divider(height: 1, color: theme.colorScheme.outline.withAlpha(50)),
        Expanded(child: _buildEditorWidget(theme, _blockComponentBuilders, _textStyleConfiguration)),
        ReminderPanel(key: _reminderPanelKey, uuid: widget.record.uuid),
        _LastModifyTimeWidget(uuid: widget.record.uuid),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _subscription?.cancel();
    editorScrollController?.dispose();
    super.dispose();
    editorState.dispose();
  }

  Widget _buildEditorWidget(
    ThemeData theme,
    Map<String, BlockComponentBuilder> blockComponentBuilders,
    TextStyleConfiguration textStyleConfiguration,
  ) {
    final editor = AppFlowyEditor(
      editorState: editorState,
      focusNode: _focusNode,
      blockComponentBuilders: blockComponentBuilders,
      characterShortcutEvents: [codeBlockInsertNewLine, ...standardCharacterShortcutEvents],
      editorScrollController: editorScrollController,
      // Mobile: disable autoScrollEdgeOffset (set 0). Default 220 is too large on phone screens;
      // non-drag-selection scenarios (tap/keyboard pop-up) also trigger autoScroll → poor UX.
      // When actually dragging selection handles, user's finger is already at the edge and can scroll.
      autoScrollEdgeOffset: Utils.isDesktop() ? 220 : 0,
      header: const SizedBox(height: 16),
      editorStyle: buildEditorStyle(theme, textStyleConfiguration),
    );

    if (Utils.isDesktop()) {
      return editor;
    }

    final scrollController = editorScrollController;
    if (scrollController == null) {
      return editor;
    }

    return MobileFloatingToolbarBuilder.build(
      context: context,
      editorState: editorState,
      editorScrollController: scrollController,
      editor: editor,
    );
  }
}

ToolbarItem createInfoToolbarItem(String? recordUuid) {
  return ToolbarItem(
    id: 'editor.info',
    group: 0,
    isActive: (_) => true,
    builder: (context, editorState, highlightColor, iconColor, tooltipBuilder) {
      final child = SVGIconItemWidget(
        iconBuilder: (_) => Icon(Icons.info_outlined, color: iconColor, size: 18),
        isHighlight: false,
        highlightColor: highlightColor,
        iconColor: iconColor,
        onPressed: () async {
          if (recordUuid == null) return;
          final record = await Repository.get().db?.getRecord(recordUuid);
          if (record == null || !context.mounted) return;
          final buffer = StringBuffer()
            ..writeln(record.uuid)
            ..writeln(record.localPath)
            ..writeln(record.localName)
            ..writeln('version: ${record.remoteVersion}')
            ..writeln('md5: ${record.remoteMd5}')
            ..writeln('createAt: ${Utils.formatTime(record.remoteCreateAt)}')
            ..writeln('editAt: ${Utils.formatTime(record.localEditAt)}')
            ..writeln('fileEditAt: ${Utils.formatTime(record.localFileEditAt)}')
            ..writeln('locked: ${record.localLocked}');
          showDialog(
            context: context,
            builder: (context) => Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
              child: Padding(padding: EdgeInsets.all(8), child: Text(buffer.toString())),
            ),
          );
        },
      );
      if (tooltipBuilder != null) {
        return tooltipBuilder(context, 'editor.info', 'Note Info', child);
      }
      return child;
    },
  );
}

class _LastModifyTimeWidget extends StatefulWidget {
  final String uuid;
  const _LastModifyTimeWidget({required this.uuid});

  @override
  State<_LastModifyTimeWidget> createState() => _LastModifyTimeWidgetState();
}

class _LastModifyTimeWidgetState extends State<_LastModifyTimeWidget> {
  late final ValueNotifier<List<RecordEvent>> _notifier;

  @override
  void initState() {
    super.initState();
    _notifier = Repository.get().recordTree.refreshNotifier;
    _notifier.addListener(_onEvents);
  }

  @override
  void dispose() {
    _notifier.removeListener(_onEvents);
    super.dispose();
  }

  void _onEvents() {
    // Only rebuild for events touching current record; skip sync/rename of other records or folders.
    final events = _notifier.value;
    if (events.isNotEmpty && !events.any((e) => e.value2 == widget.uuid)) {
      return;
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fileNode = Repository.get().recordTree.findFile(widget.uuid);
    if (fileNode == null) return const SizedBox.shrink();
    final record = fileNode.record;
    final hasConflict = record.syncConflict;
    final color = hasConflict ? theme.colorScheme.error : theme.colorScheme.onSurface.withAlpha(150);
    final conflictLabel = hasConflict ? "  [${l10n.hasConflict}]" : "";
    final version = record.localVersion != record.remoteVersion
        ? 'v${record.localVersion}->v${record.remoteVersion}'
        : 'v${record.localVersion}';
    return Text(
      " $version $conflictLabel ${l10n.lastModify}: ${Utils.formatTime(record.localEditAt)}",
      style: TextStyle(fontSize: 12, color: color),
    );
  }
}
