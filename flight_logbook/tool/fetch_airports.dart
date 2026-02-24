import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Fetch airports from aviationstack and write a minimal `assets/airports_min.json`.
/// Usage:
///   dart run tool/fetch_airports.dart YOUR_KEY
/// or set environment variable `AVIATIONSTACK_KEY`.

Future<void> main(List<String> args) async {
  final key = args.isNotEmpty ? args[0] : Platform.environment['AVIATIONSTACK_KEY'];
  if (key == null || key.isEmpty) {
    stderr.writeln('API key required: pass as first arg or set AVIATIONSTACK_KEY');
    exit(2);
  }

  final Map<String, Map<String, dynamic>> byCode = {};
  const int limit = 100;
  int page = 1;

  while (true) {
    final uri = Uri.parse('https://api.aviationstack.com/v1/airports?access_key=$key&limit=$limit&page=$page');
    stdout.writeln('Fetching page $page...');
    final res = await http.get(uri).timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) {
      stderr.writeln('HTTP ${res.statusCode}: ${res.body}');
      // if we already fetched some pages, write partial output so work isn't lost
      if (byCode.isNotEmpty) {
        final partial = byCode.values.toList()
          ..sort((a, b) => (a['code'] as String).compareTo(b['code'] as String));
        final outPath = 'assets/airports_min.json';
        final encoder = const JsonEncoder.withIndent('  ');
        await File(outPath).writeAsString(encoder.convert(partial));
        stdout.writeln('Wrote partial ${partial.length} airports to $outPath due to HTTP ${res.statusCode}');
      }
      exit(3);
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final raw = (body['data'] as List?) ?? [];
    final data = raw.cast<Map<String, dynamic>>();
    if (data.isEmpty) break;

    double? _parseNum(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    for (final item in data) {
      final code = (item['icao'] ?? item['iata'] ?? item['iata_code'] ?? item['icao_code'] ?? '').toString().trim();
      if (code.isEmpty) continue;
      double? lat = _parseNum(item['latitude']);
      double? lon = _parseNum(item['longitude']);
      if (lat == null || lon == null) {
        // try alternative keys
        lat ??= _parseNum(item['latitude_deg']);
        lon ??= _parseNum(item['longitude_deg']);
      }
      if (lat == null || lon == null) continue;
      final name = (item['airport_name'] ?? item['name'] ?? item['airport'] ?? '').toString().trim();
      byCode[code.toUpperCase()] = {
        'code': code.toUpperCase(),
        'name': name.isEmpty ? code.toUpperCase() : name,
        'lat': lat,
        'lon': lon,
      };
    }

    if (data.length < limit) break;
    page++;
    // safety: avoid infinite loops
    if (page > 1000) break;
  }

  final list = byCode.values.toList()
    ..sort((a, b) => (a['code'] as String).compareTo(b['code'] as String));

  final outPath = 'assets/airports_min.json';
  final encoder = const JsonEncoder.withIndent('  ');
  final jsonStr = encoder.convert(list);
  final file = File(outPath);
  await file.writeAsString(jsonStr);
  stdout.writeln('Wrote ${list.length} airports to $outPath');
}
