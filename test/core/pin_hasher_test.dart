import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/core/pin_hasher.dart';

void main() {
  // A low count keeps the suite fast; the algorithm under test does not
  // change with the iteration count.
  const iterations = 100;

  group('PinHasher', () {
    test('accepts the PIN it was derived from', () {
      final credential = PinHasher.hash('1234', iterations: iterations);

      expect(PinHasher.verify('1234', credential), isTrue);
    });

    test('rejects a different PIN', () {
      final credential = PinHasher.hash('1234', iterations: iterations);

      expect(PinHasher.verify('1235', credential), isFalse);
      expect(PinHasher.verify('12345', credential), isFalse);
      expect(PinHasher.verify('', credential), isFalse);
    });

    test('never stores the PIN itself', () {
      final credential = PinHasher.hash('987654', iterations: iterations);

      expect(
        credential,
        isNot(contains('987654')),
        reason: 'The verifier must not be reversible by reading it',
      );
    });

    test('salts every credential, so equal PINs hash differently', () {
      final first = PinHasher.hash('1234', iterations: iterations);
      final second = PinHasher.hash('1234', iterations: iterations);

      expect(first, isNot(second));
      // Both must still verify — the salt travels with the credential.
      expect(PinHasher.verify('1234', first), isTrue);
      expect(PinHasher.verify('1234', second), isTrue);
    });

    test('records the iteration count so old credentials keep working', () {
      final credential = PinHasher.hash('1234', iterations: 137);

      expect(credential, startsWith(r'pbkdf2-sha256$137$'));
      expect(PinHasher.verify('1234', credential), isTrue);
    });

    test('returns false rather than throwing on a corrupt credential', () {
      for (final bad in [
        '',
        'nonsense',
        r'pbkdf2-sha256$100$only-three-parts',
        r'bcrypt$100$c2FsdA==$aGFzaA==',
        r'pbkdf2-sha256$notanumber$c2FsdA==$aGFzaA==',
        r'pbkdf2-sha256$0$c2FsdA==$aGFzaA==',
        r'pbkdf2-sha256$100$not!base64$aGFzaA==',
      ]) {
        expect(
          PinHasher.verify('1234', bad),
          isFalse,
          reason: 'A corrupt entry must lock the PIN path, not crash it: $bad',
        );
      }
    });

    test('rejects a credential whose hash was tampered with', () {
      final credential = PinHasher.hash('1234', iterations: iterations);
      final parts = credential.split(r'$');
      // Flip the stored hash to something else of the same shape.
      final forged = [
        parts[0],
        parts[1],
        parts[2],
        PinHasher.hash('9999', iterations: iterations).split(r'$').last,
      ].join(r'$');

      expect(PinHasher.verify('1234', forged), isFalse);
    });
  });
}
