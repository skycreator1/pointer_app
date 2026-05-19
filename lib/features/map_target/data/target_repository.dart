import '../domain/target_point.dart';

class TargetRepository {
  TargetPoint? _current;

  TargetPoint? get current => _current;

  void save(TargetPoint point) {
    _current = point;
  }
}
