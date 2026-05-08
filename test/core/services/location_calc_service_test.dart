import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pointer_app/core/models/saved_location.dart';
import 'package:pointer_app/core/services/location_calc_service.dart';

void main() {
  test('mock GPS stream 和 compass stream，验证 pointerAngle 计算正确', () async {
    final gpsController = StreamController<GpsPosition>();
    final headingController = StreamController<double>();

    final service = LocationCalcService(
      target: SavedLocation(
        id: 't',
        name: 'target',
        latitude: 0,
        longitude: 1,
        createdAt: DateTime(2020),
      ),
      gpsStream: gpsController.stream,
      compassHeadingStream: headingController.stream,
    );

    final results = <PointerResult>[];
    final sub = service.results.listen(results.add);

    gpsController.add((latitude: 0, longitude: 0));
    headingController.add(30);
    await Future<void>.delayed(Duration.zero);

    expect(results, hasLength(1));
    expect(results.single.pointerAngle, closeTo(60, 1e-6));

    await sub.cancel();
    await gpsController.close();
    await headingController.close();
    service.dispose();
  });

  test('验证 Stream 在 dispose 后不再发出事件', () async {
    final gpsController = StreamController<GpsPosition>();
    final headingController = StreamController<double>();

    final service = LocationCalcService(
      target: SavedLocation(
        id: 't',
        name: 'target',
        latitude: 0,
        longitude: 1,
        createdAt: DateTime(2020),
      ),
      gpsStream: gpsController.stream,
      compassHeadingStream: headingController.stream,
    );

    var emissionCount = 0;
    final sub = service.results.listen((_) => emissionCount++);

    gpsController.add((latitude: 0, longitude: 0));
    headingController.add(0);
    await Future<void>.delayed(Duration.zero);
    expect(emissionCount, 1);

    service.dispose();

    gpsController.add((latitude: 0, longitude: 0));
    headingController.add(10);
    await Future<void>.delayed(Duration.zero);

    expect(emissionCount, 1);

    await sub.cancel();
    await gpsController.close();
    await headingController.close();
  });
}

