import 'package:flutter/material.dart';
import 'package:note123/config/app_config.dart';
import 'package:note123/config/language_manager.dart';
import 'package:note123/filesync/database.dart';
import 'package:note123/filesync/repository.dart';
import 'package:note123/ui/common/platform_app_bar.dart';
import 'package:note123/utils/utils.dart';
import 'package:note123/ui/desktop/desktop_tabs_page.dart';

/// Recycle bin page: lists locally deleted records (metadata snapshot + content file kept in
/// the recycler folder), supports restore / purge one / clear all.
class RecordRecyclerPage extends StatefulWidget {
  final bool showAppBar;
  final ValueCallback<BuildContext>? closeCallback;
  const RecordRecyclerPage({super.key, this.showAppBar = true, this.closeCallback});

  @override
  State<RecordRecyclerPage> createState() => _RecordRecyclerPageState();
}

class _RecordRecyclerPageState extends State<RecordRecyclerPage> implements DesktopTabPageState {
  List<RecycleRecord> _records = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    // Background sync may capture new deletions while the page is open
    Repository.get().recyclerCountNotifier.addListener(_load);
  }

  @override
  void dispose() {
    Repository.get().recyclerCountNotifier.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final records = await Repository.get().getRecycleRecords();
    if (!mounted) return;
    setState(() {
      _records = records;
      _loading = false;
    });
  }

  @override
  void setInForeground(bool value) {
    // Desktop/pad tab focus signal; refresh so newly captured deletions show up
    if (value) _load();
  }

  Future<bool> _confirm(String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.confirmDelete),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete, style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return result == true;
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _restore(RecycleRecord record) async {
    final ok = await Repository.get().restoreRecycleRecord(record.uuid);
    _snack(ok ? l10n.recyclerRestored(record.name) : l10n.recyclerRestoreFailed);
  }

  Future<void> _purge(RecycleRecord record) async {
    if (!await _confirm(l10n.confirmPurgeRecycler)) return;
    await Repository.get().purgeRecycleRecord(record.uuid);
    _snack(l10n.recyclerPurged);
  }

  Future<void> _clear() async {
    if (!await _confirm(l10n.confirmClearRecycler)) return;
    await Repository.get().clearRecycleRecords();
    _snack(l10n.recyclerCleared);
  }

  void _showActions(RecycleRecord record) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(record.path + record.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _restore(record);
            },
            icon: const Icon(Icons.restore_outlined),
            label: Text(l10n.restore),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _purge(record);
            },
            icon: const Icon(Icons.delete_forever_outlined, color: Colors.red),
            label: Text(l10n.purgeRecyclerItem, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!widget.showAppBar) {
      return SizedBox.expand(
        child: Material(
          color: theme.colorScheme.surface,
          child: Stack(
            children: [
              _buildBody(context),
              if (_records.isNotEmpty)
                Positioned(
                  right: AppConfig.pageHorizontalPadding,
                  bottom: AppConfig.pageHorizontalPadding,
                  child: FloatingActionButton(
                    onPressed: _clear,
                    tooltip: l10n.clearRecycler,
                    shape: const CircleBorder(),
                    child: const Icon(Icons.delete_sweep_outlined),
                  ),
                ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: createPlatformAppBar(
        onBack: widget.closeCallback != null ? () => widget.closeCallback!(context) : null,
        titleSpacing: 0,
        title: l10n.recycler,
        actions: [
          IconButton(
            onPressed: _records.isEmpty ? null : _clear,
            icon: const Icon(Icons.delete_forever_outlined),
            tooltip: l10n.clearRecycler,
          ),
          SizedBox(width: AppConfig.pageHorizontalPadding),
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_records.isEmpty) {
      return Center(
        child: Text(l10n.noData, style: TextStyle(color: theme.colorScheme.onSurface.withAlpha(120))),
      );
    }
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            itemCount: _records.length,
            separatorBuilder: (context, index) => Divider(height: 1, color: theme.colorScheme.outline.withAlpha(80)),
            itemBuilder: (context, index) => _buildItem(context, _records[index]),
          ),
        ),
         Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            l10n.recyclerAutoClearHint(Repository.recyclerExpireDays),
            style: TextStyle(fontSize: 12, color: theme.colorScheme.outline.withAlpha(180)),
          ),
        ),
      ],
    );
  }

  Widget _buildItem(BuildContext context, RecycleRecord record) {
    final shrink = Utils.isDesktop();
    return ListTile(
      dense: shrink,
      visualDensity: shrink ? const VisualDensity(vertical: -4) : null,
      onTap: () => _showActions(record),
      title: Text(record.path + record.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Text(Utils.formatShortTime(record.deleteAt)),
    );
  }
}

/// Clickable half-row entry shown next to [CalendarTaskItem] on record list pages,
/// with the recycle bin entry count badge.
class RecyclerEntryItem extends StatefulWidget {
  final ValueCallback<BuildContext> onTap;
  const RecyclerEntryItem({super.key, required this.onTap});

  @override
  State<RecyclerEntryItem> createState() => _RecyclerEntryItemState();
}

class _RecyclerEntryItemState extends State<RecyclerEntryItem> {
  @override
  void initState() {
    super.initState();
    Repository.get().recyclerCountNotifier.addListener(_onCountChanged);
  }

  @override
  void dispose() {
    Repository.get().recyclerCountNotifier.removeListener(_onCountChanged);
    super.dispose();
  }

  void _onCountChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = Repository.get().recyclerCountNotifier.value;
    return InkWell(
      onTap: () => widget.onTap(context),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline.withAlpha(150)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Icon(Icons.delete_outline, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 4),
            Text(l10n.recycler, style: const TextStyle(fontSize: 14)),
            const Spacer(),
            if (count > 0) Text('$count', style: TextStyle(fontSize: 14, color: theme.colorScheme.primary)),
          ],
        ),
      ),
    );
  }
}
