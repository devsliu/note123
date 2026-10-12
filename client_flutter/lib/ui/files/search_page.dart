import 'package:flutter/material.dart';
import 'package:note123/filesync/record_tree.dart';
import 'package:note123/filesync/repository.dart';
import 'package:note123/model/record_opened_state.dart';
import 'package:note123/ui/common/platform_app_bar.dart';
import 'package:note123/ui/files/record_item_widget.dart';
import 'package:note123/config/language_manager.dart';
import 'package:note123/utils/utils.dart';
import 'package:note123/config/app_config.dart';

/// Full-page record search: app bar with a back button and a search input,
/// body shows title/path matches. Replaces the whole list page while active.
class SearchPage extends StatefulWidget {
  final bool shrink;
  final VoidCallback onBack;
  final ValueCallback2<BuildContext, TreeContentFile> openRecordCallback;

  const SearchPage({super.key, required this.shrink, required this.onBack, required this.openRecordCallback});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _query = "";

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final q = _controller.text.trim();
      if (q != _query) setState(() => _query = q);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    _focusNode.requestFocus();
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return createPlatformAppBar(
      automaticallyImplyLeading: false,
      showWindowButtons: false,
      leading: IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back)),
      titleWidget: TextField(
        controller: _controller,
        focusNode: _focusNode,
        autofocus: true,
        textAlignVertical: TextAlignVertical.center,
        onTapOutside: (_) => _focusNode.unfocus(),
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          isDense: true,
          hintText: l10n.searchRecords,
          hintStyle: const TextStyle(fontSize: 14),
          suffixIcon: _controller.text.isEmpty
              ? null
              : IconButton(icon: const Icon(Icons.close, size: 16), onPressed: _clear),
          suffixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 34),
          contentPadding: const EdgeInsets.only(left: 0, right: 12, top: 10, bottom: 10),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: RecordSearchResultsControl(
          query: _query,
          shrink: widget.shrink,
          openRecordCallback: widget.openRecordCallback,
        ),
      ),
    );
  }
}

/// Flat list of records matching [query] by title or path (case-insensitive).
class RecordSearchResultsControl extends StatefulWidget {
  final String query;
  final bool shrink;
  final ValueCallback2<BuildContext, TreeContentFile> openRecordCallback;

  const RecordSearchResultsControl({
    super.key,
    required this.query,
    required this.shrink,
    required this.openRecordCallback,
  });

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
  }

  @override
  void dispose() {
    recordTree.refreshNotifier.removeListener(onRefreshChanged);
    RecordOpenedState.get().openedFileNotifier.removeListener(onRefreshChanged);
    super.dispose();
  }

  void onRefreshChanged() {
    setState(() {});
  }

  List<TreeContentFile> _matches() {
    final query = widget.query.toLowerCase();
    if (query.isEmpty) return const [];
    return recordTree.sortedFiles.where((f) {
      return f.name.toLowerCase().contains(query) || f.path.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.query.isEmpty) return const SizedBox.shrink();
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
          leftPadding: 16.0,
          rightPadding: 16.0,
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
