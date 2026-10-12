import 'dart:io';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:note123/filesync/record_tree.dart';
import 'package:note123/filesync/repository.dart';
import 'package:note123/filesync/sync_engine.dart';
import 'package:note123/model/reminder_notifier.dart';
import 'package:note123/config/theme.dart';
import 'package:note123/config/language_manager.dart';

import '../l10n/app_localizations.dart';
import 'conflict/conflict_list_page.dart';

/// 跨平台 app 抽象基类。
///
/// 三个端（Phone / Pad / Desktop）共用的逻辑集中于此：
/// - 通知点击监听（ReminderNotifier）
/// - 同步冲突自动弹窗
/// - MaterialApp 通用配置（主题、语言、localizations）
///
/// 子类需实现：[openRecord] / [openCalendar] / [buildHome]。
abstract class BaseApp extends StatefulWidget {
  const BaseApp({super.key});
}

abstract class BaseAppState<T extends BaseApp> extends State<T> with WidgetsBindingObserver {
  SyncState? _lastSyncState;

  /// 全局 navigatorKey，供跨层导航（通知点击、冲突弹窗）使用。
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// 通知点击时调用，打开对应笔记。
  void openRecord(BuildContext context, TreeContentFile record);

  /// 打开日历页。
  void openCalendar(BuildContext context);

  /// 打开回收站页。
  void openRecycler(BuildContext context);

  /// 构建 app 主体（不含 MaterialApp 外壳）。
  Widget buildHome(BuildContext context);

  /// MaterialApp.builder 中的额外包裹层。
  /// 移动端默认包 SafeArea（横屏时消费左右安全区，避免 AppBar 标题被推出大间距）；
  /// 桌面端直接返回。子类可覆写（如 Desktop 用 VirtualWindowFrame）。
  Widget buildAppWrapper(BuildContext context, Widget child) {
    if (Platform.isAndroid || Platform.isIOS) {
      return SafeArea(top: false, bottom: false, child: child);
    }
    return child;
  }

  @override
  void initState() {
    super.initState();
    LanguageManager.initializeL10n(context);
    ReminderNotifier.instance.init();
    Repository.get().syncRecords(true);
    WidgetsBinding.instance.addObserver(this);
    ReminderNotifier.instance.notificationTapNotifier.addListener(_onNotificationTap);
    Repository.get().syncStateNotifier.addListener(_onSyncStateChanged);
  }

  @override
  void dispose() {
    ReminderNotifier.instance.notificationTapNotifier.removeListener(_onNotificationTap);
    Repository.get().syncStateNotifier.removeListener(_onSyncStateChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 从后台回到前台时检查是否需要同步
      Repository.get().syncRecordsFromBackground();
    }
  }

  void _onNotificationTap() {
    final uuid = ReminderNotifier.instance.notificationTapNotifier.value;
    if (uuid == null || uuid.isEmpty) return;
    final node = Repository.get().recordTree.findFileNode(uuid);
    if (node == null) return;
    final file = node.content as TreeContentFile;
    openRecord(context, file);
  }

  /// 监听同步状态，出现冲突时自动弹出冲突处理页。
  void _onSyncStateChanged() {
    final state = Repository.get().syncStateNotifier.value;
    if (_lastSyncState?.isConflict == true) {
      _lastSyncState = state;
      return;
    }
    _lastSyncState = state;
    if (!state.isConflict) return;
    if (ConflictListPage.isShowing) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = navigatorKey.currentContext;
      if (ctx == null) return;
      ConflictListPage.open(ctx);
    });
  }

  Widget buildMaterialApp(BuildContext context, Widget home) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      theme: gAppTheme.data,
      debugShowCheckedModeBanner: false,
      locale: LanguageManager.getCurrentLocale(),
      localizationsDelegates: AppLocalizations.localizationsDelegates + [AppFlowyEditorLocalizations.delegate],
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) {
        LanguageManager.initializeL10n(context);
        return buildAppWrapper(context, child!);
      },
      home: home,
    );
  }

  @override
  Widget build(BuildContext context) {
    return buildMaterialApp(context, buildHome(context));
  }
}
