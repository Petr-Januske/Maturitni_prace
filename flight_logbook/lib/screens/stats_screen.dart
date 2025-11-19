import 'package:flutter/material.dart';
import '../services/hive_service.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final total = HiveService.getTotalHours();
    return Scaffold(
      appBar: AppBar(title: const Text('Statistiky')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Celkem nalétaných hodin', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            Text(total.toStringAsFixed(1), style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
