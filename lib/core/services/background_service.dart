import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:home_widget/home_widget.dart';
import 'package:pointer_app/core/models/saved_location.dart';
import 'package:pointer_app/core/services/connection_service.dart';
import 'package:pointer_app/core/services/location_calc_service.dart';
import 'package:rxdart/rxdart.dart';

/// Initializes background service and registers background entrypoint.
///
/// Call this before starting the app UI.
Future<void> initBackgroundService() async {
  WidgetsFlutterBinding.ensureInitialized();

  final service = FlutterBackgroundService();
  await service.configure(
    iosConfiguration: IosConfiguration(autoStart: false),
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      autoStartOnBoot: true,
      isForegroundMode: true,
      initialNotificationTitle: 'Pointer',
      initialNotificationContent: '指针运行中 · 后台定位已开启',
      foregroundServiceNotificationId: 9091,
      foregroundServiceTypes: const [AndroidForegroundType.location],
    ),
  );

  final isRunning = await service.isRunning();
  if (!isRunning) {
    await service.startService();
  }
}

/// iOS Info.plist keys required for background tasks (reference list):
/// - BGTaskSchedulerPermittedIdentifiers: ["com.pointerapp.location"]
/// - UIBackgroundModes: ["location", "fetch", "processing"]
/// - NSLocationWhenInUseUsageDescription
/// - NSLocationAlwaysAndWhenInUseUsageDescription
/// - NSLocationAlwaysUsageDescription
/// - NSLocationTemporaryUsageDescriptionDictionary (optional)
@pragma('vm:entry-point')
/// Background entrypoint for [flutter_background_service].
///
/// Do not call this directly from the UI isolate.
void onStart(ServiceInstance service) async {
  ui.DartPluginRegistrant.ensureInitialized();
  await Hive.initFlutter();

  if (service is AndroidServiceInstance) {
    await service.setForegroundNotificationInfo(
      title: 'Pointer',
      content: '指针运行中 · 后台定位已开启',
    );
  }

  final configSubject = BehaviorSubject<({Uri serverUri, String myUserId})?>();

  final targetSubject = BehaviorSubject<SavedLocation?>();
  final headingSubject = BehaviorSubject<double>.seeded(0.0);
  final gpsSubject = BehaviorSubject<GpsPosition>();

  ConnectionService? connectionService;
  var connectionInitialized = false;
  LocationCalcService? calcService;
  StreamSubscription<PointerResult>? calcSub;
  StreamSubscription? stopSub;
  StreamSubscription? configureSub;
  StreamSubscription? setTargetSub;
  StreamSubscription? setHeadingSub;
  Timer? gpsTimer;

  Future<void> stopAll() async {
    gpsTimer?.cancel();
    gpsTimer = null;

    await calcSub?.cancel();
    calcSub = null;

    await stopSub?.cancel();
    await configureSub?.cancel();
    await setTargetSub?.cancel();
    await setHeadingSub?.cancel();

    await connectionService?.dispose();

    await configSubject.close();
    await targetSubject.close();
    await headingSubject.close();
    await gpsSubject.close();
  }

  void maybeStartCalc() {
    final config = configSubject.valueOrNull;
    final target = targetSubject.valueOrNull;
    if (config == null || target == null) return;

    connectionService ??= ConnectionService(
      serverUri: config.serverUri,
      myUserId: config.myUserId,
    );
    if (!connectionInitialized) {
      connectionInitialized = true;
      connectionService!.init();
    }

    if (calcService == null) {
      calcService = LocationCalcService(
        target: target,
        gpsStream: gpsSubject.stream,
        compassHeadingStream: headingSubject.stream,
      );

      calcSub = calcService!.results.listen((result) async {
        await HomeWidget.saveWidgetData<double>(
          'pointer_angle',
          result.pointerAngle,
        );
        await HomeWidget.saveWidgetData<String>(
          'peer_distance',
          _formatDistance(result.distance),
        );
        await HomeWidget.updateWidget(name: 'PointerWidget');

        service.invoke('pointer_result', <String, dynamic>{
          'distance': result.distance,
          'pointerAngle': result.pointerAngle,
        });
      });
    } else {
      calcService!.setTarget(target);
    }
  }

  configureSub = service.on('configure').listen((data) {
    if (data == null) return;
    final serverUriString = data['serverUri']?.toString();
    final myUserId = data['myUserId']?.toString();
    if (serverUriString == null || myUserId == null) return;
    final uri = Uri.tryParse(serverUriString);
    if (uri == null) return;
    configSubject.add((serverUri: uri, myUserId: myUserId));
    maybeStartCalc();
  });

  setTargetSub = service.on('set_target').listen((data) {
    if (data == null) return;
    final id = data['id']?.toString();
    final name = data['name']?.toString();
    final lat = _toDouble(data['latitude']);
    final lon = _toDouble(data['longitude']);
    if (id == null || name == null || lat == null || lon == null) return;
    targetSubject.add(
      SavedLocation(
        id: id,
        name: name,
        latitude: lat,
        longitude: lon,
        createdAt: DateTime.now(),
      ),
    );
    maybeStartCalc();
  });

  setHeadingSub = service.on('set_heading').listen((data) {
    final heading = _toDouble(data?['heading']);
    if (heading == null) return;
    headingSubject.add(heading);
  });

  stopSub = service.on('stop').listen((_) async {
    await stopAll();
    await service.stopSelf();
  });

  gpsTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
    try {
      final pos = await Geolocator.getCurrentPosition();
      gpsSubject.add((latitude: pos.latitude, longitude: pos.longitude));
      connectionService?.broadcastMyLocation(pos);

      service.invoke('gps_tick', <String, dynamic>{
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'ts': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (_) {}
  });
}

String _formatDistance(double meters) {
  if (!meters.isFinite) return '--';
  if (meters < 1000) return '${meters.round()} m';
  final km = meters / 1000.0;
  return '${km.toStringAsFixed(1)} km';
}

double? _toDouble(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}
