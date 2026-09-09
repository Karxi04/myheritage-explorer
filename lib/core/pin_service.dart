import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';

class PinService {
  static const String _pinKey = 'user_security_pin';
  static const String _pinEnabledKey = 'pin_security_enabled';
  static const String _biometricEnabledKey = 'biometric_security_enabled';

  static final LocalAuthentication _auth = LocalAuthentication();

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
    await setBiometricEnabled(false);
  }

  static Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_biometricEnabledKey) ?? false;
  }

  static Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricEnabledKey, enabled);
  }

  static Future<bool> canCheckBiometrics() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      return canAuthenticate;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> authenticateWithBiometrics() async {
    try {
      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: 'Please authenticate to access Explorer',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
      return didAuthenticate;
    } catch (e) {
      return false;
    }
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
