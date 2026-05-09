import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
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
  static const _tileSubdomains = <String>['1', '2', '3', '4'];

  static final Uint8List _grayPngBytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMB/Upm3XQAAAAASUVORK5CYII=',
  );

  final MapController _mapController = MapController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  Timer? _idleDebounce;
  Timer? _searchDebounce;

  LatLng _selected = const LatLng(39.9, 116.4);
  double _zoom = 14;
  LatLng _pendingCenter = const LatLng(39.9, 116.4);
  double _pendingZoom = 14;
  String? _address;
  bool _geocoding = false;
  bool _searching = false;
  bool _snapping = false;
  List<_AmapTip> _tips = const [];

  @override
  void initState() {
    super.initState();
    _pendingCenter = _selected;
    _pendingZoom = _zoom;
    _searchController.addListener(_onSearchTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _onMapIdle(_selected);
    });
  }

  @override
  void dispose() {
    _idleDebounce?.cancel();
    _idleDebounce = null;
    _searchDebounce?.cancel();
    _searchDebounce = null;

    _nameController.dispose();
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tileProvider = NetworkTileProvider();
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
                  Listener(
                    onPointerUp: (_) => _onMapIdle(_pendingCenter),
                    onPointerCancel: (_) => _onMapIdle(_pendingCenter),
                    child: FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _selected,
                        initialZoom: _zoom,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                        ),
                        onPositionChanged: (camera, hasGesture) {
                          _pendingCenter = camera.center;
                          _pendingZoom = camera.zoom;
                          if (!hasGesture && !_snapping) {
                            _onMapIdle(camera.center);
                          }
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: _amapUrlTemplate(widget.amapKey),
                          subdomains: _tileSubdomains,
                          tileProvider: tileProvider,
                          userAgentPackageName: 'com.example.pointer_app',
                          errorImage: MemoryImage(_grayPngBytes),
                        ),
                      ],
                    ),
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
        locationBias: _pendingCenter,
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
    _pendingCenter = tip.location;
    _mapController.move(tip.location, _mapController.camera.zoom);
    _onMapIdle(tip.location);
  }

  void _onMapIdle(LatLng center) {
    _idleDebounce?.cancel();
    _idleDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() {
        _selected = center;
        _zoom = _pendingZoom;
      });
      unawaited(_reverseGeocodeAndMaybeSnap(center));
    });
  }

  Future<void> _locateMe() async {
    try {
      final pos = await Geolocator.getCurrentPosition();
      final center = LatLng(pos.latitude, pos.longitude);
      _pendingCenter = center;
      _mapController.move(center, _mapController.camera.zoom);
      setState(() => _selected = center);
      _onMapIdle(center);
    } catch (_) {}
  }

  Future<void> _reverseGeocodeAndMaybeSnap(LatLng p) async {
    if (_geocoding) return;
    setState(() => _geocoding = true);
    try {
      final result = await _amapReverseGeocodeDetailed(
        key: widget.amapKey,
        latitude: p.latitude,
        longitude: p.longitude,
      );
      if (!mounted) return;
      final best = result?.bestPoi;
      if (best != null && best.distanceMeters <= 35) {
        if (!_snapping) {
          _snapping = true;
          _pendingCenter = best.location;
          _mapController.move(best.location, _mapController.camera.zoom);
          await Future<void>.delayed(const Duration(milliseconds: 250));
          _snapping = false;
        }

        setState(() {
          _selected = best.location;
          _address = best.address?.isEmpty ?? true
              ? best.name
              : '${best.name} · ${best.address}';
          if (_nameController.text.trim().isEmpty) {
            _nameController.text = best.name;
          }
        });
      } else {
        setState(() => _address = result?.formattedAddress);
      }
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

String _amapUrlTemplate(String key) {
  return 'https://webrd0{s}.is.autonavi.com/appmaptile?lang=zh_cn&size=1&scale=1&style=7&x={x}&y={y}&z={z}&key=$key';
}

final class _AmapPoi {
  const _AmapPoi({
    required this.name,
    required this.location,
    required this.distanceMeters,
    this.address,
  });

  final String name;
  final LatLng location;
  final double distanceMeters;
  final String? address;
}

final class _AmapRegeoResult {
  const _AmapRegeoResult({
    required this.formattedAddress,
    required this.bestPoi,
  });

  final String? formattedAddress;
  final _AmapPoi? bestPoi;
}

Future<_AmapRegeoResult?> _amapReverseGeocodeDetailed({
  required String key,
  required double latitude,
  required double longitude,
}) async {
  final uri =
      Uri.https('restapi.amap.com', '/v3/geocode/regeo', <String, String>{
        'key': key,
        'location': '$longitude,$latitude',
        'radius': '50',
        'extensions': 'all',
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

    _AmapPoi? bestPoi;
    final pois = regeocode['pois'];
    if (pois is List) {
      for (final item in pois) {
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

        final distRaw = item['distance'];
        final dist = distRaw is num ? distRaw.toDouble() : double.nan;
        if (!dist.isFinite) continue;

        final addr = item['address']?.toString();
        final candidate = _AmapPoi(
          name: name,
          location: LatLng(lat, lon),
          distanceMeters: dist,
          address: addr,
        );
        if (bestPoi == null ||
            candidate.distanceMeters < bestPoi.distanceMeters) {
          bestPoi = candidate;
        }
      }
    }

    return _AmapRegeoResult(
      formattedAddress: formatted?.isEmpty ?? true ? null : formatted,
      bestPoi: bestPoi,
    );
  } finally {
    client.close(force: true);
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
