// Application entrypoint.
//
// Initializes local persistence (Hive) and starts the router-based UI.
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pointer_app/app_router.dart';
import 'package:pointer_app/core/models/invite_code.dart';
import 'package:pointer_app/core/models/paired_device.dart';
import 'package:pointer_app/core/models/saved_location.dart';
import 'package:pointer_app/core/theme/app_theme.dart';
import 'package:pointer_app/l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  _registerHiveAdapters();
  runApp(const _PointerApp());
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

class _PointerApp extends StatelessWidget {
  const _PointerApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      theme: AppTheme.darkTheme,
      routerConfig: appRouter,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
