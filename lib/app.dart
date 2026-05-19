import 'package:flutter/material.dart';

import 'features/navigation_pointer/presentation/pointer_page.dart';

class PointerApp extends StatelessWidget {
  const PointerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pointer App',
      theme: ThemeData(useMaterial3: true),
      home: const PointerPage(),
    );
  }
}
