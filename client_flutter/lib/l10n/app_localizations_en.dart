// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get created => 'Created';

  @override
  String get modified => 'Modified';

  @override
  String get deleted => 'Deleted';

  @override
  String get loadFailed => 'Load failed';

  @override
  String get noData => 'No data';

  @override
  String get settings => 'Settings';

  @override
  String get apiCallStats => 'API Call Statistics';

  @override
  String get callCount => 'Call count';

  @override
  String get syncServer => 'Sync Server';

  @override
  String get syncAccount => 'Sync Account';

  @override
  String get dataDirectory => 'Data Directory';

  @override
  String get theme => 'Theme';

  @override
  String get version => 'Version';

  @override
  String get notLoggedIn => 'Not logged in';

  @override
  String get loginExpired => 'Login expired, please login again';

  @override
  String get confirmLogout => 'Are you sure you want to logout?';

  @override
  String get logout => 'Logout';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get selectTheme => 'Select Theme';

  @override
  String get dataDirCopied => 'Data directory copied to clipboard';

  @override
  String get sync => 'Sync';

  @override
  String get syncSuccess => 'Sync success';

  @override
  String get syncing => 'Syncing...';

  @override
  String get syncErrUnknown => 'Sync failed: Unknown error';

  @override
  String get syncErrNetwork =>
      'Sync failed: Network error, check your connection';

  @override
  String get syncErrTimeout => 'Sync failed: Request timeout, please retry';

  @override
  String get syncErrAuthInvalid => 'Login expired, please login again';

  @override
  String get syncErrConflict => 'Conflict detected, please resolve';

  @override
  String get syncErrServerDb => 'Sync failed: Server database error';

  @override
  String get syncErrRecordNotFound => 'Sync failed: Note not found';

  @override
  String get syncErrParams => 'Sync failed: Invalid parameters';

  @override
  String get syncErrFileSave => 'Sync failed: Failed to save file';

  @override
  String get syncErrFileNotFound => 'Sync failed: File not found';

  @override
  String get errorDetails => 'Error Details';

  @override
  String get close => 'Close';

  @override
  String get loading => 'Loading...';

  @override
  String get recordLocked => 'Note is locked';

  @override
  String get enterPasswordToUnlock => 'Please enter password to unlock note';

  @override
  String get enterPassword => 'Please enter password';

  @override
  String get unlock => 'Unlock';

  @override
  String get passwordIncorrect => 'Password incorrect, please re-enter';

  @override
  String get saveRecordFailed => 'Save note failed';

  @override
  String get newRecord => 'New Note';

  @override
  String get upperLevel => 'Upper level';

  @override
  String moveFileTo(Object file) {
    return 'Move $file to';
  }

  @override
  String get outOfBounds => 'Out of bounds';

  @override
  String get moveFile => 'Move File';

  @override
  String get newFolder => 'New Folder';

  @override
  String get deleteFolder => 'Delete Folder';

  @override
  String get renameFolder => 'Rename Folder';

  @override
  String get moveFolder => 'Move Folder';

  @override
  String get unlockFile => 'Unlock File';

  @override
  String get lockFile => 'Lock File';

  @override
  String get deleteFile => 'Delete File';

  @override
  String get rename => 'Rename';

  @override
  String get enterLockPassword => 'Enter lock password';

  @override
  String get enterUnlockPassword => 'Enter unlock password';

  @override
  String get delete => 'Delete';

  @override
  String movedToPath(Object fileName, Object path) {
    return 'Moved $fileName to $path';
  }

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeFlat => 'Neon';

  @override
  String get themePurple => 'Purple';

  @override
  String get themeDarkRed => 'DarkRed';

  @override
  String get themeEarth => 'Earth';

  @override
  String get themeOrange => 'Orange';

  @override
  String get themeClassic => 'Classic';

  @override
  String get pleaseSelectRecord => 'Please select a note';

  @override
  String get lock => 'Lock';

  @override
  String lockUnlockFailedCheckPassword(Object operation) {
    return '$operation failed, please check password';
  }

  @override
  String get cannotReadRecordContent => 'Cannot read note content';

  @override
  String get login => 'Login';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get confirmDelete => 'Confirm Delete?';

  @override
  String get confirmDeleteThisRecord =>
      'Are you sure you want to delete this note?';

  @override
  String get confirmDeleteThisFolderAndAllRecords =>
      'Are you sure you want to delete this folder and all its notes?';

  @override
  String folderDeleted(Object folderPath) {
    return 'Deleted folder $folderPath';
  }

  @override
  String recordLockUnlockCompleted(Object operation) {
    return 'Note $operation completed';
  }

  @override
  String saveLockUnlockContentFailed(Object operation) {
    return 'Failed to save $operation content';
  }

  @override
  String recordDeleted(Object fileName) {
    return 'Deleted note $fileName';
  }

  @override
  String get isDeleted => 'Deleted';

  @override
  String get notExists => 'Not exists';

  @override
  String get noOpenRecords => 'No open notes';

  @override
  String get language => 'Language';

  @override
  String get followSystem => 'Follow System';

  @override
  String get chinese => '中文';

  @override
  String get english => 'English';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get minimize => 'Minimize';

  @override
  String get maximize => 'Maximize';

  @override
  String get restore => 'Restore';

  @override
  String get windowClose => 'Close';

  @override
  String get showAllTabs => 'Show all tabs';

  @override
  String get database => 'Database';

  @override
  String get operates => 'Activity Log';

  @override
  String emptyInputCheck(Object input) {
    return 'Please input $input';
  }

  @override
  String get importDocument => 'Import Documents';

  @override
  String get importSuccess => 'Import File Success';

  @override
  String get importFailed => 'Import File Failed';

  @override
  String get collapseAll => 'Collapse All Folders';

  @override
  String get undo => 'Undo';

  @override
  String get redo => 'Redo';

  @override
  String get files => 'Files';

  @override
  String get lastModify => 'Last Modified';

  @override
  String get closeOtherTabs => 'Close Other Tabs';

  @override
  String get closeAllTabs => 'Close All Tabs';

  @override
  String get closeTabsToRight => 'Close Tabs to the Right';

  @override
  String get closeTabsToLeft => 'Close Tabs to the Left';

  @override
  String get record => 'Note';

  @override
  String get sortType => 'Sort & View';

  @override
  String get sortTypeTreeFolder => 'Tree Folder';

  @override
  String get sortTypeFlatFolder => 'Flat Folder';

  @override
  String get sortTypeName => 'Sort by Name';

  @override
  String get sortTypeTime => 'Sort by Modified';

  @override
  String get copy => 'Copy';

  @override
  String get cut => 'Cut';

  @override
  String get paste => 'Paste';

  @override
  String syncConflictTitle(Object count) {
    return 'Sync Conflicts ($count)';
  }

  @override
  String get noConflicts => 'No conflicts';

  @override
  String get hasConflict => 'Conflict';

  @override
  String get fileConflict => 'File Conflict';

  @override
  String get metaConflict => 'Meta Conflict';

  @override
  String get fileContentUnchangedMetaConflict =>
      'File content unchanged, metadata conflict only. Please choose which side to keep.';

  @override
  String get conflictRemoteVersion => 'Remote Version';

  @override
  String get conflictLocalModified => 'Local Modifications';

  @override
  String get keepRemote => 'Keep Remote';

  @override
  String get keepLocal => 'Keep Local';

  @override
  String get orientationHorizontal => 'Horizontal Layout';

  @override
  String get orientationVertical => 'Vertical Layout';

  @override
  String get upgradeChecking => 'Checking...';

  @override
  String get upgradeCheckFailed => 'Check failed';

  @override
  String get upgradeUpToDate => 'Up to date ✓';

  @override
  String upgradeAvailable(Object version) {
    return 'New version $version available';
  }

  @override
  String upgradeCurrentVersion(Object current, Object latest) {
    return 'Current: v$current → Latest: $latest';
  }

  @override
  String get upgradeChangelog => 'Changelog';

  @override
  String get upgradeNoChangelog => '(none)';

  @override
  String get upgradeCopyDownloadUrl => 'Copy download URL';

  @override
  String upgradeDownloadCopied(Object url) {
    return 'Download URL copied: $url';
  }

  @override
  String get upgradeIOS => 'iOS: update via App Store';

  @override
  String upgradeServerUrl(Object url) {
    return 'via $url';
  }

  @override
  String get upgradeDownloadAndInstall => 'Download & Install';

  @override
  String get upgradeReinstall => 'Reinstall current version';

  @override
  String get upgradeDownloading => 'Downloading...';

  @override
  String get upgradeDownloadSuccess => 'Download complete';

  @override
  String get upgradeDownloadFailed => 'Download failed';

  @override
  String get switchToPad => 'Switch to tablet mode';

  @override
  String get switchToPhone => 'Switch to phone mode';

  @override
  String get reminderTasks => 'Reminders';

  @override
  String get noReminderTasks => 'No reminders';

  @override
  String get unnamedTask => 'Untitled';

  @override
  String get notSet => 'Not set';

  @override
  String get repeatOnce => 'Once';

  @override
  String get repeatWeekly => 'Weekly';

  @override
  String get repeatMonthly => 'Monthly';

  @override
  String get repeatYearly => 'Yearly';

  @override
  String get editReminder => 'Edit reminder';

  @override
  String get taskName => 'Task name';

  @override
  String get repeat => 'Repeat';

  @override
  String get save => 'Save';

  @override
  String get addReminder => 'Add reminder';

  @override
  String get weekdays => 'Mon|Tue|Wed|Thu|Fri|Sat|Sun';

  @override
  String get calendarTasks => 'Calendar';

  @override
  String get noRemindersToday => 'No reminders today';

  @override
  String get reminder => 'Reminder';

  @override
  String get today => 'Today';

  @override
  String repeatMonthlyTime(int day, String time) {
    return '$day $time';
  }

  @override
  String repeatYearlyTime(int month, int day, String time) {
    return '$month/$day $time';
  }

  @override
  String get reminderChannel => 'Reminder';

  @override
  String get reminderChannelDesc => 'Note task reminders';

  @override
  String get reminderDueBody => 'This reminder is due';

  @override
  String get unitYear => 'y';

  @override
  String get unitMonth => 'm';

  @override
  String get unitDay => 'd';

  @override
  String get unitHour => 'h';

  @override
  String get unitMinute => 'min';

  @override
  String get atLeastOneWeekday => 'Please select at least one weekday';
}
