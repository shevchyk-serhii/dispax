import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BiometricService {
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _biometricUserIdKey = 'biometric_user_id';

  final LocalAuthentication _localAuth = LocalAuthentication();
  
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: IOSAccessibility.first_unlock_this_device,
    ),
  );

  /
  Future<bool> get isAvailable async {
    try {
      final bool isAvailable = await _localAuth.canCheckBiometrics;
      final bool isDeviceSupported = await _localAuth.isDeviceSupported();
      return isAvailable && isDeviceSupported;
    } catch (e) {
      debugPrint('Error checking biometric availability: $e');
      return false;
    }
  }

  /
  Future<List<BiometricType>> get availableBiometrics async {
    try {
      final List<BiometricType> biometrics = await _localAuth.getAvailableBiometrics();
      return biometrics;
    } catch (e) {
      debugPrint('Error getting available biometrics: $e');
      return [];
    }
  }

  /
  Future<bool> get isBiometricEnabled async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_biometricEnabledKey) ?? false;
    } catch (e) {
      debugPrint('Error checking biometric enabled: $e');
      return false;
    }
  }

  /
  Future<bool> setBiometricEnabled(bool enabled, {String? userId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_biometricEnabledKey, enabled);
      if (userId != null && enabled) {
        await _secureStorage.write(key: _biometricUserIdKey, value: userId);
      } else if (!enabled) {
        await _secureStorage.delete(key: _biometricUserIdKey);
      }
      return true;
    } catch (e) {
      debugPrint('Error setting biometric enabled: $e');
      return false;
    }
  }

  /
  Future<String?> get biometricUserId async {
    try {
      return await _secureStorage.read(key: _biometricUserIdKey);
    } catch (e) {
      debugPrint('Error getting biometric user ID: $e');
      return null;
    }
  }

  /
  Future<BiometricAuthResult> authenticate({
    String? reason,
    bool stickyAuth = true,
  }) async {
    try {

      if (!await isAvailable) {
        return BiometricAuthResult.unavailable;
      }

      if (!await isBiometricEnabled) {
        return BiometricAuthResult.disabled;
      }

      final String localizedReason = reason ??
          'Подтвердите личность для входа в Der Oktopus';

      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: localizedReason,
        options: AuthenticationOptions(
          stickyAuth: stickyAuth,
          biometricOnly: true,
        ),
      );

      if (didAuthenticate) {
        return BiometricAuthResult.success;
      } else {
        return BiometricAuthResult.cancelled;
      }
    } on PlatformException catch (e) {
      debugPrint('Biometric authentication error: ${e.code} - ${e.message}');

      switch (e.code) {
        case auth_error.notEnrolled:
          return BiometricAuthResult.notEnrolled;
        case auth_error.lockedOut:
          return BiometricAuthResult.lockedOut;
        case auth_error.permanentlyLockedOut:
          return BiometricAuthResult.permanentlyLockedOut;
        case auth_error.notAvailable:
          return BiometricAuthResult.unavailable;
        default:
          return BiometricAuthResult.error;
      }
    } catch (e) {
      debugPrint('Unexpected biometric error: $e');
      return BiometricAuthResult.error;
    }
  }

  /
  String getBiometricTypeName(BiometricType type) {
    switch (type) {
      case BiometricType.face:
        return 'Face ID';
      case BiometricType.fingerprint:
        return 'Touch ID';
      case BiometricType.iris:
        return 'Iris';
      case BiometricType.weak:
        return 'Биометрия';
      case BiometricType.strong:
        return 'Биометрия';
    }
  }

  /
  Future<String> getLocalizedReason({String? customReason}) async {
    if (customReason != null) return customReason;

    final biometrics = await availableBiometrics;
    if (biometrics.contains(BiometricType.face)) {
      return 'Используйте Face ID для входа в Der Oktopus';
    } else if (biometrics.contains(BiometricType.fingerprint)) {
      return 'Используйте Touch ID для входа в Der Oktopus';
    } else {
      return 'Подтвердите личность для входа в Der Oktopus';
    }
  }

  /
  Future<void> clearBiometricData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_biometricEnabledKey);
      await _secureStorage.delete(key: _biometricUserIdKey);
    } catch (e) {
      debugPrint('Error clearing biometric data: $e');
    }
  }
}

enum BiometricAuthResult {
  success,
  cancelled,
  error,
  unavailable,
  disabled,
  notEnrolled,
  lockedOut,
  permanentlyLockedOut,
}

extension BiometricAuthResultExtension on BiometricAuthResult {
  String get message {
    switch (this) {
      case BiometricAuthResult.success:
        return 'Аутентификация прошла успешно';
      case BiometricAuthResult.cancelled:
        return 'Аутентификация отменена';
      case BiometricAuthResult.unavailable:
        return 'Биометрия недоступна на этом устройстве';
      case BiometricAuthResult.disabled:
        return 'Биометрия отключена в настройках приложения';
      case BiometricAuthResult.notEnrolled:
        return 'На устройстве не настроена биометрия';
      case BiometricAuthResult.lockedOut:
        return 'Биометрия временно заблокирована';
      case BiometricAuthResult.permanentlyLockedOut:
        return 'Биометрия заблокирована. Используйте пароль';
      case BiometricAuthResult.error:
        return 'Ошибка аутентификации';
    }
  }

  bool get isSuccess => this == BiometricAuthResult.success;
}