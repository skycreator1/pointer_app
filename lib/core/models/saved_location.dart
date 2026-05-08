import 'package:hive/hive.dart';

part 'saved_location.g.dart';

@HiveType(typeId: 0)
class SavedLocation {
  const SavedLocation({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
  });

  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final double latitude;

  @HiveField(3)
  final double longitude;

  @HiveField(4)
  final DateTime createdAt;
}
