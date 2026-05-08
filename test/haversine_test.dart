import 'package:flutter_test/flutter_test.dart';
import 'package:pointer_app/core/utils/haversine.dart';

void main() {
  test('calcDistance Beijing -> Shanghai is about 1068km (<=1% error)', () {
    const beijingLat = 39.9042;
    const beijingLon = 116.4074;
    const shanghaiLat = 31.2304;
    const shanghaiLon = 121.4737;

    final distanceMeters = calcDistance(
      beijingLat,
      beijingLon,
      shanghaiLat,
      shanghaiLon,
    );
    final distanceKm = distanceMeters / 1000.0;

    const expectedKm = 1068.0;
    final relativeError = (distanceKm - expectedKm).abs() / expectedKm;
    expect(relativeError, lessThanOrEqualTo(0.01));
  });

  test('calcBearing returns 0-360 degrees', () {
    final bearing = calcBearing(39.9042, 116.4074, 31.2304, 121.4737);
    expect(bearing, greaterThanOrEqualTo(0));
    expect(bearing, lessThan(360));
  });
}
