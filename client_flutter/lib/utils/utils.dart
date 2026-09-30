import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:intl/intl.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/key_derivators/api.dart';
import 'package:pointycastle/key_derivators/pbkdf2.dart';

typedef ReturnCallback<T> = T Function();
typedef ValueCallback<T> = void Function(T value);
typedef ValueCallback2<T, T1> = void Function(T value, T1 t1);

/// Pure utility methods, independent of Note123 business logic.
class Utils {
  /// Open a URL using the system default handler (e.g., browser)
  static Future<void> openUrlWithSystem(url) async {
    if (Platform.isWindows) {
      await Process.run('start', [url], runInShell: true);
    } else if (Platform.isMacOS) {
      await Process.run('open', [url]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [url]);
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  // ---------------------------------------------------------------
  // Encryption/decryption (password-based, PBKDF2 + AES)
  // ---------------------------------------------------------------

  /// Encrypt based on password. Output format: salt:iv:encryptedContent (Base64)
  static String? encryptContent(String content, String password) {
    try {
      final salt = encrypt.IV.fromSecureRandom(16);
      final key = encrypt.Key.fromBase64(_generateKeyFromPassword(password, salt.base64));
      final iv = encrypt.IV.fromSecureRandom(16);
      final encrypter = encrypt.Encrypter(encrypt.AES(key));
      final encrypted = encrypter.encrypt(content, iv: iv);
      return '${salt.base64}:${iv.base64}:${encrypted.base64}';
    } catch (e) {
      return null;
    }
  }

  /// Decrypt based on password. Input format: salt:iv:encryptedContent (Base64)
  static String? decryptContent(String encryptedContent, String password) {
    try {
      final parts = encryptedContent.split(':');
      if (parts.length != 3) return null;
      final salt = parts[0];
      final iv = encrypt.IV.fromBase64(parts[1]);
      final encrypted = encrypt.Encrypted.fromBase64(parts[2]);
      final key = encrypt.Key.fromBase64(_generateKeyFromPassword(password, salt));
      final encrypter = encrypt.Encrypter(encrypt.AES(key));
      return encrypter.decrypt(encrypted, iv: iv);
    } catch (e) {
      return null;
    }
  }

  static String _generateKeyFromPassword(String password, String saltBase64) {
    final salt = base64.decode(saltBase64);
    final derivator = PBKDF2KeyDerivator(Mac("SHA-256/HMAC"))
      ..init(Pbkdf2Parameters(Uint8List.fromList(salt), 1000, 32));
    final keyBytes = derivator.process(Uint8List.fromList(utf8.encode(password)));
    return base64.encode(keyBytes);
  }

  // ---------------------------------------------------------------
  // MD5 hashing
  // ---------------------------------------------------------------

  static String generateMd5(String s) {
    return md5.convert(utf8.encode(s)).toString().toUpperCase();
  }

  static Future<String> generateFileMd5({String? filePath, File? file}) async {
    var f = file ?? File(filePath!);
    if (!await f.exists()) return '';
    // Stream-based chunked computation to avoid loading entire large files into memory
    final digest = await md5.bind(f.openRead()).first;
    return digest.toString().toUpperCase();
  }

  // ---------------------------------------------------------------
  // Platform detection
  // ---------------------------------------------------------------

  static bool isDesktop() {
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  }

  // ---------------------------------------------------------------
  // Time formatting
  // ---------------------------------------------------------------

  static String formatTime(int ts) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ts);
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);
  }

  static String formatShortTime(int ts) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ts);
    final now = DateTime.now();
    String _pad(int v) => v.toString().padLeft(2, '0');
    final h = _pad(dt.hour);
    final m = _pad(dt.minute);
    final mo = _pad(dt.month);
    final d = _pad(dt.day);
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return '$h:$m';
    }
    if (dt.year == now.year) {
      return '$mo-$d $h:$m';
    }
    return '${dt.year}-$mo-$d $h:$m';
  }

  static String formatTimeNow() {
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
  }
}
