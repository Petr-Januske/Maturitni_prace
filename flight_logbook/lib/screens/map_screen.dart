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
          width: 120,
          height: 40,
          child: Column(
            children: [
              const Icon(Icons.location_on, color: Colors.red, size: 28),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), boxShadow: const [BoxShadow(blurRadius: 2, color: Colors.black26)]),
                child: Text('${a.code} • ${a.name}', style: const TextStyle(fontSize: 10)),
              ),
            ],
          ),
        ));
      }
    }
    return markers;
  }
}
