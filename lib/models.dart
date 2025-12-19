import 'package:flutter/material.dart';

enum MealType { breakfast, lunch, dinner, snack }

const Map<MealType, String> mealTypeLabels = {
  MealType.breakfast: 'Завтрак',
  MealType.lunch: 'Обед',
  MealType.dinner: 'Ужин',
  MealType.snack: 'Перекус',
};

IconData mealTypeIcon(MealType type) {
  switch (type) {
    case MealType.breakfast:
      return Icons.wb_sunny_outlined;
    case MealType.lunch:
      return Icons.ramen_dining;
    case MealType.dinner:
      return Icons.dinner_dining;
    case MealType.snack:
      return Icons.coffee;
  }
}

MealType mealTypeFromString(String value) {
  return MealType.values
      .firstWhere((type) => type.name == value, orElse: () => MealType.snack);
}

DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

String dateKey(DateTime date) => dateOnly(date).toIso8601String();

class Dish {
  Dish({
    required this.id,
    required this.name,
    required this.calories,
    required this.proteins,
    required this.fats,
    required this.carbs,
    this.description,
    this.isPublished = false,
    this.imagePath,
    this.usageCount = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  String name;
  int calories;
  double proteins;
  double fats;
  double carbs;
  String? description;
  bool isPublished;
  String? imagePath;
  int usageCount;
  DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'calories': calories,
        'proteins': proteins,
        'fats': fats,
        'carbs': carbs,
        'description': description,
        'isPublished': isPublished,
        'imagePath': imagePath,
        'usageCount': usageCount,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Dish.fromJson(Map<String, dynamic> json) {
    return Dish(
      id: json['id'] as String,
      name: json['name'] as String,
      calories: (json['calories'] as num).round(),
      proteins: (json['proteins'] as num).toDouble(),
      fats: (json['fats'] as num).toDouble(),
      carbs: (json['carbs'] as num).toDouble(),
      description: json['description'] as String?,
      isPublished: json['isPublished'] as bool? ?? false,
      imagePath: json['imagePath'] as String?,
      usageCount: (json['usageCount'] as num?)?.round() ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Dish copyWith({
    String? id,
    String? name,
    int? calories,
    double? proteins,
    double? fats,
    double? carbs,
    String? description,
    bool? isPublished,
    String? imagePath,
    int? usageCount,
    DateTime? createdAt,
  }) {
    return Dish(
      id: id ?? this.id,
      name: name ?? this.name,
      calories: calories ?? this.calories,
      proteins: proteins ?? this.proteins,
      fats: fats ?? this.fats,
      carbs: carbs ?? this.carbs,
      description: description ?? this.description,
      isPublished: isPublished ?? this.isPublished,
      imagePath: imagePath ?? this.imagePath,
      usageCount: usageCount ?? this.usageCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class MealEntry {
  MealEntry({
    required this.id,
    required this.dishId,
    required this.meal,
    this.portion = 1,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String dishId;
  final MealType meal;
  final double portion;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'dishId': dishId,
        'meal': meal.name,
        'portion': portion,
        'createdAt': createdAt.toIso8601String(),
      };

  factory MealEntry.fromJson(Map<String, dynamic> json) {
    return MealEntry(
      id: json['id'] as String,
      dishId: json['dishId'] as String,
      meal: mealTypeFromString(json['meal'] as String),
      portion: (json['portion'] as num?)?.toDouble() ?? 1,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class DailyLog {
  DailyLog({
    required this.date,
    Map<MealType, List<MealEntry>>? entries,
  }) : entries = entries ??
            {
              for (final meal in MealType.values) meal: <MealEntry>[],
            };

  final DateTime date;
  final Map<MealType, List<MealEntry>> entries;

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'entries': entries.map(
          (key, value) =>
              MapEntry(key.name, value.map((entry) => entry.toJson()).toList()),
        ),
      };

  factory DailyLog.fromJson(Map<String, dynamic> json) {
    final parsedDate =
        DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now();
    final Map<MealType, List<MealEntry>> parsedEntries = {};
    final entriesJson = json['entries'] as Map<String, dynamic>? ?? {};
    for (final type in MealType.values) {
      final list = entriesJson[type.name] as List<dynamic>? ?? [];
      parsedEntries[type] =
          list.map((item) => MealEntry.fromJson(item as Map<String, dynamic>)).toList();
    }
    return DailyLog(date: dateOnly(parsedDate), entries: parsedEntries);
  }
}

class NutritionSummary {
  const NutritionSummary({
    required this.calories,
    required this.proteins,
    required this.fats,
    required this.carbs,
  });

  final double calories;
  final double proteins;
  final double fats;
  final double carbs;
}

List<Dish> seedPublicDishes() {
  final sample = [
    Dish(
      id: 'seed-omelette',
      name: 'Омлет с овощами',
      calories: 320,
      proteins: 24,
      fats: 18,
      carbs: 12,
      isPublished: true,
      usageCount: 42,
    ),
    Dish(
      id: 'seed-oat',
      name: 'Овсянка с ягодами',
      calories: 280,
      proteins: 10,
      fats: 8,
      carbs: 40,
      isPublished: true,
      usageCount: 37,
    ),
    Dish(
      id: 'seed-chicken',
      name: 'Курица с рисом',
      calories: 450,
      proteins: 38,
      fats: 12,
      carbs: 55,
      isPublished: true,
      usageCount: 51,
    ),
    Dish(
      id: 'seed-cottage',
      name: 'Творог 5% с мёдом',
      calories: 210,
      proteins: 24,
      fats: 7,
      carbs: 16,
      isPublished: true,
      usageCount: 46,
    ),
  ];

  return sample;
}
