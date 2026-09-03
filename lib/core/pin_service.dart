import 'package:shared_preferences/shared_preferences.dart';

class PinService {
  static const String _pinKey = 'user_security_pin';
  static const String _pinEnabledKey = 'pin_security_enabled';

  static Future<bool> setPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pinKey, pin);
    await prefs.setBool(_pinEnabledKey, true);
    return true;
  }

  static Future<bool> isPinSet() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pinEnabledKey) ?? false;
  }

  static Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final storedPin = prefs.getString(_pinKey);
    return storedPin == pin;
  }

  static Future<void> disablePin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pinEnabledKey, false);
    await prefs.remove(_pinKey);
  }

  // To check if a user is currently "locked" (needs to enter PIN)
  // This is a session-based flag that resets when the app is killed
  static bool _isSessionAuthorized = false;

  static bool get isSessionAuthorized => _isSessionAuthorized;

  static void authorizeSession() {
    _isSessionAuthorized = true;
  }

  static void lockSession() {
    _isSessionAuthorized = false;
  }
}
