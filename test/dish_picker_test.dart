import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lab14/app_state.dart';
import 'package:lab14/main.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('DishPickerSheet highlights popular items and search', (tester) async {
    final state = AppState(
      storage: FakeStorage(),
      supabaseEnabled: false,
    );
    await state.init();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DishPickerSheet(state: state),
        ),
      ),
    );

    expect(find.text('Популярное:'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'овсянка');
    await tester.pumpAndSettle();

    expect(find.textContaining('Овсянка'), findsWidgets);
  });
}
