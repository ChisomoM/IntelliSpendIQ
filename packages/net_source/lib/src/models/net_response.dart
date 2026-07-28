import 'package:net_source/src/models/models.dart';

part 'net_response.g.dart';

/// A data object used to parse network responses from our API
class NetResponse {
  /// {@macro net_response}
  const NetResponse({required this.message, this.data, this.status});

  /// The data returned from the network request
  final dynamic data;

  /// A message describing the status of the response
  final String message;

  /// an int status, 0 for success, 1 for failure
  final int? status;

  /// Deserializes the given [JsonMap] into a [NetResponse].
  static NetResponse fromJson(JsonMap json) => _$NetResponseFromJson(json);

  /// Check whether network request was successful
  bool isSuccessful() {
    return status == 0;
  }
}
