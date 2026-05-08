import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
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
  static Future<void>? _fmtcInitFuture;
  static const _storeName = 'amap_tiles';
  static const _tileSubdomains = <String>['1', '2', '3', '4'];

  static final Uint8List _grayPngBytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMB/Upm3XQAAAAASUVORK5CYII=',
  );

  final MapController _mapController = MapController();
  final TextEditingController _nameController = TextEditingController();

  Timer? _idleDebounce;
  StreamSubscription<DownloadProgress>? _downloadProgressSub;

  FMTCTileProvider? _tileProvider;
  FMTCStore? _store;
  Object? _downloadInstanceId;

  LatLng _selected = const LatLng(39.9, 116.4);
  String? _address;
  bool _geocoding = false;
  bool _downloading = false;
  int _tileReloadKey = 0;
  DateTime _lastCacheStart = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _initialise();
  }

  Future<void> _initialise() async {
    _fmtcInitFuture ??= FMTCObjectBoxBackend().initialise();
    await _fmtcInitFuture;

    final store = FMTCStore(_storeName);
    final ready = await store.manage.ready;
    if (!ready) {
      await store.manage.create();
    }

    final tileProvider = FMTCTileProvider(
      stores: const {_storeName: BrowseStoreStrategy.read},
      loadingStrategy: BrowseLoadingStrategy.cacheOnly,
      recordHitsAndMisses: false,
      errorHandler: (error) => _grayPngBytes,
    );

    if (!mounted) return;
    setState(() {
      _store = store;
      _tileProvider = tileProvider;
    });
  }

  @override
  void dispose() {
    _idleDebounce?.cancel();
    _idleDebounce = null;
    _downloadProgressSub?.cancel();
    _downloadProgressSub = null;

    final store = _store;
    final instanceId = _downloadInstanceId;
    if (store != null && instanceId != null) {
      unawaited(store.download.cancel(instanceId: instanceId));
    }

    _nameController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tileProvider = _tileProvider;
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
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _selected,
                      initialZoom: 14,
                      onPositionChanged: (camera, hasGesture) {
                        if (hasGesture) return;
                        _onMapIdle(camera.center);
                      },
                    ),
                    children: [
                      TileLayer(
                        key: ValueKey(_tileReloadKey),
                        urlTemplate: _amapUrlTemplate(widget.amapKey),
                        subdomains: _tileSubdomains,
                        tileProvider: tileProvider,
                        userAgentPackageName: 'com.example.pointer_app',
                        errorImage: MemoryImage(_grayPngBytes),
                      ),
                    ],
                  ),
                  const IgnorePointer(
                    child: Center(
                      child: Icon(Icons.add, color: Colors.white, size: 28),
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
                        const SizedBox(height: 12),
                        _CircleButton(
                          icon: Icons.download,
                          onTap: _downloadViewport,
                        ),
                      ],
                    ),
                  ),
                  if (_downloading)
                    const Positioned(
                      left: 16,
                      top: 16,
                      child: _Pill(text: '缓存中…'),
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

  void _onMapIdle(LatLng center) {
    _idleDebounce?.cancel();
    _idleDebounce = Timer(const Duration(milliseconds: 550), () {
      setState(() => _selected = center);
      unawaited(_reverseGeocode(center));
      unawaited(_downloadViewport());
    });
  }

  Future<void> _locateMe() async {
    try {
      final pos = await Geolocator.getCurrentPosition();
      final center = LatLng(pos.latitude, pos.longitude);
      _mapController.move(center, _mapController.camera.zoom);
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

  Future<void> _downloadViewport() async {
    final store = _store;
    if (store == null) return;

    final now = DateTime.now();
    if (now.difference(_lastCacheStart) < const Duration(seconds: 10)) return;
    _lastCacheStart = now;

    if (_downloading) return;
    setState(() => _downloading = true);

    _downloadProgressSub?.cancel();
    _downloadProgressSub = null;

    final instanceId = Object();
    _downloadInstanceId = instanceId;

    final bounds = _mapController.camera.visibleBounds;
    final zoom = _mapController.camera.zoom;
    final minZoom = (zoom.floor() - 1).clamp(3, 18);
    final maxZoom = (zoom.ceil() + 1).clamp(3, 19);

    final region = RectangleRegion(bounds).toDownloadable(
      minZoom: minZoom,
      maxZoom: maxZoom,
      options: TileLayer(
        urlTemplate: _amapUrlTemplate(widget.amapKey),
        subdomains: _tileSubdomains,
      ),
    );

    final streams = store.download.startForeground(
      region: region,
      parallelThreads: 4,
      maxBufferLength: 120,
      skipExistingTiles: true,
      instanceId: instanceId,
    );

    _downloadProgressSub = streams.downloadProgress.listen(
      (progress) {
        final processed =
            progress.successfulTilesCount +
            progress.existingTilesCount +
            progress.seaTilesCount +
            progress.negativeResponseTilesCount +
            progress.failedRequestTilesCount;

        if (processed >= progress.maxTilesCount) {
          if (!mounted) return;
          setState(() {
            _downloading = false;
            _tileReloadKey++;
          });
        }
      },
      onDone: () {
        if (!mounted) return;
        setState(() {
          _downloading = false;
          _tileReloadKey++;
        });
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!mounted) return;
        setState(() => _downloading = false);
      },
    );
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

class _Pill extends StatelessWidget {
  const _Pill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xCC000000),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x1FFFFFFF)),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}
