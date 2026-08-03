import 'package:equatable/equatable.dart';

/// License lifecycle stages evaluated offline from the local cache.
enum EntitlementStatus {
  /// Still inside the 5-day trial window.
  trial,

  /// After trial/sub end, still within the 2-day grace window.
  grace,

  /// Paid subscription is active.
  active,

  /// Admin disabled the account.
  disabled,

  /// Trial and grace exhausted (or no trustable cache).
  blocked,

  /// No local cache and never successfully synced — force online once.
  unknown,
}

/// Cached copy of Firestore `users/{uid}` license fields + local metadata.
class LicenseSnapshot extends Equatable {
  const LicenseSnapshot({
    required this.uid,
    required this.status,
    required this.trialEndsAt,
    required this.subscriptionActive,
    required this.graceEndsAt,
    required this.checkedAt,
    this.validUntil,
    this.email,
    this.displayName,
  });

  final String uid;
  final String status;
  final DateTime trialEndsAt;
  final bool subscriptionActive;
  final DateTime? validUntil;
  final DateTime graceEndsAt;
  final DateTime checkedAt;
  final String? email;
  final String? displayName;

  bool get isDisabled => status == 'disabled';

  LicenseSnapshot copyWith({
    String? uid,
    String? status,
    DateTime? trialEndsAt,
    bool? subscriptionActive,
    DateTime? validUntil,
    DateTime? graceEndsAt,
    DateTime? checkedAt,
    String? email,
    String? displayName,
    bool clearValidUntil = false,
  }) {
    return LicenseSnapshot(
      uid: uid ?? this.uid,
      status: status ?? this.status,
      trialEndsAt: trialEndsAt ?? this.trialEndsAt,
      subscriptionActive: subscriptionActive ?? this.subscriptionActive,
      validUntil: clearValidUntil ? null : (validUntil ?? this.validUntil),
      graceEndsAt: graceEndsAt ?? this.graceEndsAt,
      checkedAt: checkedAt ?? this.checkedAt,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
    );
  }

  @override
  List<Object?> get props => [
    uid,
    status,
    trialEndsAt,
    subscriptionActive,
    validUntil,
    graceEndsAt,
    checkedAt,
    email,
    displayName,
  ];
}

/// Pure entitlement math — no I/O. Safe to unit-test offline.
///
/// Policy: 5-day trial → 2-day grace (still usable) → hard block.
/// Subscription active when [LicenseSnapshot.subscriptionActive] and
/// [LicenseSnapshot.validUntil] is null or in the future.
abstract final class EntitlementEvaluator {
  /// How far behind [LicenseSnapshot.checkedAt] the clock may run before
  /// we distrust the cache and require an online re-check.
  static const clockRollbackTolerance = Duration(days: 1);

  static const trialDuration = Duration(days: 5);
  static const graceDuration = Duration(days: 2);

  /// Compute [LicenseSnapshot.graceEndsAt] for a fresh or refreshed doc.
  static DateTime computeGraceEndsAt({
    required DateTime trialEndsAt,
    required bool subscriptionActive,
    DateTime? validUntil,
  }) {
    if (subscriptionActive && validUntil != null) {
      return validUntil.add(graceDuration);
    }
    return trialEndsAt.add(graceDuration);
  }

  static EntitlementStatus evaluate(
    LicenseSnapshot? snapshot, {
    required DateTime now,
  }) {
    if (snapshot == null) return EntitlementStatus.unknown;

    if (now.isBefore(snapshot.checkedAt.subtract(clockRollbackTolerance))) {
      // Large clock rollback — do not trust remaining trial/grace offline.
      return EntitlementStatus.blocked;
    }

    if (snapshot.isDisabled) return EntitlementStatus.disabled;

    if (snapshot.subscriptionActive) {
      final until = snapshot.validUntil;
      if (until == null || now.isBefore(until)) {
        return EntitlementStatus.active;
      }
      // Subscription expired — fall through to grace vs blocked against
      // graceEndsAt (which should be validUntil + 2 days).
      if (!now.isAfter(snapshot.graceEndsAt)) {
        return EntitlementStatus.grace;
      }
      return EntitlementStatus.blocked;
    }

    if (now.isBefore(snapshot.trialEndsAt)) {
      return EntitlementStatus.trial;
    }

    if (!now.isAfter(snapshot.graceEndsAt)) {
      return EntitlementStatus.grace;
    }

    return EntitlementStatus.blocked;
  }

  static bool allowsAppAccess(EntitlementStatus status) {
    return switch (status) {
      EntitlementStatus.trial ||
      EntitlementStatus.grace ||
      EntitlementStatus.active => true,
      EntitlementStatus.disabled ||
      EntitlementStatus.blocked ||
      EntitlementStatus.unknown => false,
    };
  }

  static bool shouldShowPaywall(EntitlementStatus status) {
    return status == EntitlementStatus.grace ||
        status == EntitlementStatus.blocked ||
        status == EntitlementStatus.disabled;
  }

  static bool canDismissPaywall(EntitlementStatus status) {
    return status == EntitlementStatus.trial ||
        status == EntitlementStatus.grace ||
        status == EntitlementStatus.active;
  }
}
