import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  final Map<Permission, StreamController<PermissionStatus>> _controllers = {};
  final Map<Permission, PermissionStatus> _lastStatus = {};
  final _observer = _PermissionLifecycleObserver();

  PermissionService() {
    _observer._onResumed = () async {
      for (final permission in _controllers.keys) {
        final status = await permission.status;
        final previous = _lastStatus[permission];
        if (previous != status) {
          _lastStatus[permission] = status;
          _controllers[permission]?.add(status);
        }
      }
    };
    WidgetsBinding.instance.addObserver(_observer);
  }

  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(_observer);
    for (final controller in _controllers.values) {
      await controller.close();
    }
    _controllers.clear();
    _lastStatus.clear();
  }

  Future<bool> checkAndRequest(Permission p) async {
    var status = await p.status;
    if (status.isGranted) {
      return true;
    }

    if (status.isPermanentlyDenied) {
      await openAppSettings();
      return false;
    }

    status = await p.request();
    if (status.isGranted) {
      return true;
    }

    if (status.isPermanentlyDenied) {
      await openAppSettings();
      return false;
    }

    return false;
  }

  Stream<PermissionStatus> watchStatus(Permission p) {
    final controller = _controllers.putIfAbsent(
      p,
      () => StreamController<PermissionStatus>.broadcast(),
    );

    p.status.then((status) {
      final previous = _lastStatus[p];
      if (previous != status) {
        _lastStatus[p] = status;
        if (!controller.isClosed) {
          controller.add(status);
        }
      }
    });

    return controller.stream;
  }
}

class PermissionGate extends StatefulWidget {
  const PermissionGate({
    super.key,
    required this.requiredPermissions,
    required this.child,
    this.title,
    this.description,
    this.buttonText = '前往授权',
  });

  final List<Permission> requiredPermissions;
  final Widget child;
  final String? title;
  final String? description;
  final String buttonText;

  @override
  State<PermissionGate> createState() => _PermissionGateState();
}

class _PermissionGateState extends State<PermissionGate> {
  late final PermissionService _service;
  final Map<Permission, PermissionStatus> _statuses = {};
  final List<StreamSubscription<PermissionStatus>> _subs = [];

  @override
  void initState() {
    super.initState();
    _service = PermissionService();
    for (final permission in widget.requiredPermissions) {
      _subs.add(
        _service.watchStatus(permission).listen((status) {
          if (!mounted) return;
          setState(() {
            _statuses[permission] = status;
          });
        }),
      );
    }
  }

  @override
  void didUpdateWidget(covariant PermissionGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_samePermissions(oldWidget.requiredPermissions, widget.requiredPermissions)) {
      for (final sub in _subs) {
        sub.cancel();
      }
      _subs.clear();
      _statuses.clear();
      for (final permission in widget.requiredPermissions) {
        _subs.add(
          _service.watchStatus(permission).listen((status) {
            if (!mounted) return;
            setState(() {
              _statuses[permission] = status;
            });
          }),
        );
      }
    }
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _subs.clear();
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final missing = _missingPermissions();
    if (missing.isEmpty) return widget.child;

    final title = widget.title ?? '需要权限';
    final description = widget.description ??
        '应用需要位置与通知权限以提供离线指针、后台定位与连接通知。请在系统设置中授予权限。';

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                description,
                style: const TextStyle(
                  color: Color(0xB3FFFFFF),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              ...missing.map(
                (p) => Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '• ${_permissionLabel(p)}',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    for (final p in missing) {
                      await _service.checkAndRequest(p);
                    }
                  },
                  child: Text(widget.buttonText),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  List<Permission> _missingPermissions() {
    final missing = <Permission>[];
    for (final p in widget.requiredPermissions) {
      final status = _statuses[p];
      if (status == null || !status.isGranted) {
        missing.add(p);
      }
    }
    return missing;
  }
}

class _PermissionLifecycleObserver extends WidgetsBindingObserver {
  Future<void> Function()? _onResumed;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _onResumed?.call();
    }
  }
}

bool _samePermissions(List<Permission> a, List<Permission> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

String _permissionLabel(Permission p) {
  if (p == Permission.locationWhenInUse) return '位置权限（使用期间）';
  if (p == Permission.locationAlways) return '位置权限（始终允许，用于后台）';
  if (p == Permission.notification) return '通知权限';
  return p.toString();
}

class PermissionPlatformHints {
  static const androidManifestPermissions = <String>[
    'android.permission.ACCESS_COARSE_LOCATION',
    'android.permission.ACCESS_FINE_LOCATION',
    'android.permission.ACCESS_BACKGROUND_LOCATION',
    'android.permission.FOREGROUND_SERVICE',
    'android.permission.FOREGROUND_SERVICE_LOCATION',
    'android.permission.POST_NOTIFICATIONS',
  ];

  static const iosInfoPlistKeys = <String>[
    'NSLocationWhenInUseUsageDescription',
    'NSLocationAlwaysAndWhenInUseUsageDescription',
    'NSLocationAlwaysUsageDescription',
  ];
}

