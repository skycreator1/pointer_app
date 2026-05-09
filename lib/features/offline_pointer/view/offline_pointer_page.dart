import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:pointer_app/core/models/saved_location.dart';
import 'package:pointer_app/core/services/location_calc_service.dart';
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

  static const _prefsBoxName = 'app_prefs';
  static const _prefCurrentTargetId = 'currentTargetId';

  SavedLocation? _target;
  LocationCalcService? _calcService;
  StreamSubscription<PointerResult>? _sub;
  StreamSubscription<double>? _headingSub;

  double _angle = 0;
  double _distance = double.nan;
  double _heading = 0;
  LocationAccuracy _gpsAccuracy = LocationAccuracy.high;

  @override
  void initState() {
    super.initState();
    _loadTarget();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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
    if (!mounted) return;
    final box = await Hive.openBox<SavedLocation>('saved_locations');
    final prefs = await Hive.openBox(_prefsBoxName);
    final selectedId = prefs.get(_prefCurrentTargetId)?.toString();
    final accuracyPref = prefs.get('locationAccuracy')?.toString();
    _gpsAccuracy = accuracyPref == 'saving'
        ? LocationAccuracy.medium
        : LocationAccuracy.high;

    SavedLocation? selected;
    if (selectedId != null && selectedId.isNotEmpty) {
      final byKey = box.get(selectedId);
      if (byKey != null) {
        selected = byKey;
      } else {
        for (final v in box.values) {
          if (v.id == selectedId) {
            selected = v;
            break;
          }
        }
      }
    }

    if (!mounted) return;
    if (selected != null) {
      _setTarget(selected);
      return;
    }
    if (selectedId != null && selectedId.isNotEmpty) {
      await prefs.delete(_prefCurrentTargetId);
    }
    _setCompassOnly();
  }

  void _setTarget(SavedLocation target) {
    _sub?.cancel();
    _sub = null;
    _headingSub?.cancel();
    _headingSub = null;
    _calcService?.dispose();
    _calcService = null;

    final gpsRaw = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: _gpsAccuracy,
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

    final compassHeadingStream = _compassHeadingStream();

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

  void _setCompassOnly() {
    _sub?.cancel();
    _sub = null;
    _headingSub?.cancel();
    _headingSub = null;
    _calcService?.dispose();
    _calcService = null;

    final compassHeadingStream = _compassHeadingStream();
    _headingSub = compassHeadingStream.listen((h) {
      if (!mounted) return;
      setState(() {
        _heading = h;
        _angle = _normalizeDegrees(-h);
      });
    });

    setState(() {
      _target = null;
      _distance = double.nan;
      _angle = _normalizeDegrees(-_heading);
    });
  }

  Stream<double> _compassHeadingStream() {
    final headingStream =
        FlutterCompass.events
            ?.map((e) => e.heading)
            .where((v) => v != null)
            .cast<double>() ??
        const Stream<double>.empty();
    return Rx.concat<double>([
      Stream<double>.value(0.0),
      headingStream.map((v) => v.isFinite ? v : 0.0),
    ]).asBroadcastStream();
  }

  Future<void> _addLocation() async {
    final loc = await context.push<SavedLocation>('/location-picker');
    if (!mounted) return;
    if (loc == null) return;
    final prefs = await Hive.openBox(_prefsBoxName);
    await prefs.put(_prefCurrentTargetId, loc.id);
    _setTarget(loc);
  }

  @override
  Widget build(BuildContext context) {
    final target = _target;
    if (target == null) {
      final isVisible = ModalRoute.of(context)?.isCurrent ?? true;
      final headingValue = ((_heading % 360) + 360) % 360;
      final headingInt = headingValue.round() % 360;
      return _PointerScaffold(
        title: '指南针',
        subtitle: '未选择目标',
        onMore: _openMoreMenu,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
          child: Column(
            children: [
              const SizedBox(height: 6),
              Text(
                '$headingInt°',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 42,
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
              const SizedBox(height: 6),
              const Text(
                '指南针',
                style: TextStyle(
                  color: Color(0x99FFFFFF),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
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

    final distanceText = _formatDistanceValue(_distance);
    final unitText = _formatDistanceUnit(_distance);

    return _PointerScaffold(
      title: target.name,
      subtitle: '固定地点',
      onMore: _openMoreMenu,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
        child: Column(
          children: [
            const SizedBox(height: 6),
            Text(
              '$headingInt°',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 42,
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
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  distanceText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 44,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    unitText,
                    style: const TextStyle(
                      color: Color(0xB3FFFFFF),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              '指针 · 追踪中',
              style: TextStyle(
                color: Color(0x99FFFFFF),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openMoreMenu() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF0F1117),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SheetItem(
                  icon: Icons.place_outlined,
                  title: '固定地点',
                  onTap: () => Navigator.of(context).pop('places'),
                ),
                _SheetItem(
                  icon: Icons.add_location_alt_outlined,
                  title: '添加地点',
                  onTap: () => Navigator.of(context).pop('add'),
                ),
                _SheetItem(
                  icon: Icons.settings_outlined,
                  title: '设置',
                  onTap: () => Navigator.of(context).pop('settings'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted) return;
    if (action == 'places') context.go('/connect');
    if (action == 'add') unawaited(_addLocation());
    if (action == 'settings') context.go('/settings');
  }
}

String _cardinal(double heading) {
  const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
  final index = ((heading + 22.5) / 45).floor() % 8;
  return dirs[index];
}

String _formatDistanceValue(double meters) {
  if (!meters.isFinite) return '--';
  if (meters < 1000) return meters.round().toString();
  return (meters / 1000).toStringAsFixed(2);
}

String _formatDistanceUnit(double meters) {
  if (!meters.isFinite) return '';
  return meters < 1000 ? 'm' : 'km';
}

double _normalizeDegrees(double degrees) {
  if (!degrees.isFinite) return 0;
  final normalized = degrees % 360;
  if (normalized < 0) return normalized + 360;
  return normalized;
}

class _PointerScaffold extends StatelessWidget {
  const _PointerScaffold({
    required this.title,
    required this.subtitle,
    required this.onMore,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Future<void> Function() onMore;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.8),
            radius: 1.2,
            colors: [Color(0x221D4ED8), Color(0x00000000)],
            stops: [0.0, 0.86],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              color: Color(0x99FFFFFF),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: IconButton(
                        onPressed: onMore,
                        icon: const Icon(Icons.more_horiz, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetItem extends StatelessWidget {
  const _SheetItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      onTap: onTap,
    );
  }
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
