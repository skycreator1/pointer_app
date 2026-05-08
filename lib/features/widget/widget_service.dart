import 'dart:async';

import 'package:home_widget/home_widget.dart';
import 'package:pointer_app/core/services/location_calc_service.dart';

class WidgetService {
  StreamSubscription<PointerResult>? _subscription;
  bool _disposed = false;

  Future<void> bindPointerResults(Stream<PointerResult> results) async {
    if (_disposed) return;
    await _subscription?.cancel();
    _subscription = results.listen((result) {
      if (_disposed) return;
      unawaited(_write(result));
    });
  }

  Future<void> dispose() async {
    _disposed = true;
    await _subscription?.cancel();
    _subscription = null;
  }

  Future<void> _write(PointerResult result) async {
    if (_disposed) return;
    await HomeWidget.saveWidgetData<double>(
      'pointer_angle',
      result.pointerAngle,
    );
    await HomeWidget.saveWidgetData<String>(
      'peer_distance',
      _formatDistance(result.distance),
    );

    await HomeWidget.updateWidget(name: 'PointerWidget');
  }
}

String _formatDistance(double meters) {
  if (!meters.isFinite) return '--';
  if (meters < 1000) return '${meters.round()} m';
  final km = meters / 1000.0;
  return '${km.toStringAsFixed(1)} km';
}
