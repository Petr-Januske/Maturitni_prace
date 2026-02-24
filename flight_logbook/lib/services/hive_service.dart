import 'package:hive_flutter/hive_flutter.dart';
import '../models/flight.dart';

class HiveService {
  static const String flightsBoxName = 'flights';
  static const String pilotBoxName = 'pilot_profile';

  static Future<void> init() async {
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(FlightAdapter());
    }
    await Hive.openBox<Flight>(flightsBoxName);
    await Hive.openBox(pilotBoxName);
  }

  static Box<Flight> _box() => Hive.box<Flight>(flightsBoxName);

  static List<Flight> getAllFlights() {
    final flights = _box().values.toList(growable: false);
    flights.sort((a, b) => b.date.compareTo(a.date));
    return flights;
  }

  static Future<int> addFlight(Flight flight) async {
    final newId = (_box().isEmpty ? 1 : ((_box().values.map((f) => f.id).reduce((a, b) => a > b ? a : b)) + 1));
    final now = DateTime.now();
    final newFlight = flight.copyWith(id: newId, createdAt: now, modifiedAt: now);
    await _box().put(newId, newFlight);
    return newId;
  }

  static Future<void> updateFlight(Flight flight) async {
    final updated = flight.copyWith(modifiedAt: DateTime.now());
    await _box().put(flight.id, updated);
  }

  static Future<void> deleteFlight(int id) async {
    await _box().delete(id);
  }

  static double getTotalHours() {
    return _box().values.fold<double>(0.0, (sum, f) => sum + f.durationHours);
  }

  // Pilot profile stored as a simple map in a separate box.
  // Keys: name:String, license:String, ratings:List<String>, allowedAircraft:List<String>
  static Box _pilotBox() => Hive.box(pilotBoxName);

  static Map<String, dynamic> getPilotProfile() {
    final raw = _pilotBox().get('profile');
    if (raw == null) return {};
    if (raw is Map) {
      final result = <String, dynamic>{};
      raw.forEach((k, v) {
        result[k.toString()] = v;
      });
      return result;
    }
    return {};
  }

  static Future<void> savePilotProfile(Map<String, dynamic> profile) async {
    await _pilotBox().put('profile', profile);
  }
}
