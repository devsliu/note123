import 'package:flutter/widgets.dart';
import 'package:note123/config/prefs.dart';
import 'package:note123/utils/reboot.dart';
import 'package:note123/filesync/record_tree.dart';

class RecordListWidgetType {
  static final ValueNotifier<int> notifier = ValueNotifier<int>(0);

  static final int sTreeFolder = 100;
  static final int sFlatFolder = 200;
  static final int sOrderByName = RecordList.sSortTypeName;
  static final int sOrderByByTime = RecordList.sSortTypeByTime;
}

/// 非桌面设备的布局模式
class LayoutMode {
  static const String pad = 'pad'; // 左右布局（平板模式）
  static const String phone = 'phone'; // 分页模式（手机模式）

  /// 当前布局模式: 优先使用 pref 中手动设置的值,
  /// pref 为空时按屏幕短边宽度自动判断 (>=600 为 pad)
  static String resolve() {
    final saved = Prefs.instance.getString(PrefKeys.layoutMode);
    if (saved == pad || saved == phone) {
      return saved!;
    }
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final shortest = view.physicalSize.shortestSide / view.devicePixelRatio;
    return shortest >= 600 ? pad : phone;
  }

  /// 设置布局模式并重启 app 使 PadApp/PhoneApp 切换生效
  static Future<void> setMode(String mode) async {
    await Prefs.instance.setString(PrefKeys.layoutMode, mode);
    Reboot.trigger();
  }
}
