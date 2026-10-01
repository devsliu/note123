import 'package:note123/filesync/repository.dart';
import 'package:flutter/material.dart';
import 'package:note123/ui/common/global_value_notify.dart';
import 'package:note123/utils/utils.dart';
import 'package:note123/config/app_config.dart';
import 'package:note123/utils/device_info.dart';
import 'package:note123/config/language_manager.dart';
import 'package:note123/config/prefs.dart';
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
  await DeviceInfo.readDeviceType();
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
  GlobalValueNotify.recordListWidgetType.value =
      Prefs.instance.getInt(PrefKeys.listType) ??
      (Utils.isDesktop() ? RecordListWidgetType.sTreeFolder : RecordListWidgetType.sFlatFolder);
  Repository.get().recordTree.setSortListType(GlobalValueNotify.recordListWidgetType.value);

  runApp(_buildApp());
}

Widget _buildApp() {
  switch (DeviceInfo.deviceType) {
    case DeviceType.desktop:
      return DesktopApp(initCallback: _initWhenAppBuild);
    case DeviceType.pad:
      return PadApp(initCallback: _initWhenAppBuild);
    case DeviceType.phone:
      return PhoneApp(initCallback: _initWhenAppBuild);
  }
}

Future<void> _initWhenAppBuild(BuildContext context) async {
  // Initialize global localizations
  LanguageManager.initializeL10n(context);

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
