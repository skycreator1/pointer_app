import 'package:geolocator/geolocator.dart';

class LocationService {
  Stream<Position> positionStream() {
    return Geolocator.getPositionStream();
  }
}
