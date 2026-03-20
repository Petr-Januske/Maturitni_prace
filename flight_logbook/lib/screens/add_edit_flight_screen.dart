import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/flight.dart';
import '../services/hive_service.dart';
import '../services/io_service.dart';
import '../services/airport_index.dart';

class AddEditFlightScreen extends StatefulWidget {
  final Flight? existing;
  const AddEditFlightScreen({super.key, this.existing});

  @override
  State<AddEditFlightScreen> createState() => _AddEditFlightScreenState();
}

class AirportAutocomplete extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  const AirportAutocomplete({required this.controller, required this.label, this.validator, super.key});

  @override
  State<AirportAutocomplete> createState() => _AirportAutocompleteState();
}

class _AirportAutocompleteState extends State<AirportAutocomplete> {
  @override
  Widget build(BuildContext context) {
    return Autocomplete<Airport>(
      displayStringForOption: (a) => '${a.code} — ${a.name}',
      optionsBuilder: (TextEditingValue textEditingValue) {
        return AirportIndex.search(textEditingValue.text);
      },
      fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
        textEditingController.text = widget.controller.text;
        textEditingController.selection = widget.controller.selection;
        textEditingController.addListener(() {
          if (widget.controller.text != textEditingController.text) {
            widget.controller.text = textEditingController.text;
            widget.controller.selection = textEditingController.selection;
          }
        });
        return TextFormField(
          controller: textEditingController,
          focusNode: focusNode,
          decoration: InputDecoration(labelText: widget.label),
          validator: widget.validator,
        );
      },
      onSelected: (airport) {
        widget.controller.text = airport.code;
        widget.controller.selection = TextSelection.fromPosition(TextPosition(offset: widget.controller.text.length));
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200, maxWidth: 600),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final Airport option = options.elementAt(index);
                  return ListTile(
                    title: Text('${option.code} — ${option.name}'),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AddEditFlightScreenState extends State<AddEditFlightScreen> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _date;
  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();
  final _aircraftCtrl = TextEditingController();
  final _regCtrl = TextEditingController();
  final _durationCtrl = TextEditingController(); // HH:mm
  final _remarksCtrl = TextEditingController();
  final _df = DateFormat.yMMMMd();

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _date = e?.date ?? DateTime.now();
    _fromCtrl.text = e?.from ?? '';
    _toCtrl.text = e?.to ?? '';
    _aircraftCtrl.text = e?.aircraft ?? '';
    _regCtrl.text = e?.registration ?? '';
    if (e != null) {
      final h = e.durationMinutes ~/ 60;
      final m = e.durationMinutes % 60;
      _durationCtrl.text = '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    }
    _remarksCtrl.text = e?.remarks ?? '';
    _loadAirports();
  }

  Future<void> _loadAirports() async {
    await AirportIndex.ensureLoaded();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();
    _aircraftCtrl.dispose();
    _regCtrl.dispose();
    _durationCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Upravit let' : 'Přidat let'),
        actions: [
          if (isEdit)
            IconButton(
              tooltip: 'Exportovat tento záznam',
              icon: const Icon(Icons.upload_file),
              onPressed: () async {
                final f = widget.existing!;
                await IOSimple.exportFlight(f);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Export dokončen')));
              },
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                const Text('Datum: '),
                TextButton(
                  onPressed: _pickDate,
                  child: Text(_df.format(_date)),
                ),
              ],
            ),
            AirportAutocomplete(
              controller: _fromCtrl,
              label: 'Z letiště (kód, např. LKPR)',
              validator: _required,
            ),
            AirportAutocomplete(
              controller: _toCtrl,
              label: 'Na letiště (kód, např. LKTB)',
              validator: _required,
            ),
            TextFormField(
              controller: _aircraftCtrl,
              decoration: const InputDecoration(labelText: 'Typ letadla (volitelné)'),
            ),
            TextFormField(
              controller: _regCtrl,
              decoration: const InputDecoration(labelText: 'Imatrikulace'),
              validator: _required,
            ),
            TextFormField(
              controller: _durationCtrl,
              decoration: const InputDecoration(labelText: 'Doba letu (HH:mm)'),
              keyboardType: TextInputType.datetime,
              validator: (v) => _validateDuration(v),
            ),
            TextFormField(
              controller: _remarksCtrl,
              decoration: const InputDecoration(labelText: 'Poznámka (volitelné)'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _save,
              child: Text(isEdit ? 'Uložit změny' : 'Přidat let'),
            ),
          ],
        ),
      ),
    );
  }

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Povinné pole' : null;

  String? _validateDuration(String? v) {
    if (v == null || v.trim().isEmpty) return 'Povinné pole';
    final parts = v.split(':');
    if (parts.length != 2) return 'Zadejte ve formátu HH:mm';
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h < 0 || m < 0 || m >= 60) return 'Neplatný čas';
    return null;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1970),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final minutes = _toMinutes(_durationCtrl.text);
    final acText = _aircraftCtrl.text.trim();
    final ac = acText.isEmpty ? null : acText;

    final base = Flight(
      id: widget.existing?.id ?? 0,
      date: _date,
      from: _fromCtrl.text.trim().toUpperCase(),
      to: _toCtrl.text.trim().toUpperCase(),
      aircraft: ac,
      registration: _regCtrl.text.trim().toUpperCase(),
      durationMinutes: minutes,
      remarks: _remarksCtrl.text.trim().isEmpty ? null : _remarksCtrl.text.trim(),
    );
    if (widget.existing == null) {
      await HiveService.addFlight(base);
    } else {
      await HiveService.updateFlight(base);
    }
    if (mounted) Navigator.of(context).pop();
  }

  int _toMinutes(String hhmm) {
    final parts = hhmm.split(':');
    final h = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    return h * 60 + m;
  }
}
