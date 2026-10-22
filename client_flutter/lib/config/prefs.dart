import 'package:notee/config/app_config.dart';
import 'package:notee/utils/kv_store.dart';

class PrefKeys {
  static const windowWidth = 'window_width';
  static const windowHeight = 'window_height';
  static const windowPosX = 'window_pos_x';
  static const windowPosY = 'window_pos_y';
  static const windowMaximized = 'window_maximized';
  static const rememberOpenTabs = 'remember_open_tabs';
  static const windowLeftWidth = 'desktop_left_width';
  static const languageCode = 'language_code';
  static const listViewState = 'list_view_state';
  static const layoutMode = 'layout_mode';
  static const openTabs = 'open_tabs';
}

class Prefs {
  static KvStore? _store;

  static KvStore get instance {
    return _store!;
  }

  static void init() {
    _store ??= KvStore('${AppConfig.appRootDir}/prefs.json');
    _store!.save();
  }
}
