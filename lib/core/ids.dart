import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

/// ID and hashing helpers used across the capture pipeline.
abstract final class Ids {
  static const Uuid _uuid = Uuid();

  static String newId() => _uuid.v4();

  /// Content hash for raw captures: hash(sender + body + received_at
  /// bucket). The timestamp is bucketed (10 minutes) so a message
  /// re-delivered moments later — or re-read during a backfill — hashes
  /// identically, while genuinely repeated messages on different days
  /// do not collide.
  static String contentHash({
    required String sender,
    required String body,
    required DateTime receivedAt,
  }) {
    final bucket =
        receivedAt.toUtc().millisecondsSinceEpoch ~/ (10 * 60 * 1000);
    final input = '${normalizeSender(sender)}|${body.trim()}|$bucket';
    return sha256.convert(utf8.encode(input)).toString();
  }

  /// Idempotency key for a transaction: prefer the provider transaction
  /// reference (TID / bank ref) when present, fall back to the raw
  /// capture content hash.
  static String idempotencyKey({
    required String providerKey,
    String? externalRef,
    String? contentHash,
  }) {
    if (externalRef != null && externalRef.isNotEmpty) {
      return '$providerKey:$externalRef';
    }
    return '$providerKey:hash:$contentHash';
  }

  /// Normalizes an SMS sender address for parser routing: strips `+`,
  /// spaces and dashes, lowercases alphanumeric sender IDs.
  static String normalizeSender(String sender) =>
      sender.replaceAll(RegExp(r'[+\s\-]'), '').toLowerCase();
}
