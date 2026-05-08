import 'package:flutter_test/flutter_test.dart';
import 'package:pointer_app/core/utils/haversine.dart';

void main() {
  test('北京(39.9,116.4) → 上海(31.2,121.5) 距离约1068km ±1%', () {
    final meters = calcDistance(39.9, 116.4, 31.2, 121.5);
    expect(meters, closeTo(1068e3, 1068e3 * 0.01));
  });

  test('同一点距离为0', () {
    final meters = calcDistance(10, 20, 10, 20);
    expect(meters, closeTo(0, 1e-9));
  });

  test('正北方位角为0，正东为90', () {
    final north = calcBearing(0, 0, 1, 0);
    final east = calcBearing(0, 0, 0, 1);
    expect(north, closeTo(0, 1e-6));
    expect(east, closeTo(90, 1e-6));
  });
}

