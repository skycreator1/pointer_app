import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:latlong2/latlong.dart';
import 'package:pointer_app/core/models/saved_location.dart';

class LocationPickerPage extends StatefulWidget {
  const LocationPickerPage({super.key, required this.amapKey});

  final String amapKey;

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  Timer? _idleDebounce;
  Timer? _searchDebounce;

  LatLng _selected = const LatLng(39.9, 116.4);
  double _zoom = 14;
  String? _address;
  bool _geocoding = false;
  bool _searching = false;
  List<_AmapTip> _tips = const [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchTextChanged);
  }

  @override
  void dispose() {
    _idleDebounce?.cancel();
    _idleDebounce = null;
    _searchDebounce?.cancel();
    _searchDebounce = null;

    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('地图选点'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  _AmapStaticMap(
                    amapKey: widget.amapKey,
                    center: _selected,
                    zoom: _zoom,
                    onCameraChanged: (center, zoom) {
                      setState(() {
                        _selected = center;
                        _zoom = zoom;
                      });
                      _onMapIdle(center);
                    },
                  ),
                  const IgnorePointer(
                    child: Center(
                      child: Icon(Icons.add, color: Colors.white, size: 28),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    top: 16,
                    child: _SearchBar(
                      controller: _searchController,
                      searching: _searching,
                      onClear: _clearSearch,
                    ),
                  ),
                  if (_tips.isNotEmpty)
                    Positioned(
                      left: 16,
                      right: 16,
                      top: 74,
                      child: _TipsPanel(tips: _tips, onSelect: _selectTip),
                    ),
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _CircleButton(
                          icon: Icons.my_location,
                          onTap: _locateMe,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _BottomPanel(
              address: _address,
              geocoding: _geocoding,
              selected: _selected,
              nameController: _nameController,
              onSave: _save,
            ),
          ],
        ),
      ),
    );
  }

  void _onSearchTextChanged() {
    final text = _searchController.text.trim();
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      if (text.isEmpty) {
        setState(() => _tips = const []);
        return;
      }
      unawaited(_searchTips(text));
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _tips = const []);
  }

  Future<void> _searchTips(String keywords) async {
    if (_searching) return;
    setState(() => _searching = true);
    try {
      final tips = await _amapInputTips(
        key: widget.amapKey,
        keywords: keywords,
        locationBias: _selected,
      );
      if (!mounted) return;
      setState(() => _tips = tips);
    } catch (_) {
      if (!mounted) return;
      setState(() => _tips = const []);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _selectTip(_AmapTip tip) {
    setState(() {
      _tips = const [];
      _selected = tip.location;
      _address = tip.address?.isEmpty ?? true ? tip.name : tip.address;
      if (_nameController.text.trim().isEmpty) {
        _nameController.text = tip.name;
      }
    });
    _onMapIdle(tip.location);
  }

  void _onMapIdle(LatLng center) {
    _idleDebounce?.cancel();
    _idleDebounce = Timer(const Duration(milliseconds: 550), () {
      if (!mounted) return;
      unawaited(_reverseGeocode(center));
    });
  }

  Future<void> _locateMe() async {
    try {
      final pos = await Geolocator.getCurrentPosition();
      final center = LatLng(pos.latitude, pos.longitude);
      setState(() => _selected = center);
      _onMapIdle(center);
    } catch (_) {}
  }

  Future<void> _reverseGeocode(LatLng p) async {
    if (_geocoding) return;
    setState(() => _geocoding = true);
    try {
      final addr = await _amapReverseGeocode(
        key: widget.amapKey,
        latitude: p.latitude,
        longitude: p.longitude,
      );
      if (!mounted) return;
      setState(() => _address = addr);
    } catch (_) {
      if (!mounted) return;
      setState(() => _address = null);
    } finally {
      if (mounted) {
        setState(() => _geocoding = false);
      }
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final box = await Hive.openBox<SavedLocation>('saved_locations');
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final loc = SavedLocation(
      id: id,
      name: name,
      latitude: _selected.latitude,
      longitude: _selected.longitude,
      createdAt: DateTime.now(),
    );
    await box.put(id, loc);
    if (!mounted) return;
    context.pop(loc);
  }
}

Uri _amapStaticMapUri({
  required String key,
  required LatLng center,
  required int zoom,
  required int width,
  required int height,
  int scale = 1,
  int traffic = 0,
}) {
  final z = zoom.clamp(1, 17);
  final w = width.clamp(1, 1024);
  final h = height.clamp(1, 1024);
  final lon = center.longitude.toStringAsFixed(6);
  final lat = center.latitude.toStringAsFixed(6);
  return Uri.https('restapi.amap.com', '/v3/staticmap', <String, String>{
    'key': key,
    'location': '$lon,$lat',
    'zoom': '$z',
    'size': '$w*$h',
    'scale': '${scale.clamp(1, 2)}',
    'traffic': '${traffic.clamp(0, 1)}',
  });
}

Future<String?> _amapReverseGeocode({
  required String key,
  required double latitude,
  required double longitude,
}) async {
  final uri =
      Uri.https('restapi.amap.com', '/v3/geocode/regeo', <String, String>{
        'key': key,
        'location': '$longitude,$latitude',
        'radius': '50',
        'extensions': 'base',
        'output': 'JSON',
      });

  final client = HttpClient();
  try {
    final req = await client.getUrl(uri);
    final resp = await req.close();
    final body = await resp.transform(utf8.decoder).join();
    final decoded = jsonDecode(body);
    if (decoded is! Map) return null;
    if (decoded['status']?.toString() != '1') return null;
    final regeocode = decoded['regeocode'];
    if (regeocode is! Map) return null;
    final formatted = regeocode['formatted_address']?.toString();
    return formatted?.isEmpty ?? true ? null : formatted;
  } finally {
    client.close(force: true);
  }
}

class _AmapStaticMap extends StatefulWidget {
  const _AmapStaticMap({
    required this.amapKey,
    required this.center,
    required this.zoom,
    required this.onCameraChanged,
  });

  final String amapKey;
  final LatLng center;
  final double zoom;
  final void Function(LatLng center, double zoom) onCameraChanged;

  @override
  State<_AmapStaticMap> createState() => _AmapStaticMapState();
}

class _AmapStaticMapState extends State<_AmapStaticMap> {
  static const _ln2 = 0.6931471805599453;
  static double _sinh(double x) => (math.exp(x) - math.exp(-x)) / 2.0;

  LatLng _center = const LatLng(39.9, 116.4);
  double _zoom = 14;

  Timer? _imageDebounce;
  String _imageUrl = '';

  LatLng? _gestureStartCenter;
  double? _gestureStartZoom;
  Offset? _gestureStartFocal;

  @override
  void initState() {
    super.initState();
    _center = widget.center;
    _zoom = widget.zoom;
  }

  @override
  void didUpdateWidget(covariant _AmapStaticMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.center != widget.center) {
      _center = widget.center;
    }
    if (oldWidget.zoom != widget.zoom) {
      _zoom = widget.zoom;
    }
  }

  @override
  void dispose() {
    _imageDebounce?.cancel();
    _imageDebounce = null;
    super.dispose();
  }

  void _scheduleImageRefresh({
    required Size size,
    Duration delay = const Duration(milliseconds: 120),
  }) {
    _imageDebounce?.cancel();
    _imageDebounce = Timer(delay, () {
      if (!mounted) return;
      final w = size.width.isFinite ? size.width.round() : 0;
      final h = size.height.isFinite ? size.height.round() : 0;
      if (w <= 0 || h <= 0) return;

      final uri = _amapStaticMapUri(
        key: widget.amapKey,
        center: _center,
        zoom: _zoom.round(),
        width: w,
        height: h,
      );
      setState(() => _imageUrl = uri.toString());
    });
  }

  void _onScaleStart(ScaleStartDetails details) {
    _gestureStartCenter = _center;
    _gestureStartZoom = _zoom;
    _gestureStartFocal = details.focalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails details, Size size) {
    final startCenter = _gestureStartCenter;
    final startZoom = _gestureStartZoom;
    final startFocal = _gestureStartFocal;
    if (startCenter == null || startZoom == null || startFocal == null) return;

    final scale = details.scale.isFinite ? details.scale : 1.0;
    final zoomDelta = math.log(scale) / _ln2;
    final nextZoom = (startZoom + zoomDelta).clamp(1.0, 17.0);
    final nextZoomInt = nextZoom.round().clamp(1, 17);

    final delta = details.focalPoint - startFocal;
    final nextCenter = _panTo(
      startCenter: startCenter,
      deltaPx: delta,
      zoom: nextZoomInt,
    );

    _center = nextCenter;
    _zoom = nextZoom;
    widget.onCameraChanged(nextCenter, nextZoom);
    _scheduleImageRefresh(size: size);
  }

  void _onScaleEnd(ScaleEndDetails details, Size size) {
    _gestureStartCenter = null;
    _gestureStartZoom = null;
    _gestureStartFocal = null;
    _scheduleImageRefresh(size: size, delay: const Duration(milliseconds: 40));
  }

  LatLng _panTo({
    required LatLng startCenter,
    required Offset deltaPx,
    required int zoom,
  }) {
    final start = _toWorldPixel(startCenter, zoom);
    final next = Offset(start.dx - deltaPx.dx, start.dy - deltaPx.dy);
    return _fromWorldPixel(next, zoom);
  }

  Offset _toWorldPixel(LatLng p, int zoom) {
    final z = zoom.clamp(1, 17);
    final worldSize = 256.0 * math.pow(2.0, z);
    final lat = p.latitude.clamp(-85.05112878, 85.05112878);
    final lon = p.longitude;

    final x = (lon + 180.0) / 360.0 * worldSize;
    final latRad = lat * math.pi / 180.0;
    final y =
        (1.0 - math.log(math.tan(latRad) + (1 / math.cos(latRad))) / math.pi) /
        2.0 *
        worldSize;
    return Offset(x, y);
  }

  LatLng _fromWorldPixel(Offset px, int zoom) {
    final z = zoom.clamp(1, 17);
    final worldSize = 256.0 * math.pow(2.0, z);
    final x = px.dx.clamp(0.0, worldSize);
    final y = px.dy.clamp(0.0, worldSize);

    final lon = x / worldSize * 360.0 - 180.0;
    final n = math.pi - 2.0 * math.pi * y / worldSize;
    final lat = 180.0 / math.pi * math.atan(_sinh(n));
    return LatLng(lat, lon);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        if (_imageUrl.isEmpty && size.width > 0 && size.height > 0) {
          final uri = _amapStaticMapUri(
            key: widget.amapKey,
            center: _center,
            zoom: _zoom.round(),
            width: size.width.round(),
            height: size.height.round(),
          );
          _imageUrl = uri.toString();
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleStart: _onScaleStart,
          onScaleUpdate: (d) => _onScaleUpdate(d, size),
          onScaleEnd: (d) => _onScaleEnd(d, size),
          child: DecoratedBox(
            decoration: const BoxDecoration(color: Color(0xFF0B0B0D)),
            child: _imageUrl.isEmpty
                ? const SizedBox.expand()
                : Image.network(
                    _imageUrl,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.low,
                    gaplessPlayback: true,
                    errorBuilder: (context, error, stackTrace) {
                      return const ColoredBox(color: Color(0xFF0B0B0D));
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          child,
                          const ColoredBox(color: Color(0x33000000)),
                          const Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        );
      },
    );
  }
}

final class _AmapTip {
  const _AmapTip({required this.name, required this.location, this.address});

  final String name;
  final LatLng location;
  final String? address;
}

Future<List<_AmapTip>> _amapInputTips({
  required String key,
  required String keywords,
  required LatLng locationBias,
}) async {
  final uri =
      Uri.https('restapi.amap.com', '/v3/assistant/inputtips', <String, String>{
        'key': key,
        'keywords': keywords,
        'location': '${locationBias.longitude},${locationBias.latitude}',
        'datatype': 'all',
        'output': 'JSON',
      });

  final client = HttpClient();
  try {
    final req = await client.getUrl(uri);
    final resp = await req.close();
    final body = await resp.transform(utf8.decoder).join();
    final decoded = jsonDecode(body);
    if (decoded is! Map) return const [];
    if (decoded['status']?.toString() != '1') return const [];
    final tips = decoded['tips'];
    if (tips is! List) return const [];

    final out = <_AmapTip>[];
    for (final item in tips) {
      if (item is! Map) continue;
      final name = item['name']?.toString();
      final location = item['location']?.toString();
      if (name == null || name.isEmpty) continue;
      if (location == null || location.isEmpty) continue;
      final parts = location.split(',');
      if (parts.length != 2) continue;
      final lon = double.tryParse(parts[0]);
      final lat = double.tryParse(parts[1]);
      if (lat == null || lon == null) continue;
      final addr = item['address']?.toString();
      out.add(_AmapTip(name: name, location: LatLng(lat, lon), address: addr));
      if (out.length >= 8) break;
    }
    return out;
  } finally {
    client.close(force: true);
  }
}

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({
    required this.address,
    required this.geocoding,
    required this.selected,
    required this.nameController,
    required this.onSave,
  });

  final String? address;
  final bool geocoding;
  final LatLng selected;
  final TextEditingController nameController;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: const BoxDecoration(
        color: Color(0xFF0B0B0D),
        border: Border(top: BorderSide(color: Color(0x1FFFFFFF))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            geocoding ? '正在获取地址…' : (address ?? '未获取到地址'),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            '${selected.latitude.toStringAsFixed(6)}, ${selected.longitude.toStringAsFixed(6)}',
            style: const TextStyle(color: Color(0xB3FFFFFF), fontSize: 12),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: nameController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: '地点名称',
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
          const SizedBox(height: 12),
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
              onPressed: onSave,
              child: const Text('保存'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.searching,
    required this.onClear,
  });

  final TextEditingController controller;
  final bool searching;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final hasText = controller.text.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xE60B0B0D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1FFFFFFF)),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: Color(0xB3FFFFFF), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: const InputDecoration(
                hintText: '搜索地点（高德）',
                hintStyle: TextStyle(color: Color(0x66FFFFFF)),
                isDense: true,
                border: InputBorder.none,
              ),
            ),
          ),
          if (searching)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          else if (hasText)
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              onPressed: onClear,
              icon: const Icon(Icons.close, color: Color(0xB3FFFFFF), size: 18),
            ),
        ],
      ),
    );
  }
}

class _TipsPanel extends StatelessWidget {
  const _TipsPanel({required this.tips, required this.onSelect});

  final List<_AmapTip> tips;
  final void Function(_AmapTip tip) onSelect;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xE60B0B0D),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x1FFFFFFF)),
        ),
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 6),
          itemCount: tips.length,
          separatorBuilder: (context, index) =>
              const Divider(height: 1, color: Color(0x1FFFFFFF)),
          itemBuilder: (context, index) {
            final t = tips[index];
            return ListTile(
              dense: true,
              title: Text(
                t.name,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: t.address == null || t.address!.isEmpty
                  ? null
                  : Text(
                      t.address!,
                      style: const TextStyle(
                        color: Color(0x99FFFFFF),
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
              onTap: () => onSelect(t),
            );
          },
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xCC000000),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}
