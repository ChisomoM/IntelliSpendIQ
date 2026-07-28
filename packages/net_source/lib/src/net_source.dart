import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:net_source/src/models/models.dart';

/// {@template net_source}
/// Package to handle network calls
/// {@endtemplate}
class NetSource {
  /// {@macro net_source}
  NetSource({
    required String baseUrl,
    required String host,
    String? token,
  })  : _baseUrl = baseUrl,
        _host = host,
        _token = token ?? '' {
    init();
    _monitor();
  }

  final String _baseUrl;
  final String _host;
  final String _token;
  late Dio _client;

  /// Initialise network api
  void init({
    String? token,
    String? refreshToken,
    String? appId,
    String? deviceId,
  }) {
    final options = BaseOptions(
      baseUrl: _baseUrl,
      followRedirects: true,
      receiveDataWhenStatusError: true,
      headers: <String, String>{
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
        'deviceId': deviceId ?? '',
        'appId': appId ?? '1efc7d35-7fd0-6000-a000-0123456789ab',
        'deviceType': 'APP',
        'refreshToken': refreshToken ?? '',
      },
      validateStatus: (status) {
        return (status ?? 501) < 501;
      },
    );
    _client = Dio(options);
    _client.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient()
          ..badCertificateCallback = (cert, host, port) => _host == host;
        return client;
      },
    );
  }

  /// Monitor network status
  void _monitor() {
    InternetConnectionChecker.instance.onStatusChange.listen((event) {
      switch (event) {
        case InternetConnectionStatus.connected:
          _netState.add(true);
        case InternetConnectionStatus.disconnected:
          _netState.add(false);
        case InternetConnectionStatus.slow:
          _netState.add(true);
      }
    });
  }

  /// Default error message
  String error = 'An Unexpected Error Has Occurred.';

  /// Default no internet message
  String noConnection =
      'No Internet Connection. Ensure you are connected and try again.';

  final _controller = StreamController<int>();
  final _netState = StreamController<bool>();

  /// Authentication status of user at any given point
  Stream<int> get uploadProgress async* {
    yield 0;
    yield* _controller.stream;
  }

  /// Network status at any given point
  Stream<bool> get hasNetConnection async* {
    yield false;
    yield* _netState.stream;
  }

  /// Send GET request to [route] with optional [data]
  Future<NetResponse> get(String route, [JsonMap? data]) async {
    try {
      final hasConnection =
          await InternetConnectionChecker.instance.hasConnection;
      if (!hasConnection) {
        log('No Internet Connection @ $route');
        return NetResponse(status: 2, message: noConnection);
      }
      final response = await _client.get<JsonMap>(route, data: data);
      log('Response @ $route: ${response.data}');
      return NetResponse.fromJson(response.data!);
    } catch (e) {
      log('Error @ $route: $e');
      return NetResponse(status: 2, message: error);
    }
  }

  /// Send POST request to [route] with optional [body]
  Future<NetResponse> post(String route, [JsonMap? body]) async {
    log('token to post: $_token');
    try {
      final hasConnection =
          await InternetConnectionChecker.instance.hasConnection;
      if (!hasConnection) {
        log('No Internet Connection @ $route');
        return NetResponse(status: 2, message: noConnection);
      }
      final response = await _client.post<dynamic>(route, data: body);
      log('Response @ $route: ${response.data}');
      return NetResponse.fromJson(response.data as JsonMap);
    } catch (e) {
      log('Error @ $route: $e');
      return NetResponse(status: 2, message: error);
    }
  }

  /// Send PUT request to [route] with [body]
  Future<NetResponse> put(String route, JsonMap body) async {
    try {
      final hasConnection =
          await InternetConnectionChecker.instance.hasConnection;
      if (!hasConnection) {
        log('No Internet Connection @ $route');
        return NetResponse(status: 2, message: noConnection);
      }
      final response = await _client.put<JsonMap>(route, data: body);
      log('Response @ $route: ${response.data}');
      return NetResponse.fromJson(response.data!);
    } catch (e) {
      log('Error @ $route: $e');
      return NetResponse(status: 2, message: error);
    }
  }

  /// Send PUT request to [route] with [files]
  Future<NetResponse> upload(String route, JsonMap files) async {
    try {
      final hasConnection =
          await InternetConnectionChecker.instance.hasConnection;
      if (!hasConnection) {
        log('No Internet Connection @ $route');
        return NetResponse(status: 2, message: noConnection);
      }
      final body = <String, dynamic>{};
      for (final file in files.entries) {
        body[file.key] = await MultipartFile.fromFile(file.value.toString());
      }
      final formData = FormData.fromMap(body);
      final response = await _client.put<JsonMap>(
        route,
        data: formData,
        onSendProgress: (sent, total) {
          final progress = sent / total * 100;
          _controller.add(progress.toInt());
          log('progress: ${progress.toStringAsFixed(0)}% ($sent/$total)');
        },
      );
      log('Response @ $route: ${response.data}');
      _controller.add(0);
      return NetResponse.fromJson(response.data!);
    } catch (e) {
      log('Error @ $route: $e');
      _controller.add(0);
      return NetResponse(status: 2, message: error);
    }
  }

  /// Send POST request to [route] with files
  Future<NetResponse> uploadFile(
    String route,
    Map<String, dynamic> formData,
  ) async {
    try {
      final hasConnection =
          await InternetConnectionChecker.instance.hasConnection;
      if (!hasConnection) {
        log('No Internet Connection @ $route');
        return NetResponse(status: 2, message: noConnection);
      }

      final body = <String, dynamic>{};
      for (final file in formData.entries) {
        if (file.value is File) {
          body[file.key] =
              await MultipartFile.fromFile((file.value as File).path);
        } else {
          body[file.key] = file.value;
        }
      }

      final multipartFormData = FormData.fromMap(body);
      final response = await _client.post<JsonMap>(
        route,
        data: multipartFormData,
        onSendProgress: (sent, total) {
          final progress = sent / total * 100;
          _controller.add(progress.toInt());
          log('progress: ${progress.toStringAsFixed(0)}% ($sent/$total)');
        },
      );

      log('Response @ $route: ${response.data}');
      _controller.add(0);
      return NetResponse.fromJson(response.data!);
    } catch (e) {
      log('Error @ $route: $e');
      _controller.add(0);
      return NetResponse(status: 2, message: error);
    }
  }

  /// Send a request to [route] with optional [data]/[params]
  Future<dynamic> rawGet(String route, {JsonMap? data, JsonMap? params}) async {
    try {
      final hasConnection =
          await InternetConnectionChecker.instance.hasConnection;
      if (!hasConnection) {
        log('No Internet Connection @ $route');
        return NetResponse(status: 2, message: noConnection);
      }
      final dio = Dio();
      final response = await dio.get<dynamic>(
        route,
        data: data,
        queryParameters: params,
      );
      log('Response @ $route: ${response.data}');
      return response.data;
    } catch (e) {
      log('Error @ $route: $e');
      return null;
    }
  }
}
