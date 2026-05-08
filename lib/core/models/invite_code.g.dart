// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'invite_code.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class InviteCodeAdapter extends TypeAdapter<InviteCode> {
  @override
  final int typeId = 2;

  @override
  InviteCode read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return InviteCode(
      code: fields[0] as String,
      refreshMode: fields[1] as InviteCodeRefreshMode,
      generatedAt: fields[2] as DateTime,
      expiresAt: fields[3] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, InviteCode obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.code)
      ..writeByte(1)
      ..write(obj.refreshMode)
      ..writeByte(2)
      ..write(obj.generatedAt)
      ..writeByte(3)
      ..write(obj.expiresAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InviteCodeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class InviteCodeRefreshModeAdapter extends TypeAdapter<InviteCodeRefreshMode> {
  @override
  final int typeId = 3;

  @override
  InviteCodeRefreshMode read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return InviteCodeRefreshMode.daily;
      case 1:
        return InviteCodeRefreshMode.onDemand;
      default:
        return InviteCodeRefreshMode.daily;
    }
  }

  @override
  void write(BinaryWriter writer, InviteCodeRefreshMode obj) {
    switch (obj) {
      case InviteCodeRefreshMode.daily:
        writer.writeByte(0);
        break;
      case InviteCodeRefreshMode.onDemand:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InviteCodeRefreshModeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
