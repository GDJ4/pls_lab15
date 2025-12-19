import 'package:flutter_test/flutter_test.dart';

import 'package:lab14/app_state.dart';
import 'package:lab14/models.dart';
import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('summary counts macros for the day', () async {
    final storage = FakeStorage();
    final state = AppState(
      storage: storage,
      useSeedDishes: false,
      supabaseEnabled: false,
    );
    await state.init();

    final dish = Dish(
      id: 'd1',
      name: 'Тестовый салат',
      calories: 250,
      proteins: 12,
      fats: 8,
      carbs: 30,
    );
    state.addDish(dish);
    final today = dateOnly(DateTime.now());
    state.addEntry(today, MealType.breakfast, dish, 2);

    final summary = state.summaryFor(today);
    expect(summary.calories, 500);
    expect(summary.proteins, 24);
    expect(summary.fats, 16);
    expect(summary.carbs, 60);
  });

  test('popular sorting demotes absurd calories', () async {
    final storage = FakeStorage();
    final state = AppState(
      storage: storage,
      useSeedDishes: false,
      supabaseEnabled: false,
    );
    await state.init();

    final normal = Dish(
      id: 'normal',
      name: 'Творог 200',
      calories: 200,
      proteins: 20,
      fats: 5,
      carbs: 15,
      usageCount: 10,
    );
    final absurd = Dish(
      id: 'absurd',
      name: 'Творог 2500000000',
      calories: 2500000000,
      proteins: 10,
      fats: 10,
      carbs: 10,
    );
    state.addDish(normal, publish: true);
    state.addDish(absurd, publish: true);

    final results = state.searchDishes('творог');
    expect(results.first.id, 'normal');
    expect(results.last.id, 'absurd');
  });

  test('togglePublication keeps dish locally but hides from каталог', () async {
    final storage = FakeStorage();
    final state = AppState(
      storage: storage,
      useSeedDishes: false,
      supabaseEnabled: false,
    );
    await state.init();

    final dish = Dish(
      id: 'd3',
      name: 'Паста',
      calories: 320,
      proteins: 14,
      fats: 8,
      carbs: 45,
      isPublished: true,
    );
    state.addDish(dish, publish: true);
    expect(state.publicDishes.any((item) => item.id == dish.id), isTrue);

    state.togglePublication(dish.id, false);
    expect(state.publicDishes.any((item) => item.id == dish.id), isFalse);
    expect(state.localDishes.any((item) => item.id == dish.id), isTrue);
  });
}
