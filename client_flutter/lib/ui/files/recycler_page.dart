import 'package:flutter/material.dart';
import 'package:note123/config/app_config.dart';
import 'package:note123/config/language_manager.dart';
import 'package:note123/filesync/database.dart';
import 'package:note123/filesync/repository.dart';
import 'package:note123/utils/utils.dart';
import 'package:note123/ui/desktop/desktop_tabs_page.dart';

/// Recycle bin page: lists locally deleted records (metadata snapshot + content file kept in
/// the recycler folder), supports restore / purge one / clear all.
class RecyclerPage extends StatefulWidget {
  final bool showAppBar;
  final ValueCallback<BuildContext>? closeCallback;
  const RecyclerPage({super.key, this.showAppBar = true, this.closeCallback});

  @override
  State<RecyclerPage> createState() => _RecyclerPageState();
}

class _RecyclerPageState extends State<RecyclerPage> implements DesktopTabPageState {
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
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.restore_outlined),
              title: Text(l10n.restore),
              onTap: () {
                Navigator.pop(ctx);
                _restore(record);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever_outlined, color: Colors.red),
              title: Text(l10n.purgeRecyclerItem, style: const TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _purge(record);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!widget.showAppBar) {
      return SizedBox.expand(
        child: Material(color: theme.colorScheme.surface, child: _buildBody(context)),
      );
    }
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => widget.closeCallback?.call(context),
          icon: const Icon(Icons.close_outlined),
        ),
        titleSpacing: 0,
        title: Text(l10n.recycler),
        actions: [
          IconButton(
            onPressed: _records.isEmpty ? null : _clear,
            icon: const Icon(Icons.delete_sweep_outlined),
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
    return ListView.separated(
      itemCount: _records.length,
      separatorBuilder: (context, index) => Divider(height: 1, color: theme.colorScheme.outline.withAlpha(80)),
      itemBuilder: (context, index) => _buildItem(context, _records[index]),
    );
  }

  Widget _buildItem(BuildContext context, RecycleRecord record) {
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.onSurface.withAlpha(120);
    return InkWell(
      onTap: () => _showActions(record),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppConfig.pageHorizontalPadding, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          record.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(Utils.formatShortTime(record.deleteAt), style: TextStyle(fontSize: 12, color: secondary)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    record.path,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: secondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.more_vert, size: 18, color: secondary),
          ],
        ),
      ),
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
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(left: 4, right: AppConfig.pageHorizontalPadding, top: 6, bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline.withAlpha(80)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.delete_outline, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 4),
            Text(l10n.recycler, style: const TextStyle(fontSize: 14)),
            const Spacer(),
            if (count > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(8)),
                child: Text('$count', style: TextStyle(fontSize: 12, color: theme.colorScheme.onPrimary)),
              ),
          ],
        ),
      ),
    );
  }
}
