import 'package:flutter/services.dart';
import '../models/installed_app.dart';

class AppListService {
  static const MethodChannel _channel = MethodChannel('app_list_service');

  /// Get list of all installed apps on the device
  Future<List<InstalledApp>> getInstalledApps() async {
    try {
      final List<dynamic> appsData = await _channel.invokeMethod('getInstalledApps');
      return appsData.map((appData) => InstalledApp.fromMap(Map<String, dynamic>.from(appData))).toList();
    } catch (e) {
      print('Error getting installed apps: $e');
      return [];
    }
  }

  /// Get list of user-installed apps (excluding system apps)
  Future<List<InstalledApp>> getUserApps() async {
    try {
      final List<dynamic> appsData = await _channel.invokeMethod('getUserApps');
      return appsData.map((appData) => InstalledApp.fromMap(Map<String, dynamic>.from(appData))).toList();
    } catch (e) {
      print('Error getting user apps: $e');
      return [];
    }
  }

  /// Get list of system apps only
  Future<List<InstalledApp>> getSystemApps() async {
    try {
      final List<dynamic> appsData = await _channel.invokeMethod('getSystemApps');
      return appsData.map((appData) => InstalledApp.fromMap(Map<String, dynamic>.from(appData))).toList();
    } catch (e) {
      print('Error getting system apps: $e');
      return [];
    }
  }

  /// Launch an app by package name
  Future<bool> launchApp(String packageName) async {
    try {
      final bool result = await _channel.invokeMethod('launchApp', {'packageName': packageName});
      return result;
    } catch (e) {
      print('Error launching app: $e');
      return false;
    }
  }

  /// Uninstall an app by package name
  Future<bool> uninstallApp(String packageName) async {
    try {
      final bool result = await _channel.invokeMethod('uninstallApp', {'packageName': packageName});
      return result;
    } catch (e) {
      print('Error uninstalling app: $e');
      return false;
    }
  }

  /// Get app info by package name
  Future<InstalledApp?> getAppInfo(String packageName) async {
    try {
      final Map<String, dynamic>? appData = await _channel.invokeMethod('getAppInfo', {'packageName': packageName});
      if (appData != null) {
        return InstalledApp.fromMap(appData);
      }
      return null;
    } catch (e) {
      print('Error getting app info: $e');
      return null;
    }
  }

  /// Check if an app is installed
  Future<bool> isAppInstalled(String packageName) async {
    try {
      final bool result = await _channel.invokeMethod('isAppInstalled', {'packageName': packageName});
      return result;
    } catch (e) {
      print('Error checking if app is installed: $e');
      return false;
    }
  }
}
