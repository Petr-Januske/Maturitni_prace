import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Download OurAirports `airports.csv` and produce a minimal
/// `assets/airports_min.json` containing objects with keys: code,name,lat,lon
/// Usage:
///   dart run tool/import_ourairports.dart

Future<void> main(List<String> args) async {
  final url = Uri.parse('https://ourairports.com/data/airports.csv');
  stdout.writeln('Downloading $url');
  final res = await http.get(url).timeout(const Duration(seconds: 120));
  if (res.statusCode != 200) {
    stderr.writeln('Failed to download airports.csv: HTTP ${res.statusCode}');
    exit(2);
  }
  final content = res.body;
  final lines = content.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).toList();
  if (lines.isEmpty) {
    stderr.writeln('Downloaded file is empty');
    exit(3);
  }

  final header = _parseCsvLine(lines.first).map((s) => s.toLowerCase()).toList();
  final idx = <String, int>{};
  for (int i = 0; i < header.length; i++) idx[header[i]] = i;

  final identIdx = idx['ident'] ?? idx['icao'] ?? idx['code'] ?? -1;
  final nameIdx = idx['name'] ?? -1;
  final latIdx = idx['latitude_deg'] ?? idx['lat'] ?? -1;
  final lonIdx = idx['longitude_deg'] ?? idx['lon'] ?? -1;

  final Map<String, Map<String, dynamic>> byCode = {};

  double? _parseNum(String? s) {
    if (s == null) return null;
    return double.tryParse(s);
  }

  for (int i = 1; i < lines.length; i++) {
    final cols = _parseCsvLine(lines[i]);
    if (cols.length <= 2) continue;
    String code = '';
    if (identIdx >= 0 && identIdx < cols.length) code = cols[identIdx].trim().toUpperCase();
    if (code.isEmpty) continue;
    final lat = (latIdx >= 0 && latIdx < cols.length) ? _parseNum(cols[latIdx]) : null;
    final lon = (lonIdx >= 0 && lonIdx < cols.length) ? _parseNum(cols[lonIdx]) : null;
    if (lat == null || lon == null) continue;
    final name = (nameIdx >= 0 && nameIdx < cols.length) ? cols[nameIdx].trim() : code;

    // filter out numeric idents and weird entries
    if (RegExp(r'^[0-9]+$').hasMatch(code)) continue;
    // keep entries with ident length >= 3 (IATA or ICAO) or starting with letters
    if (code.length < 3 && !RegExp(r'^[A-Z]').hasMatch(code)) continue;

    byCode[code] = {
      'code': code,
      'name': name.isEmpty ? code : name,
      'lat': lat,
      'lon': lon,
    };
  }

  final list = byCode.values.toList()..sort((a, b) => (a['code'] as String).compareTo(b['code'] as String));
  final outPath = 'assets/airports_min.json';
  final encoder = const JsonEncoder.withIndent('  ');
  await File(outPath).writeAsString(encoder.convert(list));
  stdout.writeln('Wrote ${list.length} airports to $outPath');
}

List<String> _parseCsvLine(String line) {
  final result = <String>[];
  final sb = StringBuffer();
  bool inQuotes = false;
  for (int i = 0; i < line.length; i++) {
    final ch = line[i];
    if (ch == '"') {
      if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
        // escaped quote
        sb.write('"');
        i++; // skip next
        continue;
      }
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
