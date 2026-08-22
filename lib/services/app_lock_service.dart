import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Biometric / device-credential gate. The app shows the whole shop's money,
/// so a phone left on the counter should not.
class AppLockService {
  AppLockService._();

  static final AppLockService instance = AppLockService._();

  final _auth = LocalAuthentication();

  Future<bool> isAvailable() async {
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) return false;
      final canCheck = await _auth.canCheckBiometrics;
      final enrolled = await _auth.getAvailableBiometrics();
      return canCheck || enrolled.isNotEmpty || supported;
    } on PlatformException {
      return false;
    }
  }

  Future<String> describeAvailable() async {
    try {
      final types = await _auth.getAvailableBiometrics();
      if (types.contains(BiometricType.face)) return 'Face unlock';
      if (types.contains(BiometricType.fingerprint)) return 'Fingerprint';
      if (types.contains(BiometricType.iris)) return 'Iris';
      return 'Device PIN';
    } on PlatformException {
      return 'Device PIN';
    }
  }

  /// Returns true when the user proved they own the device.
  Future<bool> authenticate({
    String reason = 'Unlock Ratnex',
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException {
      // No enrolled biometric or the user cancelled — treat as locked out
      // rather than silently letting them in.
      return false;
    }
  }
}
