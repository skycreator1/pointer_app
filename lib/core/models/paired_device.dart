import 'package:hive/hive.dart';

part 'paired_device.g.dart';

@HiveType(typeId: 1)
class PairedDevice {
  const PairedDevice({
    required this.pairId,
    required this.nickname,
    required this.inviteCode,
    required this.lastSeen,
    required this.isOnline,
  });

  @HiveField(0)
  final String pairId;

  @HiveField(1)
  final String nickname;

  @HiveField(2)
  final String inviteCode;

  @HiveField(3)
  final DateTime lastSeen;

  @HiveField(4)
  final bool isOnline;
}
