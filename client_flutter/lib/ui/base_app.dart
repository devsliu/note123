import 'dart:io';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:notee/filesync/repository.dart';
import 'package:notee/filesync/sync_engine.dart';
import 'package:notee/model/reminder_notifier.dart';
import 'package:notee/config/theme.dart';
import 'package:notee/config/language_manager.dart';

import '../l10n/app_localizations.dart';
import 'conflict/conflict_list_page.dart';
import 'editor/editor_save_coordinator.dart';

/// 跨平台 app 抽象基类。
///
/// 三个端（Phone / Pad / Desktop）共用的逻辑集中于此：
/// - 通知点击监听（ReminderNotifier）
/// - 同步冲突自动弹窗
/// - MaterialApp 通用配置（主题、语言、localizations）
///
/// 子类需实现：[navigate] / [buildHome]。
abstract class BaseApp extends StatefulWidget {
  const BaseApp({super.key});
}

/// 统一导航接口：所有跨页面跳转都通过它完成。
///
/// 每个平台 app 实现该接口，并通过 [AppNavigatorScope] 注入到 widget 树中，
/// 任意子节点可通过 `AppNavigator.of(context)` 获取实例后调用 [navigate]。
abstract class AppNavigator {
  /// 导航目标常量，集中定义避免散落的字符串字面量。
  static const String uriRecord = 'record';
  static const String uriCalendar = 'calendar';
  static const String uriRecycler = 'recycler';
  static const String uriSettings = 'settings';

  /// 统一导航入口。
  /// - [uri]: 目标标识，见 [uriRecord] / [uriCalendar] / [uriRecycler]
  /// - [arg1] / [arg2]: 可选位置参数，由各目标页面自行解释，各 uri 的参数契约：
  ///   - [uriRecord]: `arg1` = `String uuid`（必填，记录 id）；
  ///     `arg2` = `String? keyword`（可选，搜索关键字，打开后自动高亮首次匹配位置）
  ///   - [uriCalendar]: 无参数
  ///   - [uriRecycler]: 无参数
  void navigate(String uri, [dynamic arg1, dynamic arg2]);

  /// 从 widget 树中查找最近的 [AppNavigator] 实例。
  static AppNavigator of(BuildContext context) {
    final nav = context.dependOnInheritedWidgetOfExactType<AppNavigatorScope>()?.navigator;
    assert(nav != null, 'No AppNavigator found in context');
    return nav!;
  }

  static AppNavigator? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppNavigatorScope>()?.navigator;
  }
}

/// 将 [AppNavigator] 注入 widget 树的 InheritedWidget。
class AppNavigatorScope extends InheritedWidget {
  final AppNavigator navigator;
  const AppNavigatorScope({super.key, required this.navigator, required super.child});

  @override
  bool updateShouldNotify(AppNavigatorScope oldWidget) => navigator != oldWidget.navigator;
}

abstract class BaseAppState<T extends BaseApp> extends State<T> with WidgetsBindingObserver implements AppNavigator {
  SyncState? _lastSyncState;

  /// 全局 navigatorKey，供跨层导航（通知点击、冲突弹窗）使用。
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  bool _switchingDialogShowing = false;

  @override
  void navigate(String uri, [dynamic arg1, dynamic arg2]);

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
    Repository.get().userSwitchingNotifier.addListener(_onUserSwitchingChanged);
  }

  @override
  void dispose() {
    ReminderNotifier.instance.notificationTapNotifier.removeListener(_onNotificationTap);
    Repository.get().syncStateNotifier.removeListener(_onSyncStateChanged);
    Repository.get().userSwitchingNotifier.removeListener(_onUserSwitchingChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 从后台回到前台时检查是否需要同步
      Repository.get().syncFromBackground();
    } else if (state == AppLifecycleState.detached) {
      // 进程即将终止: 触发并等待所有打开编辑页的 pending 保存 (尽力而为, 覆盖移动端系统杀进程等路径)
      EditorSaveCoordinator.flushAll();
    }
  }

  void _onNotificationTap() {
    final uuid = ReminderNotifier.instance.notificationTapNotifier.value;
    if (uuid == null || uuid.isEmpty) return;
    navigate(AppNavigator.uriRecord, uuid);
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

  /// 监听用户切换状态：切换开始弹出不可取消的 loading 模态框，
  /// 切换完成自动 pop，期间拦截所有用户操作。
  void _onUserSwitchingChanged() {
    final switching = Repository.get().userSwitchingNotifier.value;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = navigatorKey.currentContext;
      if (ctx == null) return;
      if (switching && !_switchingDialogShowing) {
        _switchingDialogShowing = true;
        final l10n = AppLocalizations.of(ctx);
        showDialog(
          context: ctx,
          barrierDismissible: false,
          useRootNavigator: false,
          builder: (_) => PopScope(
            canPop: false,
            child: AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 2.5)),
                  const SizedBox(height: 16),
                  Text(l10n?.loadingUserData ?? 'Loading...'),
                ],
              ),
            ),
          ),
        ).whenComplete(() {
          _switchingDialogShowing = false;
        });
      } else if (!switching && _switchingDialogShowing) {
        Navigator.of(ctx).pop();
      }
    });
  }

  Widget buildMaterialApp(BuildContext context, Widget home) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      theme: gAppTheme.data,
      debugShowCheckedModeBanner: false,
      locale: LanguageManager.getCurrentLocale(),
      localizationsDelegates: AppLocalizations.localizationsDelegates + [AppFlowyEditorLocalizations.delegate],
      // zh_CN added so the appflowy_editor l10n delegate (messages keyed zh_CN/zh_TW)
      // resolves to zh_CN instead of bare zh, which it has no messages for.
      supportedLocales: AppLocalizations.supportedLocales + [const Locale('zh', 'CN')],
      builder: (context, child) {
        LanguageManager.initializeL10n(context);
        // 放在 Navigator 之上：这样所有 route（含 dialog overlay）的 context
        // 都能通过 AppNavigator.of(context) 找到导航实例。
        return AppNavigatorScope(navigator: this, child: buildAppWrapper(context, child!));
      },
      home: home,
    );
  }

  @override
  Widget build(BuildContext context) {
    return buildMaterialApp(context, buildHome(context));
  }
}
