import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../models/flight.dart';
import '../services/hive_service.dart';
import 'add_edit_flight_screen.dart';

class FlightsListScreen extends StatelessWidget {
  const FlightsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final box = Hive.box<Flight>(HiveService.flightsBoxName);
    final df = DateFormat.yMMMd();
    return Scaffold(
      appBar: AppBar(title: const Text('Lety')),
      body: ValueListenableBuilder(
        valueListenable: box.listenable(),
        builder: (context, Box<Flight> b, _) {
          final flights = b.values.toList()
            ..sort((a, b) => b.date.compareTo(a.date));
          if (flights.isEmpty) {
            return const Center(child: Text('Zatím žádné záznamy letů.'));
          }
          return ListView.builder(
            itemCount: flights.length,
            itemBuilder: (context, i) {
              final f = flights[i];
              return Dismissible(
                key: ValueKey(f.id),
                background: Container(color: Colors.red),
                onDismissed: (_) => HiveService.deleteFlight(f.id),
                child: ListTile(
                  title: Text('${df.format(f.date)} • ${f.from} → ${f.to}'),
                  subtitle: Text('${f.aircraft} ${f.registration}${f.remarks != null && f.remarks!.isNotEmpty ? ' • ${f.remarks}' : ''}'),
                  trailing: Text(_formatHours(f.durationMinutes)),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => AddEditFlightScreen(existing: f)),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddEditFlightScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  String _formatHours(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h.toString()}.${(m/6).round()} h';
  }
}
