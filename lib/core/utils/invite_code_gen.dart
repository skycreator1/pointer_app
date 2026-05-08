import 'dart:convert';

import 'package:pointer_app/core/models/invite_code.dart';

typedef RefreshMode = InviteCodeRefreshMode;

String generateCode(String userId, RefreshMode mode, {DateTime Function()? now}) {
  final resolvedNow = now ?? DateTime.now;
  final nowValue = resolvedNow();

  final input = switch (mode) {
    RefreshMode.daily => '$userId${_yyyyMMdd(nowValue)}',
    RefreshMode.onDemand => '$userId${nowValue.millisecondsSinceEpoch}',
  };

  final digestHexUpper = _sha256HexUpper(input);
  return _takeFirst8NonAmbiguousUpper(digestHexUpper, fallbackSeed: input);
}

bool isCodeExpired(InviteCode code) {
  final now = DateTime.now();

  return switch (code.refreshMode) {
    RefreshMode.daily => now.isAfter(_endOfDay(code.generatedAt)),
    RefreshMode.onDemand => false,
  };
}

String _yyyyMMdd(DateTime dt) {
  final y = dt.year.toString().padLeft(4, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  return '$y$m$d';
}

DateTime _endOfDay(DateTime dt) {
  return DateTime(dt.year, dt.month, dt.day, 23, 59, 59, 999);
}

String _takeFirst8NonAmbiguousUpper(String sourceUpper, {required String fallbackSeed}) {
  const needed = 8;
  const excluded = {'0', '1', 'O', 'I'};

  final out = StringBuffer();
  var cursorSource = sourceUpper;
  var counter = 0;

  while (out.length < needed) {
    for (var i = 0; i < cursorSource.length && out.length < needed; i++) {
      final ch = cursorSource[i];
      if (excluded.contains(ch)) continue;
      out.write(ch);
    }

    if (out.length >= needed) break;

    counter++;
    cursorSource = _sha256HexUpper('$fallbackSeed#$counter');
  }

  return out.toString();
}

String _sha256HexUpper(String input) {
  final bytes = utf8.encode(input);
  final digest = _sha256(bytes);
  final sb = StringBuffer();
  for (final b in digest) {
    sb.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return sb.toString().toUpperCase();
}

List<int> _sha256(List<int> data) {
  final message = _padMessage(data);
  var h0 = 0x6a09e667;
  var h1 = 0xbb67ae85;
  var h2 = 0x3c6ef372;
  var h3 = 0xa54ff53a;
  var h4 = 0x510e527f;
  var h5 = 0x9b05688c;
  var h6 = 0x1f83d9ab;
  var h7 = 0x5be0cd19;

  final w = List<int>.filled(64, 0);

  for (var chunkOffset = 0; chunkOffset < message.length; chunkOffset += 64) {
    for (var i = 0; i < 16; i++) {
      final j = chunkOffset + i * 4;
      w[i] = ((message[j] << 24) |
              (message[j + 1] << 16) |
              (message[j + 2] << 8) |
              (message[j + 3])) &
          0xffffffff;
    }

    for (var i = 16; i < 64; i++) {
      final s0 = _rotr32(w[i - 15], 7) ^ _rotr32(w[i - 15], 18) ^ _shr32(w[i - 15], 3);
      final s1 = _rotr32(w[i - 2], 17) ^ _rotr32(w[i - 2], 19) ^ _shr32(w[i - 2], 10);
      w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & 0xffffffff;
    }

    var a = h0;
    var b = h1;
    var c = h2;
    var d = h3;
    var e = h4;
    var f = h5;
    var g = h6;
    var h = h7;

    for (var i = 0; i < 64; i++) {
      final s1 = _rotr32(e, 6) ^ _rotr32(e, 11) ^ _rotr32(e, 25);
      final ch = (e & f) ^ ((~e) & g);
      final temp1 = (h + s1 + ch + _k256[i] + w[i]) & 0xffffffff;
      final s0 = _rotr32(a, 2) ^ _rotr32(a, 13) ^ _rotr32(a, 22);
      final maj = (a & b) ^ (a & c) ^ (b & c);
      final temp2 = (s0 + maj) & 0xffffffff;

      h = g;
      g = f;
      f = e;
      e = (d + temp1) & 0xffffffff;
      d = c;
      c = b;
      b = a;
      a = (temp1 + temp2) & 0xffffffff;
    }

    h0 = (h0 + a) & 0xffffffff;
    h1 = (h1 + b) & 0xffffffff;
    h2 = (h2 + c) & 0xffffffff;
    h3 = (h3 + d) & 0xffffffff;
    h4 = (h4 + e) & 0xffffffff;
    h5 = (h5 + f) & 0xffffffff;
    h6 = (h6 + g) & 0xffffffff;
    h7 = (h7 + h) & 0xffffffff;
  }

  return <int>[
    ..._int32ToBytes(h0),
    ..._int32ToBytes(h1),
    ..._int32ToBytes(h2),
    ..._int32ToBytes(h3),
    ..._int32ToBytes(h4),
    ..._int32ToBytes(h5),
    ..._int32ToBytes(h6),
    ..._int32ToBytes(h7),
  ];
}

List<int> _padMessage(List<int> data) {
  final message = List<int>.from(data);
  final bitLen = message.length * 8;

  message.add(0x80);

  while ((message.length % 64) != 56) {
    message.add(0x00);
  }

  for (var i = 7; i >= 0; i--) {
    message.add((bitLen >> (8 * i)) & 0xff);
  }

  return message;
}

List<int> _int32ToBytes(int v) {
  return <int>[
    (v >> 24) & 0xff,
    (v >> 16) & 0xff,
    (v >> 8) & 0xff,
    v & 0xff,
  ];
}

int _rotr32(int x, int n) {
  final v = x & 0xffffffff;
  return ((v >> n) | (v << (32 - n))) & 0xffffffff;
}

int _shr32(int x, int n) => (x & 0xffffffff) >> n;

const List<int> _k256 = <int>[
  0x428a2f98,
  0x71374491,
  0xb5c0fbcf,
  0xe9b5dba5,
  0x3956c25b,
  0x59f111f1,
  0x923f82a4,
  0xab1c5ed5,
  0xd807aa98,
  0x12835b01,
  0x243185be,
  0x550c7dc3,
  0x72be5d74,
  0x80deb1fe,
  0x9bdc06a7,
  0xc19bf174,
  0xe49b69c1,
  0xefbe4786,
  0x0fc19dc6,
  0x240ca1cc,
  0x2de92c6f,
  0x4a7484aa,
  0x5cb0a9dc,
  0x76f988da,
  0x983e5152,
  0xa831c66d,
  0xb00327c8,
  0xbf597fc7,
  0xc6e00bf3,
  0xd5a79147,
  0x06ca6351,
  0x14292967,
  0x27b70a85,
  0x2e1b2138,
  0x4d2c6dfc,
  0x53380d13,
  0x650a7354,
  0x766a0abb,
  0x81c2c92e,
  0x92722c85,
  0xa2bfe8a1,
  0xa81a664b,
  0xc24b8b70,
  0xc76c51a3,
  0xd192e819,
  0xd6990624,
  0xf40e3585,
  0x106aa070,
  0x19a4c116,
  0x1e376c08,
  0x2748774c,
  0x34b0bcb5,
  0x391c0cb3,
  0x4ed8aa4a,
  0x5b9cca4f,
  0x682e6ff3,
  0x748f82ee,
  0x78a5636f,
  0x84c87814,
  0x8cc70208,
  0x90befffa,
  0xa4506ceb,
  0xbef9a3f7,
  0xc67178f2,
];
