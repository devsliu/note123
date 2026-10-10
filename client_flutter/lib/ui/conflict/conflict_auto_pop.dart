import 'package:flutter/material.dart';
import 'package:note123/filesync/repository.dart';
import 'package:note123/filesync/sync_engine.dart';
import 'package:note123/ui/conflict/conflict_list_page.dart';

/// Listen to syncStateNotifier, auto-open conflict resolution page when state is conflict.
/// Placed inside MaterialApp, so context naturally contains Navigator.
class ConflictAutoPopListener extends StatefulWidget {
  final Widget child;
  const ConflictAutoPopListener({super.key, required this.child});

  @override
  State<ConflictAutoPopListener> createState() => _ConflictAutoPopListenerState();
}

class _ConflictAutoPopListenerState extends State<ConflictAutoPopListener> {
  SyncState? _lastState;

  @override
  void initState() {
    super.initState();
    Repository.get().syncStateNotifier.addListener(_onSyncStateChanged);
  }

  @override
  void dispose() {
    Repository.get().syncStateNotifier.removeListener(_onSyncStateChanged);
    super.dispose();
  }

  void _onSyncStateChanged() {
    final state = Repository.get().syncStateNotifier.value;
    if (_lastState?.isConflict == true) {
      _lastState = state;
      return;
    }
    _lastState = state;
    if (!state.isConflict) return;
    if (ConflictListPage.isShowing) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ConflictListPage.open(context);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
