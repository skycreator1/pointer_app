import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pointer_app/app_router.dart';
import 'package:pointer_app/core/services/background_service.dart';
import 'package:pointer_app/core/services/notification_service.dart';
import 'package:pointer_app/core/theme/app_theme.dart';
import 'package:pointer_app/l10n/app_localizations.dart';
import 'package:pointer_app/core/models/invite_code.dart';
import 'package:pointer_app/core/models/paired_device.dart';
import 'package:pointer_app/core/models/saved_location.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  _registerHiveAdapters();

  runApp(const PointerApp());

  unawaited(_startServices());
}

Future<void> _startServices() async {
  final prefs = await Hive.openBox('app_prefs');
  final backgroundEnabledValue = prefs.get('backgroundEnabled');
  final backgroundEnabled = backgroundEnabledValue is bool
      ? backgroundEnabledValue
      : true;
  if (backgroundEnabledValue == null) {
    await prefs.put('backgroundEnabled', backgroundEnabled);
  }

  try {
    if (backgroundEnabled) {
      await initBackgroundService();
      final serverUriString = prefs.get('serverUri')?.toString();
      final myUserId = prefs.get('myUserId')?.toString();
      if (serverUriString != null &&
          serverUriString.isNotEmpty &&
          myUserId != null &&
          myUserId.isNotEmpty) {
        final service = FlutterBackgroundService();
        service.invoke('configure', <String, dynamic>{
          'serverUri': serverUriString,
          'myUserId': myUserId,
        });
      }
    }
  } catch (_) {}

  try {
    final notificationService = NotificationService();
    await notificationService.init();
  } catch (_) {}
}

class PointerApp extends StatelessWidget {
  const PointerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
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
