import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:note123/ui/phone/phone_record_list_page.dart';
import 'package:note123/config/theme.dart';
import 'package:note123/config/language_manager.dart';
import 'package:note123/utils/utils.dart';

import '../../l10n/app_localizations.dart';
import '../conflict/conflict_auto_pop.dart';

class PhoneApp extends StatelessWidget {
  final ValueCallback<BuildContext> initCallback;
  const PhoneApp({super.key, required this.initCallback});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: gAppTheme.data,
      debugShowCheckedModeBanner: false,
      locale: LanguageManager.getCurrentLocale(),
      localizationsDelegates: AppLocalizations.localizationsDelegates + [AppFlowyEditorLocalizations.delegate],
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) {
        initCallback(context);
        // 横屏时统一消费左右安全区 (刘海/手势条), 避免 AppBar 标题被单独推出大间距
        return SafeArea(top: false, bottom: false, child: child!);
      },
      home: ConflictAutoPopListener(child: PhoneRecordListPage()),
    );
  }
}
