import 'package:flutter_compass/flutter_compass.dart';

class CompassService {
  Stream<CompassEvent> headingStream() {
    return FlutterCompass.events ?? const Stream.empty();
  }
}
