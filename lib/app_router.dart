import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pointer_app/core/models/paired_device.dart';
import 'package:pointer_app/core/services/permission_service.dart';
import 'package:pointer_app/features/offline_pointer/view/location_picker_page.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const _StartupPage()),
    ShellRoute(
      builder: (context, state, child) {
        return _CompassShell(location: state.uri.toString(), child: child);
      },
      routes: [
        GoRoute(
          path: '/compass',
          redirect: (context, state) => '/compass/offline',
        ),
        GoRoute(
          path: '/compass/offline',
          builder: (context, state) => const _OfflinePointerPage(),
        ),
        GoRoute(
          path: '/compass/device',
          builder: (context, state) => const _DevicePointerPage(),
        ),
      ],
    ),
    GoRoute(
      path: '/connect',
      builder: (context, state) => const _ConnectPage(),
      routes: [
        GoRoute(
          path: 'waiting',
          builder: (context, state) => const _ConnectWaitingPage(),
        ),
      ],
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const _SettingsPage(),
    ),
    GoRoute(
      path: '/location-picker',
      builder: (context, state) =>
          const LocationPickerPage(amapKey: '5e7d9c70381f2465d505ff9f0ce8129f'),
    ),
  ],
);

class _StartupPage extends StatefulWidget {
  const _StartupPage();

  @override
  State<_StartupPage> createState() => _StartupPageState();
}

class _StartupPageState extends State<_StartupPage> {
  late final Future<String> _initialRouteFuture = _decideInitialRoute();
  late final PermissionService _permissionService = PermissionService();

  @override
  Widget build(BuildContext context) {
    return PermissionGate(
      service: _permissionService,
      requiredPermissions: const [Permission.locationWhenInUse],
      child: Scaffold(
        backgroundColor: Colors.black,
        body: FutureBuilder<String>(
          future: _initialRouteFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done &&
                snapshot.hasData) {
              final path = snapshot.data;
              if (path == null) return const SizedBox.shrink();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                context.go(path);
              });
            }

            return const SafeArea(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _AppLogo(),
                    SizedBox(height: 16),
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<String> _decideInitialRoute() async {
    final box = await Hive.openBox<PairedDevice>('paired_devices');
    final hasPaired = box.values.isNotEmpty;
    return hasPaired ? '/compass/offline' : '/connect';
  }
}

class _CompassShell extends StatelessWidget {
  const _CompassShell({required this.child, required this.location});

  final Widget child;
  final String location;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = location.startsWith('/compass/device') ? 1 : 0;
    final platform = Theme.of(context).platform;
    final isCupertino = platform == TargetPlatform.iOS;

    if (isCupertino) {
      return CupertinoPageScaffold(
        backgroundColor: CupertinoColors.black,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(child: child),
              CupertinoTabBar(
                backgroundColor: const Color(0xCC000000),
                activeColor: CupertinoColors.white,
                inactiveColor: const Color(0x99FFFFFF),
                currentIndex: selectedIndex,
                onTap: (index) {
                  if (index == 0) context.go('/compass/offline');
                  if (index == 1) context.go('/compass/device');
                },
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(CupertinoIcons.location),
                    label: '离线指针',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(CupertinoIcons.antenna_radiowaves_left_right),
                    label: '设备指针',
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        backgroundColor: const Color(0xFF0B0B0D),
        selectedItemColor: Colors.white,
        unselectedItemColor: const Color(0x99FFFFFF),
        onTap: (index) {
          if (index == 0) context.go('/compass/offline');
          if (index == 1) context.go('/compass/device');
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: '离线指针'),
          BottomNavigationBarItem(icon: Icon(Icons.devices), label: '设备指针'),
        ],
      ),
    );
  }
}

class _AppLogo extends StatelessWidget {
  const _AppLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0x33FFFFFF)),
      ),
      child: const Center(
        child: Icon(Icons.navigation, color: Colors.white, size: 36),
      ),
    );
  }
}

class _OfflinePointerPage extends StatelessWidget {
  const _OfflinePointerPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Text('离线地点指针', style: TextStyle(color: Colors.white)),
        ),
      ),
    );
  }
}

class _DevicePointerPage extends StatelessWidget {
  const _DevicePointerPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Text('设备连接指针', style: TextStyle(color: Colors.white)),
        ),
      ),
    );
  }
}

class _ConnectPage extends StatelessWidget {
  const _ConnectPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('连接设备'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '输入邀请码',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 12),
            TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'XXXXXXXX',
                hintStyle: const TextStyle(color: Color(0x77FFFFFF)),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Color(0xFF2A2A2E)),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.white),
                  borderRadius: BorderRadius.circular(12),
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
                onPressed: () => context.go('/connect/waiting'),
                child: const Text('发送请求'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectWaitingPage extends StatelessWidget {
  const _ConnectWaitingPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('等待同意'),
      ),
      body: const SafeArea(child: Center(child: _PulseDot())),
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot();

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_controller.value);
        final size = 18.0 + 22.0 * t;
        final opacity = 0.25 + 0.55 * t;
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: opacity),
          ),
        );
      },
    );
  }
}

class _SettingsPage extends StatelessWidget {
  const _SettingsPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Text('设置', style: TextStyle(color: Colors.white)),
        ),
      ),
    );
  }
}
