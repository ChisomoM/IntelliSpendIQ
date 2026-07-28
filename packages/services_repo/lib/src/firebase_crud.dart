import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:net_source/net_source.dart';

/// {@template firebase_crud_service}
/// Service for Firebase Firestore CRUD operations.
/// This is optional and can be enabled/disabled.
/// {@endtemplate}
class FirebaseCrudService {
  /// {@macro firebase_crud_service}
  FirebaseCrudService({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  /// Create a document in a collection.
  Future<OpStatus> createDocument({
    required String collection,
    required String docId,
    required Map<String, dynamic> data,
  }) async {
    try {
      await _firestore.collection(collection).doc(docId).set(data);
      return OpStatus.success('Document created successfully');
    } catch (e) {
      return OpStatus.error(e.toString());
    }
  }

  /// Read a document from a collection.
  Future<OpStatus> readDocument({
    required String collection,
    required String docId,
  }) async {
    try {
      final doc = await _firestore.collection(collection).doc(docId).get();
      if (doc.exists) {
        return OpStatus.success('Document read successfully', data: doc.data());
      } else {
        return OpStatus.error('Document does not exist');
      }
    } catch (e) {
      return OpStatus.error(e.toString());
    }
  }

  /// Update a document in a collection.
  Future<OpStatus> updateDocument({
    required String collection,
    required String docId,
    required Map<String, dynamic> data,
  }) async {
    try {
      await _firestore.collection(collection).doc(docId).update(data);
      return OpStatus.success('Document updated successfully');
    } catch (e) {
      return OpStatus.error(e.toString());
    }
  }

  /// Delete a document from a collection.
  Future<OpStatus> deleteDocument({
    required String collection,
    required String docId,
  }) async {
    try {
      await _firestore.collection(collection).doc(docId).delete();
      return OpStatus.success('Document deleted successfully');
    } catch (e) {
      return OpStatus.error(e.toString());
    }
  }

  /// Query documents in a collection.
  Future<OpStatus> queryDocuments({
    required String collection,
    String? field,
    dynamic value,
    QueryOperator operator = QueryOperator.equalTo,
  }) async {
    try {
      Query query = _firestore.collection(collection);
      if (field != null && value != null) {
        switch (operator) {
          case QueryOperator.equalTo:
            query = query.where(field, isEqualTo: value);
            break;
          case QueryOperator.greaterThan:
            query = query.where(field, isGreaterThan: value);
            break;
          case QueryOperator.lessThan:
            query = query.where(field, isLessThan: value);
            break;
          // Add more operators as needed
        }
      }
      final snapshot = await query.get();
      final docs = snapshot.docs.map((doc) => doc.data()).toList();
      return OpStatus.success('Query successful', data: docs);
    } catch (e) {
      return OpStatus.error(e.toString());
    }
  }
}

/// Enum for query operators.
enum QueryOperator {
  equalTo,
  greaterThan,
  lessThan,
  // Add more as needed
}
