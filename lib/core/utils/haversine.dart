import 'dart:math';

double calcDistance(double lat1, double lon1, double lat2, double lon2) {
  const earthRadiusMeters = 6371000.0;

  final phi1 = _degToRad(lat1);
  final phi2 = _degToRad(lat2);
  final deltaPhi = _degToRad(lat2 - lat1);
  final deltaLambda = _degToRad(lon2 - lon1);

  final sinDeltaPhi = sin(deltaPhi / 2);
  final sinDeltaLambda = sin(deltaLambda / 2);

  final a =
      sinDeltaPhi * sinDeltaPhi +
      cos(phi1) * cos(phi2) * sinDeltaLambda * sinDeltaLambda;
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return earthRadiusMeters * c;
}

double calcBearing(double lat1, double lon1, double lat2, double lon2) {
  final phi1 = _degToRad(lat1);
  final phi2 = _degToRad(lat2);
  final deltaLambda = _degToRad(lon2 - lon1);

  final y = sin(deltaLambda) * cos(phi2);
  final x =
      cos(phi1) * sin(phi2) - sin(phi1) * cos(phi2) * cos(deltaLambda);

  final theta = atan2(y, x);
  final bearingDeg = (_radToDeg(theta) + 360) % 360;
  return bearingDeg;
}

double _degToRad(double deg) => deg * (pi / 180.0);

double _radToDeg(double rad) => rad * (180.0 / pi);
