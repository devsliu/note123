import 'package:flutter/widgets.dart';
import 'package:notee/config/prefs.dart';
import 'package:notee/l10n/app_localizations.dart';
import 'package:notee/utils/reboot.dart';
import 'package:notee/filesync/record_tree.dart';
import 'package:notee/utils/utils.dart';

/// List-page view state: tab ([tabList] records / [tabTag] tags), records list type
/// ([typeFlat]/[typeTree]/[typeName]/[typeTime]), tag type reserved for the tags panel.
/// Serialized to prefs as `<tab>|<listType>|<tagType>`, e.g. "list|tree|".
class ListPageType {
  static const String tabList = 'list';
  static const String tabTag = 'tag';

  static const String typeFlat = 'flat';
  static const String typeTree = 'tree';
  static const String typeName = 'name';
  static const String typeTime = 'time';

  final String tab;
  final String listType;
  final String tagType;

  ListPageType(this.tab, this.listType, this.tagType);

  static ListPageType parse(String value) {
    final parts = value.split('|');
    return ListPageType(parts[0], parts.length > 1 ? parts[1] : '', parts.length > 2 ? parts[2] : '');
  }

  @override
  String toString() => '$tab|$listType|$tagType';

  static final ValueNotifier<ListPageType> notifier = ValueNotifier(ListPageType(tabList, typeTree, ''));
  static ListPageType get value => notifier.value;

  /// Sort type consumed by [RecordList]; folder views keep the default order.
  int get sortType {
    if (listType == typeName) return RecordList.sSortTypeName;
    if (listType == typeTime) return RecordList.sSortTypeByTime;
    return 0;
  }

  /// Startup load from prefs.
  static void init() {
    final saved = Prefs.instance.getString(PrefKeys.listViewState);
    notifier.value = saved != null
        ? ListPageType.parse(saved)
        : ListPageType(tabList, Utils.isDesktop() ? typeTree : typeFlat, '');
  }

  static void setTab(String tab) => _update(ListPageType(tab, notifier.value.listType, notifier.value.tagType));
  static void setListType(String listType) =>
      _update(ListPageType(notifier.value.tab, listType, notifier.value.tagType));

  static void _update(ListPageType next) {
    notifier.value = next;
    Prefs.instance.setString(PrefKeys.listViewState, next.toString()).save();
  }
}

/// 非桌面设备的布局模式
class LayoutMode {
  static const String pad = 'pad'; // 左右布局（平板模式）
  static const String phone = 'phone'; // 分页模式（手机模式）
  static const String desktop = 'desktop'; // 分页模式（桌面模式）

  static String getName(String mode, AppLocalizations l10n) {
    switch (mode) {
      case LayoutMode.desktop:
        return l10n.modeDesktop;
      case LayoutMode.pad:
        return l10n.modePad;
      default:
        return l10n.modePhone;
    }
  }

  /// 当前布局模式: 优先使用 pref 中手动设置的值,
  /// pref 为空时按屏幕短边宽度自动判断 (>=600 为 pad)
  static String resolve() {
    final saved = Prefs.instance.getString(PrefKeys.layoutMode);
    if (saved == pad || saved == phone || saved == desktop) {
      return saved!;
    }
    
    if (Utils.isDesktop()) {
      return desktop;
    }
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final shortest = view.physicalSize.shortestSide / view.devicePixelRatio;
    return shortest >= 600 ? pad : phone;
  }

  /// 设置布局模式并重启 app 使 PadApp/PhoneApp 切换生效
  static Future<void> setMode(String mode) async {
    Prefs.instance.setString(PrefKeys.layoutMode, mode).save();
    Reboot.trigger();
  }
}
