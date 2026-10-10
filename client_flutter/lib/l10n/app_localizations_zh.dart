// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get created => '创建';

  @override
  String get modified => '修改';

  @override
  String get deleted => '删除';

  @override
  String get loadFailed => '加载失败';

  @override
  String get noData => '暂无数据';

  @override
  String get settings => '设置';

  @override
  String get apiCallStats => 'API调用统计';

  @override
  String get callCount => '调用次数';

  @override
  String get syncServer => '同步服务器';

  @override
  String get syncAccount => '同步账号';

  @override
  String get dataDirectory => '数据目录';

  @override
  String get theme => '主题';

  @override
  String get version => '版本';

  @override
  String get notLoggedIn => '未登录';

  @override
  String get loginExpired => '登录失效,请重新登陆';

  @override
  String get confirmLogout => '确定要退出登录吗？';

  @override
  String get logout => '退出登录';

  @override
  String get cancel => '取消';

  @override
  String get confirm => '确定';

  @override
  String get selectTheme => '选择主题';

  @override
  String get dataDirCopied => '数据目录已复制到剪贴板';

  @override
  String get sync => '同步';

  @override
  String get syncSuccess => '同步成功';

  @override
  String get syncing => '正在同步...';

  @override
  String get syncErrUnknown => '同步失败: 未知错误';

  @override
  String get syncErrNetwork => '同步失败: 网络连接异常, 请检查网络';

  @override
  String get syncErrTimeout => '同步失败: 请求超时, 请稍后重试';

  @override
  String get syncErrAuthInvalid => '登录状态已失效, 请重新登录';

  @override
  String get syncErrConflict => '有冲突文件, 请点击解决';

  @override
  String get syncErrServerDb => '同步失败: 服务端数据库错误';

  @override
  String get syncErrRecordNotFound => '同步失败: 笔记不存在';

  @override
  String get syncErrParams => '同步失败: 参数错误';

  @override
  String get syncErrFileSave => '同步失败: 文件保存失败';

  @override
  String get syncErrFileNotFound => '同步失败: 文件不存在';

  @override
  String get errorDetails => '错误详情';

  @override
  String get close => '关闭';

  @override
  String get loading => '加载中...';

  @override
  String get recordLocked => '笔记已锁定';

  @override
  String get enterPasswordToUnlock => '请输入密码解锁笔记';

  @override
  String get enterPassword => '请输入密码';

  @override
  String get unlock => '解锁';

  @override
  String get passwordIncorrect => '密码错误，请重新输入';

  @override
  String get saveRecordFailed => '保存笔记失败';

  @override
  String get newRecord => '新建笔记';

  @override
  String get upperLevel => '上一级';

  @override
  String moveFileTo(Object file) {
    return '移动 $file 到';
  }

  @override
  String get outOfBounds => '超出范围';

  @override
  String get moveFile => '移动文件';

  @override
  String get newFolder => '新建文件夹';

  @override
  String get deleteFolder => '删除文件夹';

  @override
  String get renameFolder => '重命名文件夹';

  @override
  String get moveFolder => '移动文件夹';

  @override
  String get unlockFile => '解锁文件';

  @override
  String get lockFile => '锁定文件';

  @override
  String get deleteFile => '删除文件';

  @override
  String get rename => '重命名';

  @override
  String get enterLockPassword => '输入加锁密码';

  @override
  String get enterUnlockPassword => '输入解锁密码';

  @override
  String get delete => '删除';

  @override
  String movedToPath(Object fileName, Object path) {
    return '已将 $fileName 移动到 $path';
  }

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get themeFlat => '霓虹';

  @override
  String get themePurple => '紫色';

  @override
  String get themeDarkRed => '黑红';

  @override
  String get themeEarth => '暖陶土';

  @override
  String get themeOrange => '橙色';

  @override
  String get themeClassic => '古典';

  @override
  String get pleaseSelectRecord => '请选择笔记';

  @override
  String get lock => '加锁';

  @override
  String lockUnlockFailedCheckPassword(Object operation) {
    return '$operation失败，请检查密码';
  }

  @override
  String get cannotReadRecordContent => '无法读取笔记内容';

  @override
  String get login => '登录';

  @override
  String get username => '用户名';

  @override
  String get password => '密码';

  @override
  String get confirmDelete => '确认删除？';

  @override
  String get confirmDeleteThisRecord => '确定要删除这个笔记吗？';

  @override
  String get confirmDeleteThisFolderAndAllRecords => '确定要删除这个文件夹及其所有笔记吗？';

  @override
  String folderDeleted(Object folderPath) {
    return '已删除文件夹 $folderPath';
  }

  @override
  String recordLockUnlockCompleted(Object operation) {
    return '笔记$operation完成';
  }

  @override
  String saveLockUnlockContentFailed(Object operation) {
    return '保存$operation内容失败';
  }

  @override
  String recordDeleted(Object fileName) {
    return '已删除笔记 $fileName';
  }

  @override
  String get isDeleted => '已删除';

  @override
  String get notExists => '不存在';

  @override
  String get noOpenRecords => '未打开笔记';

  @override
  String get language => '语言';

  @override
  String get followSystem => '跟随系统';

  @override
  String get chinese => '中文';

  @override
  String get english => 'English';

  @override
  String get selectLanguage => '选择语言';

  @override
  String get minimize => '最小化';

  @override
  String get maximize => '最大化';

  @override
  String get restore => '还原';

  @override
  String get windowClose => '关闭';

  @override
  String get showAllTabs => '显示所有标签页';

  @override
  String get database => '数据库';

  @override
  String get operates => '操作日志';

  @override
  String emptyInputCheck(Object input) {
    return '请输入$input';
  }

  @override
  String get importDocument => '导入文档';

  @override
  String get importSuccess => '文件导入成功';

  @override
  String get importFailed => '文件导入失败';

  @override
  String get collapseAll => '收起所有文件夹';

  @override
  String get undo => '撤销';

  @override
  String get redo => '重做';

  @override
  String get files => '个文件';

  @override
  String get lastModify => '上次修改';

  @override
  String get closeOtherTabs => '关闭其他标签';

  @override
  String get closeAllTabs => '关闭所有标签';

  @override
  String get closeTabsToRight => '关闭右侧标签';

  @override
  String get closeTabsToLeft => '关闭左侧标签';

  @override
  String get record => '笔记';

  @override
  String get sortType => '查看与排序';

  @override
  String get sortTypeTreeFolder => '树形文件夹';

  @override
  String get sortTypeFlatFolder => '平铺文件夹';

  @override
  String get sortTypeName => '按名字排序';

  @override
  String get sortTypeTime => '按时间排序';

  @override
  String get copy => '复制';

  @override
  String get cut => '剪切';

  @override
  String get paste => '粘贴';

  @override
  String syncConflictTitle(Object count) {
    return '同步冲突 ($count)';
  }

  @override
  String get noConflicts => '暂无冲突';

  @override
  String get hasConflict => '有冲突';

  @override
  String get fileConflict => '文件冲突';

  @override
  String get metaConflict => '元数据冲突';

  @override
  String get fileContentUnchangedMetaConflict =>
      '文件内容未改变, 仅元数据冲突. 请选择保留哪一侧的修改.';

  @override
  String get conflictRemoteVersion => '远端版本';

  @override
  String get conflictLocalModified => '本地修改';

  @override
  String get keepRemote => '保留远端';

  @override
  String get keepLocal => '保留本地';

  @override
  String get orientationHorizontal => '横向排列';

  @override
  String get orientationVertical => '竖向排列';

  @override
  String get upgradeChecking => '正在检查...';

  @override
  String get upgradeCheckFailed => '检查失败';

  @override
  String get upgradeUpToDate => '已是最新版本 ✓';

  @override
  String upgradeAvailable(Object version) {
    return '有新版本 $version';
  }

  @override
  String upgradeCurrentVersion(Object current, Object latest) {
    return '当前版本: v$current → 最新: $latest';
  }

  @override
  String get upgradeChangelog => '更新日志';

  @override
  String get upgradeNoChangelog => '(无)';

  @override
  String get upgradeCopyDownloadUrl => '复制下载链接';

  @override
  String upgradeDownloadCopied(Object url) {
    return '下载链接已复制: $url';
  }

  @override
  String get upgradeIOS => 'iOS 端需通过 App Store 更新';

  @override
  String upgradeServerUrl(Object url) {
    return '服务器: $url';
  }

  @override
  String get upgradeDownloadAndInstall => '下载并安装';

  @override
  String get upgradeReinstall => '重新安装当前版本';

  @override
  String get upgradeDownloading => '正在下载...';

  @override
  String get upgradeDownloadSuccess => '下载完成';

  @override
  String get upgradeDownloadFailed => '下载失败';

  @override
  String get switchToPad => '切换到平板模式';

  @override
  String get switchToPhone => '切换到手机模式';

  @override
  String get reminderTasks => '提醒任务';

  @override
  String get noReminderTasks => '暂无提醒任务';

  @override
  String get unnamedTask => '未命名任务';

  @override
  String get notSet => '未设置';

  @override
  String get repeatOnce => '单次';

  @override
  String get repeatWeekly => '每周';

  @override
  String get repeatMonthly => '每月';

  @override
  String get repeatYearly => '每年';

  @override
  String get editReminder => '编辑提醒';

  @override
  String get taskName => '任务名称';

  @override
  String get repeat => '重复';

  @override
  String get save => '保存';

  @override
  String get addReminder => '添加提醒';

  @override
  String get weekdays => '周一|周二|周三|周四|周五|周六|周日';

  @override
  String get calendarTasks => '日历任务';

  @override
  String get noRemindersToday => '当天无提醒';

  @override
  String get reminder => '提醒';

  @override
  String get today => '今';

  @override
  String repeatMonthlyTime(int day, String time) {
    return '$day日 $time';
  }

  @override
  String repeatYearlyTime(int month, int day, String time) {
    return '$month月$day日 $time';
  }

  @override
  String get reminderChannel => '提醒';

  @override
  String get reminderChannelDesc => '笔记任务提醒';

  @override
  String get reminderDueBody => '该提醒已到时间';

  @override
  String get unitYear => '年';

  @override
  String get unitMonth => '月';

  @override
  String get unitDay => '日';

  @override
  String get unitHour => '时';

  @override
  String get unitMinute => '分';

  @override
  String get atLeastOneWeekday => '请至少选择一个星期';
}
