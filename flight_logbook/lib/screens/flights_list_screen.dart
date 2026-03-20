import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../models/flight.dart';
import '../services/hive_service.dart';
import '../services/io_service.dart';
import 'add_edit_flight_screen.dart';

class FlightsListScreen extends StatefulWidget {
  const FlightsListScreen({super.key});

  @override
  State<FlightsListScreen> createState() => _FlightsListScreenState();
}

class _FlightsListScreenState extends State<FlightsListScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  // temporary selections before saving
  DateTime? _tempStartDate;
  DateTime? _tempEndDate;
  TimeOfDay? _tempStartTime;
  TimeOfDay? _tempEndTime;
  final _searchCtrl = TextEditingController();
  int? _selectedYear;
  bool _showFilters = true;

  @override
  void initState() {
    super.initState();
    _selectedYear = DateTime.now().year;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;
    final box = Hive.box<Flight>(HiveService.flightsBoxName);
    final df = DateFormat.yMMMd();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lety'),
        actions: [
          if (!isMobile)
            IconButton(
              tooltip: 'Skrýt/zobrazit filtry',
              icon: Icon(_showFilters ? Icons.expand_less : Icons.filter_list),
              onPressed: () => setState(() => _showFilters = !_showFilters),
            ),
          IconButton(
            tooltip: 'Exportovat JSON',
            icon: const Icon(Icons.upload_file),
            onPressed: () async {
              await IOSimple.exportFlights();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Export dokončen')));
              }
            },
          ),
          PopupMenuButton<String>(
            tooltip: 'Import',
            icon: const Icon(Icons.download),
            onSelected: (val) async {
              if (val == 'json') {
                final count = await IOSimple.importFlights();
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Načteno záznamů: $count')));
              } else if (val == 'csv') {
                final info = await IOSimple.importFlightRadarCsv();
                if (!mounted) return;
                if (info == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSV import selhal nebo soubor neobsahuje data')));
                } else {
                  final from = info['from'] ?? '';
                  final to = info['to'] ?? '';
                  final callsign = info['callsign'] ?? '';
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Nalezeno: $callsign • $from → $to')));
                }
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'json', child: Text('Importovat JSON')),
              const PopupMenuItem(value: 'csv', child: Text('Importovat FlightRadar CSV')),
            ],
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: box.listenable(),
        builder: (context, Box<Flight> b, _) {
          final flights = b.values.toList()..sort((a, b) => b.date.compareTo(a.date));
          if (flights.isEmpty) {
            return const Center(child: Text('Zatím žádné záznamy letů.'));
          }

          // build available years for dropdown
          final years = <int>{};
          for (final f in flights) {
            years.add(f.date.year);
          }
          final yearsList = years.toList()..sort((a, b) => b.compareTo(a));

          // determine active year (guard against value not present in available years)
          final activeYear = (_selectedYear != null && yearsList.contains(_selectedYear)) ? _selectedYear : (yearsList.isNotEmpty ? yearsList.first : null);

          // apply filters
          final query = _searchCtrl.text.trim().toLowerCase();
          final filtered = flights.where((f) {
            final dt = f.date;
            if (activeYear != null && dt.year != activeYear) return false;

            if (_startDate != null) {
              final s = DateTime(_startDate!.year, _startDate!.month, _startDate!.day, _startTime?.hour ?? 0, _startTime?.minute ?? 0);
              if (dt.isBefore(s)) return false;
            }
            if (_endDate != null) {
              final e = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, _endTime?.hour ?? 23, _endTime?.minute ?? 59);
              if (dt.isAfter(e)) return false;
            }

            if (query.isNotEmpty) {
              final hay = '${f.from} ${f.to} ${f.aircraft ?? ''} ${f.registration} ${f.remarks ?? ''} ${DateFormat.yMMMMd().format(f.date)}'.toLowerCase();
              if (!hay.contains(query)) return false;
            }

            return true;
          }).toList();

          // group by year-month key YYYY-MM
          final Map<String, List<Flight>> grouped = {};
          for (final f in filtered) {
            final key = '${f.date.year}-${f.date.month.toString().padLeft(2, '0')}';
            grouped.putIfAbsent(key, () => []).add(f);
          }
          final keys = grouped.keys.toList()..sort((a, b) => b.compareTo(a)); // newest first

          return Column(
            children: [
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                child: _showFilters
                    ? Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              children: [
                                // search row
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _searchCtrl,
                                        decoration: InputDecoration(
                                          prefixIcon: const Icon(Icons.search),
                                          hintText: 'Hledat (letiště, typ, poznámka...)',
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                          isDense: true,
                                        ),
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                // filter controls row
                                Row(
                                  children: [
                                    DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.surface,
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                        child: DropdownButton<int>(
                                          value: activeYear,
                                          underline: const SizedBox.shrink(),
                                          items: yearsList.map((y) => DropdownMenuItem<int>(value: y, child: Text(y.toString()))).toList(),
                                          onChanged: (v) => setState(() => _selectedYear = v),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(shape: const StadiumBorder()),
                                      icon: const Icon(Icons.date_range),
                                      label: Text(_startDate == null && _endDate == null
                                          ? 'Datum'
                                          : '${_shortDate(_startDate!)}${_startDate != null && _endDate != null ? ' – ' : ''}${_shortDate(_endDate!)}'),
                                      onPressed: () async {
                                        final picked = await showDateRangePicker(
                                          context: context,
                                          firstDate: DateTime(2000),
                                          lastDate: DateTime(2100),
                                          initialDateRange: _startDate != null && _endDate != null
                                              ? DateTimeRange(start: _startDate!, end: _endDate!)
                                              : null,
                                        );
                                        if (picked != null) {
                                          setState(() {
                                            // apply selection immediately for mobile UX
                                            _startDate = picked.start;
                                            _endDate = picked.end;
                                            _tempStartDate = null;
                                            _tempEndDate = null;
                                          });
                                        }
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(shape: const StadiumBorder()),
                                      icon: const Icon(Icons.access_time),
                                      label: Text(_startTime == null && _endTime == null
                                          ? 'Čas'
                                          : '${_startTime != null ? _startTime!.format(context) : ''}${_startTime != null && _endTime != null ? ' – ' : ''}${_endTime != null ? _endTime!.format(context) : ''}'),
                                      onPressed: () async {
                                        // sequential time pickers (no nested dialogs)
                                        final s = await showTimePicker(context: context, initialTime: _startTime ?? const TimeOfDay(hour: 0, minute: 0));
                                        if (s == null) return;
                                        final e = await showTimePicker(context: context, initialTime: _endTime ?? const TimeOfDay(hour: 23, minute: 59));
                                        if (e == null) return;
                                        setState(() {
                                          // apply immediately
                                          _startTime = s;
                                          _endTime = e;
                                          _tempStartTime = null;
                                          _tempEndTime = null;
                                        });
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton(
                                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                                      onPressed: () async {
                                        // On mobile show a confirmation dialog before resetting filters
                                        if (isMobile) {
                                          final ok = await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: const Text('Resetovat filtry?'),
                                              content: const Text('Opravdu chceš vymazat všechny filtry?'),
                                              actions: [
                                                TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Zrušit')),
                                                TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Reset')),
                                              ],
                                            ),
                                          );
                                          if (ok != true) return;
                                        }
                                        setState(() {
                                          _selectedYear = DateTime.now().year;
                                          _startDate = null;
                                          _endDate = null;
                                          _startTime = null;
                                          _endTime = null;
                                          _tempStartDate = null;
                                          _tempEndDate = null;
                                          _tempStartTime = null;
                                          _tempEndTime = null;
                                          _searchCtrl.clear();
                                        });
                                      },
                                      child: const Text('Vymazat filtr'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                // active chips
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Wrap(
                                    spacing: 8,
                                    children: [
                                      
                                      if (_startDate != null || _endDate != null)
                                        InputChip(
                                          label: Text('Datum: ${_chipDateLabel(_startDate, _endDate)}'),
                                          onDeleted: () => setState(() {
                                            _startDate = null;
                                            _endDate = null;
                                          }),
                                        ),
                                      if (_startTime != null || _endTime != null) InputChip(label: Text('Čas: ${_startTime != null ? _startTime!.format(context) : ''}${_startTime != null && _endTime != null ? '–' : ''}${_endTime != null ? _endTime!.format(context) : ''}'), onDeleted: () => setState(() { _startTime = null; _endTime = null; })),
                                      if (_searchCtrl.text.trim().isNotEmpty) InputChip(label: Text('Hledat: ${_searchCtrl.text}'), onDeleted: () => setState(() { _searchCtrl.clear(); })),
                                      ],
                                    ),
                             ) ],
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              Expanded(
                child: ListView(
                  children: [
                    for (final key in keys) ...[
                      // header
                      Container(
                        width: double.infinity,
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        child: Text(
                          '${DateFormat.MMMM().format(DateTime(int.parse(key.split('-')[0]), int.parse(key.split('-')[1])))} ${key.split('-')[0]}',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      // items
                      for (final f in grouped[key]!)
                        Dismissible(
                          key: ValueKey(f.id),
                          background: Container(color: Colors.red),
                          onDismissed: (_) => HiveService.deleteFlight(f.id),
                          child: Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              leading: CircleAvatar(backgroundColor: Theme.of(context).colorScheme.primaryContainer, child: const Icon(Icons.flight, size: 20)),
                              title: Row(
                                children: [
                                  Expanded(child: Text('${df.format(f.date)} • ${f.from} → ${f.to}', style: Theme.of(context).textTheme.bodyLarge)),
                                  if (f.modifiedAt != null || f.createdAt != null)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8.0),
                                      child: Text(
                                        _formatTimestamps(f),
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54),
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Text('${f.aircraft ?? ''} ${f.registration}${f.remarks != null && f.remarks!.isNotEmpty ? ' • ${f.remarks}' : ''}'),
                              trailing: Text(_formatHours(f.durationMinutes)),
                              onTap: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => AddEditFlightScreen(existing: f)),
                                );
                              },
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddEditFlightScreen()),
          );
        },
        label: const Icon(Icons.add),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );

  }

  String _formatHours(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h.toString()}.${(m/6).round()} h';
  }

  Future<void> _showDateRangeDialog(BuildContext context) async {
    // replaced by direct showDateRangePicker in button handler to avoid nested dialogs
    return;
  }

  Future<void> _showTimeRangeDialog(BuildContext context) async {
    // now handled inline (sequential showTimePicker) to avoid nested dialogs
    return;
  }

  String _formatTimestamps(Flight f) {
    final df2 = DateFormat('yyyy-MM-dd HH:mm');
    final dt = f.modifiedAt ?? f.createdAt;
    if (dt == null) return '';
    return 'Upraveno: ${df2.format(dt)}';
  }

  String _shortDate(DateTime d) {
    // short date for buttons: omit year if matches selected year
    if (_selectedYear != null && d.year == _selectedYear) {
      return DateFormat('d. M.').format(d);
    }
    return DateFormat.yMMMd().format(d);
  }

  String _chipDateLabel(DateTime? start, DateTime? end) {
    if (start == null && end == null) return '';
    if (start != null && end != null) {
      // if both in same year and equal to selected year, omit year
      if (_selectedYear != null && start.year == _selectedYear && end.year == _selectedYear) {
        return '${DateFormat('d. M.').format(start)} – ${DateFormat('d. M.').format(end)}';
      }
      if (start.year == end.year) {
        return '${DateFormat('d. M. yyyy').format(start)} – ${DateFormat('d. M. yyyy').format(end)}';
      }
      return '${DateFormat.yMMMd().format(start)} – ${DateFormat.yMMMd().format(end)}';
    }
    final d = start ?? end!;
    if (_selectedYear != null && d.year == _selectedYear) return DateFormat('d. M.').format(d);
    return DateFormat.yMMMd().format(d);
  }
}
