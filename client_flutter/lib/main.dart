import 'dart:async';

import 'package:note123/filesync/repository.dart';
import 'package:flutter/material.dart';
import 'package:note123/model/record_opened_state.dart';
import 'package:note123/model/record_utils.dart';
import 'package:note123/utils/utils.dart';
import 'package:note123/config/app_config.dart';
import 'package:note123/config/language_manager.dart';
import 'package:note123/config/layout_mode.dart';
import 'package:note123/config/prefs.dart';
import 'package:note123/utils/reboot.dart';
import 'package:window_manager/window_manager.dart';

import 'ui/desktop/desktop_app.dart';
import 'ui/phone/phone_app.dart';
import 'ui/pad/pad_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Prefs.init();
  await AppConfig.init();
  LanguageManager.init();
  await Repository.init(AppConfig.appRootDir, searchExtractor: RecordUtils.extractTextFromFile);
  ListPageType.init();
  Repository.get().recordTree.setSortListType(ListPageType.value.sortType);
  RecordOpenedState.get().setOpenedFolder("/");

  if (Utils.isDesktop()) {
    await _initWindows();
  }
  // 根节点监听 Reboot, 切换布局模式后可在 PadApp/PhoneApp 之间重建
  runApp(ValueListenableBuilder<int>(valueListenable: Reboot.notifier, builder: (_, _, _) => _buildApp()));
}

Future<void> _initWindows() async {
  await windowManager.ensureInitialized();
  final width = Prefs.instance.getDouble(PrefKeys.windowWidth);
  final height = Prefs.instance.getDouble(PrefKeys.windowHeight);
  Size? size = (width != null && height != null) ? Size(width, height) : null;
  WindowOptions windowOptions = WindowOptions(
    size: size ?? const Size(900, 600),
    center: size == null,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: false,
  );
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setResizable(true);
    await windowManager.setMinimumSize(const Size(600, 400));
    await windowManager.setTitle(AppConfig.appTitle);
    await windowManager.show();
    await windowManager.focus();
  });
}

Widget _buildApp() {
  if (Utils.isDesktop()) {
    return DesktopApp();
  }
  if (LayoutMode.resolve() == LayoutMode.pad) {
    return PadApp();
  }
  return PhoneApp();
}
