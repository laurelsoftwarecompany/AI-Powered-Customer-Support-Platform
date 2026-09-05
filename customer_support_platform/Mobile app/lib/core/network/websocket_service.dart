import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../storage/token_storage.dart';

/// Real-time WebSocket service that connects to the backend and streams
/// parsed JSON events to listeners.
///
/// Supports:
/// - Auto-reconnect with exponential backoff (1 s → 2 s → 4 s … max 30 s)
/// - JWT authentication via query parameter
/// - Typed event stream
class WebSocketService {
  final TokenStorage tokenStorage;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;

  bool _disposed = false;
  int _reconnectAttempts = 0;
  String? _currentPath;

  /// Give up after this many consecutive failures. The server rejects a
  /// socket it will never accept (bad token, someone else's conversation)
  /// during the handshake, so retrying forever just floods its log and
  /// drains the battery.
  static const int _maxReconnectAttempts = 6;

  final _eventController = StreamController<Map<String, dynamic>>.broadcast();

  /// Parsed JSON events from the server (`new_message`, `status_change`, …).
  Stream<Map<String, dynamic>> get events => _eventController.stream;

  /// Whether the WebSocket is currently connected.
  bool get isConnected => _channel != null;

  WebSocketService({required this.tokenStorage});

  // ------------------------------------------------------------------
  // Base URL — mirrors logic from ApiClient but uses the `ws://` scheme.
  // ------------------------------------------------------------------

  static const String _override = String.fromEnvironment('WS_BASE_URL');

  static String get _wsBase {
    if (_override.isNotEmpty) return _override;
    // Derive from API_BASE_URL override if present
    const apiOverride = String.fromEnvironment('API_BASE_URL');
    if (apiOverride.isNotEmpty) {
      return apiOverride
          .replaceFirst('http://', 'ws://')
          .replaceFirst('https://', 'wss://');
    }
    if (kIsWeb) return 'ws://127.0.0.1:8000/api/v1';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'ws://10.0.2.2:8000/api/v1';
    }
    return 'ws://127.0.0.1:8000/api/v1';
  }

  // ------------------------------------------------------------------
  // CONNECT
  // ------------------------------------------------------------------

  /// Connect to a WebSocket path, e.g. `/ws/conversations/5`.
  Future<void> connect(String path) async {
    if (_disposed) return;

    // Disconnect any previous connection
    await _disconnectInternal();

    _currentPath = path;
    _reconnectAttempts = 0;

    await _doConnect(path);
  }

  Future<void> _doConnect(String path) async {
    if (_disposed) return;

    final token = await tokenStorage.getAccessToken();
    if (token == null || token.isEmpty) return;

    final separator = path.contains('?') ? '&' : '?';
    final uri = Uri.parse('$_wsBase$path${separator}token=$token');

    try {
      _channel = WebSocketChannel.connect(uri);
      await _channel!.ready;

      _reconnectAttempts = 0;

      _subscription = _channel!.stream.listen(
        (data) {
          if (data is String && data.trim().isNotEmpty) {
            try {
              final parsed = jsonDecode(data) as Map<String, dynamic>;
              _eventController.add(parsed);
            } catch (_) {
              // Not valid JSON — ignore
            }
          }
        },
        onError: (_) => _scheduleReconnect(),
        onDone: () {
          // 4001 auth failed / 4003 access denied / 4004 not found are all
          // permanent - reconnecting cannot change the answer.
          final code = _channel?.closeCode;
          if (code != null && code >= 4001 && code <= 4004) {
            _currentPath = null;
            return;
          }
          _scheduleReconnect();
        },
        cancelOnError: false,
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  // ------------------------------------------------------------------
  // DISCONNECT
  // ------------------------------------------------------------------

  Future<void> disconnect() async {
    _currentPath = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _disconnectInternal();
  }

  Future<void> _disconnectInternal() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _subscription?.cancel();
    _subscription = null;
    try {
      await _channel?.sink.close();
    } catch (_) {
      // Socket already closed
    }
    _channel = null;
  }

  // ------------------------------------------------------------------
  // AUTO-RECONNECT
  // ------------------------------------------------------------------

  void _scheduleReconnect() {
    if (_disposed || _currentPath == null) return;

    if (_reconnectAttempts >= _maxReconnectAttempts) {
      // Almost always a rejected handshake (the server answers 403 before
      // accepting, so no close code reaches us). Stop rather than loop.
      _currentPath = null;
      return;
    }

    _reconnectTimer?.cancel();

    // Exponential backoff: 1s, 2s, 4s, 8s, … capped at 30s
    final delay = Duration(
      seconds: min(30, pow(2, _reconnectAttempts).toInt()),
    );
    _reconnectAttempts++;

    _reconnectTimer = Timer(delay, () {
      if (!_disposed && _currentPath != null) {
        _doConnect(_currentPath!);
      }
    });
  }

  // ------------------------------------------------------------------
  // SEND (for heartbeat / ping)
  // ------------------------------------------------------------------

  void send(Map<String, dynamic> data) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode(data));
    }
  }

  // ------------------------------------------------------------------
  // DISPOSE
  // ------------------------------------------------------------------

  Future<void> dispose() async {
    _disposed = true;
    await disconnect();
    await _eventController.close();
  }
}
