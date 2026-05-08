import 'package:hive/hive.dart';

part 'invite_code.g.dart';

@HiveType(typeId: 3)
enum InviteCodeRefreshMode {
  @HiveField(0)
  daily,
  @HiveField(1)
  onDemand,
}

@HiveType(typeId: 2)
class InviteCode {
  const InviteCode({
    required this.code,
    required this.refreshMode,
    required this.generatedAt,
    required this.expiresAt,
  });

  @HiveField(0)
  final String code;

  @HiveField(1)
  final InviteCodeRefreshMode refreshMode;

  @HiveField(2)
  final DateTime generatedAt;

  @HiveField(3)
  final DateTime expiresAt;
}
