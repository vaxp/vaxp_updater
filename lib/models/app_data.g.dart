// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_data.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************


class AppDataAdapter extends TypeAdapter<AppData> {
  @override
  final int typeId = 0;

  @override
  AppData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AppData(
      name: fields[0] as String,
      package: fields[1] as String,
      currentVersion: fields[2] as String,
      updateJsonUrl: fields[3] as String,
      installed: fields[4] as bool? ?? false,
      lastIndexFetch: fields[5] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, AppData obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.package)
      ..writeByte(2)
      ..write(obj.currentVersion)
      ..writeByte(3)
      ..write(obj.updateJsonUrl)
      ..writeByte(4)
      ..write(obj.installed)
      ..writeByte(5)
      ..write(obj.lastIndexFetch);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
