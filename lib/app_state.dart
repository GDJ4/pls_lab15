import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'models.dart';
import 'storage.dart';
import 'supabase_service.dart';

class AppState extends ChangeNotifier {
  AppState({
    CalorieStorage? storage,
    this.useSeedDishes = true,
    this.supabaseEnabled = true,
  }) : _storage = storage ?? CalorieStorage();

  final CalorieStorage _storage;
  final bool useSeedDishes;
  final bool supabaseEnabled;
  bool _ready = false;
  String? _currentUserId;
  List<Dish> _localDishes = [];
  List<Dish> _publicDishes = [];
  final Map<String, DailyLog> _logs = {};

  bool get isReady => _ready;

  List<Dish> get localDishes => List.unmodifiable(_localDishes);

  List<Dish> get publicDishes => List.unmodifiable(_publicDishes);

  List<Dish> get allDishes {
    final merged = <String, Dish>{};
    for (final dish in _publicDishes) {
      merged[dish.id] = dish;
    }
    for (final dish in _localDishes) {
      merged[dish.id] = dish;
    }
    return merged.values.toList();
  }

  Future<void> init({String? userId}) async {
    final sessionUser = supabaseEnabled && SupabaseService.isEnabled
        ? SupabaseService.currentSession?.user.id
        : null;
    await switchUser(userId ?? sessionUser);
  }

  Future<void> switchUser(String? userId) async {
    _ready = false;
    _currentUserId = userId;
    _localDishes = [];
    _publicDishes = [];
    _logs.clear();

    final loaded = await _storage.load(userId: _currentUserId);
    _localDishes = [...loaded.localDishes];
    _logs.addAll(loaded.logs);

    final useRemote = supabaseEnabled && SupabaseService.isEnabled;
    if (useRemote) {
      try {
        _publicDishes = await SupabaseService.fetchPublicDishes();
      } catch (_) {
        _publicDishes = [...loaded.publicDishes];
      }
      if (_currentUserId != null) {
        try {
          final userDishes =
              await SupabaseService.fetchPrivateDishes(_currentUserId!);
          _localDishes = _mergeDishes(_localDishes, userDishes);
          final userLogs =
              await SupabaseService.fetchPrivateLogs(_currentUserId!);
          _logs.addAll(userLogs);
        } catch (_) {
          // fallback to local only
        }
      }
    }
    _publicDishes = _publicDishes.isEmpty
        ? [
            if (useSeedDishes) ...seedPublicDishes(),
            ...loaded.publicDishes,
          ]
        : _publicDishes;
    _ready = true;
    notifyListeners();
  }

  DailyLog logFor(DateTime date) {
    final key = dateKey(date);
    return _logs.putIfAbsent(key, () => DailyLog(date: dateOnly(date)));
  }

  Dish? dishById(String id) {
    try {
      return allDishes.firstWhere((dish) => dish.id == id);
    } catch (_) {
      return null;
    }
  }

  NutritionSummary summaryFor(DateTime date) {
    final log = logFor(date);
    double calories = 0;
    double proteins = 0;
    double fats = 0;
    double carbs = 0;

    for (final meal in MealType.values) {
      for (final entry in log.entries[meal] ?? []) {
        final dish = dishById(entry.dishId);
        if (dish == null) continue;
        calories += dish.calories * entry.portion;
        proteins += dish.proteins * entry.portion;
        fats += dish.fats * entry.portion;
        carbs += dish.carbs * entry.portion;
      }
    }

    return NutritionSummary(
      calories: calories,
      proteins: proteins,
      fats: fats,
      carbs: carbs,
    );
  }

  void addDish(Dish dish, {bool publish = false}) {
    final updatedDish = dish.copyWith(isPublished: publish || dish.isPublished);
    _localDishes.add(updatedDish);
    if (updatedDish.isPublished) {
      _upsertPublic(updatedDish);
    }
    unawaited(_persist());
    if (_currentUserId != null) {
      unawaited(SupabaseService.upsertPrivateDish(_currentUserId!, updatedDish));
    }
    if (updatedDish.isPublished && supabaseEnabled && SupabaseService.isEnabled) {
      unawaited(SupabaseService.publishDish(updatedDish));
    }
    notifyListeners();
  }

  void publishDish(Dish dish) {
    _upsertPublic(dish.copyWith(isPublished: true));
    final index = _localDishes.indexWhere((item) => item.id == dish.id);
    if (index != -1) {
      _localDishes[index] = dish.copyWith(isPublished: true);
    }
    unawaited(_persist());
    if (_currentUserId != null) {
      unawaited(SupabaseService.upsertPrivateDish(_currentUserId!, dish));
    }
    if (supabaseEnabled && SupabaseService.isEnabled) {
      unawaited(SupabaseService.publishDish(dish));
    }
    notifyListeners();
  }

  void updateDish(Dish dish) {
    final localIndex = _localDishes.indexWhere((item) => item.id == dish.id);
    if (localIndex != -1) {
      _localDishes[localIndex] = dish;
    }

    final publicIndex = _publicDishes.indexWhere((item) => item.id == dish.id);
    if (publicIndex != -1 || dish.isPublished) {
      _upsertPublic(dish.copyWith(isPublished: true));
    }
    unawaited(_persist());
    if (_currentUserId != null) {
      unawaited(SupabaseService.upsertPrivateDish(_currentUserId!, dish));
    }
    notifyListeners();
  }

  void togglePublication(String dishId, bool publish) {
    final localIndex = _localDishes.indexWhere((dish) => dish.id == dishId);
    if (localIndex != -1) {
      _localDishes[localIndex] =
          _localDishes[localIndex].copyWith(isPublished: publish);
    }

    if (publish) {
      final local = dishById(dishId);
      if (local != null) {
        _upsertPublic(local.copyWith(isPublished: true));
        if (supabaseEnabled && SupabaseService.isEnabled) {
          unawaited(SupabaseService.publishDish(local.copyWith(isPublished: true)));
        }
      }
    } else {
      _publicDishes.removeWhere((dish) => dish.id == dishId);
    }
    unawaited(_persist());
    notifyListeners();
  }

  void addEntry(DateTime date, MealType meal, Dish dish, double portion) {
    final log = logFor(date);
    final entry = MealEntry(
      id: _generateId(),
      dishId: dish.id,
      meal: meal,
      portion: portion,
    );
    log.entries[meal]?.add(entry);
    _incrementUsage(dish.id);
    unawaited(_persist());
    if (supabaseEnabled && SupabaseService.isEnabled) {
      unawaited(SupabaseService.incrementUsage(dish.id));
    }
    if (_currentUserId != null) {
      unawaited(SupabaseService.upsertPrivateLog(_currentUserId!, log));
    }
    notifyListeners();
  }

  void removeEntry(DateTime date, MealEntry entry) {
    final log = logFor(date);
    log.entries[entry.meal]?.removeWhere((item) => item.id == entry.id);
    unawaited(_persist());
    if (_currentUserId != null) {
      unawaited(SupabaseService.upsertPrivateLog(_currentUserId!, log));
    }
    notifyListeners();
  }

  List<Dish> searchDishes(
    String query, {
    bool includeLocal = true,
    bool includePublic = true,
  }) {
    final normalized = query.toLowerCase().trim();
    final pool = <Dish>[
      if (includePublic) ..._publicDishes,
      if (includeLocal) ..._localDishes,
    ];

    final seen = <String>{};
    final filtered = <Dish>[];
    for (final dish in pool) {
      if (!seen.add(dish.id)) continue;
      if (normalized.isEmpty ||
          dish.name.toLowerCase().contains(normalized) ||
          dish.name.toLowerCase().startsWith(normalized)) {
        filtered.add(dish);
      }
    }

    filtered.sort((a, b) {
      final scoreB = _dishScore(b, normalized);
      final scoreA = _dishScore(a, normalized);
      if (scoreB != scoreA) return scoreB.compareTo(scoreA);
      return b.createdAt.compareTo(a.createdAt);
    });
    return filtered;
  }

  List<Dish> popularDishes([int limit = 6]) {
    final sorted = [..._publicDishes]..sort(
        (a, b) {
          if (b.usageCount != a.usageCount) {
            return b.usageCount.compareTo(a.usageCount);
          }
          return a.calories.compareTo(b.calories);
        },
      );
    return sorted.take(limit).toList();
  }

  String allocateId() => _generateId();

  String _generateId() => DateTime.now().microsecondsSinceEpoch.toString();

  void _incrementUsage(String dishId) {
    for (var i = 0; i < _localDishes.length; i++) {
      if (_localDishes[i].id == dishId) {
        _localDishes[i] =
            _localDishes[i].copyWith(usageCount: _localDishes[i].usageCount + 1);
      }
    }
    for (var i = 0; i < _publicDishes.length; i++) {
      if (_publicDishes[i].id == dishId) {
        _publicDishes[i] =
            _publicDishes[i].copyWith(usageCount: _publicDishes[i].usageCount + 1);
      }
    }
  }

  void _upsertPublic(Dish dish) {
    final index = _publicDishes.indexWhere((item) => item.id == dish.id);
    if (index == -1) {
      _publicDishes.add(dish.copyWith(isPublished: true));
    } else {
      _publicDishes[index] = dish.copyWith(isPublished: true);
    }
  }

  int _dishScore(Dish dish, String query) {
    final popularWeight = dish.usageCount * 6;
    final plausibleCalories = (dish.calories >= 40 && dish.calories <= 1500) ? 10 : 0;
    final absurdPenalty = dish.calories > 3000 ? -40 : 0;
    final textBoost = query.isNotEmpty && dish.name.toLowerCase().startsWith(query) ? 8 : 0;
    final freshnessBonus = max(0, 5 - DateTime.now().difference(dish.createdAt).inDays);
    return popularWeight + plausibleCalories + absurdPenalty + textBoost + freshnessBonus;
  }

  Future<void> _persist() async {
    final snapshot = StoredState(
      localDishes: _localDishes,
      publicDishes: _publicDishes,
      logs: _logs,
    );
    await _storage.save(snapshot, userId: _currentUserId);
  }

  List<Dish> _mergeDishes(List<Dish> base, List<Dish> incoming) {
    final map = {for (final dish in base) dish.id: dish};
    for (final dish in incoming) {
      map[dish.id] = dish;
    }
    return map.values.toList();
  }
}
