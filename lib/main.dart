import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_state.dart';
import 'models.dart';
import 'supabase_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SupabaseService.ensureInitialized().then(
    (_) => runApp(const CalorieApp()),
  );
}

class CalorieApp extends StatefulWidget {
  const CalorieApp({super.key});

  @override
  State<CalorieApp> createState() => _CalorieAppState();
}

class _CalorieAppState extends State<CalorieApp> {
  late final AppState _state = AppState();
  late final Future<void> _init = _state.init();
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    if (SupabaseService.isEnabled) {
      _authSub = SupabaseService.authChanges().listen((_) {
        final userId = SupabaseService.currentSession?.user.id;
        _state.switchUser(userId);
      });
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Счётчик калорий',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        scaffoldBackgroundColor: const Color(0xFFF7F7F7),
        useMaterial3: true,
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ru', 'RU'),
        Locale('en', ''),
      ],
      home: FutureBuilder<void>(
        future: _init,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _LoadingScreen();
          }
          return AppStateScope(
            state: _state,
            child: AuthGate(
              enabled: SupabaseService.isEnabled,
              child: const HomeShell(),
            ),
          );
        },
      ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Загружаем дневник...'),
          ],
        ),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({required this.enabled, required this.child, super.key});

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return StreamBuilder<AuthState>(
      stream: SupabaseService.authChanges(),
      builder: (context, snapshot) {
        final session = SupabaseService.currentSession;
        if (snapshot.connectionState == ConnectionState.waiting &&
            session == null) {
          return const _LoadingScreen();
        }
        if (session != null) {
          return child;
        }
        return const AuthScreen();
      },
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _register = false;
  bool _loading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Вход в аккаунт')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Supabase ${_register ? "регистрация" : "логин"}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) =>
                    v != null && v.contains('@') ? null : 'Неверный email',
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _passwordCtrl,
                decoration: const InputDecoration(labelText: 'Пароль'),
                obscureText: true,
                validator: (v) =>
                    v != null && v.length >= 6 ? null : 'Минимум 6 символов',
              ),
              const SizedBox(height: 12),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              if (_register)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'После регистрации подтвердите email через письмо от Supabase, иначе вход не сработает.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.orange.shade700),
                  ),
                ),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: Text(_register ? 'Зарегистрироваться' : 'Войти'),
                  ),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () => setState(() => _register = !_register),
                    child: Text(
                      _register ? 'У меня есть аккаунт' : 'Регистрация',
                    ),
                  ),
                  TextButton(
                    onPressed: _loading ? null : () => _skip(context),
                    child: const Text('Гостевой режим'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_register) {
        await SupabaseService.signUp(
          _emailCtrl.text.trim(),
          _passwordCtrl.text,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Проверьте почту и подтвердите email для входа'),
            ),
          );
        }
      } else {
        await SupabaseService.signIn(
          _emailCtrl.text.trim(),
          _passwordCtrl.text,
        );
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _skip(BuildContext context) {
    AppStateScope.of(context).switchUser(null);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeShell()),
    );
  }
}

class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope({
    required AppState state,
    required super.child,
    super.key,
  }) : super(notifier: state);

  static AppState of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AppStateScope>();
    assert(scope != null, 'AppStateScope не найден');
    return scope!.notifier!;
  }

  static AppState? maybeOf(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AppStateScope>();
    return scope?.notifier;
  }

  @override
  bool updateShouldNotify(covariant InheritedNotifier<AppState> oldWidget) {
    return true;
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _tabIndex,
          children: const [
            DailyLogPage(),
            DishesPage(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (index) => setState(() => _tabIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: 'День',
          ),
          NavigationDestination(
            icon: Icon(Icons.restaurant_menu_outlined),
            selectedIcon: Icon(Icons.restaurant_menu),
            label: 'Блюда',
          ),
        ],
      ),
    );
  }
}

class DailyLogPage extends StatefulWidget {
  const DailyLogPage({super.key});

  @override
  State<DailyLogPage> createState() => _DailyLogPageState();
}

class _DailyLogPageState extends State<DailyLogPage> {
  DateTime _selectedDate = dateOnly(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final summary = state.summaryFor(_selectedDate);
    final log = state.logFor(_selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Дневник калорий'),
        actions: [
          IconButton(
            tooltip: 'Выбрать дату',
            icon: const Icon(Icons.calendar_today),
            onPressed: _pickDate,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _DateHeader(
            date: _selectedDate,
            onPrev: () => setState(
              () => _selectedDate = _selectedDate.subtract(const Duration(days: 1)),
            ),
            onNext: () => setState(
              () => _selectedDate = _selectedDate.add(const Duration(days: 1)),
            ),
          ),
          const SizedBox(height: 12),
          _SummaryCard(summary: summary),
          const SizedBox(height: 20),
          FilledButton.tonalIcon(
            onPressed: () => _openDishForm(context),
            icon: const Icon(Icons.add_a_photo_outlined),
            label: const Text('Создать своё блюдо'),
          ),
          const SizedBox(height: 12),
          for (final meal in MealType.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _MealSection(
                meal: meal,
                log: log,
                date: _selectedDate,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final chosen = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('ru', 'RU'),
    );
    if (chosen != null) {
      setState(() => _selectedDate = dateOnly(chosen));
    }
  }

  void _openDishForm(BuildContext context) {
    final state = AppStateScope.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DishFormSheet(state: state),
    );
  }
}

class _DateHeader extends StatelessWidget {
  const _DateHeader({
    required this.date,
    required this.onPrev,
    required this.onNext,
  });

  final DateTime date;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final today = dateOnly(DateTime.now());
    final isToday = dateOnly(date) == today;
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: onPrev,
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                _formatDate(date),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                isToday ? 'Сегодня' : 'План на день',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: onNext,
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'января',
      'февраля',
      'марта',
      'апреля',
      'мая',
      'июня',
      'июля',
      'августа',
      'сентября',
      'октября',
      'ноября',
      'декабря',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final NutritionSummary summary;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.labelLarge;
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Итоги за день',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _StatChip(
                  label: 'Калории',
                  value: summary.calories.toStringAsFixed(0),
                  color: Colors.deepOrange.shade300,
                  textStyle: textStyle,
                ),
                _StatChip(
                  label: 'Белки',
                  value: '${summary.proteins.toStringAsFixed(1)} г',
                  color: Colors.teal.shade300,
                  textStyle: textStyle,
                ),
                _StatChip(
                  label: 'Жиры',
                  value: '${summary.fats.toStringAsFixed(1)} г',
                  color: Colors.amber.shade500,
                  textStyle: textStyle,
                ),
                _StatChip(
                  label: 'Углеводы',
                  value: '${summary.carbs.toStringAsFixed(1)} г',
                  color: Colors.blue.shade300,
                  textStyle: textStyle,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
    required this.textStyle,
  });

  final String label;
  final String value;
  final Color color;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return Chip(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      avatar: CircleAvatar(backgroundColor: color.withValues(alpha: 0.2)),
      label: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: textStyle),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
      backgroundColor: Colors.grey.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

class _MealSection extends StatelessWidget {
  const _MealSection({
    required this.meal,
    required this.log,
    required this.date,
  });

  final MealType meal;
  final DailyLog log;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final entries = log.entries[meal] ?? [];
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(mealTypeIcon(meal), color: Colors.grey.shade700),
                    const SizedBox(width: 8),
                    Text(
                      mealTypeLabels[meal] ?? '',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                Text(
                  '${entries.length} блюд',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Пока ничего не добавлено',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              )
            else
              ...entries.map(
                (entry) => _MealEntryTile(
                  entry: entry,
                  dish: state.dishById(entry.dishId),
                  onRemove: () => state.removeEntry(date, entry),
                ),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _openPicker(context, state),
                icon: const Icon(Icons.add),
                label: const Text('Добавить блюдо'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPicker(BuildContext context, AppState state) async {
    final dish = await showDishPicker(context, state: state);
    if (dish == null) return;
    if (!context.mounted) return;

    final portion = await showDialog<double>(
      context: context,
      builder: (context) {
        final controller = TextEditingController(text: '1');
        return AlertDialog(
          title: const Text('Указать порцию'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Количество порций',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                final value = double.tryParse(controller.text.replaceAll(',', '.'));
                Navigator.pop(context, value ?? 1);
              },
              child: const Text('Добавить'),
            ),
          ],
        );
      },
    );

    if (portion != null) {
      state.addEntry(date, meal, dish, portion);
    }
  }
}

class _MealEntryTile extends StatelessWidget {
  const _MealEntryTile({
    required this.entry,
    required this.dish,
    required this.onRemove,
  });

  final MealEntry entry;
  final Dish? dish;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    if (dish == null) {
      return ListTile(
        title: const Text('Блюдо удалено'),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: onRemove,
        ),
      );
    }

    final totalCalories = (dish!.calories * entry.portion).toStringAsFixed(0);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      title: Text(dish!.name),
      subtitle: Wrap(
        spacing: 8,
        children: [
          Text('${dish!.calories} ккал x ${entry.portion.toStringAsFixed(1)}'),
          Text('Б: ${(dish!.proteins * entry.portion).toStringAsFixed(1)}'),
          Text('Ж: ${(dish!.fats * entry.portion).toStringAsFixed(1)}'),
          Text('У: ${(dish!.carbs * entry.portion).toStringAsFixed(1)}'),
        ],
      ),
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$totalCalories ккал',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            icon: const Icon(Icons.close),
            tooltip: 'Удалить',
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

class DishesPage extends StatefulWidget {
  const DishesPage({super.key});

  @override
  State<DishesPage> createState() => _DishesPageState();
}

class _DishesPageState extends State<DishesPage> {
  final _searchCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final query = _searchCtrl.text.trim();
    final publicDishes = state.searchDishes(query, includePublic: true, includeLocal: true);
    final myDishes = state.localDishes;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Библиотека блюд'),
        actions: [
          if (SupabaseService.isEnabled && SupabaseService.currentSession != null)
            IconButton(
              tooltip: 'Выйти',
              onPressed: () => SupabaseService.signOut(),
              icon: const Icon(Icons.logout),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          TextField(
            controller: _searchCtrl,
            decoration: const InputDecoration(
              labelText: 'Поиск блюда',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Text(
            'Мои блюда',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (myDishes.isEmpty)
            const Text('Вы ещё не создали блюдо. Создайте и при желании опубликуйте.')
          else
            ...myDishes.map(
              (dish) => Card(
                child: SwitchListTile(
                  title: Text(dish.name),
                  subtitle: Text(
                    '${dish.calories} ккал • Б ${dish.proteins.toStringAsFixed(1)} / Ж ${dish.fats.toStringAsFixed(1)} / У ${dish.carbs.toStringAsFixed(1)}',
                  ),
                  value: dish.isPublished,
                  onChanged: (value) => _handlePublishToggle(context, state, dish, value),
                  secondary: const Icon(Icons.verified_user_outlined),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Каталог пользователей',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text('${publicDishes.length} блюд'),
            ],
          ),
          const SizedBox(height: 8),
          ...publicDishes.map((dish) => _DishCard(dish: dish, state: state)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            builder: (_) => DishFormSheet(state: state),
          );
        },
        icon: const Icon(Icons.add_a_photo),
        label: const Text('Опубликовать своё блюдо'),
      ),
    );
  }

  Future<void> _handlePublishToggle(
    BuildContext context,
    AppState state,
    Dish dish,
    bool publish,
  ) async {
    if (publish && (dish.imagePath?.isEmpty ?? true)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Для публикации добавьте фото блюда'),
        ),
      );
      final updated = await showDialog<Dish>(
        context: context,
        builder: (context) => _PhotoRequestDialog(dish: dish),
      );
      if (updated != null) {
        state.updateDish(updated.copyWith(isPublished: publish));
      }
      return;
    }
    state.togglePublication(dish.id, publish);
  }
}

class _DishCard extends StatelessWidget {
  const _DishCard({required this.dish, required this.state});

  final Dish dish;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final isSuspicious = dish.calories > 3000;
    return Card(
      child: InkWell(
        onTap: () => _openDetails(context, dish),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ListTile(
            leading: _DishAvatar(dish: dish),
            title: Text(dish.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${dish.calories} ккал • Б ${dish.proteins.toStringAsFixed(1)} / Ж ${dish.fats.toStringAsFixed(1)} / У ${dish.carbs.toStringAsFixed(1)}',
                ),
                if (dish.description != null && dish.description!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      dish.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                Wrap(
                  spacing: 6,
                  children: [
                    Chip(
                      label: Text('Выбрано ${dish.usageCount} раз'),
                      avatar: const Icon(Icons.trending_up, size: 18),
                    ),
                    if (isSuspicious)
                      Chip(
                        label: const Text('Похоже на ошибку'),
                        backgroundColor: Colors.red.shade50,
                        labelStyle: const TextStyle(color: Colors.red),
                      ),
                  ],
                ),
              ],
            ),
            trailing: dish.isPublished ? const Icon(Icons.public) : const Icon(Icons.lock_outline),
          ),
        ),
      ),
    );
  }

  void _openDetails(BuildContext context, Dish dish) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DishDetailsSheet(dish: dish, state: state),
    );
  }
}

class _DishAvatar extends StatelessWidget {
  const _DishAvatar({required this.dish});

  final Dish dish;

  @override
  Widget build(BuildContext context) {
    final path = dish.imagePath;
    if (path != null && path.isNotEmpty) {
      if (path.startsWith('http')) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            path,
            width: 48,
            height: 48,
            fit: BoxFit.cover,
          ),
        );
      }
      final file = File(path);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            file,
            width: 48,
            height: 48,
            fit: BoxFit.cover,
          ),
        );
      }
    }
    return CircleAvatar(
      backgroundColor: Colors.green.shade50,
      child: Text(
        dish.name.characters.take(1).toString().toUpperCase(),
        style: const TextStyle(color: Colors.green),
      ),
    );
  }
}

class DishDetailsSheet extends StatelessWidget {
  const DishDetailsSheet({required this.dish, required this.state, super.key});

  final Dish dish;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  dish.name,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _DishHeroImage(dish: dish),
          const SizedBox(height: 12),
          Text(
            '${dish.calories} ккал на порцию',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            'Б ${dish.proteins.toStringAsFixed(1)} / Ж ${dish.fats.toStringAsFixed(1)} / У ${dish.carbs.toStringAsFixed(1)}',
          ),
          if (dish.description != null && dish.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              dish.description!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              Chip(
                label: Text('Выбрано ${dish.usageCount} раз'),
                avatar: const Icon(Icons.trending_up, size: 18),
              ),
              if (dish.isPublished) const Chip(label: Text('Публиковано')),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Добавить в дневник'),
              onPressed: () async {
                final meal = await _pickMeal(context);
                if (meal == null) return;
                if (!context.mounted) return;
                final portion = await _pickPortion(context);
                if (portion == null) return;
                state.addEntry(dateOnly(DateTime.now()), meal, dish, portion);
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<MealType?> _pickMeal(BuildContext context) async {
    return showModalBottomSheet<MealType>(
      context: context,
      builder: (_) {
        return Wrap(
          children: [
            const ListTile(title: Text('Выберите приём пищи')),
            ...MealType.values.map(
              (meal) => ListTile(
                leading: Icon(mealTypeIcon(meal)),
                title: Text(mealTypeLabels[meal] ?? ''),
                onTap: () => Navigator.pop(context, meal),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<double?> _pickPortion(BuildContext context) async {
    final controller = TextEditingController(text: '1');
    return showDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Количество порций'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Порции',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                final v = double.tryParse(controller.text.replaceAll(',', '.'));
                Navigator.pop(context, v ?? 1);
              },
              child: const Text('Добавить'),
            ),
          ],
        );
      },
    );
  }
}

class _DishHeroImage extends StatelessWidget {
  const _DishHeroImage({required this.dish});

  final Dish dish;

  @override
  Widget build(BuildContext context) {
    final path = dish.imagePath;
    Widget image;
    if (path != null && path.isNotEmpty) {
      if (path.startsWith('http')) {
        image = Image.network(path, fit: BoxFit.cover, height: 180, width: double.infinity);
      } else {
        final file = File(path);
        if (file.existsSync()) {
          image = Image.file(file, fit: BoxFit.cover, height: 180, width: double.infinity);
        } else {
          image = _placeholder();
        }
      }
    } else {
      image = _placeholder();
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: image,
    );
  }

  Widget _placeholder() {
    return Container(
      height: 180,
      color: Colors.grey.shade200,
      child: const Center(child: Icon(Icons.image_not_supported_outlined, size: 48)),
    );
  }
}

Future<Dish?> showDishPicker(
  BuildContext context, {
  required AppState state,
}) async {
  return showModalBottomSheet<Dish>(
    context: context,
    isScrollControlled: true,
    builder: (_) => DishPickerSheet(state: state),
  );
}

class DishPickerSheet extends StatefulWidget {
  const DishPickerSheet({required this.state, super.key});

  final AppState state;

  @override
  State<DishPickerSheet> createState() => _DishPickerSheetState();
}

class _DishPickerSheetState extends State<DishPickerSheet> {
  final _queryCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final query = _queryCtrl.text;
    final results = widget.state.searchDishes(query);
    final popular = widget.state.popularDishes();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
        left: 16,
        right: 16,
        top: 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          TextField(
            controller: _queryCtrl,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Поиск блюда',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          if (query.isEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  const Text('Популярное:'),
                  ...popular.map(
                    (dish) => ActionChip(
                      label: Text(dish.name),
                      onPressed: () => Navigator.pop(context, dish),
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.55,
            child: results.isEmpty
                ? const Center(child: Text('Ничего не найдено'))
                : ListView.separated(
                    itemCount: results.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final dish = results[index];
                      final suspicious = dish.calories > 3000;
                      return ListTile(
                        onTap: () => Navigator.pop(context, dish),
                        leading: _DishAvatar(dish: dish),
                        title: Text(dish.name),
                        subtitle: Text(
                          '${dish.calories} ккал • Б ${dish.proteins.toStringAsFixed(1)} / Ж ${dish.fats.toStringAsFixed(1)} / У ${dish.carbs.toStringAsFixed(1)}',
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('x${dish.usageCount}'),
                            if (suspicious)
                              const Icon(
                                Icons.flag_outlined,
                                color: Colors.red,
                                size: 18,
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class DishFormSheet extends StatefulWidget {
  const DishFormSheet({required this.state, super.key});

  final AppState state;

  @override
  State<DishFormSheet> createState() => _DishFormSheetState();
}

class _DishFormSheetState extends State<DishFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _caloriesCtrl = TextEditingController();
  final _proteinsCtrl = TextEditingController();
  final _fatsCtrl = TextEditingController();
  final _carbsCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  bool _publish = false;
  String? _imagePath;
  final ImagePicker _picker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Новое блюдо',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Название'),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Введите название' : null,
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _caloriesCtrl,
                        decoration: const InputDecoration(labelText: 'Калории'),
                        keyboardType: TextInputType.number,
                        validator: _validateNumber,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _proteinsCtrl,
                        decoration: const InputDecoration(labelText: 'Белки (г)'),
                        keyboardType: TextInputType.number,
                        validator: _validateNumber,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _fatsCtrl,
                        decoration: const InputDecoration(labelText: 'Жиры (г)'),
                        keyboardType: TextInputType.number,
                        validator: _validateNumber,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _carbsCtrl,
                        decoration: const InputDecoration(labelText: 'Углеводы (г)'),
                        keyboardType: TextInputType.number,
                        validator: _validateNumber,
                      ),
                    ),
                  ],
                ),
                TextFormField(
                  controller: _descriptionCtrl,
                  decoration: const InputDecoration(labelText: 'Описание / рецепт'),
                  minLines: 2,
                  maxLines: 4,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Опубликовать в общий каталог'),
                  subtitle: const Text('Нужно фото, чтобы блюдо увидели другие'),
                  value: _publish,
                  onChanged: (value) => setState(() => _publish = value),
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.photo_camera),
                      label: Text(_imagePath == null ? 'Добавить фото' : 'Заменить фото'),
                    ),
                    const SizedBox(width: 12),
                    if (_imagePath != null)
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            File(_imagePath!),
                            height: 80,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _submit,
                    child: const Text('Сохранить блюдо'),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _validateNumber(String? value) {
    if (value == null || value.isEmpty) return 'Обязательное поле';
    return double.tryParse(value.replaceAll(',', '.')) == null
        ? 'Введите число'
        : null;
  }

  Future<void> _pickImage() async {
    final result = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1400);
    if (result != null) {
      setState(() => _imagePath = result.path);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final calories = double.parse(_caloriesCtrl.text.replaceAll(',', '.')).round();
    final proteins = double.parse(_proteinsCtrl.text.replaceAll(',', '.'));
    final fats = double.parse(_fatsCtrl.text.replaceAll(',', '.'));
    final carbs = double.parse(_carbsCtrl.text.replaceAll(',', '.'));

    if (_publish && (_imagePath == null || _imagePath!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Добавьте фото перед публикацией')),
      );
      return;
    }

    final dish = Dish(
      id: widget.state.allocateId(),
      name: _nameCtrl.text.trim(),
      calories: calories,
      proteins: proteins,
      fats: fats,
      carbs: carbs,
      description: _descriptionCtrl.text.trim().isEmpty
          ? null
          : _descriptionCtrl.text.trim(),
      isPublished: _publish,
      imagePath: _imagePath,
    );
    widget.state.addDish(dish, publish: _publish);
    Navigator.pop(context);
  }
}

class _PhotoRequestDialog extends StatefulWidget {
  const _PhotoRequestDialog({required this.dish});

  final Dish dish;

  @override
  State<_PhotoRequestDialog> createState() => _PhotoRequestDialogState();
}

class _PhotoRequestDialogState extends State<_PhotoRequestDialog> {
  final ImagePicker _picker = ImagePicker();
  String? _imagePath;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Добавьте фото для публикации'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_imagePath != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(File(_imagePath!), height: 140, fit: BoxFit.cover),
            )
          else
            const Text(
              'Чтобы блюдо появилось в каталоге, прикрепите фотографию.',
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        TextButton(
          onPressed: _pickImage,
          child: const Text('Выбрать фото'),
        ),
        FilledButton(
          onPressed: _imagePath == null
              ? null
              : () {
                  Navigator.pop(
                    context,
                    widget.dish.copyWith(
                      imagePath: _imagePath,
                      isPublished: true,
                    ),
                  );
                },
          child: const Text('Сохранить'),
        ),
      ],
    );
  }

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1400);
    if (file != null) {
      setState(() => _imagePath = file.path);
    }
  }
}
