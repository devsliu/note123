import 'dart:async';

import 'package:note123/filesync/repository.dart';
import 'package:flutter/material.dart';
import 'package:note123/model/record_opened_state.dart';
import 'package:note123/utils/utils.dart';
import 'package:note123/model/reminder_notifier.dart';
import 'package:note123/config/app_config.dart';
import 'package:note123/config/language_manager.dart';
import 'package:note123/config/layout_mode.dart';
import 'package:note123/config/prefs.dart';
import 'package:note123/utils/reboot.dart';
import 'package:window_manager/window_manager.dart';

import 'ui/desktop/desktop_app.dart';
import 'ui/phone/phone_app.dart';
import 'ui/pad/pad_app.dart';

bool _isFirstInitAppWidget = true; // Flag to mark whether this is the first app initialization

// Global app lifecycle observer
class _AppLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Check if sync is needed when app returns to foreground from background
      Repository.get().syncRecordsFromBackground();
    }
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Prefs.init();
  Prefs.instance.setBool(PrefKeys.isFirstLaunchApp, false);

  Size? lastWindowSize;
  if (Utils.isDesktop()) {
    await windowManager.ensureInitialized();
    // Read previous window size
    final width = Prefs.instance.getDouble(PrefKeys.windowWidth);
    final height = Prefs.instance.getDouble(PrefKeys.windowHeight);
    if (width != null && height != null) {
      lastWindowSize = Size(width, height);
    }
    WindowOptions windowOptions = WindowOptions(
      size: lastWindowSize ?? const Size(900, 600),
      center: lastWindowSize == null,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: false,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.ensureInitialized();
      await windowManager.setResizable(true);
      await windowManager.setMinimumSize(const Size(600, 400));
      await windowManager.setTitle(AppConfig.appTitle);
      await windowManager.show();
      await windowManager.focus();
    });
    // Listen for window size changes and save them
    windowManager.addListener(_WindowSizeListener());

    // Register global app lifecycle observer
    WidgetsBinding.instance.addObserver(_AppLifecycleObserver());
  }

  await AppConfig.init();
  LanguageManager.init();
  await Repository.init(AppConfig.appRootDir);
  RecordListWidgetType.notifier.value =
      Prefs.instance.getInt(PrefKeys.listType) ??
      (Utils.isDesktop() ? RecordListWidgetType.sTreeFolder : RecordListWidgetType.sFlatFolder);
  final listType = RecordListWidgetType.notifier.value;
  Repository.get().recordTree.setSortListType(listType);
  if (listType != 0) RecordOpenedState.get().setOpenedFolder("/");

  // 根节点监听 Reboot, 切换布局模式后可在 PadApp/PhoneApp 之间重建
  runApp(ValueListenableBuilder<int>(valueListenable: Reboot.notifier, builder: (_, _, _) => _buildApp()));
}

Widget _buildApp() {
  if (Utils.isDesktop()) {
    return DesktopApp(initCallback: _initWhenAppBuild);
  }
  if (LayoutMode.resolve() == LayoutMode.pad) {
    return PadApp(initCallback: _initWhenAppBuild);
  }
  return PhoneApp(initCallback: _initWhenAppBuild);
}

Future<void> _initWhenAppBuild(BuildContext context) async {
  // Initialize global localizations
  LanguageManager.initializeL10n(context);

  // Initialize reminder notifications (also schedules all pending reminders)
  await ReminderNotifier.instance.init();

  if (_isFirstInitAppWidget) {
    await Repository.get().syncRecords(true);
  }

  _isFirstInitAppWidget = false; // Mark app initialization as complete
}

class _WindowSizeListener extends WindowListener {
  @override
  void onWindowResize() async {
    final size = await windowManager.getSize();
    await Prefs.instance.setDouble(PrefKeys.windowWidth, size.width);
    await Prefs.instance.setDouble(PrefKeys.windowHeight, size.height);
  }
}
