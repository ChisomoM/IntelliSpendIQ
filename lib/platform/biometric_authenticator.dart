import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Fingerprint / face unlock, behind an interface so cubit tests never
/// reach for a real sensor.
abstract interface class BiometricAuthenticator {
  /// Whether this device has usable enrolled biometrics right now.
  Future<bool> isAvailable();

  /// Prompts the user. Returns false for any refusal — cancelled,
  /// wrong finger, no sensor — because the caller's response is the
  /// same in every case: stay locked and offer the PIN.
  Future<bool> authenticate({required String reason});
}

class LocalAuthBiometrics implements BiometricAuthenticator {
  LocalAuthBiometrics({LocalAuthentication? auth})
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> isAvailable() async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      if (!await _auth.canCheckBiometrics) return false;
      return (await _auth.getAvailableBiometrics()).isNotEmpty;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<bool> authenticate({required String reason}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        // The prompt survives the OS backgrounding us mid-scan, which
        // otherwise reads to the user as a silent failure.
        persistAcrossBackgrounding: true,
      );
    } on PlatformException {
      return false;
    }
  }
}
