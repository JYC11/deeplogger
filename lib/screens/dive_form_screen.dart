import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/dive_log.dart';
import '../providers/dive_providers.dart';

class DiveFormScreen extends ConsumerStatefulWidget {
  const DiveFormScreen({super.key, this.existingLog});

  final DiveLog? existingLog;

  @override
  ConsumerState<DiveFormScreen> createState() => _DiveFormScreenState();
}

class _DiveFormScreenState extends ConsumerState<DiveFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _locationCtrl;
  late final TextEditingController _altitudeCtrl;
  late final TextEditingController _maxDepthCtrl;
  late final TextEditingController _avgDepthCtrl;
  late final TextEditingController _durationCtrl;
  late final TextEditingController _tankSizeCtrl;
  late final TextEditingController _startPressureCtrl;
  late final TextEditingController _endPressureCtrl;
  late final TextEditingController _waterTempCtrl;
  late final TextEditingController _visibilityCtrl;
  late final TextEditingController _weightCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _gasOtherCtrl;

  String? _gasType;
  String? _salinity;
  DateTime? _startTime;
  final Set<int> _selectedGearIds = {};
  bool _saving = false;

  static const _gasTypes = ['Air', 'Nitrox', 'Other'];
  static const _salinities = ['Fresh Water', 'Ocean', 'Other'];

  @override
  void initState() {
    super.initState();
    final log = widget.existingLog;
    _locationCtrl = TextEditingController(text: log?.location ?? '');
    _altitudeCtrl = TextEditingController(text: log?.altitude ?? '');
    _maxDepthCtrl = TextEditingController(
      text: log?.maxDepthM?.toStringAsFixed(1) ?? '',
    );
    _avgDepthCtrl = TextEditingController(
      text: log?.avgDepthM?.toStringAsFixed(1) ?? '',
    );
    _durationCtrl = TextEditingController(
      text: log?.durationMin?.toStringAsFixed(0) ?? '',
    );
    _tankSizeCtrl = TextEditingController(text: log?.tankSize ?? '');
    _startPressureCtrl = TextEditingController(
      text: log?.startPressureBar?.toStringAsFixed(0) ?? '',
    );
    _endPressureCtrl = TextEditingController(
      text: log?.endPressureBar?.toStringAsFixed(0) ?? '',
    );
    _waterTempCtrl = TextEditingController(
      text: log?.waterTempC?.toStringAsFixed(0) ?? '',
    );
    _visibilityCtrl = TextEditingController(
      text: log?.visibilityM?.toStringAsFixed(0) ?? '',
    );
    _weightCtrl = TextEditingController(
      text: log?.weightKg?.toStringAsFixed(1) ?? '',
    );
    _notesCtrl = TextEditingController(text: log?.notes ?? '');
    _gasOtherCtrl = TextEditingController(text: log?.gasOther ?? '');
    _gasType = log?.gasType;
    _salinity = log?.salinity;
    _startTime = log?.startTime;
  }

  @override
  void dispose() {
    for (final c in [
      _locationCtrl,
      _altitudeCtrl,
      _maxDepthCtrl,
      _avgDepthCtrl,
      _durationCtrl,
      _tankSizeCtrl,
      _startPressureCtrl,
      _endPressureCtrl,
      _waterTempCtrl,
      _visibilityCtrl,
      _weightCtrl,
      _notesCtrl,
      _gasOtherCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingLog == null ? 'New Dive' : 'Edit Dive'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Basic / Temporal
            _SectionHeader('Basic'),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                _startTime == null
                    ? 'Select start time'
                    : '${_startTime!.toLocal()}'.split('.').first,
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickDateTime,
            ),
            TextFormField(
              controller: _locationCtrl,
              decoration: const InputDecoration(labelText: 'Location'),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            TextFormField(
              controller: _altitudeCtrl,
              decoration: const InputDecoration(labelText: 'Altitude'),
            ),

            const SizedBox(height: 16),
            _SectionHeader('Depth & Duration'),
            TextFormField(
              controller: _maxDepthCtrl,
              decoration: const InputDecoration(labelText: 'Max Depth (m)'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            TextFormField(
              controller: _avgDepthCtrl,
              decoration: const InputDecoration(labelText: 'Average Depth (m)'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            TextFormField(
              controller: _durationCtrl,
              decoration: const InputDecoration(labelText: 'Duration (min)'),
              keyboardType: TextInputType.number,
            ),

            const SizedBox(height: 16),
            _SectionHeader('Tank & Gas'),
            DropdownButtonFormField<String>(
              initialValue: _gasType,
              decoration: const InputDecoration(labelText: 'Gas Type'),
              items: _gasTypes
                  .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                  .toList(),
              onChanged: (v) => setState(() => _gasType = v),
            ),
            if (_gasType == 'Other')
              TextFormField(
                controller: _gasOtherCtrl,
                decoration: const InputDecoration(labelText: 'Gas (specify)'),
                validator: (v) =>
                    (_gasType == 'Other' && (v == null || v.isEmpty))
                    ? 'Required when Other'
                    : null,
              ),
            TextFormField(
              controller: _tankSizeCtrl,
              decoration: const InputDecoration(
                labelText: 'Tank Size (e.g. 12L, 80 cu ft)',
              ),
            ),
            TextFormField(
              controller: _startPressureCtrl,
              decoration: const InputDecoration(
                labelText: 'Start Pressure (bar)',
              ),
              keyboardType: TextInputType.number,
            ),
            TextFormField(
              controller: _endPressureCtrl,
              decoration: const InputDecoration(
                labelText: 'End Pressure (bar)',
              ),
              keyboardType: TextInputType.number,
            ),

            const SizedBox(height: 16),
            _SectionHeader('Environmental'),
            TextFormField(
              controller: _waterTempCtrl,
              decoration: const InputDecoration(labelText: 'Water Temp (°C)'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            DropdownButtonFormField<String>(
              initialValue: _salinity,
              decoration: const InputDecoration(labelText: 'Salinity'),
              items: _salinities
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _salinity = v),
            ),
            TextFormField(
              controller: _visibilityCtrl,
              decoration: const InputDecoration(labelText: 'Visibility (m)'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),

            const SizedBox(height: 16),
            _SectionHeader('Gear'),
            _GearSelector(
              selectedIds: _selectedGearIds,
              onToggle: (id) => setState(() {
                if (_selectedGearIds.contains(id)) {
                  _selectedGearIds.remove(id);
                } else {
                  _selectedGearIds.add(id);
                }
              }),
            ),

            const SizedBox(height: 16),
            _SectionHeader('Personal'),
            TextFormField(
              controller: _weightCtrl,
              decoration: const InputDecoration(labelText: 'Weight (kg)'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            TextFormField(
              controller: _notesCtrl,
              decoration: const InputDecoration(labelText: 'Notes'),
              maxLines: 3,
            ),

            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving...' : 'Save Dive'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startTime ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null) return;
    if (!mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startTime ?? DateTime.now()),
    );
    if (time == null) return;

    setState(() {
      _startTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final log = (widget.existingLog ?? DiveLog()).copyWith(
      startTime: _startTime,
      location: _locationCtrl.text.isEmpty ? null : _locationCtrl.text,
      altitude: _altitudeCtrl.text.isEmpty ? null : _altitudeCtrl.text,
      maxDepthM: double.tryParse(_maxDepthCtrl.text),
      avgDepthM: double.tryParse(_avgDepthCtrl.text),
      durationMin: double.tryParse(_durationCtrl.text),
      gasType: _gasType,
      gasOther: _gasType == 'Other' ? _gasOtherCtrl.text : null,
      tankSize: _tankSizeCtrl.text.isEmpty ? null : _tankSizeCtrl.text,
      startPressureBar: double.tryParse(_startPressureCtrl.text),
      endPressureBar: double.tryParse(_endPressureCtrl.text),
      waterTempC: double.tryParse(_waterTempCtrl.text),
      salinity: _salinity,
      visibilityM: double.tryParse(_visibilityCtrl.text),
      weightKg: double.tryParse(_weightCtrl.text),
      notes: _notesCtrl.text.isEmpty ? null : _notesCtrl.text,
      isDraft: false,
      updatedAt: DateTime.now(),
    );

    final db = ref.read(databaseProvider);
    if (log.id != null) {
      await db.updateDiveLog(log);
    } else {
      final newId = await db.insertDiveLog(log);
      await db.setGearForDive(newId, _selectedGearIds.toList());
    }
    if (log.id != null) {
      await db.setGearForDive(log.id!, _selectedGearIds.toList());
    }

    if (mounted) Navigator.pop(context);
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _GearSelector extends ConsumerWidget {
  const _GearSelector({required this.selectedIds, required this.onToggle});

  final Set<int> selectedIds;
  final void Function(int) onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncGear = ref.watch(gearListProvider);

    return asyncGear.when(
      data: (items) {
        if (items.isEmpty) {
          return const Text(
            'No gear items. Add some in the gear screen.',
            style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
          );
        }
        return Wrap(
          children: items.map((item) {
            final selected = selectedIds.contains(item.id);
            return FilterChip(
              label: Text(item.name),
              selected: selected,
              onSelected: (_) => onToggle(item.id!),
            );
          }).toList(),
        );
      },
      loading: () => const Text('Loading gear...'),
      error: (_, _) => const Text('Error loading gear'),
    );
  }
}
