import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'http_api.dart';

class User {
  static const _kUserId = 'user_id';
  static const _kUserName = 'user_name';
  static const _kUserToken = 'user_token';
  static const _kUserPassword = 'user_password';

  int id = 0;
  String? name;
  String? token;

  final ValueNotifier<bool> isLogin = ValueNotifier<bool>(false);

  static final User instance = User._internal();

  User._internal();

  Future<void> init() async {
    final sp = await SharedPreferences.getInstance();
    id = sp.getInt(_kUserId) ?? 0;
    name = sp.getString(_kUserName);
    token = sp.getString(_kUserToken);
    isLogin.value = id > 0 && token != null && token!.isNotEmpty;
  }

  Future<void> setLogin(int userId, String userName, String userToken, {String? password}) async {
    id = userId;
    name = userName;
    token = userToken;
    final sp = await SharedPreferences.getInstance();
    await sp.setInt(_kUserId, userId);
    await sp.setString(_kUserName, userName);
    await sp.setString(_kUserToken, userToken);
    if (password != null && password.isNotEmpty) {
      await sp.setString(_kUserPassword, password);
    }
    isLogin.value = true;
  }

  Future<void> logout() async {
    id = 0;
    token = null;
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kUserId);
    await sp.remove(_kUserToken);
    await sp.remove(_kUserPassword);
    isLogin.value = false;
  }

  Future<void> forgetUser() async {
    id = 0;
    name = null;
    token = null;
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kUserId);
    await sp.remove(_kUserName);
    await sp.remove(_kUserToken);
    await sp.remove(_kUserPassword);
    isLogin.value = false;
  }

  Future<void> clearToken() async {
    token = null;
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kUserToken);
    await sp.remove(_kUserPassword);
    isLogin.value = false;
  }

  Future<bool> autoRelogin() async {
    if (id == 0 || name == null || name!.isEmpty) return false;
    final sp = await SharedPreferences.getInstance();
    final pwd = sp.getString(_kUserPassword);
    if (pwd == null || pwd.isEmpty) return false;
    try {
      final result = await HttpApi.login(name!, pwd);
      if (result.code == 200 && result.data != null) {
        await setLogin(id, name!, result.data!.token, password: pwd);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
