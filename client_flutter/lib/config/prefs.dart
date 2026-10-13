import 'package:shared_preferences/shared_preferences.dart';

class PrefKeys {
  static const windowWidth = 'window_width';
  static const windowHeight = 'window_height';
  static const windowLeftWidth = 'desktop_left_width';
  static const languageCode = 'language_code';
  static const listType = 'list_type';
  static const layoutMode = 'layout_mode';
  static const listActiveTab = 'list_active_tab';
  static const tagViewType = 'tag_view_type';
}

class Prefs {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static SharedPreferences get instance => _prefs!;
}
