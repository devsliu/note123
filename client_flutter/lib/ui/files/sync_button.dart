import 'dart:math';

import 'package:flutter/material.dart';
import 'package:note123/filesync/repository.dart';
import 'package:note123/filesync/sync_engine.dart';
import 'package:note123/filesync/user.dart';
import 'package:note123/filesync/http_api.dart';

import '../../config/app_config.dart';
import '../settings/login_dialog.dart';
import '../conflict/conflict_list_page.dart';
import '../../config/language_manager.dart';
import '../../l10n/app_localizations.dart';

Future<bool> _onErrorClick(BuildContext context, SyncState state) async {
  if (state.isConflict) {
    if (context.mounted) ConflictListPage.open(context);
    return true;
  }
  if (state.isAuthError) {
    await LoginDialog.show(context);
    return true;
  }
  return false;
}

class SyncButton extends StatefulWidget {
  const SyncButton({super.key});

  @override
  State<SyncButton> createState() => _SyncButtonState();
}

class _SyncButtonState extends State<SyncButton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(seconds: 1), vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: User.instance.isLogin,
      builder: (context, isLogin, _) {
        return ValueListenableBuilder<SyncState>(
          valueListenable: Repository.get().syncStateNotifier,
          builder: (context, state, _) {
            bool isError = state.isError || !isLogin;
            bool isSyncing = state.state == SyncState.syncing;
            // Control animation
            if (isSyncing && !_controller.isAnimating) {
              _controller.repeat();
            } else if (!isSyncing && _controller.isAnimating) {
              _controller.stop();
            }
            Widget icon = Icon(
              !isError ? Icons.sync_outlined : Icons.sync_problem_outlined,
              color: !isError ? null : Colors.red,
            );
            if (isSyncing) {
              icon = AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Transform.rotate(angle: _controller.value * 2 * pi, child: child);
                },
                child: icon,
              );
            }
            return IconButton(icon: icon, tooltip: l10n.sync, onPressed: _onSyncPressed);
          },
        );
      },
    );
  }

  void _onSyncPressed() async {
    if (await _onErrorClick(context, Repository.get().syncStateNotifier.value)) return;
    if (!mounted) return;
    if (!User.instance.isLogin.value) {
      final result = await LoginDialog.show(context);
      if (result != true) return; // Login failed or cancelled
    }
    if (!mounted) return;
    Repository.get().syncRecords(true);
  }
}

class SyncStateWidget extends StatelessWidget {
  const SyncStateWidget({super.key});

  static final Map<int, String Function(AppLocalizations)> _errorMap = {
    401: (l) => l.syncErrAuthInvalid,
    HttpApi.ResultErrorRecordConflict: (l) => l.syncErrConflict,
    HttpApi.ResultErrorDatabase: (l) => l.syncErrServerDb,
    HttpApi.ResultErrorRecordNotFound: (l) => l.syncErrRecordNotFound,
    HttpApi.ResultErrorParams: (l) => l.syncErrParams,
    HttpApi.ResultErrorFileSave: (l) => l.syncErrFileSave,
    HttpApi.ResultErrorFileNotFound: (l) => l.syncErrFileNotFound,
    HttpApi.ResultErrorUserPasswordError: (l) => l.syncErrAuthInvalid,
    HttpApi.ClientErrorNetwork: (l) => l.syncErrNetwork,
    HttpApi.ClientErrorTimeout: (l) => l.syncErrTimeout,
    HttpApi.ClientErrorNoBaseUrl: (l) => l.syncErrUnknown,
    HttpApi.ClientErrorDownloadFailed: (l) => l.syncErrFileSave,
  };

  String _syncErrorText(SyncState state) {
    final fn = _errorMap[state.errorCode];
    if (fn != null) return fn(l10n);
    return state.message;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SyncState>(
      valueListenable: Repository.get().syncStateNotifier,
      builder: (context, state, _) {
        if (state.state == SyncState.idle) return SizedBox.shrink();
        if (state.state == SyncState.success) {
          final now = DateTime.now();
          final timeStr =
              "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} "
              "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
          return Container(
            color: Colors.green.withAlpha(30),
            width: double.infinity,
            padding: AppConfig.itemPadding,
            child: Text(
              "${l10n.syncSuccess} $timeStr",
              style: const TextStyle(color: Colors.green),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          );
        }
        if (state.state == SyncState.syncing) {
          return Container(
            color: Colors.blue.withAlpha(30),
            width: double.infinity,
            padding: AppConfig.itemPadding,
            child: Text(l10n.syncing, style: const TextStyle(color: Colors.blue)),
          );
        }
        // error state: conflict is orange, others are red. Tap action: conflict→conflict page, auth expired→login dialog, others→details
        return GestureDetector(
          onTap: () async {
            if (await _onErrorClick(context, state)) return;

            if (!context.mounted) return;
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: Text(l10n.errorDetails),
                content: SingleChildScrollView(child: Text(_syncErrorText(state))),
                actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.close))],
              ),
            );
          },
          child: Container(
            color: (state.isConflict ? Colors.orange : Colors.red).withAlpha(30),
            width: double.infinity,
            padding: AppConfig.pagePadding,
            child: Text(
              _syncErrorText(state),
              style: TextStyle(color: state.isConflict ? Colors.orange : Colors.red),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      },
    );
  }
}
