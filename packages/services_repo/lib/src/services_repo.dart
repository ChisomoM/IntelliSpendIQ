import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:local_data/local_data.dart';
import 'package:net_source/net_source.dart';

import 'firebase_crud.dart';

/// {@template services_repo}
/// Repo for application services
/// {@endtemplate}
class ServicesRepo {
  /// {@macro services_repo}
  ServicesRepo({
    required SharedPrefs prefs,
    // ignore: avoid_unused_constructor_parameters
    required LocalData db,
    required NetSource net,
    FirebaseFirestore? firestore,
  })  : _prefs = prefs,
        _net = net,
        _firebaseCrud = firestore != null
            ? FirebaseCrudService(firestore: firestore)
            : null;

  // Shared preferences keys
  final String _keyId = 'user_id';
  // final String _keyToken = 'token';

  // final String _keyCurrentToken = 'services_token';

  final NetSource _net;
  final SharedPrefs _prefs;
  final FirebaseCrudService? _firebaseCrud;

  final _authController = StreamController<int>.broadcast();

  /// App auth state to indicate when a user session has expired
  Stream<int> get authState async* {
    yield 0;
    yield* _authController.stream;
  }

  /// Firebase CRUD service, if enabled.
  FirebaseCrudService? get firebaseCrud => _firebaseCrud;

  ///getting providers review
  Future<OpStatus> getPlansReviews() async {
    try {
      final id = await _prefs.getString(_keyId);
      final response = await _net.get('plans/reviews/$id');
      if (response.isSuccessful()) {
        log('GOT PLANS VIEWS FROM API: ${response.data}');
        final rawData = response.data;
        log('Response Type: ${rawData.runtimeType}');
      }
      return OpStatus.fromResponse(response);
    } catch (e) {
      return OpStatus.unexpected(e.toString());
    }
  }
}
