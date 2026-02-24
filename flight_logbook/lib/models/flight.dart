import 'package:hive/hive.dart';

class Flight {
  final int id;
  final DateTime date;
  final String from;
  final String to;
  final String? aircraft;
  final String registration;
  final int durationMinutes;
  final String? remarks;
  final DateTime? createdAt;
  final DateTime? modifiedAt;

  const Flight({
    required this.id,
    required this.date,
    required this.from,
    required this.to,
    this.aircraft,
    required this.registration,
    required this.durationMinutes,
    this.remarks,
    this.createdAt,
    this.modifiedAt,
  });

  Flight copyWith({
    int? id,
    DateTime? date,
    String? from,
    String? to,
    String? aircraft,
    String? registration,
    int? durationMinutes,
    String? remarks,
    DateTime? createdAt,
    DateTime? modifiedAt,
  }) => Flight(
        id: id ?? this.id,
        date: date ?? this.date,
        from: from ?? this.from,
        to: to ?? this.to,
        aircraft: aircraft ?? this.aircraft,
        registration: registration ?? this.registration,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        remarks: remarks ?? this.remarks,
        createdAt: createdAt ?? this.createdAt,
        modifiedAt: modifiedAt ?? this.modifiedAt,
      );

  double get durationHours => durationMinutes / 60.0;
}

class FlightAdapter extends TypeAdapter<Flight> {
  @override
  final int typeId = 0;

  @override
  Flight read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return Flight(
      id: fields[0] as int,
      date: DateTime.fromMillisecondsSinceEpoch(fields[1] as int),
      from: fields[2] as String,
      to: fields[3] as String,
      aircraft: fields[4] as String?,
      registration: fields[5] as String,
      durationMinutes: fields[6] as int,
      remarks: fields[7] as String?,
      createdAt: fields.containsKey(8) && fields[8] != null ? DateTime.fromMillisecondsSinceEpoch(fields[8] as int) : null,
      modifiedAt: fields.containsKey(9) && fields[9] != null ? DateTime.fromMillisecondsSinceEpoch(fields[9] as int) : null,
    );
  }

  @override
  void write(BinaryWriter writer, Flight obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.date.millisecondsSinceEpoch)
      ..writeByte(2)
      ..write(obj.from)
      ..writeByte(3)
      ..write(obj.to)
      ..writeByte(4)
      ..write(obj.aircraft)
      ..writeByte(5)
      ..write(obj.registration)
      ..writeByte(6)
      ..write(obj.durationMinutes)
      ..writeByte(7)
      ..write(obj.remarks)
      ..writeByte(8)
      ..write(obj.createdAt?.millisecondsSinceEpoch)
      ..writeByte(9)
      ..write(obj.modifiedAt?.millisecondsSinceEpoch);
  }
}
