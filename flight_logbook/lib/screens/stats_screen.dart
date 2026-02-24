import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/hive_service.dart';
import '../models/flight.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  Map<String, dynamic> _profile = {};
  List<Flight> _recent = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _profile = HiveService.getPilotProfile();
    final all = HiveService.getAllFlights();
    _recent = all.take(5).toList();
    setState(() {});
  }

  Future<void> _editProfile() async {
    final nameCtrl = TextEditingController(text: _profile['name'] as String? ?? '');
    final licCtrl = TextEditingController(text: _profile['license'] as String? ?? '');
    final ratingsCtrl = TextEditingController(text: (_profile['ratings'] as List<dynamic>?)?.join(', ') ?? '');
    final allowedCtrl = TextEditingController(text: (_profile['allowedAircraft'] as List<dynamic>?)?.join(', ') ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Upravit profil pilota'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Jméno')),
              TextField(controller: licCtrl, decoration: const InputDecoration(labelText: 'Licence / číslo')),
              TextField(controller: ratingsCtrl, decoration: const InputDecoration(labelText: 'Oprávnění / ratings (oddělit čárkou)')),
              TextField(controller: allowedCtrl, decoration: const InputDecoration(labelText: 'Letadla které smí létat (oddělit čárkou)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Zrušit')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Uložit')),
        ],
      ),
    );
    if (ok != true) return;

    final newProfile = {
      'name': nameCtrl.text.trim(),
      'license': licCtrl.text.trim(),
      'ratings': ratingsCtrl.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
      'allowedAircraft': allowedCtrl.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
    };
    await HiveService.savePilotProfile(newProfile);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final total = HiveService.getTotalHours();
    final flightsCount = HiveService.getAllFlights().length;
    final df = DateFormat('d. M. yyyy');

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: RefreshIndicator(
        onRefresh: () async => _load(),
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Card(
              child: ListTile(
                title: Text(_profile['name'] as String? ?? 'Neznámý pilot', style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(_profile['license'] as String? ?? ''),
                trailing: IconButton(icon: const Icon(Icons.edit), onPressed: _editProfile),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Celkem hodin', style: TextStyle(fontSize: 12, color: Colors.black54)),
                          const SizedBox(height: 6),
                          Text(total.toStringAsFixed(1), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Počet letů', style: TextStyle(fontSize: 12, color: Colors.black54)),
                          const SizedBox(height: 6),
                          Text(flightsCount.toString(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Oprávnění (ratings)', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: ((
                                    _profile['ratings'] as List<dynamic>?)
                                ?.map((r) => Chip(label: Text(r.toString())))
                                .toList() ??
                            [const Text('Žádná')]),
                    ),
                    const SizedBox(height: 12),
                    const Text('Letadla které smíte létat', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: ((
                                    _profile['allowedAircraft'] as List<dynamic>?)
                                ?.map((r) => Chip(label: Text(r.toString())))
                                .toList() ??
                            [const Text('Žádná')]),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Poslední lety', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    for (final f in _recent)
                      ListTile(
                        dense: true,
                        title: Text('${f.from} → ${f.to}'),
                        subtitle: Text('${f.aircraft ?? ''} • ${f.registration} • ${df.format(f.date)}'),
                        trailing: Text('${(f.durationMinutes/60).toStringAsFixed(1)} h'),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
