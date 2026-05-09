import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive/hive.dart';
import 'package:pointer_app/core/models/invite_code.dart';
import 'package:pointer_app/core/models/paired_device.dart';
import 'package:pointer_app/core/models/saved_location.dart';
import 'package:pointer_app/core/services/background_service.dart';
import 'package:pointer_app/core/services/connection_service.dart';
import 'package:pointer_app/core/theme/app_theme.dart';
import 'package:pointer_app/core/utils/haversine.dart';
import 'package:pointer_app/core/utils/invite_code_gen.dart';
import 'package:pointer_app/features/offline_pointer/view/offline_pointer_page.dart';
import 'package:pointer_app/features/offline_pointer/view/location_picker_page.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/pointer',
  routes: [
    ShellRoute(
      builder: (context, state, child) {
        return _RootShell(location: state.uri.toString(), child: child);
      },
      routes: [
        GoRoute(path: '/', redirect: (context, state) => '/pointer'),
        GoRoute(
          path: '/pointer',
          builder: (context, state) => Theme(
            data: AppTheme.darkTheme,
            child: const OfflinePointerPage(),
          ),
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
          const LocationPickerPage(amapKey: 'bfc214ef010237257a892c500fe0ffe2'),
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
                  if (index == 0) context.go('/pointer');
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
          if (index == 0) context.go('/pointer');
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

class _ConnectPage extends StatelessWidget {
  const _ConnectPage();

  @override
  Widget build(BuildContext context) {
    return const _ConnectHome();
  }
}

class _ConnectHome extends StatefulWidget {
  const _ConnectHome();

  @override
  State<_ConnectHome> createState() => _ConnectHomeState();
}

class _ConnectHomeState extends State<_ConnectHome> {
  int _segmentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    final isCupertino = platform == TargetPlatform.iOS;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '连接',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: IconButton(
                      onPressed: () => context.go('/settings'),
                      icon: const Icon(Icons.settings, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _Segmented(
                isCupertino: isCupertino,
                selectedIndex: _segmentIndex,
                labels: const ['固定地点', '社交连接'],
                onTap: (i) => setState(() => _segmentIndex = i),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _segmentIndex == 0
                    ? const _FixedPlacesPane(key: ValueKey('fixed'))
                    : const _SocialConnectPane(key: ValueKey('social')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FixedPlacesPane extends StatefulWidget {
  const _FixedPlacesPane({super.key});

  @override
  State<_FixedPlacesPane> createState() => _FixedPlacesPaneState();
}

class _FixedPlacesPaneState extends State<_FixedPlacesPane> {
  static const _prefCurrentTargetId = 'currentTargetId';

  late final Future<void> _initFuture = _init();
  Position? _pos;
  List<SavedLocation> _places = const [];
  String? _currentTargetId;

  Future<void> _init() async {
    Position? pos;
    try {
      pos = await Geolocator.getLastKnownPosition();
      pos ??= await Geolocator.getCurrentPosition();
    } catch (_) {}

    final box = await Hive.openBox<SavedLocation>('saved_locations');
    final prefs = await _openPrefsBox();
    final currentTargetId = prefs.get(_prefCurrentTargetId)?.toString();

    if (!mounted) return;
    setState(() {
      _pos = pos;
      _places = box.values
          .toList(growable: false)
          .reversed
          .toList(growable: false);
      _currentTargetId = currentTargetId;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snapshot) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          children: [
            const Text(
              '已保存地点',
              style: TextStyle(
                color: Color(0x99FFFFFF),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            ..._places.map(
              (p) => _PlaceRow(
                place: p,
                distanceMeters: _pos == null
                    ? null
                    : calcDistance(
                        _pos!.latitude,
                        _pos!.longitude,
                        p.latitude,
                        p.longitude,
                      ),
                selected: _currentTargetId == p.id,
                onTap: () => _selectPlace(p),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0x33FFFFFF)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => _addLocation(context),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, size: 18),
                    SizedBox(width: 8),
                    Text('添加新地点'),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _selectPlace(SavedLocation p) async {
    final prefs = await _openPrefsBox();
    await prefs.put(_prefCurrentTargetId, p.id);
    setState(() => _currentTargetId = p.id);
    await _invokeSetTarget(p);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已添加该地点：${p.name}'),
        backgroundColor: const Color(0xFF1C1C1E),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _addLocation(BuildContext context) async {
    final router = GoRouter.of(context);
    final loc = await router.push<SavedLocation>('/location-picker');
    if (!mounted) return;
    if (loc == null) return;
    await _selectPlace(loc);
    await _refreshPlaces();
  }

  Future<void> _refreshPlaces() async {
    final box = await Hive.openBox<SavedLocation>('saved_locations');
    if (!mounted) return;
    setState(() {
      _places = box.values
          .toList(growable: false)
          .reversed
          .toList(growable: false);
    });
  }
}

class _PlaceRow extends StatelessWidget {
  const _PlaceRow({
    required this.place,
    required this.distanceMeters,
    required this.selected,
    required this.onTap,
  });

  final SavedLocation place;
  final double? distanceMeters;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = distanceMeters == null
        ? '—'
        : distanceMeters! < 1000
        ? '${distanceMeters!.round()} m'
        : '${(distanceMeters! / 1000).toStringAsFixed(1)} km';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: const Color(0xFF121217),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected
                        ? const Color(0x33FFFFFF)
                        : const Color(0x1AFFFFFF),
                    border: Border.all(color: const Color(0x1AFFFFFF)),
                  ),
                  child: Icon(
                    Icons.place,
                    size: 16,
                    color: selected ? Colors.white : const Color(0x99FFFFFF),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Color(0x99FFFFFF),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  selected ? Icons.check_circle : Icons.chevron_right,
                  color: selected
                      ? const Color(0xFF30D158)
                      : const Color(0x66FFFFFF),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SocialConnectPane extends StatefulWidget {
  const _SocialConnectPane({super.key});

  @override
  State<_SocialConnectPane> createState() => _SocialConnectPaneState();
}

class _SocialConnectPaneState extends State<_SocialConnectPane> {
  static const _inviteBoxName = 'invite_code';
  static const _inviteKey = 'current';
  static const _prefServerUri = 'serverUri';

  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocus = FocusNode();

  Timer? _ticker;
  InviteCode? _inviteCode;
  List<PairedDevice> _paired = const [];
  bool _connecting = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _ticker = null;
    _inputController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final invite = _inviteCode;
    final inviteText = invite?.code ?? '--------';
    final inviteMeta = invite == null
        ? '未生成'
        : invite.refreshMode == InviteCodeRefreshMode.daily
        ? '今日有效 · 剩余 ${_formatRemain(invite.expiresAt)}'
        : '手动刷新';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        const Text(
          '我的邀请码',
          style: TextStyle(
            color: Color(0x99FFFFFF),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        _InviteCard(
          code: inviteText,
          meta: inviteMeta,
          onCopy: invite == null ? null : () => _copy(invite.code),
          onRefresh: () => _refreshInvite(),
        ),
        const SizedBox(height: 16),
        const Text(
          '输入对方邀请码',
          style: TextStyle(
            color: Color(0x99FFFFFF),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        _InviteCodeInput(
          controller: _inputController,
          focusNode: _inputFocus,
          enabled: !_connecting,
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: _connecting ? null : () => _connect(),
            child: Text(_connecting ? '连接中…' : '连接'),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          '已配对',
          style: TextStyle(
            color: Color(0x99FFFFFF),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        ..._paired.map((d) => _PairedRow(device: d)),
      ],
    );
  }

  Future<void> _load() async {
    final prefs = await _openPrefsBox();
    await _getOrCreateMyUserId(prefs);

    final inviteBox = await Hive.openBox<InviteCode>(_inviteBoxName);
    final invite = inviteBox.get(_inviteKey);

    final devicesBox = await Hive.openBox<PairedDevice>('paired_devices');
    final paired = devicesBox.values
        .toList(growable: false)
        .reversed
        .toList(growable: false);

    if (!mounted) return;
    setState(() {
      _inviteCode = invite;
      _paired = paired;
    });

    if (invite == null) {
      await _refreshInvite();
    }
  }

  Future<void> _refreshInvite() async {
    final prefs = await _openPrefsBox();
    final myUserId = await _getOrCreateMyUserId(prefs);

    final now = DateTime.now();
    final expiresAt = _endOfDay(now);
    final code = generateCode(myUserId, InviteCodeRefreshMode.daily);
    final invite = InviteCode(
      code: code,
      refreshMode: InviteCodeRefreshMode.daily,
      generatedAt: now,
      expiresAt: expiresAt,
    );

    final inviteBox = await Hive.openBox<InviteCode>(_inviteBoxName);
    await inviteBox.put(_inviteKey, invite);

    if (!mounted) return;
    setState(() => _inviteCode = invite);
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已复制'),
        backgroundColor: Color(0xFF1C1C1E),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<void> _connect() async {
    final input = _inputController.text.trim().toUpperCase();
    final cleaned = input.replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (cleaned.length != 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('邀请码需为 8 位'),
          backgroundColor: Color(0xFF1C1C1E),
        ),
      );
      return;
    }

    final prefs = await _openPrefsBox();
    final serverUriString = prefs.get(_prefServerUri)?.toString();
    final serverUri = serverUriString == null
        ? null
        : Uri.tryParse(serverUriString);
    if (serverUri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('未配置服务器地址，请先到设置填写'),
          backgroundColor: Color(0xFF1C1C1E),
        ),
      );
      return;
    }

    final myUserId = await _getOrCreateMyUserId(prefs);

    setState(() => _connecting = true);
    try {
      final service = ConnectionService(
        serverUri: serverUri,
        myUserId: myUserId,
      );
      await service.connectAndWait(
        cleaned,
        timeout: const Duration(seconds: 20),
      );
      await service.dispose();

      final connectionBox = await Hive.openBox<String>('connection');
      final pairId = connectionBox.get('pairId') ?? '';
      if (pairId.isNotEmpty) {
        final devicesBox = await Hive.openBox<PairedDevice>('paired_devices');
        final device = PairedDevice(
          pairId: pairId,
          nickname: '已配对设备',
          inviteCode: cleaned,
          lastSeen: DateTime.now(),
          isOnline: true,
        );
        await devicesBox.put(pairId, device);
      }
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('连接失败，请检查网络或服务器'),
          backgroundColor: Color(0xFF1C1C1E),
        ),
      );
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({
    required this.code,
    required this.meta,
    required this.onCopy,
    required this.onRefresh,
  });

  final String code;
  final String meta;
  final VoidCallback? onCopy;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF121217),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x1AFFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _formatCode(code),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            meta,
            style: const TextStyle(
              color: Color(0x99FFFFFF),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0x33FFFFFF)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: onCopy,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.copy, size: 16),
                      SizedBox(width: 8),
                      Text('复制'),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0x33FFFFFF)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: onRefresh,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.refresh, size: 16),
                      SizedBox(width: 8),
                      Text('刷新'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InviteCodeInput extends StatefulWidget {
  const _InviteCodeInput({
    required this.controller,
    required this.focusNode,
    required this.enabled,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;

  @override
  State<_InviteCodeInput> createState() => _InviteCodeInputState();
}

class _InviteCodeInputState extends State<_InviteCodeInput> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    widget.focusNode.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(covariant _InviteCodeInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onChanged);
      widget.focusNode.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    widget.focusNode.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final raw = widget.controller.text.toUpperCase();
    final text = raw.replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (text != raw) {
      final selection = widget.controller.selection;
      widget.controller.value = TextEditingValue(
        text: text,
        selection: selection.copyWith(
          baseOffset: selection.baseOffset.clamp(0, text.length),
          extentOffset: selection.extentOffset.clamp(0, text.length),
        ),
      );
    }

    return GestureDetector(
      onTap: widget.enabled ? () => widget.focusNode.requestFocus() : null,
      child: Stack(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(8, (i) {
              final ch = i < text.length ? text[i] : '';
              final focused =
                  widget.focusNode.hasFocus && i == text.length.clamp(0, 7);
              return Expanded(
                child: Container(
                  height: 48,
                  margin: EdgeInsets.only(right: i == 7 ? 0 : 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF121217),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: focused ? Colors.white : const Color(0x1AFFFFFF),
                      width: focused ? 1.4 : 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    ch,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              );
            }),
          ),
          Opacity(
            opacity: 0,
            child: TextField(
              enabled: widget.enabled,
              controller: widget.controller,
              focusNode: widget.focusNode,
              keyboardType: TextInputType.visiblePassword,
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                LengthLimitingTextInputFormatter(8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PairedRow extends StatelessWidget {
  const _PairedRow({required this.device});

  final PairedDevice device;

  @override
  Widget build(BuildContext context) {
    final onlineColor = device.isOnline
        ? const Color(0xFF30D158)
        : const Color(0xFF8E8E93);
    final statusText = device.isOnline ? '在线' : '离线';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: const Color(0xFF121217),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x1AFFFFFF)),
        ),
        child: Row(
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: onlineColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.nickname,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_formatLastSeen(device.lastSeen)} · $statusText',
                    style: const TextStyle(
                      color: Color(0x99FFFFFF),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0x66FFFFFF)),
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
    return const _SettingsHome();
  }
}

class _SettingsHome extends StatefulWidget {
  const _SettingsHome();

  @override
  State<_SettingsHome> createState() => _SettingsHomeState();
}

class _SettingsHomeState extends State<_SettingsHome> {
  static const _prefBackgroundEnabled = 'backgroundEnabled';
  static const _prefAccuracy = 'locationAccuracy';
  static const _prefServerUri = 'serverUri';

  final TextEditingController _serverController = TextEditingController();
  bool _backgroundEnabled = true;
  String _accuracy = 'high';

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _serverController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await _openPrefsBox();
    final server = prefs.get(_prefServerUri)?.toString() ?? '';
    final bg = prefs.get(_prefBackgroundEnabled);
    final acc = prefs.get(_prefAccuracy)?.toString();

    if (!mounted) return;
    setState(() {
      _serverController.text = server;
      _backgroundEnabled = bg is bool ? bg : true;
      _accuracy = acc == 'saving' ? 'saving' : 'high';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          children: [
            const Text(
              '设置',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              '后台与定位',
              style: TextStyle(
                color: Color(0x99FFFFFF),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            _SettingsTile(
              title: '后台运行',
              trailing: Switch(
                value: _backgroundEnabled,
                onChanged: (v) => _toggleBackground(v),
              ),
              onTap: null,
            ),
            const SizedBox(height: 10),
            _SettingsTile(
              title: '定位精度',
              trailing: Text(
                _accuracy == 'saving' ? '省电模式' : '高精度',
                style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 12),
              ),
              onTap: () => _pickAccuracy(),
            ),
            const SizedBox(height: 16),
            const Text(
              '服务器',
              style: TextStyle(
                color: Color(0x99FFFFFF),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: const Color(0xFF121217),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x1AFFFFFF)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'WebSocket 地址',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _serverController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'ws://公网IP:端口/ws',
                      hintStyle: TextStyle(color: Color(0x66FFFFFF)),
                      border: InputBorder.none,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0x33FFFFFF)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _saveServer,
                      child: const Text('保存'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '关于',
              style: TextStyle(
                color: Color(0x99FFFFFF),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: const Color(0xFF121217),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x1AFFFFFF)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0x1AFFFFFF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0x1AFFFFFF)),
                    ),
                    child: const Icon(Icons.navigation, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pointer',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '用“指针”连接地点、好友与世界的距离。',
                          style: TextStyle(
                            color: Color(0x99FFFFFF),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleBackground(bool enabled) async {
    setState(() => _backgroundEnabled = enabled);
    final prefs = await _openPrefsBox();
    await prefs.put(_prefBackgroundEnabled, enabled);

    if (enabled) {
      try {
        await initBackgroundService();
        await _invokeConfigureFromPrefs(prefs);
        final target = await _readCurrentTarget();
        if (target != null) {
          await _invokeSetTarget(target);
        }
      } catch (_) {}
      return;
    }

    try {
      final service = FlutterBackgroundService();
      service.invoke('stop');
    } catch (_) {}
  }

  Future<void> _pickAccuracy() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF0F1117),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SheetPick(
                  title: '高精度',
                  selected: _accuracy != 'saving',
                  onTap: () => Navigator.of(context).pop('high'),
                ),
                _SheetPick(
                  title: '省电模式',
                  selected: _accuracy == 'saving',
                  onTap: () => Navigator.of(context).pop('saving'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted) return;
    if (selected == null) return;
    setState(() => _accuracy = selected);
    final prefs = await _openPrefsBox();
    await prefs.put(_prefAccuracy, selected);
  }

  Future<void> _saveServer() async {
    final raw = _serverController.text.trim();
    final uri = Uri.tryParse(raw);
    if (uri == null || (uri.scheme != 'ws' && uri.scheme != 'wss')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请输入有效的 ws:// 或 wss:// 地址'),
          backgroundColor: Color(0xFF1C1C1E),
        ),
      );
      return;
    }

    final prefs = await _openPrefsBox();
    await prefs.put(_prefServerUri, raw);
    await _invokeConfigureFromPrefs(prefs);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已保存'),
        backgroundColor: Color(0xFF1C1C1E),
        duration: Duration(seconds: 1),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.title,
    required this.trailing,
    required this.onTap,
  });

  final String title;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF121217),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetPick extends StatelessWidget {
  const _SheetPick({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title, style: const TextStyle(color: Colors.white)),
      trailing: selected ? const Icon(Icons.check, color: Colors.white) : null,
      onTap: onTap,
    );
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({
    required this.isCupertino,
    required this.selectedIndex,
    required this.labels,
    required this.onTap,
  });

  final bool isCupertino;
  final int selectedIndex;
  final List<String> labels;
  final void Function(int index) onTap;

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

Future<Box> _openPrefsBox() => Hive.openBox('app_prefs');

Future<String> _getOrCreateMyUserId(Box prefs) async {
  final existing = prefs.get('myUserId')?.toString();
  if (existing != null && existing.isNotEmpty) return existing;

  final r = Random.secure();
  final bytes = List<int>.generate(12, (_) => r.nextInt(256));
  final id = base64UrlEncode(bytes).replaceAll('=', '');
  await prefs.put('myUserId', id);
  return id;
}

Future<void> _invokeConfigureFromPrefs(Box prefs) async {
  final serverUriString = prefs.get('serverUri')?.toString();
  final serverUri = serverUriString == null
      ? null
      : Uri.tryParse(serverUriString);
  if (serverUri == null) return;
  final myUserId = await _getOrCreateMyUserId(prefs);

  final service = FlutterBackgroundService();
  service.invoke('configure', <String, dynamic>{
    'serverUri': serverUri.toString(),
    'myUserId': myUserId,
  });
}

Future<SavedLocation?> _readCurrentTarget() async {
  final prefs = await _openPrefsBox();
  final id = prefs.get('currentTargetId')?.toString();
  if (id == null || id.isEmpty) return null;
  final box = await Hive.openBox<SavedLocation>('saved_locations');
  return box.get(id);
}

Future<void> _invokeSetTarget(SavedLocation loc) async {
  final service = FlutterBackgroundService();
  service.invoke('set_target', <String, dynamic>{
    'id': loc.id,
    'name': loc.name,
    'latitude': loc.latitude,
    'longitude': loc.longitude,
  });
}

String _formatCode(String code) {
  final c = code.padRight(8, '-');
  return '${c.substring(0, 4)} · ${c.substring(4, 8)}';
}

DateTime _endOfDay(DateTime dt) =>
    DateTime(dt.year, dt.month, dt.day, 23, 59, 59);

String _formatRemain(DateTime expiresAt) {
  final diff = expiresAt.difference(DateTime.now());
  if (diff.isNegative) return '00:00:00';
  final h = diff.inHours.toString().padLeft(2, '0');
  final m = (diff.inMinutes % 60).toString().padLeft(2, '0');
  final s = (diff.inSeconds % 60).toString().padLeft(2, '0');
  return '$h:$m:$s';
}

String _formatLastSeen(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return '刚刚';
  if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
  if (diff.inDays < 1) return '${diff.inHours} 小时前';
  return '${diff.inDays} 天前';
}
