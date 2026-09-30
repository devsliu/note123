import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Device type enumeration
enum DeviceType { desktop, phone, pad }

class DeviceInfo {
  static const MethodChannel _channel = MethodChannel('device_info');
  static DeviceType? _cachedDeviceType;

  static DeviceType get deviceType {
    if (_cachedDeviceType != null) {
      return _cachedDeviceType!;
    }
    throw Exception('Device type not initialized. Call readDeviceType() first.');
  }

  /// Read the current device type
  static Future<DeviceType> readDeviceType() async {
    if (_cachedDeviceType != null) {
      return _cachedDeviceType!;
    }

    if (kIsWeb) {
      _cachedDeviceType = DeviceType.desktop;
      return _cachedDeviceType!;
    }

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      _cachedDeviceType = DeviceType.desktop;
      return _cachedDeviceType!;
    }

    if (Platform.isAndroid || Platform.isIOS) {
      // Try to get device type from Android BuildConfig
      try {
        _cachedDeviceType = await _getAndroidDeviceType();
        return _cachedDeviceType!;
      } catch (e) {
        // If that fails, fall back to screen size detection
        _cachedDeviceType = DeviceType.phone; // Default to phone
        return _cachedDeviceType!;
      }
    }

    _cachedDeviceType = DeviceType.phone;
    return _cachedDeviceType!;
  }

  /// Get device type from Android BuildConfig
  static Future<DeviceType> _getAndroidDeviceType() async {
    if (Platform.isAndroid) {
      try {
        final String deviceType = await _channel.invokeMethod('getDeviceType');
        switch (deviceType) {
          case 'phone':
            return DeviceType.phone;
          case 'pad':
            return DeviceType.pad;
          default:
            return DeviceType.phone;
        }
      } catch (e) {
        return DeviceType.phone;
      }
    }
    return DeviceType.phone;
  }

  /// Get device type string (for API calls)
  static String getDeviceTypeString() {
    switch (deviceType) {
      case DeviceType.desktop:
        if (Platform.isWindows) return 'windows';
        if (Platform.isMacOS) return 'macos';
        if (Platform.isLinux) return 'linux';
        return 'desktop';
      case DeviceType.phone:
        return 'android_phone';
      case DeviceType.pad:
        return 'android_pad';
    }
  }

  /// Check if running on desktop platform
  static Future<bool> isDesktop() async {
    return deviceType == DeviceType.desktop;
  }

  /// Check if running on phone
  static Future<bool> isPhone() async {
    return deviceType == DeviceType.phone;
  }

  /// Check if running on tablet
  static Future<bool> isPad() async {
    return deviceType == DeviceType.pad;
  }
}
