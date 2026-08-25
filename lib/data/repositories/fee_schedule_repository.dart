import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:intellispendiq/data/secure/secure_store.dart';
import 'package:intellispendiq/domain/models/fee_schedule.dart';

/// Shared tariff list: edited on the web, cached on the phone.
abstract interface class FeeScheduleRepository {
  /// Last known list — memory, then disk, then empty. Never hits the
  /// network, so capture and transfer screens can use it offline.
  Future<FeeSchedule> current();

  /// Downloads when online; keeps the cached list when offline or when
  /// the fetch fails.
  Future<FeeSchedule> refreshIfOnline();
}

/// In-memory stand-in for tests.
class MemoryFeeScheduleRepository implements FeeScheduleRepository {
  MemoryFeeScheduleRepository({FeeSchedule schedule = FeeSchedule.empty})
    : _schedule = schedule;

  FeeSchedule _schedule;

  void replace(FeeSchedule schedule) => _schedule = schedule;

  @override
  Future<FeeSchedule> current() async => _schedule;

  @override
  Future<FeeSchedule> refreshIfOnline() async => _schedule;
}

/// Firestore `config/feeSchedule`, mirrored into [SecureStore].
class FirestoreFeeScheduleRepository implements FeeScheduleRepository {
  FirestoreFeeScheduleRepository({
    required SecureStore secureStore,
    FirebaseFirestore? firestore,
    Connectivity? connectivity,
  }) : _store = secureStore,
       _db = firestore ?? FirebaseFirestore.instance,
       _connectivity = connectivity ?? Connectivity();

  final SecureStore _store;
  final FirebaseFirestore _db;
  final Connectivity _connectivity;

  FeeSchedule? _memory;

  static const collection = 'config';
  static const documentId = 'feeSchedule';

  DocumentReference<Map<String, dynamic>> get _doc =>
      _db.collection(collection).doc(documentId);

  @override
  Future<FeeSchedule> current() async {
    if (_memory != null) return _memory!;
    final cached = await _store.readFeeScheduleCache();
    _memory = cached ?? FeeSchedule.empty;
    return _memory!;
  }

  @override
  Future<FeeSchedule> refreshIfOnline() async {
    final online = await _isOnline();
    if (!online) return current();

    try {
      final snap = await _doc.get();
      final now = DateTime.now().toUtc();
      final FeeSchedule schedule;
      if (!snap.exists) {
        schedule = FeeSchedule(fetchedAt: now);
      } else {
        schedule = _fromFirestore(snap.data()!, fetchedAt: now);
      }
      _memory = schedule;
      await _store.writeFeeScheduleCache(schedule);
      return schedule;
    } on Object {
      return current();
    }
  }

  Future<bool> _isOnline() async {
    final results = await _connectivity.checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  static FeeSchedule _fromFirestore(
    Map<String, dynamic> data, {
    required DateTime fetchedAt,
  }) {
    final parsed = FeeSchedule.fromJson(Map<String, Object?>.from(data));
    return FeeSchedule(
      bands: parsed.bands,
      fetchedAt: fetchedAt,
      remoteUpdatedAt: _asDate(data['updatedAt']) ?? parsed.remoteUpdatedAt,
    );
  }

  static DateTime? _asDate(Object? value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate().toUtc();
    if (value is DateTime) return value.toUtc();
    if (value is String) return DateTime.tryParse(value)?.toUtc();
    return null;
  }
}
