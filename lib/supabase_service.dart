import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'models.dart';

class SupabaseService {
  SupabaseService._();

  static bool _initialized = false;
  static bool _enabled = false;

  static bool get isEnabled => _enabled;

  static SupabaseClient get _client => Supabase.instance.client;

  static Future<void> ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      _enabled = false;
      return;
    }
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
    _enabled = true;
  }

  static Stream<AuthState> authChanges() =>
      _client.auth.onAuthStateChange;

  static Session? get currentSession => _client.auth.currentSession;

  static Future<AuthResponse> signIn(String email, String password) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  static Future<AuthResponse> signUp(String email, String password) {
    return _client.auth.signUp(email: email, password: password);
  }

  static Future<void> signOut() => _client.auth.signOut();

  /// Читает опубликованные блюда из таблицы public_dishes.
  static Future<List<Dish>> fetchPublicDishes() async {
    if (!_enabled) return seedPublicDishes();
    final response = await _client
        .from('public_dishes')
        .select()
        .order('usage_count', ascending: false);

    final rows = List<Map<String, dynamic>>.from(response);
    return rows
        .map((row) => Dish(
              id: row['id'] as String,
              name: row['name'] as String,
              calories: (row['calories'] as num).round(),
              proteins: (row['proteins'] as num).toDouble(),
              fats: (row['fats'] as num).toDouble(),
              carbs: (row['carbs'] as num).toDouble(),
              description: row['description'] as String?,
              isPublished: true,
              imagePath: row['image_url'] as String?,
              usageCount: (row['usage_count'] as num?)?.round() ?? 0,
              createdAt: DateTime.tryParse(row['created_at'] as String? ?? '') ??
                  DateTime.now(),
            ))
        .toList();
  }

  static Future<void> publishDish(Dish dish) async {
    if (!_enabled) return;
    String? imageUrl = dish.imagePath;
    if (dish.imagePath != null && File(dish.imagePath!).existsSync()) {
      try {
        final bytes = await File(dish.imagePath!).readAsBytes();
        final fileName = '${dish.id}.jpg';
        await _client.storage.from('dish_photos').uploadBinary(
              fileName,
              bytes,
              fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
            );
        imageUrl = _client.storage.from('dish_photos').getPublicUrl(fileName);
      } catch (e) {
        debugPrint('Upload dish photo failed (check bucket policy): $e');
        imageUrl = null;
      }
    }
    try {
      await _client.from('public_dishes').upsert({
        'id': dish.id,
        'name': dish.name,
        'calories': dish.calories,
        'proteins': dish.proteins,
        'fats': dish.fats,
        'carbs': dish.carbs,
        'description': dish.description,
        'image_url': imageUrl,
        'usage_count': dish.usageCount,
      });
    } catch (e) {
      debugPrint('Publish dish failed: $e');
    }
  }

  static Future<void> incrementUsage(String dishId) async {
    if (!_enabled) return;
    try {
      await _client.rpc('increment_usage', params: {'dish_id': dishId});
    } catch (e) {
      debugPrint('incrementUsage rpc failed: $e');
    }
  }

  static Future<List<Dish>> fetchPrivateDishes(String userId) async {
    if (!_enabled) return [];
    final response = await _client
        .from('user_dishes')
        .select()
        .eq('user_id', userId);

    final rows = List<Map<String, dynamic>>.from(response);
    return rows
        .map((row) => Dish(
              id: row['id'] as String,
              name: row['name'] as String,
              calories: (row['calories'] as num).round(),
              proteins: (row['proteins'] as num).toDouble(),
              fats: (row['fats'] as num).toDouble(),
              carbs: (row['carbs'] as num).toDouble(),
              description: row['description'] as String?,
              isPublished: false,
              imagePath: row['image_url'] as String?,
              usageCount: (row['usage_count'] as num?)?.round() ?? 0,
              createdAt: DateTime.tryParse(row['created_at'] as String? ?? '') ??
                  DateTime.now(),
            ))
        .toList();
  }

  static Future<Map<String, DailyLog>> fetchPrivateLogs(String userId) async {
    if (!_enabled) return {};
    final response = await _client
        .from('user_logs')
        .select()
        .eq('user_id', userId);

    final rows = List<Map<String, dynamic>>.from(response);
    final result = <String, DailyLog>{};
    for (final row in rows) {
      final date = row['date'] as String;
      final entries = Map<String, dynamic>.from(row['entries'] as Map? ?? {});
      result[date] = DailyLog.fromJson({
        'date': date,
        'entries': entries,
      });
    }
    return result;
  }

  static Future<void> upsertPrivateDish(String userId, Dish dish) async {
    if (!_enabled) return;
    await _client.from('user_dishes').upsert({
      'user_id': userId,
      'id': dish.id,
      'name': dish.name,
      'calories': dish.calories,
      'proteins': dish.proteins,
      'fats': dish.fats,
      'carbs': dish.carbs,
      'description': dish.description,
      'usage_count': dish.usageCount,
      'image_url': dish.imagePath,
    });
  }

  static Future<void> upsertPrivateLog(String userId, DailyLog log) async {
    if (!_enabled) return;
    await _client.from('user_logs').upsert({
      'user_id': userId,
      'date': dateKey(log.date),
      'entries': log.toJson()['entries'],
    });
  }
}
