import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/licensing/entitlement.dart';

void main() {
  final base = DateTime.utc(2026, 1, 10, 12);

  LicenseSnapshot snapshot({
    required DateTime trialEndsAt,
    required DateTime checkedAt,
    DateTime? graceEndsAt,
    bool subscriptionActive = false,
    DateTime? validUntil,
    String status = 'approved',
  }) {
    return LicenseSnapshot(
      uid: 'u1',
      status: status,
      trialEndsAt: trialEndsAt,
      subscriptionActive: subscriptionActive,
      validUntil: validUntil,
      graceEndsAt:
          graceEndsAt ??
          EntitlementEvaluator.computeGraceEndsAt(
            trialEndsAt: trialEndsAt,
            subscriptionActive: subscriptionActive,
            validUntil: validUntil,
          ),
      checkedAt: checkedAt,
      email: 'a@b.com',
    );
  }

  group('EntitlementEvaluator', () {
    test('null snapshot is unknown', () {
      expect(
        EntitlementEvaluator.evaluate(null, now: base),
        EntitlementStatus.unknown,
      );
    });

    test('trial while now < trialEndsAt', () {
      final license = snapshot(
        trialEndsAt: base.add(const Duration(days: 5)),
        checkedAt: base,
      );
      expect(
        EntitlementEvaluator.evaluate(license, now: base.add(const Duration(days: 2))),
        EntitlementStatus.trial,
      );
      expect(EntitlementEvaluator.allowsAppAccess(EntitlementStatus.trial), isTrue);
    });

    test('grace for 2 days after trial ends', () {
      final trialEnds = base;
      final license = snapshot(trialEndsAt: trialEnds, checkedAt: base);
      expect(
        EntitlementEvaluator.evaluate(
          license,
          now: trialEnds.add(const Duration(days: 1)),
        ),
        EntitlementStatus.grace,
      );
      expect(
        EntitlementEvaluator.evaluate(license, now: trialEnds.add(const Duration(days: 2))),
        EntitlementStatus.grace,
      );
      expect(EntitlementEvaluator.shouldShowPaywall(EntitlementStatus.grace), isTrue);
      expect(EntitlementEvaluator.canDismissPaywall(EntitlementStatus.grace), isTrue);
    });

    test('blocked after grace ends', () {
      final trialEnds = base;
      final license = snapshot(trialEndsAt: trialEnds, checkedAt: base);
      expect(
        EntitlementEvaluator.evaluate(
          license,
          now: trialEnds.add(const Duration(days: 2, seconds: 1)),
        ),
        EntitlementStatus.blocked,
      );
      expect(
        EntitlementEvaluator.allowsAppAccess(EntitlementStatus.blocked),
        isFalse,
      );
      expect(
        EntitlementEvaluator.canDismissPaywall(EntitlementStatus.blocked),
        isFalse,
      );
    });

    test('subscription active with null validUntil', () {
      final license = snapshot(
        trialEndsAt: base.subtract(const Duration(days: 10)),
        checkedAt: base,
        subscriptionActive: true,
      );
      expect(
        EntitlementEvaluator.evaluate(license, now: base),
        EntitlementStatus.active,
      );
    });

    test('subscription active with future validUntil', () {
      final license = snapshot(
        trialEndsAt: base.subtract(const Duration(days: 10)),
        checkedAt: base,
        subscriptionActive: true,
        validUntil: base.add(const Duration(days: 30)),
      );
      expect(
        EntitlementEvaluator.evaluate(license, now: base),
        EntitlementStatus.active,
      );
    });

    test('expired subscription enters grace then blocked', () {
      final until = base;
      final license = snapshot(
        trialEndsAt: base.subtract(const Duration(days: 20)),
        checkedAt: base,
        subscriptionActive: true,
        validUntil: until,
      );
      expect(
        EntitlementEvaluator.evaluate(
          license,
          now: until.add(const Duration(days: 1)),
        ),
        EntitlementStatus.grace,
      );
      expect(
        EntitlementEvaluator.evaluate(
          license,
          now: until.add(const Duration(days: 2, seconds: 1)),
        ),
        EntitlementStatus.blocked,
      );
    });

    test('disabled blocks immediately', () {
      final license = snapshot(
        trialEndsAt: base.add(const Duration(days: 5)),
        checkedAt: base,
        status: 'disabled',
      );
      expect(
        EntitlementEvaluator.evaluate(license, now: base),
        EntitlementStatus.disabled,
      );
      expect(
        EntitlementEvaluator.allowsAppAccess(EntitlementStatus.disabled),
        isFalse,
      );
    });

    test('large clock rollback treats as blocked', () {
      final license = snapshot(
        trialEndsAt: base.add(const Duration(days: 5)),
        checkedAt: base,
      );
      final rolledBack = base.subtract(const Duration(days: 2));
      expect(
        EntitlementEvaluator.evaluate(license, now: rolledBack),
        EntitlementStatus.blocked,
      );
    });

    test('small clock skew within tolerance still allows trial', () {
      final license = snapshot(
        trialEndsAt: base.add(const Duration(days: 5)),
        checkedAt: base,
      );
      final skewed = base.subtract(const Duration(hours: 12));
      expect(
        EntitlementEvaluator.evaluate(license, now: skewed),
        EntitlementStatus.trial,
      );
    });

    test('computeGraceEndsAt uses validUntil when sub active', () {
      final trialEnds = base;
      final until = base.add(const Duration(days: 30));
      expect(
        EntitlementEvaluator.computeGraceEndsAt(
          trialEndsAt: trialEnds,
          subscriptionActive: true,
          validUntil: until,
        ),
        until.add(const Duration(days: 2)),
      );
      expect(
        EntitlementEvaluator.computeGraceEndsAt(
          trialEndsAt: trialEnds,
          subscriptionActive: false,
        ),
        trialEnds.add(const Duration(days: 2)),
      );
    });
  });
}
