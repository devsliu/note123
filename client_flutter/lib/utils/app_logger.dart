// lib/utils/app_logger.dart
import 'dart:developer';

class AppLogger {
  static String _now() {
    final now = DateTime.now();
    return "${now.year.toString().padLeft(4, '0')}-"
        "${now.month.toString().padLeft(2, '0')}-"
        "${now.day.toString().padLeft(2, '0')} "
        "${now.hour.toString().padLeft(2, '0')}:"
        "${now.minute.toString().padLeft(2, '0')}:"
        "${now.second.toString().padLeft(2, '0')}."
        "${now.millisecond.toString().padLeft(3, '0')}";
  }

  static void d(String message, {String tag = 'DEBUG'}) {
    log('[${_now()}][$tag] $message');
  }

  static void i(String message, {String tag = 'INFO'}) {
    log('[${_now()}][$tag] $message');
  }

  static void w(String message, {String tag = 'WARN'}) {
    log('[${_now()}][$tag] $message');
  }

  static void e(String message, {String tag = 'ERROR'}) {
    log('[${_now()}][$tag] $message');
  }
}
