import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'http_api.dart';

class UserLoginState {
  final User user;
  final bool isLogin;
  const UserLoginState(this.user, this.isLogin);

  @override
  String toString() => 'UserLoginState(key: ${user.key}, isLogin: $isLogin)';
}

// =============================================================================
// User — data model + instance lifecycle methods (logout/clearToken/autoRelogin)
// =============================================================================

class User {

  final int id;
  String? name;
  String? token;
  String? password;
  String? apiUrl;

  bool get isGuest => id == 0;
  bool get isLoggedIn => !isGuest && token != null && token!.isNotEmpty && apiUrl != null && apiUrl!.isNotEmpty;

  /// 稳定唯一键：base64url(hash("apiUrl|id"))，11 字符，天然唯一
  String get key {
    return calcKey(id, apiUrl);
  }

  static String calcKey(int id, String? apiUrl) {
    if (id == 0) return 'guest';
    final bd = ByteData(4)..setUint32(0, '${apiUrl ?? ''}|$id'.hashCode & 0xFFFFFFFF);
    return base64Url.encode(bd.buffer.asUint8List()).replaceAll('=', '');
  }

  /// 用户数据目录名：user_{key}_{id}。guest → 'guest'。
  String get folderName {
    return '${key}_$id';
  }

  /// Absolute path to this user's data directory: appRootDir/folderName.
  String get dirAbsPath => p.join(UserManager.appRootDir, folderName);

  User({required this.id});

  User.fromMap(Map<String, dynamic> m) : id = (m['id'] as num?)?.toInt() ?? 0 {
    name = m['name'] as String?;
    token = m['token'] as String?;
    password = m['password'] as String?;
    apiUrl = m['apiUrl'] as String?;
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'id': id,
    'name': name,
    if (token != null && token!.isNotEmpty) 'token': token,
    if (password != null && password!.isNotEmpty) 'password': password,
    if (apiUrl != null && apiUrl!.isNotEmpty) 'apiUrl': apiUrl,
  };

  // =========================================================================
  // Instance lifecycle — operates on [this], persists via [UserManager]
  // =========================================================================

  /// Clear token + password, persist, refresh stateNotifier.
  /// Leaves id/name intact so local DB stays open for offline editing.
  Future<void> logout() async {
    token = null;
    password = null;
    if (!isGuest) {
      await UserManager._syncAndPersist(this);
    }
    UserManager._notifyState();
  }

  /// Clear only the remote token (keep password for potential auto-relogin).
  Future<void> clearToken() async {
    token = null;
    if (!isGuest) {
      await UserManager._syncAndPersist(this);
    }
    UserManager._notifyState();
  }

  /// Try to login with saved credentials. On success refreshes token
  /// and ensures this user is the current one.
  Future<bool> autoRelogin() async {
    if (id == 0 || name == null || name!.isEmpty || apiUrl == null || apiUrl!.isEmpty) return false;
    final pwd = password;
    if (pwd == null || pwd.isEmpty) return false;
    try {
      final result = await HttpApi.login(name!, pwd);
      if (result.code == 200 && result.data != null) {
        await UserManager.setLogin(id, name!, result.data!.token, pwd, apiUrl!);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}

// =============================================================================
// UserManager — owns the users list + current reference + persistence + setLogin
// =============================================================================

class UserManager {
  static const String kGuestDirName = 'guest';
  static const _kCurrentKey = 'user_curr_key';
  static const _kUsers = 'user_list';

  /// Find a user in [list] matching both apiUrl and id.
  /// Falls back to id-only match only if apiUrl is null/empty (guest / legacy).
  static int _findUser(List<User> list, String userKey) {
    if (userKey.isEmpty) return -1;
    return list.indexWhere((u) => u.key == userKey);
  }

  /// In-memory saved-account list. [current] always points to one of these
  /// elements when logged in, or to a fresh [User] in guest mode.
  static List<User> users = [];

  /// The currently-active user. In guest mode this is a transient [User];
  /// once logged in it becomes the matching element inside [users].
  static late User current;
  static final User guest = User(id: 0);

  /// Base directory for all user data folders (guest, 1_0, 2_1, ...).
  /// Set once by [init].
  static String appRootDir = '';

  static final stateNotifier = ValueNotifier<UserLoginState>(UserLoginState(guest, false));

  // =========================================================================
  // Persistence — package-private (User can call these since same library)
  // =========================================================================

  static Future<List<User>> _loadUsers(SharedPreferences sp) async {
    final raw = sp.getString(_kUsers);
    if (raw == null || raw.isEmpty) return [];
    try {
      final List list = jsonDecode(raw);
      final loaded = list.map((e) => User.fromMap(Map<String, dynamic>.from(e as Map))).where((u) => u.id > 0).toList();
      return loaded;
    } catch (_) {
      return [];
    }
  }

  static Future<void> _saveUsers(SharedPreferences sp, List<User> list) async {
    final nonGuest = list.where((u) => u.id != 0).toList();
    if (nonGuest.isEmpty) {
      await sp.remove(_kUsers);
    } else {
      await sp.setString(_kUsers, jsonEncode(nonGuest.map((u) => u.toMap()).toList()));
    }
  }

  /// Sync a live user's token/password fields back into [users] and persist.
  /// Used by [User.logout]/[User.clearToken] after they mutate `this`.
  static Future<void> _syncAndPersist(User u) async {
    final idx = _findUser(users, u.key);
    if (idx >= 0) {
      users[idx].token = u.token;
      users[idx].password = u.password;
      final sp = await SharedPreferences.getInstance();
      await _saveUsers(sp, users);
    }
  }

  static void _notifyState() {
    final cur = stateNotifier.value;
    if (cur.user.key == current.key && cur.isLogin == current.isLoggedIn) return;
    stateNotifier.value = UserLoginState(current, current.isLoggedIn);
  }

  // =========================================================================
  // Public API
  // =========================================================================

  static Future<void> init(String appRootDir) async {
    UserManager.appRootDir = appRootDir;
    final sp = await SharedPreferences.getInstance();
    final savedKey = sp.getString(_kCurrentKey) ?? '';
    users = await _loadUsers(sp);
    final idx = users.indexWhere((u) => u.key == savedKey);
    if (idx >= 0) {
      current = users[idx]; // reference into the list
      if (current.apiUrl != null && current.apiUrl!.isNotEmpty) {
        HttpApi.setBaseUrl(current.apiUrl!);
      }
    } else {
      current = guest; // guest mode
    }
    _notifyState();
  }

  static List<User> getUsers() => users;

  /// Find-or-create a user, persist, make it [current].
  /// On an existing entry we preserve password/apiUrl if not supplied.
  static Future<void> setLogin(int userId, String userName, String userToken, String password, String apiUrl) async {
    final sp = await SharedPreferences.getInstance();

    final idx = _findUser(users, User.calcKey(userId, apiUrl));
    if (idx >= 0) {
      // Update in place — current becomes this element
      final entry = users[idx];
      entry.name = userName;
      entry.token = userToken;
      entry.password = password;
      entry.apiUrl = apiUrl;
      current = entry;
    } else {
      // Brand-new account
      final entry = User(id: userId)
        ..name = userName
        ..token = userToken
        ..password = password.isNotEmpty ? password : null
        ..apiUrl = apiUrl;
      users.add(entry);
      current = entry;
    }
    await sp.setString(_kCurrentKey, current.key);
    await _saveUsers(sp, users);
    _notifyState();
  }

  // =========================================================================
  // Account switch / delete
  // =========================================================================

  /// Switch to a saved account: make it [current], restore apiUrl,
  /// then try to login with saved credentials.
  static Future<bool> switchTo(User saved) async {
    final userId = saved.id;
    if (userId == 0) return false;
    // Ensure saved is present in our live list (may come from old getUsers result)
    var idx = _findUser(users, saved.key);
    if (idx < 0) {
      users.add(User.fromMap(saved.toMap()));
      idx = users.length - 1;
    }
    current = users[idx];
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kCurrentKey, current.key);
    await _saveUsers(sp, users);
    if (current.apiUrl != null && current.apiUrl!.isNotEmpty) {
      HttpApi.setBaseUrl(current.apiUrl!);
    }
    _notifyState();

    final pwd = current.password;
    if (pwd != null && pwd.isNotEmpty) {
      try {
        final result = await HttpApi.login(current.name!, pwd);
        if (result.code == 200 && result.data != null) {
          current.token = result.data!.token;
          await _saveUsers(sp, users);
          _notifyState();
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  /// Remove a saved account from memory + disk + optional data directory.
  static Future<void> removeAccount(User user) async {
    var removed = guest;
    final idx = _findUser(users, user.key);
    if (idx >= 0) {
      removed = users[idx];
      users.removeAt(idx);
    }
    final sp = await SharedPreferences.getInstance();
    await _saveUsers(sp, users);
    if (removed != guest && appRootDir.isNotEmpty) {
      final dir = Directory(removed.dirAbsPath);
      if (await dir.exists()) {
        try {
          await dir.delete(recursive: true);
        } catch (_) {}
      }
    }
    if (current.key == user.key) {
      // current is the one to be removed
      current = guest;
      _notifyState();
    }
  }
}
