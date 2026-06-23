import 'package:permission_handler/permission_handler.dart';

enum AppPermission { microphone, storage }

class PermissionService {
  static Permission _permissionFor(AppPermission permission) {
    switch (permission) {
      case AppPermission.microphone:
        return Permission.microphone;
      case AppPermission.storage:
        return Permission.storage;
    }
  }

  static Future<bool> request(AppPermission permission) async {
    final status = await _permissionFor(permission).request();
    return status.isGranted;
  }

  static Future<bool> isGranted(AppPermission permission) async {
    return _permissionFor(permission).isGranted;
  }

  static Future<bool> ensure(AppPermission permission) async {
    final current = await _permissionFor(permission).status;
    if (current.isGranted) return true;
    final status = await _permissionFor(permission).request();
    return status.isGranted;
  }

  static Future<bool> openSettingsIfNeeded() async {
    return openAppSettings();
  }
}
