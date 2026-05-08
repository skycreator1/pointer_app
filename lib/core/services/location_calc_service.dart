import 'package:pointer_app/core/models/saved_location.dart';
import 'package:pointer_app/core/utils/haversine.dart';
import 'package:rxdart/rxdart.dart';

typedef GpsPosition = ({double latitude, double longitude});

class PointerResult {
  const PointerResult({required this.distance, required this.pointerAngle});

  final double distance;
  final double pointerAngle;
}

class LocationCalcService {
  LocationCalcService({
    required SavedLocation target,
    required Stream<GpsPosition> gpsStream,
    required Stream<double> compassHeadingStream,
  }) : _targetSubject = BehaviorSubject<SavedLocation>.seeded(target) {
    _results =
        Rx.combineLatest3<SavedLocation, GpsPosition, double, PointerResult>(
          _targetSubject.stream,
          gpsStream,
          compassHeadingStream,
          (target, gps, heading) {
            final distance = calcDistance(
              gps.latitude,
              gps.longitude,
              target.latitude,
              target.longitude,
            );

            final bearing = calcBearing(
              gps.latitude,
              gps.longitude,
              target.latitude,
              target.longitude,
            );

            final headingSafe = heading.isFinite ? heading : 0.0;
            final pointerAngle = _normalizeDegrees(bearing - headingSafe);

            return PointerResult(
              distance: distance,
              pointerAngle: pointerAngle,
            );
          },
        ).asBroadcastStream();
  }

  final BehaviorSubject<SavedLocation> _targetSubject;
  late final Stream<PointerResult> _results;

  Stream<PointerResult> get results => _results;

  void setTarget(SavedLocation target) {
    _targetSubject.add(target);
  }

  SavedLocation get target => _targetSubject.value;

  void dispose() {
    _targetSubject.close();
  }
}

double _normalizeDegrees(double degrees) {
  final normalized = degrees % 360;
  if (normalized < 0) return normalized + 360;
  return normalized;
}
