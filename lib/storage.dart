import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class StoredState {
  const StoredState({
    required this.localDishes,
    required this.publicDishes,
    required this.logs,
  });

  const StoredState.empty()
      : localDishes = const [],
        publicDishes = const [],
        logs = const {};

  final List<Dish> localDishes;
  final List<Dish> publicDishes;
  final Map<String, DailyLog> logs;

  Map<String, dynamic> toJson() => {
        'localDishes': localDishes.map((dish) => dish.toJson()).toList(),
        'publicDishes': publicDishes.map((dish) => dish.toJson()).toList(),
        'logs': logs.map((key, value) => MapEntry(key, value.toJson())),
      };

  factory StoredState.fromJson(Map<String, dynamic> json) {
    final local = (json['localDishes'] as List<dynamic>? ?? [])
        .map((item) => Dish.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();

    final public = (json['publicDishes'] as List<dynamic>? ?? [])
        .map((item) => Dish.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();

    final logsJson = json['logs'] as Map<String, dynamic>? ?? {};
    final parsedLogs = <String, DailyLog>{};
    for (final entry in logsJson.entries) {
      parsedLogs[entry.key] =
          DailyLog.fromJson(Map<String, dynamic>.from(entry.value as Map));
    }

    return StoredState(
      localDishes: local,
      publicDishes: public,
      logs: parsedLogs,
    );
  }
}

class CalorieStorage {
  static const _storageKey = 'calorie_app_state_v1';

  String _keyFor(String? userId) =>
      userId == null ? _storageKey : '$_storageKey::$userId';

  Future<StoredState> load({String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyFor(userId));
    if (raw == null) {
      return const StoredState.empty();
    }

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return StoredState.fromJson(decoded);
    } on FormatException {
      return const StoredState.empty();
    }
  }

  Future<void> save(StoredState state, {String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(state.toJson());
    await prefs.setString(_keyFor(userId), encoded);
  }
}
