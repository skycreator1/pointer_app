import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pointer_app/app_router.dart';
import 'package:pointer_app/core/services/background_service.dart';
import 'package:pointer_app/core/services/notification_service.dart';
import 'package:pointer_app/core/models/invite_code.dart';
import 'package:pointer_app/core/models/paired_device.dart';
import 'package:pointer_app/core/models/saved_location.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  _registerHiveAdapters();

  await initBackgroundService();
  final notificationService = NotificationService();
  await notificationService.init();

  runApp(const PointerApp());
}

class PointerApp extends StatelessWidget {
  const PointerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
    );
  }
}

void _registerHiveAdapters() {
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(SavedLocationAdapter());
  }
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(PairedDeviceAdapter());
  }
  if (!Hive.isAdapterRegistered(2)) {
    Hive.registerAdapter(InviteCodeAdapter());
  }
  if (!Hive.isAdapterRegistered(3)) {
    Hive.registerAdapter(InviteCodeRefreshModeAdapter());
  }
}
