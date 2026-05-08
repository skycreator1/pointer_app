import 'dart:async';
import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:hive/hive.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Device-to-device connection state machine based on WebSocket + JSON messages.
enum ConnectionState {
  idle,
  waitingApproval,
  connected,
  peerOffline,
  reconnecting,
}

/// Peer location update payload emitted by [ConnectionService.peerLocationStream].
class PeerLocation {
  const PeerLocation({
    required this.latitude,
    required this.longitude,
    required this.receivedAt,
  });

  final double latitude;
  final double longitude;
  final DateTime receivedAt;
}

/// Incoming connect request emitted by [ConnectionService.incomingRequestStream].
class ConnectRequest {
  const ConnectRequest({
    required this.requestId,
    required this.inviteCode,
    required this.receivedAt,
  });

  final String requestId;
  final String inviteCode;
  final DateTime receivedAt;
}

/// WebSocket based connection service that:
/// - Sends connect requests and approvals/rejections.
/// - Emits connection state changes and peer locations.
/// - Sends heartbeat every 15s and marks peer offline after 45s of silence.
/// - Persists pairId using Hive for auto-reconnect on restart.
class ConnectionService {
  ConnectionService({
    required this.serverUri,
    required this.myUserId,
    WebSocketChannel Function(Uri uri)? channelFactory,
    DateTime Function()? now,
    bool persistPairId = true,
  }) : _channelFactory = channelFactory ?? WebSocketChannel.connect,
       _now = now ?? DateTime.now,
       _persistPairIdEnabled = persistPairId;

  /// WebSocket server endpoint.
  final Uri serverUri;

  /// Local user identifier used in messages.
  final String myUserId;
  final WebSocketChannel Function(Uri uri) _channelFactory;
  final DateTime Function() _now;
  final bool _persistPairIdEnabled;

  /// Broadcast stream of current [ConnectionState].
  final StreamController<ConnectionState> _stateController =
      StreamController<ConnectionState>.broadcast();

  /// Broadcast stream of peer location updates.
  final StreamController<PeerLocation> _peerLocationController =
      StreamController<PeerLocation>.broadcast();

  /// Broadcast stream of incoming connect requests.
  final StreamController<ConnectRequest> _incomingRequestController =
      StreamController<ConnectRequest>.broadcast();

  /// State changes for UI/BLoC to subscribe to.
  Stream<ConnectionState> get stateStream => _stateController.stream;

  /// Peer location stream for UI/BLoC to subscribe to.
  Stream<PeerLocation> get peerLocationStream => _peerLocationController.stream;

  /// Incoming connect requests containing requestId for approve/reject.
  Stream<ConnectRequest> get incomingRequestStream =>
      _incomingRequestController.stream;

  /// Current connection state.
  ConnectionState _state = ConnectionState.idle;

  /// Current connection state snapshot.
  ConnectionState get state => _state;

  WebSocketChannel? _channel;
  StreamSubscription? _channelSubscription;

  Timer? _heartbeatTimer;
  Timer? _peerTimeoutTimer;
  Timer? _reconnectTimer;

  DateTime _lastReceivedAt = DateTime.fromMillisecondsSinceEpoch(0);
  String? _pairId;
  String? _pendingRequestId;
  String? _pendingInviteCode;

  int _requestNonce = 0;
  int _reconnectAttempt = 0;
  bool _disposed = false;

  static const _heartbeatInterval = Duration(seconds: 15);
  static const _peerTimeout = Duration(seconds: 45);

  /// Initializes storage and triggers auto-reconnect if a persisted pairId exists.
  Future<void> init() async {
    final box = await Hive.openBox<String>('connection');
    _pairId = box.get('pairId');

    if (_pairId != null && _pairId!.isNotEmpty) {
      _setState(ConnectionState.reconnecting);
      await _connect();
      _sendJson(<String, Object?>{
        'type': 'connect_request',
        'requestId': _newRequestId(),
        'pairId': _pairId,
        'fromUserId': myUserId,
      });
    }
  }

  /// Sends a connect request to peer using an invite code.
  Future<void> sendConnectRequest(String inviteCode) async {
    _pendingInviteCode = inviteCode;
    _pendingRequestId = _newRequestId();

    _setState(ConnectionState.waitingApproval);
    await _connect();

    _sendJson(<String, Object?>{
      'type': 'connect_request',
      'requestId': _pendingRequestId,
      'inviteCode': inviteCode,
      'fromUserId': myUserId,
    });
  }

  /// Approves an incoming connect request.
  Future<void> approveRequest(String requestId) async {
    await _connect();

    final generatedPairId = _pairId ?? _generatePairId(requestId);
    _pairId = generatedPairId;
    if (_persistPairIdEnabled) {
      await _persistPairId(generatedPairId);
    }

    _sendJson(<String, Object?>{
      'type': 'connect_approved',
      'requestId': requestId,
      'pairId': generatedPairId,
    });

    _setState(ConnectionState.connected);
  }

  /// Rejects an incoming connect request.
  Future<void> rejectRequest(String requestId) async {
    await _connect();
    _sendJson(<String, Object?>{
      'type': 'connect_rejected',
      'requestId': requestId,
    });
    if (_state == ConnectionState.waitingApproval) {
      _setState(ConnectionState.idle);
    }
  }

  /// Broadcasts local GPS position to peer as a location_update message.
  void broadcastMyLocation(Position pos) {
    final pairId = _pairId;
    if (_state != ConnectionState.connected || pairId == null) return;

    _sendJson(<String, Object?>{
      'type': 'location_update',
      'pairId': pairId,
      'lat': pos.latitude,
      'lon': pos.longitude,
      'ts': _now().millisecondsSinceEpoch,
    });
  }

  /// Cancels all timers/subscriptions and closes streams.
  Future<void> dispose() async {
    _disposed = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _closeSocket();

    await _stateController.close();
    await _peerLocationController.close();
    await _incomingRequestController.close();
  }

  Future<void> _connect() async {
    if (_disposed) return;
    if (_channel != null) return;

    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    final channel = _channelFactory(serverUri);
    _channel = channel;
    _reconnectAttempt = 0;

    _lastReceivedAt = _now();
    _startHeartbeat();
    _startPeerTimeoutWatchdog();

    _channelSubscription = channel.stream.listen(
      (event) {
        _lastReceivedAt = _now();
        _handleIncoming(event);
      },
      onError: (_) {
        unawaited(_handlePeerOffline());
      },
      onDone: () {
        unawaited(_handlePeerOffline());
      },
      cancelOnError: true,
    );
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      _sendJson(<String, Object?>{
        'type': 'heartbeat',
        'ts': _now().millisecondsSinceEpoch,
      });
    });
  }

  void _startPeerTimeoutWatchdog() {
    _peerTimeoutTimer?.cancel();
    _peerTimeoutTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      final now = _now();
      if (now.difference(_lastReceivedAt) > _peerTimeout) {
        unawaited(_handlePeerOffline());
      }
    });
  }

  void _handleIncoming(Object? event) {
    if (_disposed) return;

    Map<String, Object?>? msg;
    try {
      final decoded = jsonDecode(event.toString());
      if (decoded is Map) {
        msg = decoded.map((k, v) => MapEntry(k.toString(), v));
      }
    } catch (_) {
      return;
    }

    if (msg == null) return;
    final type = msg['type']?.toString();
    if (type == null) return;

    switch (type) {
      case 'heartbeat':
        return;
      case 'connect_request':
        final requestId = msg['requestId']?.toString();
        final inviteCode = msg['inviteCode']?.toString() ?? '';
        if (requestId == null) return;
        _incomingRequestController.add(
          ConnectRequest(
            requestId: requestId,
            inviteCode: inviteCode,
            receivedAt: _now(),
          ),
        );
        _setState(ConnectionState.waitingApproval);
        return;
      case 'connect_approved':
        final requestId = msg['requestId']?.toString();
        final pairId = msg['pairId']?.toString();
        if (requestId == null || pairId == null) return;
        if (_pendingRequestId != null && _pendingRequestId != requestId) return;
        _pairId = pairId;
        _pendingRequestId = null;
        _pendingInviteCode = null;
        if (_persistPairIdEnabled) {
          _persistPairId(pairId);
        }
        _setState(ConnectionState.connected);
        return;
      case 'connect_rejected':
        final requestId = msg['requestId']?.toString();
        if (requestId == null) return;
        if (_pendingRequestId != null && _pendingRequestId != requestId) return;
        _pendingRequestId = null;
        _pendingInviteCode = null;
        _setState(ConnectionState.idle);
        return;
      case 'location_update':
        final lat = _toDouble(msg['lat']);
        final lon = _toDouble(msg['lon']);
        if (lat == null || lon == null) return;
        _peerLocationController.add(
          PeerLocation(latitude: lat, longitude: lon, receivedAt: _now()),
        );
        return;
      case 'peer_offline':
        unawaited(_handlePeerOffline());
        return;
    }
  }

  Future<void> _handlePeerOffline() async {
    if (_disposed) return;

    if (_state != ConnectionState.peerOffline) {
      _setState(ConnectionState.peerOffline);
    }

    if (_pairId != null && _pairId!.isNotEmpty) {
      _setState(ConnectionState.reconnecting);
      _scheduleReconnect();
    } else {
      _setState(ConnectionState.idle);
    }

    await _closeSocket();
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _reconnectTimer?.cancel();

    _reconnectAttempt++;
    final delaySeconds = (_reconnectAttempt * 2).clamp(2, 30);
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () async {
      if (_disposed) return;
      try {
        await _connect();
        _sendJson(<String, Object?>{
          'type': 'connect_request',
          'requestId': _newRequestId(),
          'pairId': _pairId,
          'fromUserId': myUserId,
          'inviteCode': _pendingInviteCode,
        });
      } catch (_) {
        _scheduleReconnect();
      }
    });
  }

  Future<void> _closeSocket() async {
    _heartbeatTimer?.cancel();
    _peerTimeoutTimer?.cancel();
    _heartbeatTimer = null;
    _peerTimeoutTimer = null;

    final subscription = _channelSubscription;
    _channelSubscription = null;
    await subscription?.cancel();

    final channel = _channel;
    _channel = null;
    await channel?.sink.close();
  }

  void _sendJson(Map<String, Object?> msg) {
    if (_disposed) return;
    final channel = _channel;
    if (channel == null) return;
    channel.sink.add(jsonEncode(msg));
  }

  void _setState(ConnectionState next) {
    if (_disposed) return;
    if (_state == next) return;
    _state = next;
    if (next == ConnectionState.connected || next == ConnectionState.idle) {
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      _reconnectAttempt = 0;
    }
    _stateController.add(next);
  }

  String _newRequestId() {
    _requestNonce++;
    return '${_now().millisecondsSinceEpoch}-$myUserId-$_requestNonce';
  }

  String _generatePairId(String requestId) {
    final base = '${_now().millisecondsSinceEpoch}-$myUserId-$requestId';
    final bytes = utf8.encode(base);
    final sum = bytes.fold<int>(0, (a, b) => (a + b) & 0xffffffff);
    return 'p$sum${base.hashCode.abs()}';
  }

  Future<void> _persistPairId(String pairId) async {
    try {
      final box = await Hive.openBox<String>('connection');
      await box.put('pairId', pairId);
    } catch (_) {}
  }
}

double? _toDouble(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}
