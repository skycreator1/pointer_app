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
import 'package:pointer_app/core/utils/haversine.dart';
import 'package:pointer_app/core/models/saved_location.dart';

class LocationPickerPage extends StatefulWidget {
  const LocationPickerPage({super.key, required this.amapKey});

  final String amapKey;

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  static const _tileSubdomains = <String>['1', '2', '3', '4'];
  static const _prefsBoxName = 'app_prefs';
  static const _prefLastUserLat = 'lastUserLat';
  static const _prefLastUserLon = 'lastUserLon';
  static const _prefLastCenterLat = 'lastCenterLat';
  static const _prefLastCenterLon = 'lastCenterLon';

  static const _persistCenterDelay = Duration(milliseconds: 500);
  static const _searchDelay = Duration(milliseconds: 350);

  static const _chinaCenter = LatLng(35.86166, 104.195397);
  static const _chinaZoom = 4.2;

  static final Uint8List _grayPngBytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMB/Upm3XQAAAAASUVORK5CYII=',
  );

  final MapController _mapController = MapController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  Timer? _persistCenterDebounce;
  Timer? _searchDebounce;

  LatLng _mapCenter = const LatLng(39.9, 116.4);
  double _mapZoom = 14;
  LatLng _pendingCenter = const LatLng(39.9, 116.4);
  double _pendingZoom = 14;
  LatLng? _userLocation;
  bool _nameEdited = false;
  bool _updatingName = false;

  LatLng? _selectedPoint;
  String? _selectedName;
  String? _selectedAddress;
  bool _geocoding = false;
  int _geocodeSeq = 0;
  bool _searching = false;
  LatLng? _selectedSearchLocation;
  List<_AmapTip> _tips = const [];

  @override
  void initState() {
    super.initState();
    _pendingCenter = _mapCenter;
    _pendingZoom = _mapZoom;
    _searchController.addListener(_onSearchTextChanged);
    _nameController.addListener(() {
      if (_updatingName) return;
      _nameEdited = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_initDefaultCenter());
    });
  }

  @override
  void dispose() {
    _persistCenterDebounce?.cancel();
    _persistCenterDebounce = null;
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
                    child: FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _mapCenter,
                        initialZoom: _mapZoom,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                        ),
                        onTap: (tapPosition, point) {
                          _selectPoint(point);
                        },
                        onPositionChanged: (camera, hasGesture) {
                          _pendingCenter = camera.center;
                          _pendingZoom = camera.zoom;
                          _persistCenterDebounced(camera.center);
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
                        if (_selectedPoint != null)
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: _selectedPoint!,
                                width: 220,
                                height: 100,
                                alignment: Alignment.topCenter,
                                child: _MapPin(title: _selectedName),
                              ),
                            ],
                          ),
                      ],
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
                      child: _TipsPanel(
                        tips: _tips,
                        selectedLocation: _selectedSearchLocation,
                        onSelect: _selectTip,
                      ),
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
              name: _selectedName,
              address: _selectedAddress,
              geocoding: _geocoding,
              selected: _selectedPoint,
              center: _mapCenter,
              nameController: _nameController,
              nameHint: _selectedName,
              onSave: _selectedPoint == null ? null : _save,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _initDefaultCenter() async {
    LatLng? user;
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (enabled) {
        var perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          perm = await Geolocator.requestPermission();
        }
        if (perm == LocationPermission.always ||
            perm == LocationPermission.whileInUse) {
          final pos = await Geolocator.getCurrentPosition();
          user = LatLng(pos.latitude, pos.longitude);
          _userLocation = user;
          final prefs = await Hive.openBox(_prefsBoxName);
          await prefs.put(_prefLastUserLat, pos.latitude);
          await prefs.put(_prefLastUserLon, pos.longitude);
        }
      }
    } catch (_) {}

    LatLng center;
    double zoom;
    if (user != null) {
      center = user;
      zoom = 16;
    } else {
      final prefs = await Hive.openBox(_prefsBoxName);
      final lastUser = _readLatLng(
        lat: prefs.get(_prefLastUserLat),
        lon: prefs.get(_prefLastUserLon),
      );
      final lastCenter = _readLatLng(
        lat: prefs.get(_prefLastCenterLat),
        lon: prefs.get(_prefLastCenterLon),
      );
      center = lastUser ?? lastCenter ?? _chinaCenter;
      zoom = (lastUser != null || lastCenter != null) ? 16 : _chinaZoom;
      if (lastUser != null) _userLocation = lastUser;
    }

    if (!mounted) return;
    setState(() {
      _pendingCenter = center;
      _pendingZoom = zoom;
      _mapCenter = center;
      _mapZoom = zoom;
    });
    _mapController.move(center, zoom);
    _persistCenterDebounced(center);
  }

  void _onSearchTextChanged() {
    final text = _searchController.text.trim();
    _searchDebounce?.cancel();
    _searchDebounce = Timer(_searchDelay, () {
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
      final anchor = _userLocation ?? _pendingCenter;
      final withDistance =
          tips
              .map(
                (t) => t.copyWith(
                  distanceMeters: calcDistance(
                    anchor.latitude,
                    anchor.longitude,
                    t.location.latitude,
                    t.location.longitude,
                  ),
                ),
              )
              .toList()
            ..sort(
              (a, b) => (a.distanceMeters ?? double.infinity).compareTo(
                b.distanceMeters ?? double.infinity,
              ),
            );

      setState(() => _tips = withDistance);
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
      _selectedPoint = tip.location;
      _selectedSearchLocation = tip.location;
      _selectedName = tip.name;
      _selectedAddress = tip.address?.isEmpty ?? true ? null : tip.address;
      if (_nameController.text.trim().isEmpty) {
        _setNameIfNotEdited(tip.name);
      }
    });
    _pendingCenter = tip.location;
    _mapController.move(tip.location, _mapController.camera.zoom);
    unawaited(_reverseGeocode(tip.location, zoom: _pendingZoom));
  }

  void _persistCenterDebounced(LatLng center) {
    _persistCenterDebounce?.cancel();
    _persistCenterDebounce = Timer(_persistCenterDelay, () {
      if (!mounted) return;
      setState(() {
        _mapCenter = center;
        _mapZoom = _pendingZoom;
      });
      unawaited(_persistLastCenter(center));
    });
  }

  void _selectPoint(LatLng point) {
    setState(() {
      _tips = const [];
      _selectedSearchLocation = null;
      _selectedPoint = point;
    });
    unawaited(_reverseGeocode(point, zoom: _pendingZoom));
    unawaited(_persistLastCenter(point));
  }

  Future<void> _locateMe() async {
    try {
      final pos = await Geolocator.getCurrentPosition();
      final center = LatLng(pos.latitude, pos.longitude);
      _userLocation = center;
      final prefs = await Hive.openBox(_prefsBoxName);
      await prefs.put(_prefLastUserLat, pos.latitude);
      await prefs.put(_prefLastUserLon, pos.longitude);
      _pendingCenter = center;
      _mapController.move(center, _mapController.camera.zoom);
      setState(() {
        _mapCenter = center;
        _mapZoom = _mapController.camera.zoom;
      });
      _persistCenterDebounced(center);
    } catch (_) {}
  }

  Future<void> _reverseGeocode(LatLng p, {required double zoom}) async {
    final seq = ++_geocodeSeq;
    if (!_geocoding) setState(() => _geocoding = true);
    try {
      final radius = _radiusForZoom(zoom);
      final result = await _amapReverseGeocodeDetailed(
        key: widget.amapKey,
        latitude: p.latitude,
        longitude: p.longitude,
        radiusMeters: radius,
      );
      if (!mounted) return;
      if (seq != _geocodeSeq) return;

      final formatted = result?.formattedAddress?.trim();
      final best = result?.bestPoi;
      final name = best?.name.trim().isNotEmpty ?? false
          ? best!.name.trim()
          : (formatted == null || formatted.isEmpty ? null : formatted);

      setState(() {
        _selectedName = name;
        _selectedAddress = _addressForZoom(result, zoom: zoom);
      });
      if (name != null) _setNameIfNotEdited(name);
    } catch (_) {
      if (!mounted) return;
    } finally {
      if (mounted) {
        if (seq == _geocodeSeq) setState(() => _geocoding = false);
      }
    }
  }

  Future<void> _persistLastCenter(LatLng center) async {
    try {
      final prefs = await Hive.openBox(_prefsBoxName);
      await prefs.put(_prefLastCenterLat, center.latitude);
      await prefs.put(_prefLastCenterLon, center.longitude);
    } catch (_) {}
  }

  void _setNameIfNotEdited(String value) {
    if (_nameEdited) return;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    _updatingName = true;
    _nameController.text = trimmed;
    _nameController.selection = TextSelection.collapsed(
      offset: _nameController.text.length,
    );
    _updatingName = false;
  }

  Future<void> _save() async {
    final point = _selectedPoint;
    if (point == null) return;
    final typedName = _nameController.text.trim();
    final autoName = _selectedName?.trim() ?? '';
    final name = typedName.isNotEmpty
        ? typedName
        : (autoName.isNotEmpty
              ? autoName
              : '${point.latitude.toStringAsFixed(6)},${point.longitude.toStringAsFixed(6)}');
    if (name.isEmpty) return;

    final box = await Hive.openBox<SavedLocation>('saved_locations');
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final loc = SavedLocation(
      id: id,
      name: name,
      latitude: point.latitude,
      longitude: point.longitude,
      createdAt: DateTime.now(),
    );
    await box.put(id, loc);
    if (!mounted) return;
    context.pop(loc);
  }
}

int _radiusForZoom(double zoom) {
  if (zoom < 6) return 10000;
  if (zoom < 9) return 5000;
  if (zoom < 11) return 2500;
  if (zoom < 13) return 1200;
  if (zoom < 15) return 600;
  return 200;
}

String? _addressForZoom(_AmapRegeoResult? result, {required double zoom}) {
  if (result == null) return null;
  final formatted = result.formattedAddress?.trim();
  if (formatted == null || formatted.isEmpty) return null;

  final province = result.province?.trim() ?? '';
  final city = result.city?.trim() ?? '';
  final district = result.district?.trim() ?? '';
  final township = result.township?.trim() ?? '';

  if (zoom < 7) {
    final a = <String>[province, city].where((s) => s.isNotEmpty).toList();
    return a.isEmpty ? formatted : a.join(' ');
  }
  if (zoom < 11) {
    final a = <String>[
      city.isNotEmpty ? city : province,
      district,
      township,
    ].where((s) => s.isNotEmpty).toList();
    return a.isEmpty ? formatted : a.join(' ');
  }
  return formatted;
}

LatLng? _readLatLng({required Object? lat, required Object? lon}) {
  final latNum = lat is num
      ? lat.toDouble()
      : double.tryParse(lat?.toString() ?? '');
  final lonNum = lon is num
      ? lon.toDouble()
      : double.tryParse(lon?.toString() ?? '');
  if (latNum == null || lonNum == null) return null;
  if (!latNum.isFinite || !lonNum.isFinite) return null;
  return LatLng(latNum, lonNum);
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
    required this.province,
    required this.city,
    required this.district,
    required this.township,
  });

  final String? formattedAddress;
  final _AmapPoi? bestPoi;
  final String? province;
  final String? city;
  final String? district;
  final String? township;
}

Future<_AmapRegeoResult?> _amapReverseGeocodeDetailed({
  required String key,
  required double latitude,
  required double longitude,
  required int radiusMeters,
}) async {
  final uri =
      Uri.https('restapi.amap.com', '/v3/geocode/regeo', <String, String>{
        'key': key,
        'location': '$longitude,$latitude',
        'radius': radiusMeters.toString(),
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
    final addressComp = regeocode['addressComponent'];
    String? province;
    String? city;
    String? district;
    String? township;
    if (addressComp is Map) {
      province = addressComp['province']?.toString();
      final cityRaw = addressComp['city'];
      if (cityRaw is List) {
        city = cityRaw.isEmpty ? null : cityRaw.first?.toString();
      } else {
        city = cityRaw?.toString();
      }
      district = addressComp['district']?.toString();
      township = addressComp['township']?.toString();
    }

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
      province: province?.isEmpty ?? true ? null : province,
      city: city?.isEmpty ?? true ? null : city,
      district: district?.isEmpty ?? true ? null : district,
      township: township?.isEmpty ?? true ? null : township,
    );
  } finally {
    client.close(force: true);
  }
}

final class _AmapTip {
  const _AmapTip({
    required this.name,
    required this.location,
    this.address,
    this.distanceMeters,
  });

  final String name;
  final LatLng location;
  final String? address;
  final double? distanceMeters;

  _AmapTip copyWith({double? distanceMeters}) {
    return _AmapTip(
      name: name,
      location: location,
      address: address,
      distanceMeters: distanceMeters ?? this.distanceMeters,
    );
  }
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
    required this.name,
    required this.address,
    required this.geocoding,
    required this.selected,
    required this.center,
    required this.nameController,
    required this.nameHint,
    required this.onSave,
  });

  final String? name;
  final String? address;
  final bool geocoding;
  final LatLng? selected;
  final LatLng center;
  final TextEditingController nameController;
  final String? nameHint;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final nameText = name?.trim() ?? '';
    final addressText = address?.trim() ?? '';
    final coords = selected ?? center;
    final enabled = selected != null;
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
            nameText.isEmpty ? '未选择地点' : nameText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 1.15,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            geocoding
                ? '正在获取地址…'
                : (!enabled
                      ? '点击地图或搜索结果选择地点'
                      : (addressText.isEmpty ? '未获取到地址' : addressText)),
            style: const TextStyle(
              color: Color(0xB3FFFFFF),
              fontSize: 13,
              height: 1.2,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            '${coords.latitude.toStringAsFixed(6)}, ${coords.longitude.toStringAsFixed(6)}',
            style: const TextStyle(color: Color(0xB3FFFFFF), fontSize: 12),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: nameController,
            style: const TextStyle(color: Colors.white),
            enabled: enabled,
            decoration: InputDecoration(
              hintText: nameHint == null || nameHint!.trim().isEmpty
                  ? '地点名称（可选）'
                  : nameHint,
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
  const _TipsPanel({
    required this.tips,
    required this.selectedLocation,
    required this.onSelect,
  });

  final List<_AmapTip> tips;
  final LatLng? selectedLocation;
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
            final selected = _isSameLatLng(selectedLocation, t.location);
            final distance = t.distanceMeters;
            final distanceText = distance == null
                ? null
                : _formatDistance(distance);
            return Material(
              color: selected ? const Color(0x1AFFFFFF) : Colors.transparent,
              child: ListTile(
                dense: true,
                leading: Icon(
                  selected ? Icons.check_circle : Icons.place_outlined,
                  color: selected ? Colors.white : const Color(0xB3FFFFFF),
                  size: 18,
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        t.name,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (distanceText != null) ...[
                      const SizedBox(width: 10),
                      Text(
                        distanceText,
                        style: const TextStyle(
                          color: Color(0x99FFFFFF),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
                subtitle: t.address == null || t.address!.trim().isEmpty
                    ? null
                    : Text(
                        t.address!.trim(),
                        style: const TextStyle(
                          color: Color(0x99FFFFFF),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                onTap: () => onSelect(t),
              ),
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

class _MapPin extends StatelessWidget {
  const _MapPin({required this.title});

  final String? title;

  @override
  Widget build(BuildContext context) {
    final text = title?.trim() ?? '';
    return IgnorePointer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (text.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xE6000000),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0x1FFFFFFF)),
              ),
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(height: 6),
          const Icon(Icons.place, color: Color(0xFFE11D48), size: 30),
        ],
      ),
    );
  }
}

bool _isSameLatLng(LatLng? a, LatLng b) {
  if (a == null) return false;
  return (a.latitude - b.latitude).abs() < 1e-6 &&
      (a.longitude - b.longitude).abs() < 1e-6;
}

String _formatDistance(double meters) {
  if (!meters.isFinite) return '';
  if (meters < 1000) return '${meters.round()} m';
  final km = meters / 1000.0;
  return '${km.toStringAsFixed(km < 10 ? 1 : 0)} km';
}
