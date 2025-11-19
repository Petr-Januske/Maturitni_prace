import 'package:hive_flutter/hive_flutter.dart';
import '../models/flight.dart';

class HiveService {
  static const String flightsBoxName = 'flights';

  static Future<void> init() async {
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(FlightAdapter());
    }
    await Hive.openBox<Flight>(flightsBoxName);
  }

  static Box<Flight> _box() => Hive.box<Flight>(flightsBoxName);

  static List<Flight> getAllFlights() {
    final flights = _box().values.toList(growable: false);
    flights.sort((a, b) => b.date.compareTo(a.date));
    return flights;
  }

  static Future<int> addFlight(Flight flight) async {
    final newId = (_box().isEmpty ? 1 : ((_box().values.map((f) => f.id).reduce((a, b) => a > b ? a : b)) + 1));
    final newFlight = flight.copyWith(id: newId);
    await _box().put(newId, newFlight);
    return newId;
  }

  static Future<void> updateFlight(Flight flight) async {
    await _box().put(flight.id, flight);
  }

  static Future<void> deleteFlight(int id) async {
    await _box().delete(id);
  }

  static double getTotalHours() {
    return _box().values.fold<double>(0.0, (sum, f) => sum + f.durationHours);
  }
}
