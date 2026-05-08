import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pointer_app/core/services/connection_service.dart';

class NotificationService {
  NotificationService({
    ConnectionService? connectionService,
    FlutterLocalNotificationsPlugin? plugin,
  }) : _connectionService = connectionService,
       _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const String _categoryConnectRequest = 'connect_request';
  static const String _androidChannelId = 'connect_requests';
  static const String _androidChannelName = '连接请求';
  static const String _androidChannelDescription = '连接请求与状态通知';

  static const String actionApprove = 'approve';
  static const String actionReject = 'reject';

  final ConnectionService? _connectionService;
  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;
  bool _disabled = false;

  Future<void> init() async {
    if (_initialized) return;
    if (_disabled) {
      _initialized = true;
      return;
    }

    const androidSettings = AndroidInitializationSettings(
      'ic_bg_service_small',
    );
    final iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      notificationCategories: <DarwinNotificationCategory>[
        DarwinNotificationCategory(
          _categoryConnectRequest,
          actions: <DarwinNotificationAction>[
            DarwinNotificationAction.plain(actionApprove, '同意'),
            DarwinNotificationAction.plain(
              actionReject,
              '拒绝',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.destructive,
              },
            ),
          ],
        ),
      ],
    );

    try {
      await _plugin.initialize(
        settings: InitializationSettings(
          android: androidSettings,
          iOS: iosSettings,
        ),
        onDidReceiveNotificationResponse: (response) {
          unawaited(_handleResponse(response));
        },
      );
    } on PlatformException catch (e) {
      if (e.code != 'invalid_icon') rethrow;
      _disabled = true;
      _initialized = true;
      return;
    }

    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidImpl != null) {
      await androidImpl.createNotificationChannel(
        const AndroidNotificationChannel(
          _androidChannelId,
          _androidChannelName,
          description: _androidChannelDescription,
          importance: Importance.high,
        ),
      );
      await androidImpl.requestNotificationsPermission();
    }

    final iosImpl = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (iosImpl != null) {
      await iosImpl.requestPermissions(alert: true, badge: true, sound: true);
    }

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    final response = launchDetails?.notificationResponse;
    if (response != null) {
      await _handleResponse(response);
    }

    _initialized = true;
  }

  Future<void> showConnectRequest({
    required String requestId,
    required String deviceNickname,
  }) async {
    await init();
    if (_disabled) return;

    final payload = jsonEncode(<String, Object?>{
      'requestId': requestId,
      'deviceNickname': deviceNickname,
    });

    final androidDetails = AndroidNotificationDetails(
      _androidChannelId,
      _androidChannelName,
      channelDescription: _androidChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction(
          actionApprove,
          '同意',
          cancelNotification: true,
          showsUserInterface: true,
        ),
        const AndroidNotificationAction(
          actionReject,
          '拒绝',
          cancelNotification: true,
          showsUserInterface: true,
        ),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      categoryIdentifier: _categoryConnectRequest,
      presentAlert: true,
      presentSound: true,
    );

    final id = _notificationIdFromRequestId(requestId);
    await _plugin.show(
      id: id,
      title: '连接请求',
      body: '$deviceNickname 请求与你连接',
      notificationDetails: NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      ),
      payload: payload,
    );
  }

  Future<void> showPeerOnline(String nickname) async {
    await init();
    if (_disabled) return;

    final androidDetails = AndroidNotificationDetails(
      _androidChannelId,
      _androidChannelName,
      channelDescription: _androidChannelDescription,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
    );

    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch & 0x7fffffff,
      title: '对方已上线',
      body: nickname,
      notificationDetails: NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      ),
    );
  }

  void cancelAll() {
    unawaited(_cancelAll());
  }

  Future<void> _cancelAll() async {
    await init();
    await _plugin.cancelAll();
  }

  Future<void> _handleResponse(NotificationResponse response) async {
    if (response.notificationResponseType !=
        NotificationResponseType.selectedNotificationAction) {
      return;
    }

    final actionId = response.actionId;
    if (actionId == null || actionId.isEmpty) return;

    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    String? requestId;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map) {
        requestId = decoded['requestId']?.toString();
      }
    } catch (_) {
      return;
    }

    if (requestId == null) return;

    if (actionId == actionApprove) {
      await _connectionService?.approveRequest(requestId);
      return;
    }
    if (actionId == actionReject) {
      await _connectionService?.rejectRequest(requestId);
      return;
    }
  }
}

int _notificationIdFromRequestId(String requestId) {
  var h = 0;
  for (final unit in requestId.codeUnits) {
    h = (h * 31 + unit) & 0x7fffffff;
  }
  return h;
}
