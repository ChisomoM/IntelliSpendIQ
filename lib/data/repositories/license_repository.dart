import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:intellispendiq/data/repositories/identity_repository.dart';
import 'package:intellispendiq/data/secure/secure_store.dart';
import 'package:intellispendiq/licensing/entitlement.dart';

/// Fetches / creates Firestore `users/{uid}` and mirrors it into
/// [SecureStore] for offline entitlement checks.
abstract interface class LicenseRepository {
  Future<LicenseSnapshot?> readCache();

  /// Online refresh when possible; falls back to cache offline.
  /// On first login, creates the user doc if missing and always writes cache.
  Future<LicenseSnapshot> ensureLicense({
    required IdentityUser user,
    String? appVersion,
  });

  /// Tries an online refresh; returns cached snapshot when offline.
  Future<LicenseSnapshot?> refreshIfOnline({IdentityUser? user});

  Future<void> clearCache();
}

class FirestoreLicenseRepository implements LicenseRepository {
  FirestoreLicenseRepository({
    required SecureStore secureStore,
    FirebaseFirestore? firestore,
    Connectivity? connectivity,
  }) : _store = secureStore,
       _db = firestore ?? FirebaseFirestore.instance,
       _connectivity = connectivity ?? Connectivity();

  final SecureStore _store;
  final FirebaseFirestore _db;
  final Connectivity _connectivity;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  @override
  Future<LicenseSnapshot?> readCache() => _store.readLicenseCache();

  @override
  Future<void> clearCache() => _store.clearLicenseCache();

  Future<bool> _isOnline() async {
    final results = await _connectivity.checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  @override
  Future<LicenseSnapshot> ensureLicense({
    required IdentityUser user,
    String? appVersion,
  }) async {
    final online = await _isOnline();
    final cached = await readCache();

    if (!online) {
      if (cached != null && cached.uid == user.uid) return cached;
      throw const LicenseNetworkRequiredException(
        'Sign in once while online to start your trial.',
      );
    }

    final docRef = _users.doc(user.uid);
    final snap = await docRef.get();
    final now = DateTime.now().toUtc();

    if (!snap.exists) {
      final trialEndsAt = now.add(EntitlementEvaluator.trialDuration);
      final graceEndsAt = EntitlementEvaluator.computeGraceEndsAt(
        trialEndsAt: trialEndsAt,
        subscriptionActive: false,
      );
      final payload = <String, Object?>{
        'email': user.email,
        'displayName': user.displayName,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        'status': 'approved',
        'trialEndsAt': Timestamp.fromDate(trialEndsAt),
        'subscriptionActive': false,
        'validUntil': null,
        'notes': null,
        'appVersion': ?appVersion,
        'lastSeenAt': Timestamp.fromDate(now),
      };
      await docRef.set(payload);
      final license = LicenseSnapshot(
        uid: user.uid,
        status: 'approved',
        trialEndsAt: trialEndsAt,
        subscriptionActive: false,
        graceEndsAt: graceEndsAt,
        checkedAt: now,
        email: user.email,
        displayName: user.displayName,
      );
      await _store.writeLicenseCache(license);
      return license;
    }

    final data = snap.data()!;
    // Best-effort presence — rules allow non-license field updates.
    try {
      await docRef.update({
        'lastSeenAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        'appVersion': ?appVersion,
        'displayName': ?user.displayName,
      });
    } on Object {
      // Ignore presence write failures — license read still succeeds.
    }

    final license = _fromFirestore(user.uid, data, checkedAt: now);
    await _store.writeLicenseCache(license);
    return license;
  }

  @override
  Future<LicenseSnapshot?> refreshIfOnline({IdentityUser? user}) async {
    final online = await _isOnline();
    final cached = await readCache();
    if (!online) return cached;
    if (user == null) return cached;
    return ensureLicense(user: user);
  }

  static LicenseSnapshot _fromFirestore(
    String uid,
    Map<String, dynamic> data, {
    required DateTime checkedAt,
  }) {
    final trialEndsAt = _asDate(data['trialEndsAt'])!;
    final subscriptionActive = data['subscriptionActive'] as bool? ?? false;
    final validUntil = _asDate(data['validUntil']);
    final graceEndsAt = EntitlementEvaluator.computeGraceEndsAt(
      trialEndsAt: trialEndsAt,
      subscriptionActive: subscriptionActive,
      validUntil: validUntil,
    );
    return LicenseSnapshot(
      uid: uid,
      status: data['status'] as String? ?? 'approved',
      trialEndsAt: trialEndsAt,
      subscriptionActive: subscriptionActive,
      validUntil: validUntil,
      graceEndsAt: graceEndsAt,
      checkedAt: checkedAt,
      email: data['email'] as String?,
      displayName: data['displayName'] as String?,
    );
  }

  static DateTime? _asDate(Object? value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate().toUtc();
    if (value is DateTime) return value.toUtc();
    if (value is String) return DateTime.parse(value).toUtc();
    return null;
  }
}

class LicenseNetworkRequiredException implements Exception {
  const LicenseNetworkRequiredException(this.message);
  final String message;

  @override
  String toString() => message;
}
