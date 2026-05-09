import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:pointer_app/core/models/saved_location.dart';
import 'package:pointer_app/core/services/location_calc_service.dart';
import 'package:pointer_app/core/theme/app_text_styles.dart';
import 'package:pointer_app/core/utils/l10n_ext.dart';
import 'package:pointer_app/features/offline_pointer/widgets/compass_widget.dart';
import 'package:rxdart/rxdart.dart';

class OfflinePointerPage extends StatefulWidget {
  const OfflinePointerPage({super.key});

  @override
  State<OfflinePointerPage> createState() => _OfflinePointerPageState();
}

class _OfflinePointerPageState extends State<OfflinePointerPage> {
  static const _stillSpeedThreshold = 0.5;
  static const _movingInterval = Duration(milliseconds: 200);
  static const _stillInterval = Duration(seconds: 2);

  SavedLocation? _target;
  LocationCalcService? _calcService;
  StreamSubscription<PointerResult>? _sub;
  StreamSubscription<double>? _headingSub;

  double _angle = 0;
  double _distance = double.nan;
  double _heading = 0;

  @override
  void initState() {
    super.initState();
    _loadTarget();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _sub = null;
    _headingSub?.cancel();
    _headingSub = null;
    _calcService?.dispose();
    _calcService = null;
    super.dispose();
  }

  Future<void> _loadTarget() async {
    final box = await Hive.openBox<SavedLocation>('saved_locations');
    final values = box.values.toList(growable: false);
    if (values.isEmpty) return;
    _setTarget(values.last);
  }

  void _setTarget(SavedLocation target) {
    _sub?.cancel();
    _sub = null;
    _headingSub?.cancel();
    _headingSub = null;
    _calcService?.dispose();
    _calcService = null;

    final gpsRaw = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 0,
      ),
    );
    final gpsThrottled = _adaptiveThrottle(
      gpsRaw,
      movingInterval: _movingInterval,
      stillInterval: _stillInterval,
      stillSpeedThreshold: _stillSpeedThreshold,
    );

    final gpsStream = gpsThrottled.map<GpsPosition>(
      (pos) => (latitude: pos.latitude, longitude: pos.longitude),
    );

    final headingStream =
        FlutterCompass.events
            ?.map((e) => e.heading)
            .where((v) => v != null)
            .cast<double>() ??
        const Stream<double>.empty();
    final compassHeadingStream = Rx.concat<double>([
      Stream<double>.value(0.0),
      headingStream.map((v) => v.isFinite ? v : 0.0),
    ]).asBroadcastStream();

    final service = LocationCalcService(
      target: target,
      gpsStream: gpsStream,
      compassHeadingStream: compassHeadingStream,
    );

    _calcService = service;
    _sub = service.results.listen((result) {
      if (!mounted) return;
      setState(() {
        _angle = result.pointerAngle;
        _distance = result.distance;
      });
    });
    _headingSub = compassHeadingStream.listen((h) {
      if (!mounted) return;
      setState(() {
        _heading = h;
      });
    });

    setState(() {
      _target = target;
    });
  }

  Future<void> _addLocation() async {
    final loc = await context.push<SavedLocation>('/location-picker');
    if (!mounted) return;
    if (loc == null) return;
    _setTarget(loc);
  }

  @override
  Widget build(BuildContext context) {
    final target = _target;
    if (target == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.navigation, color: Colors.white, size: 46),
              const SizedBox(height: 12),
              Text(
                context.l10n.noTargetSelected,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xB3FFFFFF), fontSize: 14),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _addLocation,
                  child: Text(context.l10n.addLocation),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final isVisible = ModalRoute.of(context)?.isCurrent ?? true;
    final headingValue = ((_heading % 360) + 360) % 360;
    final headingInt = headingValue.round() % 360;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
      child: Column(
        children: [
          Column(
            children: [
              Text(
                '$headingInt°',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 44,
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _cardinal(headingValue),
                style: const TextStyle(
                  color: Color(0xB3FFFFFF),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: RepaintBoundary(
                  child: TickerMode(
                    enabled: isVisible,
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: CompassWidget(angle: _angle, isOnline: true),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          RepaintBoundary(
            child: _InfoPanel(
              targetName: target.name,
              distanceMeters: _distance,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Color(0x33FFFFFF)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _addLocation,
              child: Text(context.l10n.addLocation),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.targetName, required this.distanceMeters});

  final String targetName;
  final double distanceMeters;

  @override
  Widget build(BuildContext context) {
    final distanceText = _formatDistance(context, distanceMeters);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          targetName,
          style: AppTextStyles.bodySecondary.copyWith(
            color: const Color(0xB3FFFFFF),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        Text(
          distanceText,
          style: AppTextStyles.displayDistance.copyWith(
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  String _formatDistance(BuildContext context, double meters) {
    if (!meters.isFinite) return '--';
    if (meters < 1000) {
      return context.l10n.distanceUnit_m(meters.round());
    }
    return context.l10n.distanceUnit_km((meters / 1000).toStringAsFixed(2));
  }
}

String _cardinal(double heading) {
  const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
  final index = ((heading + 22.5) / 45).floor() % 8;
  return dirs[index];
}

Stream<Position> _adaptiveThrottle(
  Stream<Position> source, {
  required Duration movingInterval,
  required Duration stillInterval,
  required double stillSpeedThreshold,
}) {
  late final StreamController<Position> controller;
  StreamSubscription<Position>? sub;
  Timer? timer;
  bool canEmit = true;
  Position? pending;

  Duration intervalFor(Position p) {
    final speed = p.speed.isFinite ? p.speed : 0.0;
    return speed < stillSpeedThreshold ? stillInterval : movingInterval;
  }

  void emit(Position p) {
    controller.add(p);
    canEmit = false;
    timer?.cancel();
    timer = Timer(intervalFor(p), () {
      canEmit = true;
      final next = pending;
      pending = null;
      if (next != null) {
        emit(next);
      }
    });
  }

  controller = StreamController<Position>(
    sync: true,
    onListen: () {
      sub = source.listen(
        (p) {
          if (canEmit) {
            emit(p);
          } else {
            pending = p;
          }
        },
        onError: controller.addError,
        onDone: () {
          timer?.cancel();
          controller.close();
        },
      );
    },
    onCancel: () async {
      timer?.cancel();
      await sub?.cancel();
      sub = null;
    },
  );

  return controller.stream;
}
