import 'dart:async';

import 'package:flutter/material.dart';

enum ConnectResult { approve, reject, timeout }

Future<({ConnectResult result, String? nickname})?> showConnectRequestDialog(
  BuildContext context, {
  required String requestId,
  required String deviceNickname,
}) {
  return showDialog<({ConnectResult result, String? nickname})?>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return _ConnectRequestDialog(
        requestId: requestId,
        deviceNickname: deviceNickname,
      );
    },
  );
}

class _ConnectRequestDialog extends StatefulWidget {
  const _ConnectRequestDialog({
    required this.requestId,
    required this.deviceNickname,
  });

  final String requestId;
  final String deviceNickname;

  @override
  State<_ConnectRequestDialog> createState() => _ConnectRequestDialogState();
}

class _ConnectRequestDialogState extends State<_ConnectRequestDialog> {
  static const int _timeoutSeconds = 60;

  Timer? _timer;
  var _remaining = _timeoutSeconds;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _remaining -= 1;
      });
      if (_remaining <= 0) {
        _timer?.cancel();
        _timer = null;
        Navigator.of(
          context,
        ).pop((result: ConnectResult.timeout, nickname: null));
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _remaining.clamp(0, _timeoutSeconds) / _timeoutSeconds;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: const Color(0xFF141416),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.deviceNickname,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '请求与你连接',
              style: TextStyle(fontSize: 14, color: Color(0xB3FFFFFF)),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: const Color(0xFF2A2A2E),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$_remaining s',
              style: const TextStyle(fontSize: 12, color: Color(0xB3FFFFFF)),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF2A2A2E)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(
                        context,
                      ).pop((result: ConnectResult.reject, nickname: null));
                    },
                    child: const Text('拒绝'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      final navigator = Navigator.of(context);
                      final nickname = await _askPeerNickname(context);
                      if (!context.mounted) return;
                      navigator.pop((
                        result: ConnectResult.approve,
                        nickname: nickname,
                      ));
                    },
                    child: const Text('同意'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _askPeerNickname(BuildContext context) async {
    final platform = Theme.of(context).platform;
    final defaultNickname = platform == TargetPlatform.android
        ? 'Android 设备'
        : platform == TargetPlatform.iOS
        ? 'iOS 设备'
        : '设备';
    final controller = TextEditingController();

    final result = await showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('设置对方昵称'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(hintText: defaultNickname),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('跳过'),
            ),
            TextButton(
              onPressed: () {
                final text = controller.text.trim();
                Navigator.of(
                  context,
                ).pop(text.isEmpty ? defaultNickname : text);
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );

    controller.dispose();
    return result;
  }
}
