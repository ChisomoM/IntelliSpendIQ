import 'dart:developer';

import 'package:net_source/src/models/net_response.dart';

/// Returns the status of an operation.
class OpStatus {
  /// {@macro OpStatus}
  OpStatus({
    required this.message,
    required this.success,
    this.data,
    this.code = 0,
  });

  /// Returns a [OpStatus] representation from a [NetResponse].
  factory OpStatus.fromResponse(NetResponse response) {
    return OpStatus(
      message: response.message,
      success: response.isSuccessful(),
      data: response.data,
      code: response.status,
    );
  }

  /// Returns a [OpStatus] error with a [message].
  factory OpStatus.success(
    String message, {
    dynamic data,
    int? code,
  }) {
    return OpStatus(
      success: true,
      message: message,
      data: data,
      code: code,
    );
  }

  /// Returns a [OpStatus] error with a [message].
  factory OpStatus.error(
    String message, {
    Map<String, dynamic>? data,
    int? code,
  }) {
    return OpStatus(
      message: message,
      success: false,
      data: data,
      code: code,
    );
  }

  /// Returns a [OpStatus] error when an unexpected error occurs.
  factory OpStatus.unexpected(
    String message, {
    Map<String, dynamic>? data,
    int? code,
  }) {
    log(message);
    return OpStatus(
      message: 'An Unexpected Error Has Occurred.',
      success: false,
      data: data,
      code: code,
    );
  }

  /// String [message] to give a description of the status.
  final String message;

  /// bool [success] for whether the operation was successful or not.
  final bool success;

  /// an int [code] representing the response code from an operation
  final int? code;

  /// Optional JsonMap [data] to return from the network operation.
  final dynamic data;
}
