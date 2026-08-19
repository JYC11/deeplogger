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

/// Clean notifier with no pre-populated state — used by F4 tests so the
/// gear selector button shows its default "Select gear" label.
class _EmptyFormNotifier extends DiveFormNotifier {
  _EmptyFormNotifier() : super(null);

  @override
  Future<DiveFormState> build() async => const DiveFormState();
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

  testWidgets('ad-hoc gear chips render on the form when present', (
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
    // F4: the ad-hoc chip still renders on the form (the in-line add-field
    // is kept on the form so it's reachable even with an empty master list).
    expect(find.text('Rental BCD'), findsOneWidget);
    expect(find.text('Add ad-hoc gear'), findsOneWidget);
  });

  // F4: the old gear selector rendered an unbounded Wrap of FilterChips
  // directly in the form ListView, which overflowed at 100+ items. Now a
  // compact "Select gear" button opens a modal dialog with a search field
  // and a bounded scrollable checkbox list.
  group('F4 gear selector dialog', () {
    List<GearItem> fiftyItems() => List.generate(
      50,
      (i) => GearItem(id: i + 1, name: 'Gear ${i.toString().padLeft(2, '0')}'),
    );

    testWidgets('renders without overflow even with 50 gear items', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          diveFormProvider.overrideWith2((_) => _EmptyFormNotifier()),
          gearListProvider.overrideWith((ref) async => fiftyItems()),
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

      // Scroll to the Gear section.
      await tester.dragUntilVisible(
        find.text('Select gear'),
        find.byType(ListView),
        const Offset(0, -400),
      );
      expect(find.text('Select gear'), findsOneWidget);
      // No RenderFlex overflow should fire.
      expect(tester.takeException(), isNull);
    });

    testWidgets('opening dialog shows searchable list; search filters it', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          diveFormProvider.overrideWith2((_) => _EmptyFormNotifier()),
          gearListProvider.overrideWith((ref) async => fiftyItems()),
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
        find.text('Select gear'),
        find.byType(ListView),
        const Offset(0, -400),
      );
      await tester.tap(find.text('Select gear'));
      await tester.pumpAndSettle();

      expect(find.text('Select Gear'), findsOneWidget);
      expect(find.text('Search gear...'), findsOneWidget);
      // First few items are visible; the dialog is bounded so not all 50
      // render at once — but at least the first one must be present.
      expect(find.text('Gear 00'), findsOneWidget);

      // Type a query that only matches one item. Find the search field by
      // its hint text (the form behind the dialog also has TextFields, so
      // `find.byType(TextField).first` would hit the form, not the dialog).
      final searchField = find.ancestor(
        of: find.text('Search gear...'),
        matching: find.byType(TextField),
      );
      await tester.enterText(searchField, 'Gear 07');
      await tester.pumpAndSettle();

      // The filtered list contains only 'Gear 07' (as a checkbox tile).
      expect(
        find.descendant(
          of: find.byType(CheckboxListTile),
          matching: find.text('Gear 07'),
        ),
        findsOneWidget,
      );
      // Other items should be filtered out of the checkbox list.
      expect(
        find.descendant(
          of: find.byType(CheckboxListTile),
          matching: find.text('Gear 00'),
        ),
        findsNothing,
      );
    });

    testWidgets('checking a gear item commits to the form state', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          diveFormProvider.overrideWith2((_) => _EmptyFormNotifier()),
          gearListProvider.overrideWith((ref) async => fiftyItems()),
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
        find.text('Select gear'),
        find.byType(ListView),
        const Offset(0, -400),
      );
      await tester.tap(find.text('Select gear'));
      await tester.pumpAndSettle();

      // Toggle the first checkbox.
      await tester.tap(find.text('Gear 00'));
      await tester.pumpAndSettle();
      // Close the dialog.
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      final state = container.read(diveFormProvider(null)).requireValue;
      expect(state.selectedGearIds, contains(1));
      expect(find.text('Gear 00'), findsOneWidget);
    });
  });
}
