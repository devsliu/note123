import 'package:flutter/material.dart';
import 'package:note123/filesync/record_tree.dart';
import 'package:note123/filesync/repository.dart';
import 'package:note123/model/record_opened_state.dart';
import 'package:note123/ui/files/record_item_widget.dart';
import 'package:note123/config/language_manager.dart';
import 'package:note123/utils/utils.dart';
import 'package:note123/config/app_config.dart';

/// Slim search box shown above the record list. Typing updates
/// [RecordOpenedState.searchQueryNotifier]; list pages switch to a flat
/// result list rendered by [RecordSearchResultsControl] while it is non-empty.
class RecordSearchBox extends StatefulWidget {
  final bool shrink;
  const RecordSearchBox({super.key, required this.shrink});

  @override
  State<RecordSearchBox> createState() => _RecordSearchBoxState();
}

class _RecordSearchBoxState extends State<RecordSearchBox> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _keyboardVisible = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = MediaQuery.of(context).viewInsets.bottom > 0;
    // Soft keyboard collapsed (back gesture / tap outside): drop focus so the
    // field does not stay focused with the keyboard gone
    if (_keyboardVisible && !visible) {
      _focusNode.unfocus();
    }
    _keyboardVisible = visible;
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    RecordOpenedState.get().searchQueryNotifier.value = "";
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(top: widget.shrink ? 2 : 4, bottom: widget.shrink ? 4 : 6),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        onTapOutside: (_) => _focusNode.unfocus(),
        style: const TextStyle(fontSize: 14),
        onChanged: (v) => RecordOpenedState.get().searchQueryNotifier.value = v.trim(),
        decoration: InputDecoration(
          isDense: true,
          hintText: l10n.searchRecords,
          prefixIcon: const Icon(Icons.search, size: 18),
          prefixIconConstraints: const BoxConstraints(minWidth: 34, minHeight: 34),
          suffixIcon: _controller.text.isEmpty
              ? null
              : IconButton(icon: const Icon(Icons.close, size: 16), onPressed: _clear),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          filled: true,
          fillColor: theme.colorScheme.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: theme.colorScheme.outline.withAlpha(80)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: theme.colorScheme.outline.withAlpha(80)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: theme.colorScheme.primary),
          ),
        ),
      ),
    );
  }
}

/// Flat list of records matching the current search query by title or path
/// (case-insensitive). Shown instead of the normal list controls while
/// the search query is non-empty.
class RecordSearchResultsControl extends StatefulWidget {
  final bool shrink;
  final ValueCallback2<BuildContext, TreeContentFile> openRecordCallback;

  const RecordSearchResultsControl({super.key, required this.shrink, required this.openRecordCallback});

  @override
  State<RecordSearchResultsControl> createState() => _RecordSearchResultsControlState();
}

class _RecordSearchResultsControlState extends State<RecordSearchResultsControl> {
  final RecordTree recordTree = Repository.get().recordTree;

  @override
  void initState() {
    super.initState();
    recordTree.refreshNotifier.addListener(onRefreshChanged);
    RecordOpenedState.get().openedFileNotifier.addListener(onRefreshChanged);
    RecordOpenedState.get().searchQueryNotifier.addListener(onRefreshChanged);
  }

  @override
  void dispose() {
    recordTree.refreshNotifier.removeListener(onRefreshChanged);
    RecordOpenedState.get().openedFileNotifier.removeListener(onRefreshChanged);
    RecordOpenedState.get().searchQueryNotifier.removeListener(onRefreshChanged);
    super.dispose();
  }

  void onRefreshChanged() {
    setState(() {});
  }

  List<TreeContentFile> _matches() {
    final query = RecordOpenedState.get().searchQueryNotifier.value.toLowerCase();
    if (query.isEmpty) return const [];
    return recordTree.sortedFiles.where((f) {
      return f.name.toLowerCase().contains(query) || f.path.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final list = _matches();
    if (list.isEmpty) {
      final theme = Theme.of(context);
      return Center(
        child: Text(l10n.searchNoResults, style: TextStyle(fontSize: 13, color: theme.colorScheme.outline)),
      );
    }
    return ListView.separated(
      itemCount: list.length,
      itemBuilder: (BuildContext context, int index) {
        final file = list[index];
        return FileWidget(
          showIcon: true,
          horizontalPadding: 16.0,
          verticalPadding: widget.shrink ? 4.0 : 10.0,
          content: file,
          isSelected: RecordOpenedState.get().openedFile?.key == file.key,
          onContentPressed: (content) {
            widget.openRecordCallback(context, content as TreeContentFile);
          },
        );
      },
      separatorBuilder: (_, i) => AppConfig.listViewDivider(context),
    );
  }
}
