import 'package:deeplogger/models/gear_item.dart';
import 'package:deeplogger/providers/dive_form_provider.dart';
import 'package:deeplogger/providers/dive_providers.dart';
import 'package:deeplogger/screens/dive_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Returns a dive form notifier with pre-populated ad-hoc gear and an empty
/// master gear list, so the ad-hoc chips render without a DB.
class _AdHocFormNotifier extends DiveFormNotifier {
  _AdHocFormNotifier() : super(null);

  @override
  Future<DiveFormState> build() async {
    return const DiveFormState(adHocGear: ['Rental BCD']);
  }
}

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('tapping an ad-hoc gear chip removes it (does not duplicate)', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        diveFormProvider.overrideWith2((_) => _AdHocFormNotifier()),
        gearListProvider.overrideWith((ref) async => <GearItem>[]),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: DiveFormScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('Rental BCD'),
      find.byType(ListView),
      const Offset(0, -300),
    );
    expect(find.text('Rental BCD'), findsOneWidget);

    await tester.tap(find.text('Rental BCD'));
    await tester.pumpAndSettle();

    final state = container.read(diveFormProvider(null)).requireValue;
    expect(state.adHocGear, isEmpty);
    expect(find.text('Rental BCD'), findsNothing);
  });

  testWidgets('ad-hoc gear chips render alongside the add-field', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        diveFormProvider.overrideWith2((_) => _AdHocFormNotifier()),
        gearListProvider.overrideWith((ref) async => <GearItem>[]),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: DiveFormScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('Rental BCD'),
      find.byType(ListView),
      const Offset(0, -300),
    );
    expect(find.text('Rental BCD'), findsOneWidget);
    expect(find.text('Add ad-hoc gear'), findsOneWidget);
  });
}
