import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// PBKDF2-HMAC-SHA256 verifier for the app-lock PIN.
///
/// The PIN itself is never stored — only a salted verifier, so reading
/// the Keystore entry back is not enough to unlock the app.
///
/// [defaultIterations] is deliberately modest. A 4–6 digit PIN has so
/// little entropy that no iteration count makes it brute-force proof
/// once an attacker has the verifier; the real defences are the
/// Keystore-backed storage it lives in and the attempt throttling in
/// AppLockRepository. The cost here is tuned to stay imperceptible on a
/// mid-range phone, because a slow unlock is a real usability tax paid
/// on every single launch.
abstract final class PinHasher {
  static const defaultIterations = 20000;
  static const _saltBytes = 16;
  static const _keyBytes = 32;
  static const _scheme = 'pbkdf2-sha256';

  /// Derives a fresh verifier for [pin], generating a random salt.
  ///
  /// Format: `pbkdf2-sha256$<iterations>$<saltB64>$<hashB64>`.
  static String hash(String pin, {int iterations = defaultIterations}) {
    final random = Random.secure();
    final salt = Uint8List.fromList(
      List.generate(_saltBytes, (_) => random.nextInt(256)),
    );
    final key = _pbkdf2(utf8.encode(pin), salt, iterations, _keyBytes);
    return [
      _scheme,
      '$iterations',
      base64.encode(salt),
      base64.encode(key),
    ].join(r'$');
  }

  /// Whether [pin] reproduces [credential]. Returns false rather than
  /// throwing on a malformed or unknown-scheme credential, so a corrupt
  /// Keystore entry locks the user out of the PIN path instead of
  /// crashing the lock screen.
  static bool verify(String pin, String credential) {
    final parts = credential.split(r'$');
    if (parts.length != 4 || parts.first != _scheme) return false;

    final iterations = int.tryParse(parts[1]);
    if (iterations == null || iterations < 1) return false;

    final Uint8List salt;
    final Uint8List expected;
    try {
      salt = base64.decode(parts[2]);
      expected = base64.decode(parts[3]);
    } on FormatException {
      return false;
    }

    final actual = _pbkdf2(
      utf8.encode(pin),
      salt,
      iterations,
      expected.length,
    );
    return _constantTimeEquals(actual, expected);
  }

  static Uint8List _pbkdf2(
    List<int> password,
    List<int> salt,
    int iterations,
    int keyLength,
  ) {
    final hmac = Hmac(sha256, password);
    final output = BytesBuilder();

    for (var block = 1; output.length < keyLength; block++) {
      // U1 = PRF(password, salt || INT_32_BE(block))
      var previous = hmac.convert([...salt, ..._int32be(block)]).bytes;
      final accumulator = Uint8List.fromList(previous);

      for (var round = 1; round < iterations; round++) {
        previous = hmac.convert(previous).bytes;
        for (var i = 0; i < accumulator.length; i++) {
          accumulator[i] ^= previous[i];
        }
      }
      output.add(accumulator);
    }

    return Uint8List.sublistView(output.toBytes(), 0, keyLength);
  }

  static List<int> _int32be(int value) => [
    (value >> 24) & 0xff,
    (value >> 16) & 0xff,
    (value >> 8) & 0xff,
    value & 0xff,
  ];

  /// Compares without an early return, so timing does not leak how much
  /// of the verifier matched.
  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var difference = 0;
    for (var i = 0; i < a.length; i++) {
      difference |= a[i] ^ b[i];
    }
    return difference == 0;
  }
}
