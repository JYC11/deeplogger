import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/dive_form_provider.dart';
import '../providers/dive_providers.dart';
import '../services/unit_converter.dart';

class DiveFormScreen extends ConsumerWidget {
  const DiveFormScreen({super.key, this.existingLogId});

  /// Existing log id, or null for a new dive.
  final int? existingLogId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncForm = ref.watch(diveFormProvider(existingLogId));

    return Scaffold(
      appBar: AppBar(
        title: Text(existingLogId == null ? 'New Dive' : 'Edit Dive'),
      ),
      body: asyncForm.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading: $e')),
        data: (state) => _DiveFormBody(existingLogId: existingLogId),
      ),
    );
  }
}

class _DiveFormBody extends ConsumerWidget {
  const _DiveFormBody({required this.existingLogId});

  final int? existingLogId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final form = ref.watch(diveFormProvider(existingLogId)).requireValue;
    final notifier = ref.read(diveFormProvider(existingLogId).notifier);
    final errors = form.validationErrors;

    return Form(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Basic / Temporal
          _SectionHeader('Basic'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              form.startTime == null
                  ? 'Select start time'
                  : '${form.startTime!.toLocal()}'.split('.').first,
            ),
            trailing: const Icon(Icons.calendar_today),
            onTap: () => _pickDateTime(context, form.startTime, notifier),
          ),
          if (errors['startTime'] != null) _ErrorText(errors['startTime']!),
          TextFormField(
            initialValue: form.location,
            decoration: InputDecoration(
              labelText: 'Location',
              errorText: errors['location'],
            ),
            onChanged: notifier.setLocation,
          ),
          TextFormField(
            initialValue: form.altitude,
            decoration: const InputDecoration(labelText: 'Altitude'),
            onChanged: notifier.setAltitude,
          ),

          const SizedBox(height: 16),
          _SectionHeader('Depth & Duration'),
          _UnitField(
            field: DiveField.maxDepth,
            column: 'max_depth_m',
            label: 'Max Depth',
            metricValue: form.maxDepthM,
            unitPrefs: form.unitPreferences,
            errorText: errors['maxDepthM'],
            onMetricChanged: notifier.setMaxDepth,
            onUnitChanged: notifier.setUnitPreference,
          ),
          _UnitField(
            field: DiveField.avgDepth,
            column: 'avg_depth_m',
            label: 'Average Depth',
            metricValue: form.avgDepthM,
            unitPrefs: form.unitPreferences,
            errorText: errors['avgDepthM'],
            onMetricChanged: notifier.setAvgDepth,
            onUnitChanged: notifier.setUnitPreference,
          ),
          TextFormField(
            initialValue: form.durationMin?.toStringAsFixed(0),
            decoration: InputDecoration(
              labelText: 'Duration (min)',
              errorText: errors['durationMin'],
            ),
            keyboardType: TextInputType.number,
            onChanged: (v) => notifier.setDuration(double.tryParse(v)),
          ),

          const SizedBox(height: 16),
          _SectionHeader('Tank & Gas'),
          DropdownButtonFormField<String>(
            initialValue: form.gasType,
            decoration: const InputDecoration(labelText: 'Gas Type'),
            items: const [
              'Air',
              'Nitrox',
              'Other',
            ].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
            onChanged: notifier.setGasType,
          ),
          if (form.gasType == 'Other')
            TextFormField(
              initialValue: form.gasOther,
              decoration: InputDecoration(
                labelText: 'Gas (specify)',
                errorText: errors['gasOther'],
              ),
              onChanged: notifier.setGasOther,
            ),
          // Tank volume (structured, per D-TANK). New dives use the
          // structured value + unit; legacy rows still parse tankSize on read.
          TextFormField(
            initialValue: form.tankVolumeValue?.toStringAsFixed(1),
            decoration: InputDecoration(
              labelText: 'Tank Volume',
              errorText: errors['tankVolumeValue'],
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (v) => notifier.setTankVolumeValue(double.tryParse(v)),
          ),
          DropdownButtonFormField<String>(
            initialValue: form.tankVolumeUnit,
            decoration: const InputDecoration(labelText: 'Tank Volume Unit'),
            items: const [
              'L',
              'cu ft',
            ].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
            onChanged: (v) => notifier.setTankVolumeUnit(v ?? 'L'),
          ),
          _UnitField(
            field: DiveField.startPressure,
            column: 'start_pressure_bar',
            label: 'Start Pressure',
            metricValue: form.startPressureBar,
            unitPrefs: form.unitPreferences,
            errorText: errors['startPressureBar'],
            onMetricChanged: notifier.setStartPressure,
            onUnitChanged: notifier.setUnitPreference,
          ),
          _UnitField(
            field: DiveField.endPressure,
            column: 'end_pressure_bar',
            label: 'End Pressure',
            metricValue: form.endPressureBar,
            unitPrefs: form.unitPreferences,
            errorText: errors['endPressureBar'],
            onMetricChanged: notifier.setEndPressure,
            onUnitChanged: notifier.setUnitPreference,
          ),

          const SizedBox(height: 16),
          _SectionHeader('Environmental'),
          _UnitField(
            field: DiveField.waterTemp,
            column: 'water_temp_c',
            label: 'Water Temp',
            metricValue: form.waterTempC,
            unitPrefs: form.unitPreferences,
            errorText: errors['waterTempC'],
            onMetricChanged: notifier.setWaterTemp,
            onUnitChanged: notifier.setUnitPreference,
          ),
          DropdownButtonFormField<String>(
            initialValue: form.salinity,
            decoration: const InputDecoration(labelText: 'Salinity'),
            items: const [
              'Fresh Water',
              'Ocean',
              'Other',
            ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: notifier.setSalinity,
          ),
          _UnitField(
            field: DiveField.visibility,
            column: 'visibility_m',
            label: 'Visibility',
            metricValue: form.visibilityM,
            unitPrefs: form.unitPreferences,
            errorText: errors['visibilityM'],
            onMetricChanged: notifier.setVisibility,
            onUnitChanged: notifier.setUnitPreference,
          ),

          const SizedBox(height: 16),
          _SectionHeader('Gear'),
          _GearSelector(
            selectedIds: form.selectedGearIds,
            adHocGear: form.adHocGear,
            onToggle: notifier.toggleGear,
            onAddAdHoc: notifier.addAdHocGear,
          ),

          const SizedBox(height: 16),
          _SectionHeader('Personal'),
          _UnitField(
            field: DiveField.weight,
            column: 'weight_kg',
            label: 'Weight',
            metricValue: form.weightKg,
            unitPrefs: form.unitPreferences,
            errorText: errors['weightKg'],
            onMetricChanged: notifier.setWeight,
            onUnitChanged: notifier.setUnitPreference,
          ),
          TextFormField(
            initialValue: form.notes,
            decoration: const InputDecoration(labelText: 'Notes'),
            maxLines: 3,
            onChanged: notifier.setNotes,
          ),

          if (form.saveError != null) ...[
            const SizedBox(height: 8),
            _ErrorText('Save failed: ${form.saveError}'),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: form.isSaving
                ? null
                : () async {
                    final ok = await notifier.save();
                    if (ok && context.mounted) {
                      Navigator.pop(context);
                    }
                  },
            child: Text(form.isSaving ? 'Saving...' : 'Save Dive'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDateTime(
    BuildContext context,
    DateTime? current,
    DiveFormNotifier notifier,
  ) async {
    final date = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null) return;
    if (!context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current ?? DateTime.now()),
    );
    if (time == null) return;
    notifier.setStartTime(
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
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

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Text(
        text,
        style: TextStyle(
          color: Theme.of(context).colorScheme.error,
          fontSize: 12,
        ),
      ),
    );
  }
}

/// A numeric field paired with a per-field unit dropdown (D-UNITS).
///
/// Storage is metric-canonical: [metricValue] is always in metric. The
/// displayed value is converted via [UnitConverter.fromMetric]; entered
/// values are converted back via [UnitConverter.toMetric] before calling
/// [onMetricChanged]. The text field is keyed on the unit so it rebuilds
/// (re-applying [initialValue]) when the unit changes.
class _UnitField extends StatelessWidget {
  const _UnitField({
    required this.field,
    required this.column,
    required this.label,
    required this.metricValue,
    required this.unitPrefs,
    required this.onMetricChanged,
    required this.onUnitChanged,
    this.errorText,
  });

  final DiveField field;
  final String column;
  final String label;
  final double? metricValue;
  final Map<String, String> unitPrefs;
  final void Function(double? metric) onMetricChanged;
  final void Function(String column, String unit) onUnitChanged;
  final String? errorText;

  static const _converter = UnitConverter();

  @override
  Widget build(BuildContext context) {
    final unit = unitPrefs[column] ?? UnitConverter.defaultUnit(field);
    final display = _converter.fromMetric(field, metricValue, unit);
    final isInt =
        field == DiveField.startPressure || field == DiveField.endPressure;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextFormField(
            // Re-key on unit so the field re-renders with the converted value
            // when the unit changes.
            key: ValueKey('${column}_$unit'),
            initialValue: display == null
                ? ''
                : (isInt
                      ? display.toStringAsFixed(0)
                      : display.toStringAsFixed(1)),
            decoration: InputDecoration(
              labelText: '$label ($unit)',
              errorText: errorText,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (v) {
              final entered = double.tryParse(v);
              onMetricChanged(_converter.toMetric(field, entered, unit));
            },
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 90,
          child: DropdownButtonFormField<String>(
            initialValue: unit,
            decoration: const InputDecoration(labelText: 'Unit'),
            items: UnitConverter.unitOptions(
              field,
            ).map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
            onChanged: (u) {
              if (u != null) onUnitChanged(column, u);
            },
          ),
        ),
      ],
    );
  }
}

class _GearSelector extends ConsumerWidget {
  const _GearSelector({
    required this.selectedIds,
    required this.adHocGear,
    required this.onToggle,
    required this.onAddAdHoc,
  });

  final Set<int> selectedIds;
  final List<String> adHocGear;
  final void Function(int) onToggle;
  final void Function(String) onAddAdHoc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncGear = ref.watch(gearListProvider);
    final ctrl = TextEditingController();

    return asyncGear.when(
      data: (items) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (items.isEmpty)
              const Text(
                'No gear items. Add some in the gear screen.',
                style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
              )
            else
              Wrap(
                children: items.map((item) {
                  final selected = selectedIds.contains(item.id);
                  return FilterChip(
                    label: Text(item.name),
                    selected: selected,
                    onSelected: (_) => onToggle(item.id!),
                  );
                }).toList(),
              ),
            if (adHocGear.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                children: adHocGear
                    .map(
                      (text) => FilterChip(
                        label: Text(text),
                        selected: true,
                        onSelected: (_) => onAddAdHoc(text),
                        // Ad-hoc entries are visually distinct.
                        avatar: const Icon(Icons.edit, size: 16),
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: ctrl,
                    decoration: const InputDecoration(
                      labelText: 'Add ad-hoc gear',
                      isDense: true,
                    ),
                    onSubmitted: (v) {
                      if (v.trim().isNotEmpty) {
                        onAddAdHoc(v);
                        ctrl.clear();
                      }
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    if (ctrl.text.trim().isNotEmpty) {
                      onAddAdHoc(ctrl.text);
                      ctrl.clear();
                    }
                  },
                ),
              ],
            ),
          ],
        );
      },
      loading: () => const Text('Loading gear...'),
      error: (_, _) => const Text('Error loading gear'),
    );
  }
}
