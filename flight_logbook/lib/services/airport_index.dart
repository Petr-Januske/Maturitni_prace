import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;

class Airport {
  final String code;
  final String name;
  final double lat;
  final double lon;
  Airport({required this.code, required this.name, required this.lat, required this.lon});
}

class AirportIndex {
  static Map<String, Airport>? _byCode;
  static List<Airport>? _list;
  static bool _loadedFromAssets = false;


  static Future<void> ensureLoaded() async {
    if (_byCode != null) return;
    final data = await rootBundle.loadString('assets/airports_min.json');
    final list = (jsonDecode(data) as List).cast<Map<String, dynamic>>();
    _byCode = {
      for (final e in list)
        (e['code'] as String).toUpperCase(): Airport(
          code: (e['code'] as String).toUpperCase(),
          name: e['name'] as String,
          lat: (e['lat'] as num).toDouble(),
          lon: (e['lon'] as num).toDouble(),
        )
    };
    _list = _byCode!.values.toList(growable: false);
    _loadedFromAssets = true;
  }

  // Load airports from a CSV file on disk. The CSV should contain columns
  // with headers including one of: ident/icao/code, name, latitude_deg, longitude_deg
  static Future<int> loadFromCsvFile(String path) async {
    final file = File(path);
    if (!await file.exists()) return 0;
    final content = await file.readAsString();
    final lines = content.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return 0;
    final header = _parseCsvLine(lines.first);
    final idx = <String, int>{};
    for (int i = 0; i < header.length; i++) {
      idx[header[i].toLowerCase()] = i;
    }

    int identIdx = idx['ident'] ?? idx['icao'] ?? idx['code'] ?? -1;
    int nameIdx = idx['name'] ?? idx['airport_name'] ?? -1;
    int latIdx = idx['latitude_deg'] ?? idx['lat'] ?? -1;
    int lonIdx = idx['longitude_deg'] ?? idx['lon'] ?? -1;

    final map = <String, Airport>{};
    for (int i = 1; i < lines.length; i++) {
      final cols = _parseCsvLine(lines[i]);
      if (cols.length <= 2) continue;
      String code = '';
      if (identIdx >= 0 && identIdx < cols.length) code = cols[identIdx].trim().toUpperCase();
      if (code.isEmpty && nameIdx >= 0 && nameIdx < cols.length) code = cols[nameIdx].trim().toUpperCase();
      double? lat;
      double? lon;
      if (latIdx >= 0 && latIdx < cols.length) lat = double.tryParse(cols[latIdx]);
      if (lonIdx >= 0 && lonIdx < cols.length) lon = double.tryParse(cols[lonIdx]);
      // fallback: try numeric columns
      if ((lat == null || lon == null) && cols.length >= 5) {
        lat ??= double.tryParse(cols[4]);
        lon ??= double.tryParse(cols[5]);
      }
      if (code.isEmpty || lat == null || lon == null) continue;
      final name = (nameIdx >= 0 && nameIdx < cols.length) ? cols[nameIdx] : code;
      map[code] = Airport(code: code, name: name, lat: lat, lon: lon);
    }
    if (map.isEmpty) return 0;
    _byCode = map;
    _list = _byCode!.values.toList(growable: false);
    _loadedFromAssets = false;
    return _byCode!.length;
  }

  static int count() => _byCode?.length ?? 0;

  static Airport? byCode(String code) {
    final map = _byCode;
    if (map == null) return null;
    return map[code.toUpperCase()];
  }

  // Find nearest airport to given lat/lon within `maxKm` kilometers.
  static Airport? nearest(double lat, double lon, {double maxKm = 200}) {
    final list = _list ?? _byCode?.values.toList();
    if (list == null || list.isEmpty) return null;
    double best = double.infinity;
    Airport? bestA;
    for (final a in list) {
      final d = _distanceKm(lat, lon, a.lat, a.lon);
      if (d < best) {
        best = d;
        bestA = a;
      }
    }
    if (best <= maxKm) return bestA;
    // if we loaded only the small bundled asset, avoid returning distant matches
    if (_loadedFromAssets) return null;
    return bestA; // when loaded from a real DB, allow any-distance match
  }

  static double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0; // Earth radius km
    final phi1 = _deg2rad(lat1);
    final phi2 = _deg2rad(lat2);
    final dphi = _deg2rad(lat2 - lat1);
    final dlambda = _deg2rad(lon2 - lon1);
    final a =
        (sin(dphi / 2) * sin(dphi / 2)) +
        cos(phi1) * cos(phi2) * (sin(dlambda / 2) * sin(dlambda / 2));
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  static double _deg2rad(double deg) => deg * (pi / 180.0);

  // Search airports by code or name (case-insensitive). Returns up to [limit] matches.
  static List<Airport> search(String query, {int limit = 10}) {
    if (query.trim().isEmpty) return const [];
    final q = query.toLowerCase();
    final list = _list ?? _byCode?.values.toList(growable: false) ?? const [];
    final matches = list.where((a) {
      return a.code.toLowerCase().contains(q) || a.name.toLowerCase().contains(q);
    }).toList();
    matches.sort((a, b) {
      final ai = a.code.toLowerCase().indexOf(q);
      final bi = b.code.toLowerCase().indexOf(q);
      if (ai != bi) return ai.compareTo(bi);
      return a.name.compareTo(b.name);
    });
    if (matches.length > limit) return matches.sublist(0, limit);
    return matches;
  }

  // reuse CSV line parser for loading
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
}
