import 'dart:async';

import 'package:note123/filesync/http_api.dart';
import 'package:note123/filesync/repository.dart';
import 'package:note123/filesync/user.dart';
import 'package:note123/ui/settings/record_operates_page.dart';
import 'package:note123/model/reminder_notifier.dart';
import 'package:note123/ui/common/platform_app_bar.dart';
import 'package:note123/ui/settings/server_api_stats_page.dart';
import 'package:note123/ui/settings/record_database_page.dart';
import 'package:flutter/material.dart';
import 'package:note123/config/theme.dart';
import 'package:note123/ui/settings/theme_selector_dialog.dart';
import 'package:note123/config/app_config.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'login_dialog.dart';
import 'upgrade_manager.dart';
import '../../config/language_manager.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String version = "";
  int _buildNumber = 0;

  // 升级状态
  bool? _hasUpdate;
  VersionInfo? _versionInfo;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    loadVersionInfo();
    User.instance.isLogin.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    User.instance.isLogin.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (mounted) setState(() {});
  }

  void _onUserTap() async {
    User user = User.instance;
    if (user.id > 0 && user.token != null && user.token!.isNotEmpty) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.logout),
          content: Text(l10n.confirmLogout),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.logout)),
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          ],
        ),
      );
      if (confirm == true) {
        User.instance.logout();
        if (context.mounted) {
          setState(() {});
        }
        return;
      }
    } else {
      LoginDialog.show(context);
      return;
    }
  }

  void _onThemeTap() async {
    await showThemeSelector(context);
    setState(() {});
  }

  Future<void> loadVersionInfo() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      version = packageInfo.version;
      _buildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;
    });
    _checkUpgrade();
  }

  Future<void> _checkUpgrade() async {
    if (_checking) return;
    setState(() => _checking = true);

    final info = await UpgradeManager.checkUpgrade();
    if (info != null && mounted) {
      _versionInfo = info;
      _hasUpdate = UpgradeManager.isNewerVersion(info.versionName, version);
      setState(() {});
    }
    if (mounted) setState(() => _checking = false);
  }

  void _onVersionTap() {
    if (_checking) {
      return;
    }
    UpgradeManager.showVersionDialog(context, currentVersion: version, versionInfo: _versionInfo);
  }

  bool _isUserLoggedIn() {
    final user = User.instance;
    return user.id > 0 && user.token != null && user.token!.isNotEmpty;
  }

  String getUserInfo(BuildContext context) {
    User user = User.instance;
    if (user.id == 0) return l10n.notLoggedIn;
    if (user.token == null || user.token!.isEmpty) return l10n.loginExpired;
    return user.name ?? user.id.toString();
  }

  void _onLanguageTap() async {
    final currentLanguage = LanguageManager.getCurrentLanguage();

    LanguageOption? selected = await showDialog<LanguageOption>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.selectLanguage),
        children: [
          SimpleDialogOption(
            child: Row(
              children: [
                if (currentLanguage == LanguageOption.system) const Icon(Icons.check, size: 16),
                if (currentLanguage != LanguageOption.system) const SizedBox(width: 16),
                const SizedBox(width: 8),
                Text(l10n.followSystem),
              ],
            ),
            onPressed: () => Navigator.pop(ctx, LanguageOption.system),
          ),
          SimpleDialogOption(
            child: Row(
              children: [
                if (currentLanguage == LanguageOption.chinese) const Icon(Icons.check, size: 16),
                if (currentLanguage != LanguageOption.chinese) const SizedBox(width: 16),
                const SizedBox(width: 8),
                Text(l10n.chinese),
              ],
            ),
            onPressed: () => Navigator.pop(ctx, LanguageOption.chinese),
          ),
          SimpleDialogOption(
            child: Row(
              children: [
                if (currentLanguage == LanguageOption.english) const Icon(Icons.check, size: 16),
                if (currentLanguage != LanguageOption.english) const SizedBox(width: 16),
                const SizedBox(width: 8),
                Text(l10n.english),
              ],
            ),
            onPressed: () => Navigator.pop(ctx, LanguageOption.english),
          ),
        ],
      ),
    );

    if (selected != null && selected != currentLanguage) {
      await LanguageManager.setLanguage(selected);
    }
  }

  String _getLanguageDisplayName(BuildContext context) {
    final currentLanguage = LanguageManager.getCurrentLanguage();
    return LanguageManager.getLanguageDisplayName(currentLanguage, l10n.followSystem, l10n.chinese, l10n.english);
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = _buildVersionSubtitle();
    return Scaffold(
      appBar: createPlatformAppBar(title: l10n.settings),
      body: ListView(
        children: [
          ListTile(
            onTap: _onUserTap,
            title: Text(l10n.syncAccount),
            subtitle: Text(
              '${Repository.get().apiUrl}\n${getUserInfo(context)}',
              style: TextStyle(color: _isUserLoggedIn() ? null : Theme.of(context).colorScheme.error),
            ),
          ),
          AppConfig.listViewDivider(context),
          ListTile(onTap: _onAppFolderTap, title: Text(l10n.dataDirectory), subtitle: Text(AppConfig.appRootDir)),
          AppConfig.listViewDivider(context),
          ListTile(onTap: _onThemeTap, title: Text(l10n.theme), subtitle: Text(gAppTheme.getName(l10n))),
          AppConfig.listViewDivider(context),
          ListTile(onTap: _onLanguageTap, title: Text(l10n.language), subtitle: Text(_getLanguageDisplayName(context))),
          AppConfig.listViewDivider(context),
          ListTile(
            onTap: _onVersionTap,
            title: _buildVersionTitle(),
            subtitle: subtitle,
            trailing: _hasUpdate == true ? const Icon(Icons.new_releases, color: Colors.orange) : null,
          ),
          const Divider(height: 20, thickness: 20),
          ListTile(onTap: _onApiStatTap, title: Text(l10n.apiCallStats)),
          AppConfig.listViewDivider(context),
          ListTile(onTap: _onRecordsDbTap, title: Text(l10n.database)),
          AppConfig.listViewDivider(context),
          ListTile(onTap: _onOperatesDbTap, title: Text(l10n.operates)),
          AppConfig.listViewDivider(context),
          ListTile(
            onTap: () => ReminderNotifier.instance.showTestNotification(),
            title: const Text('测试通知'),
            subtitle: const Text('立即发送一条本地通知'),
          ),
        ],
      ),
    );
  }

  Widget _buildVersionTitle() {
    if (_checking) return Text('${l10n.version} · ${l10n.upgradeChecking}');
    if (_hasUpdate == true) {
      return Text(
        '${l10n.version} · ${l10n.upgradeAvailable(_versionInfo?.versionName ?? '')}',
        style: TextStyle(color: Theme.of(context).colorScheme.primary),
      );
    }
    if (_hasUpdate == false) return Text('${l10n.version} · ${l10n.upgradeUpToDate}');
    return Text(l10n.version);
  }

  Widget _buildVersionSubtitle() {
    var current = '$version ($_buildNumber)';
    if (AppConfig.buildGitCommit.isNotEmpty) current += ' · ${AppConfig.buildGitCommit}';
    if (AppConfig.buildTime.isNotEmpty) current += ' · ${AppConfig.buildTime}';
    return Text(current);
  }

  void _onApiStatTap() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => ServerApiStatsPage()));
  }

  void _onAppFolderTap() {
    Clipboard.setData(ClipboardData(text: AppConfig.appRootDir));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${l10n.dataDirCopied}: ${AppConfig.appRootDir}'), duration: const Duration(seconds: 2)),
    );
  }

  void _onRecordsDbTap() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => RecordDatabasePage()));
  }

  void _onOperatesDbTap() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => RecordOperatesPage()));
  }
}
