import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../models/flight.dart';
import 'hive_service.dart';

class IOSimple {
  // Export all flights to a selected JSON file
  static Future<void> exportFlights() async {
    final flights = HiveService.getAllFlights();
    final data = flights.map((f) => {
          'id': f.id,
          'date': f.date.toIso8601String(),
          'from': f.from,
          'to': f.to,
          'aircraft': f.aircraft,
          'registration': f.registration,
          'durationMinutes': f.durationMinutes,
          'remarks': f.remarks,
        }).toList();
    final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Uložit lety jako JSON',
      type: FileType.custom,
      allowedExtensions: ['json'],
      fileName: 'flights.json',
    );
    if (savePath == null) return;
    final file = File(savePath);
    await file.writeAsString(jsonStr);
  }

  // Import flights from chosen JSON file
  static Future<int> importFlights() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Vyberte JSON soubor letů',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.isEmpty) return 0;
    final path = result.files.single.path;
    if (path == null) return 0;
    final file = File(path);
    final content = await file.readAsString();
    final list = jsonDecode(content) as List<dynamic>;
    int count = 0;
    for (final item in list) {
      final m = item as Map<String, dynamic>;
      final flight = Flight(
        id: 0,
        date: DateTime.parse(m['date'] as String),
        from: (m['from'] as String).toUpperCase(),
        to: (m['to'] as String).toUpperCase(),
        aircraft: m['aircraft'] as String,
        registration: (m['registration'] as String).toUpperCase(),
        durationMinutes: (m['durationMinutes'] as num).toInt(),
        remarks: m['remarks'] as String?,
      );
      await HiveService.addFlight(flight);
      count++;
    }
    return count;
  }
}
