import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';

class GeoMath {
  static double distanceMeters({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }

  static double bearingDegrees({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) {
    final double lat1 = _toRadians(startLat);
    final double lat2 = _toRadians(endLat);
    final double dLon = _toRadians(endLng - startLng);

    final double y = math.sin(dLon) * math.cos(lat2);
    final double x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    final double bearing = _toDegrees(math.atan2(y, x));
    return (bearing + 360) % 360;
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180.0;
  static double _toDegrees(double radians) => radians * 180.0 / math.pi;
}
