import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Encapsulates the background-location permission lifecycle for Android.
///
/// On Android 11+ (API level 30+), Google Play and Android security policies
/// prohibit applications from requesting background location ('Allow all the time')
/// in the standard runtime permissions dialog. Instead:
/// 1. Foreground location ('While using the app') is granted first.
/// 2. The app presents an educational rationale explaining why background location
///    is needed (e.g. proximity alerts for verified hazards when closed).
/// 3. After explicit user confirmation, the app directs the user to the
///    system App Settings screen via [openLocationSettings].
/// 4. The user manually navigates: Permissions -> Location -> 'Allow all the time'.
/// 5. When the app resumes, [hasBackgroundPermission] checks if [LocationPermission.always]
///    was granted.
///
/// Note: Step 12 background proximity alerting is strictly Android-only.
/// On iOS and Web, this service safely returns false so background workers
/// are never scheduled or executed.
class BackgroundLocationPermissionService {
  const BackgroundLocationPermissionService();

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Returns true when running on Android and 'always' background location
  /// has been granted.
  Future<bool> hasBackgroundPermission() async {
    if (!_isAndroid) return false;
    try {
      final permission = await Geolocator.checkPermission();
      return permission == LocationPermission.always;
    } catch (_) {
      return false;
    }
  }

  /// Opens the device App Settings screen where the user can manually select:
  /// Permissions -> Location -> 'Allow all the time'.
  ///
  /// On Android 11+, background location cannot be granted via an in-app runtime
  /// dialog; the user must be directed to system settings.
  Future<bool> openLocationSettings() async {
    if (!_isAndroid) return false;
    try {
      return await Geolocator.openAppSettings();
    } catch (e) {
      debugPrint('Failed to open app settings for background location: $e');
      return false;
    }
  }

  /// Directs the user to App Settings to enable 'Allow all the time' and
  /// returns whether 'always' permission is currently granted.
  ///
  /// Kept for compatibility. Callers should prefer presenting an educational
  /// dialog first and invoking [openLocationSettings].
  Future<bool> requestBackgroundPermission() async {
    if (!_isAndroid) return false;
    try {
      final current = await Geolocator.checkPermission();
      if (current == LocationPermission.always) return true;
      await openLocationSettings();
      final updated = await Geolocator.checkPermission();
      return updated == LocationPermission.always;
    } catch (e) {
      debugPrint('Background location permission request failed: $e');
      return false;
    }
  }
}
