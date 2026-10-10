import 'package:shared_preferences/shared_preferences.dart';

class PrefKeys {
  static const windowWidth = 'window_width';
  static const windowHeight = 'window_height';
  static const windowLeftWidth = 'desktop_left_width';
  static const languageCode = 'language_code';
  static const isFirstLaunchApp = 'is_first_launch_app';
  static const listType = 'list_type';
  static const layoutMode = 'layout_mode';
}

class Prefs {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static SharedPreferences get instance => _prefs!;
}
