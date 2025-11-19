import 'dart:convert';
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
  }

  static Airport? byCode(String code) {
    final map = _byCode;
    if (map == null) return null;
    return map[code.toUpperCase()];
  }
}
