import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pointer_app/core/services/connection_service.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class _MockWebSocketChannel extends Mock implements WebSocketChannel {}

class _MockWebSocketSink extends Mock implements WebSocketSink {}

void main() {
  setUpAll(() {
    registerFallbackValue('');
  });

  test('mock WebSocket，验证握手消息格式', () async {
    final channel = _MockWebSocketChannel();
    final sink = _MockWebSocketSink();
    final incoming = StreamController<Object?>.broadcast(sync: true);

    when(() => channel.sink).thenReturn(sink);
    when(() => channel.stream).thenAnswer((_) => incoming.stream);
    when(() => sink.close(any(), any())).thenAnswer((_) async {});

    final svc = ConnectionService(
      serverUri: Uri.parse('ws://example.test/ws'),
      myUserId: 'u1',
      channelFactory: (_) => channel,
      now: () => DateTime(2020, 1, 1),
      persistPairId: false,
    );

    await svc.sendConnectRequest('ABCDEFGH');

    final captured = verify(() => sink.add(captureAny())).captured;
    expect(captured, hasLength(1));

    final msg = jsonDecode(captured.single as String) as Map<String, Object?>;
    expect(msg['type'], 'connect_request');
    expect(msg['fromUserId'], 'u1');
    expect(msg['inviteCode'], 'ABCDEFGH');
    expect((msg['requestId'] as String).isNotEmpty, isTrue);

    await svc.dispose();
    await incoming.close();
  });

  test('模拟心跳超时（fake async，45秒后触发 peerOffline）', () {
    fakeAsync((async) {
      final channel = _MockWebSocketChannel();
      final sink = _MockWebSocketSink();
      final incoming = StreamController<Object?>.broadcast(sync: true);

      when(() => channel.sink).thenReturn(sink);
      when(() => channel.stream).thenAnswer((_) => incoming.stream);
      when(() => sink.close(any(), any())).thenAnswer((_) async {});

      final base = DateTime(2020, 1, 1);

      final svc = ConnectionService(
        serverUri: Uri.parse('ws://example.test/ws'),
        myUserId: 'u1',
        channelFactory: (_) => channel,
        now: () => base.add(async.elapsed),
        persistPairId: false,
      );

      final states = <ConnectionState>[];
      svc.stateStream.listen(states.add);

      svc.sendConnectRequest('ABCDEFGH');
      async.flushMicrotasks();
      expect(svc.state, ConnectionState.waitingApproval);

      async.elapse(const Duration(seconds: 49));
      async.flushMicrotasks();

      expect(states.contains(ConnectionState.peerOffline), isTrue);

      svc.dispose();
      incoming.close();
    });
  });

  test('模拟重连：断开后重新上线，状态从 reconnecting → connected', () {
    fakeAsync((async) {
      final ch1 = _MockWebSocketChannel();
      final sink1 = _MockWebSocketSink();
      final incoming1 = StreamController<Object?>.broadcast(sync: true);

      when(() => ch1.sink).thenReturn(sink1);
      when(() => ch1.stream).thenAnswer((_) => incoming1.stream);
      when(() => sink1.close(any(), any())).thenAnswer((_) async {});

      final ch2 = _MockWebSocketChannel();
      final sink2 = _MockWebSocketSink();
      final incoming2 = StreamController<Object?>.broadcast(sync: true);

      when(() => ch2.sink).thenReturn(sink2);
      when(() => ch2.stream).thenAnswer((_) => incoming2.stream);
      when(() => sink2.close(any(), any())).thenAnswer((_) async {});

      var connectCount = 0;
      WebSocketChannel factory(Uri uri) {
        connectCount++;
        if (connectCount == 1) return ch1;
        return ch2;
      }

      final base = DateTime(2020, 1, 1);

      final svc = ConnectionService(
        serverUri: Uri.parse('ws://example.test/ws'),
        myUserId: 'u1',
        channelFactory: factory,
        now: () => base.add(async.elapsed),
        persistPairId: false,
      );

      final states = <ConnectionState>[];
      svc.stateStream.listen(states.add);

      svc.sendConnectRequest('ABCDEFGH');
      async.flushMicrotasks();
      async.flushMicrotasks();

      final captured1 = verify(() => sink1.add(captureAny())).captured;
      expect(captured1, hasLength(1));
      final msg1 =
          jsonDecode(captured1.single as String) as Map<String, Object?>;
      final requestId1 = msg1['requestId'] as String;

      incoming1.add(
        jsonEncode(<String, Object?>{
          'type': 'connect_approved',
          'requestId': requestId1,
          'pairId': 'pair123',
        }),
      );
      expect(svc.state, ConnectionState.connected);
      async.flushMicrotasks();

      incoming1.addError(StateError('disconnect'));
      async.flushMicrotasks();
      async.flushMicrotasks();

      expect(states.contains(ConnectionState.reconnecting), isTrue);

      async.elapse(const Duration(seconds: 3));
      async.flushMicrotasks();
      async.flushMicrotasks();

      expect(connectCount, 2);

      final captured2 = verify(() => sink2.add(captureAny())).captured;
      expect(captured2, hasLength(1));
      final msg2 =
          jsonDecode(captured2.single as String) as Map<String, Object?>;
      final requestId2 = msg2['requestId'] as String;

      incoming2.add(
        jsonEncode(<String, Object?>{
          'type': 'connect_approved',
          'requestId': requestId2,
          'pairId': 'pair123',
        }),
      );
      async.flushMicrotasks();

      expect(svc.state, ConnectionState.connected);

      svc.dispose();
      incoming1.close();
      incoming2.close();
    });
  });

  test('验证 pairId 被写入 Hive', () async {
    final tempDir = await Directory.systemTemp.createTemp('pointer_app_hive_');
    addTearDown(() async {
      await Hive.close();
      await tempDir.delete(recursive: true);
    });

    Hive.init(tempDir.path);

    final channel = _MockWebSocketChannel();
    final sink = _MockWebSocketSink();
    final incoming = StreamController<Object?>.broadcast(sync: true);

    when(() => channel.sink).thenReturn(sink);
    when(() => channel.stream).thenAnswer((_) => incoming.stream);
    when(() => sink.close(any(), any())).thenAnswer((_) async {});

    final svc = ConnectionService(
      serverUri: Uri.parse('ws://example.test/ws'),
      myUserId: 'u1',
      channelFactory: (_) => channel,
      now: () => DateTime(2020, 1, 1),
      persistPairId: true,
    );

    await svc.sendConnectRequest('ABCDEFGH');

    final captured = verify(() => sink.add(captureAny())).captured;
    expect(captured, hasLength(1));
    final msg = jsonDecode(captured.single as String) as Map<String, Object?>;
    final requestId = msg['requestId'] as String;

    incoming.add(
      jsonEncode(<String, Object?>{
        'type': 'connect_approved',
        'requestId': requestId,
        'pairId': 'pair123',
      }),
    );

    await Future<void>.delayed(const Duration(milliseconds: 10));

    final box = await Hive.openBox<String>('connection');
    expect(box.get('pairId'), 'pair123');

    await svc.dispose();
    await incoming.close();
  });
}
