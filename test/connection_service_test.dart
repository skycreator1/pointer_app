import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pointer_app/core/services/connection_service.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class FakeWebSocketSink implements WebSocketSink {
  FakeWebSocketSink(this._outgoing);

  final StreamController<Object?> _outgoing;
  final Completer<void> _done = Completer<void>();

  @override
  void add(event) {
    _outgoing.add(event);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    _outgoing.addError(error, stackTrace);
  }

  @override
  Future addStream(Stream stream) {
    final completer = Completer<void>();
    stream.listen(
      add,
      onError: addError,
      onDone: completer.complete,
      cancelOnError: false,
    );
    return completer.future;
  }

  @override
  Future close([int? closeCode, String? closeReason]) async {
    if (!_done.isCompleted) {
      _done.complete();
    }
    await _outgoing.close();
  }

  @override
  Future<void> get done => _done.future;
}

class FakeWebSocketChannel
    with StreamChannelMixin<Object?>
    implements WebSocketChannel {
  FakeWebSocketChannel()
    : _incoming = StreamController<Object?>.broadcast(),
      _outgoing = StreamController<Object?>.broadcast() {
    sink = FakeWebSocketSink(_outgoing);
  }

  final StreamController<Object?> _incoming;
  final StreamController<Object?> _outgoing;

  @override
  late final WebSocketSink sink;

  @override
  Stream<Object?> get stream => _incoming.stream;

  Stream<Object?> get outgoingStream => _outgoing.stream;

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  @override
  String? get protocol => null;

  @override
  Future<void> get ready => Future.value();

  void serverSendJson(Map<String, Object?> message) {
    _incoming.add(jsonEncode(message));
  }
}

Map<String, Object?> _decodeJson(Object? event) {
  final decoded = jsonDecode(event.toString());
  return (decoded as Map).map((k, v) => MapEntry(k.toString(), v));
}

Future<Directory> _createHiveTempDir() async {
  return Directory.systemTemp.createTemp('pointer_app_hive_test_');
}

void main() {
  group('ConnectionService', () {
    Directory? hiveDir;

    setUp(() async {
      hiveDir = await _createHiveTempDir();
      Hive.init(hiveDir!.path);
    });

    tearDown(() async {
      await Hive.close();
      if (hiveDir != null) {
        await hiveDir!.delete(recursive: true);
      }
    });

    test(
      'normal connect: waitingApproval -> connected and persist pairId',
      () async {
        var now = DateTime(2026, 1, 1, 0, 0, 0);
        final channel = FakeWebSocketChannel();

        final service = ConnectionService(
          serverUri: Uri.parse('ws://localhost:1234'),
          myUserId: 'u1',
          channelFactory: (_) => channel,
          now: () => now,
        );

        final states = <ConnectionState>[];
        final stateSub = service.stateStream.listen(states.add);

        final outgoing = <Map<String, Object?>>[];
        final outgoingSub = channel.outgoingStream.listen((e) {
          outgoing.add(_decodeJson(e));
        });

        await service.sendConnectRequest('ABCD1234');
        await Future<void>.delayed(Duration.zero);

        expect(states, contains(ConnectionState.waitingApproval));
        expect(outgoing.isNotEmpty, isTrue);
        expect(outgoing.last['type'], 'connect_request');
        expect(outgoing.last['inviteCode'], 'ABCD1234');
        final requestId = outgoing.last['requestId'] as String;

        channel.serverSendJson(<String, Object?>{
          'type': 'connect_approved',
          'requestId': requestId,
          'pairId': 'pair-001',
        });
        await Future<void>.delayed(Duration.zero);

        expect(states, contains(ConnectionState.connected));

        final box = await Hive.openBox<String>('connection');
        expect(box.get('pairId'), 'pair-001');

        await stateSub.cancel();
        await outgoingSub.cancel();
        await service.dispose();
      },
    );

    test('reject connect: waitingApproval -> idle', () async {
      var now = DateTime(2026, 1, 1, 0, 0, 0);
      final channel = FakeWebSocketChannel();

      final service = ConnectionService(
        serverUri: Uri.parse('ws://localhost:1234'),
        myUserId: 'u1',
        channelFactory: (_) => channel,
        now: () => now,
      );

      final states = <ConnectionState>[];
      final stateSub = service.stateStream.listen(states.add);

      final outgoing = <Map<String, Object?>>[];
      final outgoingSub = channel.outgoingStream.listen((e) {
        outgoing.add(_decodeJson(e));
      });

      await service.sendConnectRequest('ABCD1234');
      await Future<void>.delayed(Duration.zero);

      final requestId = outgoing.last['requestId'] as String;
      channel.serverSendJson(<String, Object?>{
        'type': 'connect_rejected',
        'requestId': requestId,
      });
      await Future<void>.delayed(Duration.zero);

      expect(states, contains(ConnectionState.idle));

      await stateSub.cancel();
      await outgoingSub.cancel();
      await service.dispose();
    });

    test('heartbeat timeout triggers peerOffline and reconnecting', () {
      fakeAsync((async) {
        var now = DateTime(2026, 1, 1, 0, 0, 0);
        final channel = FakeWebSocketChannel();

        final service = ConnectionService(
          serverUri: Uri.parse('ws://localhost:1234'),
          myUserId: 'u1',
          channelFactory: (_) => channel,
          now: () => now,
          persistPairId: false,
        );

        final states = <ConnectionState>[];
        final stateSub = service.stateStream.listen(states.add);

        final outgoing = <Map<String, Object?>>[];
        final outgoingSub = channel.outgoingStream.listen((e) {
          outgoing.add(_decodeJson(e));
        });

        service.sendConnectRequest('ABCD1234');
        async.flushMicrotasks();

        final requestId = outgoing.last['requestId'] as String;
        channel.serverSendJson(<String, Object?>{
          'type': 'connect_approved',
          'requestId': requestId,
          'pairId': 'pair-001',
        });
        async.flushMicrotasks();

        now = now.add(const Duration(seconds: 46));
        async.elapse(const Duration(seconds: 46));
        async.flushMicrotasks();

        expect(states, contains(ConnectionState.peerOffline));
        expect(states, contains(ConnectionState.reconnecting));

        now = now.add(const Duration(seconds: 3));
        async.elapse(const Duration(seconds: 3));
        async.flushMicrotasks();

        final reconnectRequest = outgoing
            .where((m) => m['type'] == 'connect_request')
            .last;
        expect(reconnectRequest['pairId'], 'pair-001');

        stateSub.cancel();
        outgoingSub.cancel();
        service.dispose();
        async.flushMicrotasks();
      });
    });

    test('init() auto reconnect when persisted pairId exists', () async {
      var now = DateTime(2026, 1, 1, 0, 0, 0);
      final box = await Hive.openBox<String>('connection');
      await box.put('pairId', 'pair-xyz');

      final channel = FakeWebSocketChannel();
      final service = ConnectionService(
        serverUri: Uri.parse('ws://localhost:1234'),
        myUserId: 'u1',
        channelFactory: (_) => channel,
        now: () => now,
      );

      final states = <ConnectionState>[];
      final stateSub = service.stateStream.listen(states.add);

      final outgoing = <Map<String, Object?>>[];
      final outgoingSub = channel.outgoingStream.listen((e) {
        outgoing.add(_decodeJson(e));
      });

      await service.init();
      await Future<void>.delayed(Duration.zero);

      expect(states, contains(ConnectionState.reconnecting));

      final connectRequest = outgoing
          .where((m) => m['type'] == 'connect_request')
          .last;
      expect(connectRequest['pairId'], 'pair-xyz');

      await stateSub.cancel();
      await outgoingSub.cancel();
      await service.dispose();
    });
  });
}
