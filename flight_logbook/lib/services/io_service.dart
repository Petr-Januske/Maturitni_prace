import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../models/flight.dart';
import 'hive_service.dart';
import 'airport_index.dart';

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

  // Export single flight to a selected JSON file
  static Future<void> exportFlight(Flight f) async {
    final data = {
      'id': f.id,
      'date': f.date.toIso8601String(),
      'from': f.from,
      'to': f.to,
      'aircraft': f.aircraft,
      'registration': f.registration,
      'durationMinutes': f.durationMinutes,
      'remarks': f.remarks,
      'createdAt': f.createdAt?.toIso8601String(),
      'modifiedAt': f.modifiedAt?.toIso8601String(),
    };
    final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Uložit záznam letu jako JSON',
      type: FileType.custom,
      allowedExtensions: ['json'],
      fileName: 'flight_${f.id}.json',
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
      final acRaw = m['aircraft'] as String?;
      final ac = (acRaw != null && acRaw.trim().isEmpty) ? null : acRaw?.trim();

      final flight = Flight(
        id: 0,
        date: DateTime.parse(m['date'] as String),
        from: (m['from'] as String).toUpperCase(),
        to: (m['to'] as String).toUpperCase(),
        aircraft: ac,
        registration: (m['registration'] as String).toUpperCase(),
        durationMinutes: (m['durationMinutes'] as num).toInt(),
        remarks: m['remarks'] as String?,
      );
      await HiveService.addFlight(flight);
      count++;
    }
    return count;
  }

  // Import a FlightRadar-style CSV and return origin/destination info.
  // Returns a map with keys: 'from','to','from_coord','to_coord','callsign'
  static Future<Map<String, String>?> importFlightRadarCsv() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Vyberte FlightRadar CSV soubor',
      type: FileType.custom,
      allowedExtensions: ['csv', 'txt'],
    );
    if (result == null || result.files.isEmpty) return null;
    final path = result.files.single.path;
    if (path == null) return null;
    final file = File(path);
    final content = await file.readAsString();
    final lines = content.split(RegExp(r'\r?\n'));
    if (lines.length < 2) return null;

    // find first non-empty data row (skip header)
    int firstIdx = -1;
    int lastIdx = -1;
    for (int i = 1; i < lines.length; i++) {
      if (lines[i].trim().isEmpty) continue;
      firstIdx = i;
      break;
    }
    for (int i = lines.length - 1; i >= 1; i--) {
      if (lines[i].trim().isEmpty) continue;
      lastIdx = i;
      break;
    }
    if (firstIdx == -1 || lastIdx == -1) return null;

    final first = _parseCsvLine(lines[firstIdx]);
    final last = _parseCsvLine(lines[lastIdx]);
    if (first.length <= 3 || last.length <= 3) return null;

    String posFirst = first[3];
    String posLast = last[3];
    // position may be quoted "lat,lon"
    posFirst = posFirst.replaceAll('"', '');
    posLast = posLast.replaceAll('"', '');
    final a = posFirst.split(',');
    final b = posLast.split(',');
    if (a.length < 2 || b.length < 2) return null;
    final lat1 = double.tryParse(a[0].trim());
    final lon1 = double.tryParse(a[1].trim());
    final lat2 = double.tryParse(b[0].trim());
    final lon2 = double.tryParse(b[1].trim());
    if (lat1 == null || lon1 == null || lat2 == null || lon2 == null) return null;

    // parse UTC timestamps (column 1)
    DateTime? dtFirst;
    DateTime? dtLast;
    try {
      dtFirst = DateTime.parse(first[1]);
    } catch (_) {}
    try {
      dtLast = DateTime.parse(last[1]);
    } catch (_) {}

    await AirportIndex.ensureLoaded();
    // Use only a reasonable radius to find nearest airport (avoid distant false matches)
    var fromAirport = AirportIndex.nearest(lat1, lon1, maxKm: 100);
    var toAirport = AirportIndex.nearest(lat2, lon2, maxKm: 100);

    final callsign = (first.length > 2 ? first[2] : '').trim();

    // compute duration in minutes from timestamps if available
    int durationMinutes = 0;
    if (dtFirst != null && dtLast != null) {
      durationMinutes = dtLast.difference(dtFirst).inMinutes;
      if (durationMinutes < 0) durationMinutes = 0;
    }

    // create Flight and save to Hive
    final fromCode = (fromAirport?.code ?? '').toUpperCase();
    final toCode = (toAirport?.code ?? '').toUpperCase();
    final fromName = fromAirport?.name ?? '';
    final toName = toAirport?.name ?? '';
    final remarks = 'Imported from FlightRadar CSV${fromName.isNotEmpty ? ' • From: $fromName ($fromCode)' : ''}${toName.isNotEmpty ? ' • To: $toName ($toCode)' : ''}';

    final flight = Flight(
      id: 0,
      date: dtFirst ?? DateTime.now(),
      from: fromCode,
      to: toCode,
      aircraft: null,
      registration: callsign.toUpperCase(),
      durationMinutes: durationMinutes,
      remarks: remarks,
    );
    final newId = await HiveService.addFlight(flight);

    return {
      'callsign': callsign,
      'from': fromCode,
      'to': toCode,
      'from_name': fromName,
      'to_name': toName,
      'from_coord': '$lat1,$lon1',
      'to_coord': '$lat2,$lon2',
      'createdId': newId.toString(),
    };
  }

  // Very small CSV line parser that handles quoted fields with commas.
  static List<String> _parseCsvLine(String line) {
    final result = <String>[];
    final sb = StringBuffer();
    bool inQuotes = false;
    for (int i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        inQuotes = !inQuotes;
        continue;
      }
      if (ch == ',' && !inQuotes) {
        result.add(sb.toString());
        sb.clear();
        continue;
      }
      sb.write(ch);
    }
    result.add(sb.toString());
    return result;
  }

  // Let the user pick a CSV airports DB (e.g. OurAirports airports.csv) and load it.
  static Future<int> loadAirportsDb() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Vyberte CSV soubor letišť (např. OurAirports airports.csv)',
      type: FileType.custom,
      allowedExtensions: ['csv', 'txt'],
    );
    if (result == null || result.files.isEmpty) return 0;
    final path = result.files.single.path;
    if (path == null) return 0;
    final count = await AirportIndex.loadFromCsvFile(path);
    return count;
  }
}
