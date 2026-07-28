import 'dart:async';
import 'dart:developer';

import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:net_source/src/models/models.dart';
import 'package:phoenix_socket/phoenix_socket.dart';

/// {@template socket_source}
/// Package to handle socket calls
/// {@endtemplate}
class SocketSource {
  /// {@macro socket_source}
  SocketSource._();

  /// Public factory
  static Future<SocketSource> init(
    String socketUrl, {
    bool alwaysConnected = false,
  }) async {
    final socketApi = SocketSource._();
    await socketApi._init(
      socketUrl: socketUrl,
      alwaysConnected: alwaysConnected,
    );

    return socketApi;
  }

  late PhoenixSocket _socket;

  Future<void> _init({
    required String socketUrl,
    bool alwaysConnected = false,
  }) async {
    _socket = PhoenixSocket(socketUrl);
    final hasConnection =
        await InternetConnectionChecker.instance.hasConnection;

    InternetConnectionChecker.instance.onStatusChange.listen((event) {
      switch (event) {
        case InternetConnectionStatus.connected:
          _socketState.add(true);
        case InternetConnectionStatus.disconnected:
          _socketState.add(false);
        case InternetConnectionStatus.slow:
          _socketState.add(true);
      }
    });

    if (hasConnection && alwaysConnected) {
      await _socket.connect().catchError((dynamic e, st) {
        log('SOCKET ERROR: $e');
        return null;
      });
    }
  }

  /// Close the socket connection
  void disconnect() {
    if (_socket.channels.isEmpty) _socket.close();
  }

  /// Default error message
  String error = 'An Unexpected Error Has Occurred.';

  /// Default no internet message
  String noConnection =
      'No Internet Connection. Ensure you are connected and try again.';

  final _socketState = StreamController<bool>();

  /// Socket status at any given point
  Stream<bool> get hasSocketConnection async* {
    yield false;
    yield* _socketState.stream;
  }

  final _socketController = StreamController<Map<dynamic, dynamic>?>();

  /// Responses from the web socket
  Stream<Map<dynamic, dynamic>?> get channelStream async* {
    yield* _socketController.stream;
  }

  /// Pushes [data] to an [event]
  Future<dynamic> push(
    dynamic channel,
    String event,
    JsonMap data,
  ) async {
    try {
      final hasConnection =
          await InternetConnectionChecker.instance.hasConnection;
      if (!hasConnection) {
        log('No Internet Connection @ $event');
        return NetResponse(status: 2, message: noConnection);
      }
      final response = await (channel as PhoenixChannel)
          .push(event, data, const Duration(milliseconds: 1000))
          .future;
      log('Push @ $event: ${response.response}');
      return response.response;
    } catch (e) {
      log('Error @ $event: $e');
      return e;
    }
  }

  /// Connects to a socket channel [topic]
  Future<PhoenixChannel?> connect(String topic, {JsonMap? parameters}) async {
    if (!_socket.isConnected) {
      final hasConnection =
          await InternetConnectionChecker.instance.hasConnection;
      if (hasConnection) {
        await _socket.connect();
      } else {
        return null;
      }
    }
    final channel = _socket.addChannel(topic: topic);
    await channel.join().future;
    channel.messages.listen((event) {
      final data = <String, dynamic>{
        'event': event.event.value,
        'data': event.payload,
      };
      _socketController.add(data);
    });
    return channel;
  }
}
