import 'dart:math' as math;

import 'package:flutter/material.dart';

class PointerCompassWidget extends StatelessWidget {
  const PointerCompassWidget({super.key, required this.rotationDegrees});

  final double rotationDegrees;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotationDegrees * math.pi / 180,
      child: const Icon(Icons.navigation, size: 96),
    );
  }
}
