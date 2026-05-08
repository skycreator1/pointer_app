// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'paired_device.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PairedDeviceAdapter extends TypeAdapter<PairedDevice> {
  @override
  final int typeId = 1;

  @override
  PairedDevice read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PairedDevice(
      pairId: fields[0] as String,
      nickname: fields[1] as String,
      inviteCode: fields[2] as String,
      lastSeen: fields[3] as DateTime,
      isOnline: fields[4] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, PairedDevice obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.pairId)
      ..writeByte(1)
      ..write(obj.nickname)
      ..writeByte(2)
      ..write(obj.inviteCode)
      ..writeByte(3)
      ..write(obj.lastSeen)
      ..writeByte(4)
      ..write(obj.isOnline);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PairedDeviceAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
