import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pointer_app/core/services/permission_service.dart';
import 'package:pointer_app/core/theme/app_theme.dart';
import 'package:pointer_app/features/offline_pointer/view/offline_pointer_page.dart';
import 'package:pointer_app/features/offline_pointer/view/location_picker_page.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/compass/offline',
  routes: [
    ShellRoute(
      builder: (context, state, child) {
        return _RootShell(location: state.uri.toString(), child: child);
      },
      routes: [
        ShellRoute(
          builder: (context, state, child) {
            return Theme(
              data: AppTheme.darkTheme,
              child: _CompassSectionShell(
                location: state.uri.toString(),
                child: child,
              ),
            );
          },
          routes: [
            GoRoute(
              path: '/compass',
              redirect: (context, state) => '/compass/offline',
            ),
            GoRoute(
              path: '/compass/offline',
              builder: (context, state) => const OfflinePointerPage(),
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
      ],
    ),
    GoRoute(
      path: '/location-picker',
      builder: (context, state) =>
          const LocationPickerPage(amapKey: '5e7d9c70381f2465d505ff9f0ce8129f'),
    ),
  ],
);

class _RootShell extends StatelessWidget {
  const _RootShell({required this.child, required this.location});

  final Widget child;
  final String location;

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    final isCupertino = platform == TargetPlatform.iOS;
    final selectedIndex = location.startsWith('/connect')
        ? 1
        : location.startsWith('/settings')
        ? 2
        : 0;

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
                  if (index == 1) context.go('/connect');
                  if (index == 2) context.go('/settings');
                },
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(CupertinoIcons.location),
                    label: '指针',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(CupertinoIcons.link),
                    label: '连接',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(CupertinoIcons.settings),
                    label: '设置',
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
          if (index == 1) context.go('/connect');
          if (index == 2) context.go('/settings');
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: '指针'),
          BottomNavigationBarItem(icon: Icon(Icons.link), label: '连接'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: '设置'),
        ],
      ),
    );
  }
}

class _CompassSectionShell extends StatefulWidget {
  const _CompassSectionShell({required this.child, required this.location});

  final Widget child;
  final String location;

  @override
  State<_CompassSectionShell> createState() => _CompassSectionShellState();
}

class _CompassSectionShellState extends State<_CompassSectionShell> {
  late final PermissionService _permissionService = PermissionService();

  @override
  void dispose() {
    unawaited(_permissionService.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDevice = widget.location.startsWith('/compass/device');
    final platform = Theme.of(context).platform;
    final isCupertino = platform == TargetPlatform.iOS;

    return PermissionGate(
      service: _permissionService,
      requiredPermissions: const [Permission.locationWhenInUse],
      title: '需要位置权限',
      description: '指针功能需要定位与传感器权限来计算目标方位与距离。',
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.65),
              radius: 1.15,
              colors: [Color(0x331D4ED8), Color(0x00000000)],
              stops: [0.0, 0.85],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                  child: Row(
                    children: [
                      const SizedBox(width: 44),
                      Expanded(
                        child: Text(
                          '指南针',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: IconButton(
                          onPressed: () => context.push('/location-picker'),
                          icon: const Icon(
                            Icons.add_location_alt_outlined,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _SegmentedControl(
                    isCupertino: isCupertino,
                    selectedIndex: isDevice ? 1 : 0,
                    onTap: (index) {
                      if (index == 0) context.go('/compass/offline');
                      if (index == 1) context.go('/compass/device');
                    },
                    labels: const ['离线指针', '设备指针'],
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(child: widget.child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SegmentedControl extends StatelessWidget {
  const _SegmentedControl({
    required this.isCupertino,
    required this.selectedIndex,
    required this.onTap,
    required this.labels,
  });

  final bool isCupertino;
  final int selectedIndex;
  final void Function(int index) onTap;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    if (isCupertino) {
      return CupertinoSlidingSegmentedControl<int>(
        groupValue: selectedIndex,
        children: {
          for (var i = 0; i < labels.length; i++)
            i: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(labels[i], style: const TextStyle(fontSize: 13)),
            ),
        },
        onValueChanged: (v) {
          if (v == null) return;
          onTap(v);
        },
      );
    }

    return Container(
      height: 40,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF121217),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x1AFFFFFF)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onTap(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  decoration: BoxDecoration(
                    color: selectedIndex == i
                        ? const Color(0xFF2A2A2E)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      color: selectedIndex == i
                          ? Colors.white
                          : const Color(0xB3FFFFFF),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DevicePointerPage extends StatelessWidget {
  const _DevicePointerPage();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('设备连接指针', style: TextStyle(color: Colors.white)),
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
