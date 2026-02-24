import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:latlong2/latlong.dart';
import '../models/flight.dart';
import '../services/airport_index.dart';
import '../services/hive_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  bool _loaded = false;
  String? _selectedAirportCode;
  List<Polyline> _polylines = [];

  @override
  void initState() {
    super.initState();
    AirportIndex.ensureLoaded().then((_) => setState(() => _loaded = true));
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final box = Hive.box<Flight>(HiveService.flightsBoxName);

    return Scaffold(
      appBar: AppBar(title: const Text('Mapa letišť')),
      body: ValueListenableBuilder(
        valueListenable: box.listenable(),
        builder: (context, Box<Flight> b, _) {
          final markers = _buildMarkers(b.values);
          final center = markers.isNotEmpty ? markers.first.point : const LatLng(49.8, 15.5); // CZ center
          return FlutterMap(
            options: MapOptions(initialCenter: center, initialZoom: 6),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'flight_logbook',
              ),
              if (_polylines.isNotEmpty) PolylineLayer(polylines: _polylines),
              MarkerLayer(markers: markers),
            ],
          );
        },
      ),
    );
  }

  List<Marker> _buildMarkers(Iterable<Flight> flights) {
    final seen = <String>{};
    final markers = <Marker>[];
    for (final f in flights) {
      for (final code in [f.from, f.to]) {
        if (seen.contains(code)) continue;
        seen.add(code);
        final a = AirportIndex.byCode(code);
        if (a == null) continue;
        markers.add(Marker(
          point: LatLng(a.lat, a.lon),
          width: 40,
          height: 40,
          child: MouseRegion(
            onEnter: (_) => _onAirportHover(a),
            onExit: (_) => _clearPolylines(),
            child: GestureDetector(
              onTap: () => _showAirportDetails(a),
              onLongPress: () => _onAirportHover(a),
              onLongPressEnd: (_) => _clearPolylines(),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black26, offset: Offset(0,2))],
                ),
                child: const Center(
                  child: Icon(Icons.airplanemode_active, color: Colors.white, size: 18),
                ),
              ),
            ),
          ),
        ));
      }
    }
    return markers;
  }

  void _onAirportHover(a) {
    if (_selectedAirportCode == a.code) return;
    final box = Hive.box<Flight>(HiveService.flightsBoxName);
    final flightsFrom = box.values.where((f) => f.from == a.code).toList();
    final destCodes = <String>{};
    final polylines = <Polyline>[];
    for (final f in flightsFrom) {
      final dest = f.to;
      if (destCodes.contains(dest)) continue;
      destCodes.add(dest);
      final da = AirportIndex.byCode(dest);
      if (da == null) continue;
      polylines.add(Polyline(points: [LatLng(a.lat, a.lon), LatLng(da.lat, da.lon)], strokeWidth: 3.0, color: Colors.blue.withOpacity(0.8)));
    }
    setState(() {
      _selectedAirportCode = a.code;
      _polylines = polylines;
    });
  }

  void _clearPolylines() {
    if (_selectedAirportCode == null) return;
    setState(() {
      _selectedAirportCode = null;
      _polylines = [];
    });
  }

  Future<void> _showAirportDetails(a) async {
    final box = Hive.box<Flight>(HiveService.flightsBoxName);
    final flightsFrom = box.values.where((f) => f.from == a.code).toList();
    final destCodes = <String>{};
    final polylines = <Polyline>[];
    for (final f in flightsFrom) {
      final dest = f.to;
      if (destCodes.contains(dest)) continue;
      destCodes.add(dest);
      final da = AirportIndex.byCode(dest);
      if (da == null) continue;
      polylines.add(Polyline(points: [LatLng(a.lat, a.lon), LatLng(da.lat, da.lon)], strokeWidth: 3.0, color: Colors.blue.withOpacity(0.8)));
    }

    setState(() {
      _selectedAirportCode = a.code;
      _polylines = polylines;
    });

    await showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${a.code}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(a.name ?? '', style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 12),
            if (destCodes.isEmpty) const Text('Žádné lety z tohoto letiště.'),
            if (destCodes.isNotEmpty) ...[
              const Text('Letěl jsi z tohoto letiště do:'),
              const SizedBox(height: 8),
              for (final code in destCodes)
                Builder(
                  builder: (ctx2) {
                    final da = AirportIndex.byCode(code);
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text('$code ${da?.name ?? ''}'),
                    );
                  },
                ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Zavřít'),
              ),
            ),
          ],
        ),
      ),
    );

    setState(() {
      _selectedAirportCode = null;
      _polylines = [];
    });
  }
}
