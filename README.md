# Счётчик калорий — отчёт по ПЗ №14

## Цели
- Реализовать дневник калорий по приёмам пищи (завтрак/обед/ужин/перекус) с БЖУ.
- База блюд с публикацией/фото: локальные и глобальные (Supabase), сортировка по популярности/адекватности.
- Авторизация/регистрация (Supabase Auth), сохранение дневников и блюд на пользователя.
- Написать unit/widget-тесты, настроить линтинг и подготовить шаги профилирования/оптимизации.

## Среда
- Flutter 3.10.3 / Dart 3.1 (sdk constraint 3.10.3).
- Пакеты: `supabase_flutter`, `shared_preferences`, `image_picker`, `flutter_localizations`.
- iOS: добавлены разрешения на камеру/галерею в `ios/Runner/Info.plist`.

## Реализация
- `lib/models.dart`: модели Dish (с описанием/фото/публикацией/usage), MealEntry, DailyLog, seed публичных блюд.
- `lib/storage.dart`: локальный стораж per-user (SharedPreferences, ключ с userId).
- `lib/supabase_service.dart`: инициализация Supabase, auth, загрузка/публикация блюд в `public_dishes`, приватные `user_dishes`, дневники `user_logs`, загрузка фото в bucket `dish_photos`.
- `lib/app_state.dart`: управление состоянием, суммаризация БЖУ, поиск/сортивка популярных, переключение пользователя по сессии Supabase.
- `lib/main.dart`: UI с двумя вкладками (День, Блюда), календарь, добавление блюд по приёмам, форма блюда (фото, описание, публикация), каталог с детальной карточкой (фото/описание/БЖУ/добавить в дневник), auth-экран с подсказкой про подтверждение email.

## Тестирование
- Unit: `test/app_state_test.dart` — расчёт БЖУ, сортировка по адекватности, переключение публикации.
- Widget: `test/dish_picker_test.dart` — популярные блюда и поиск в пикере.
- Запуск: `flutter test` (добавь `--coverage` при необходимости).  
  _Не запускалось здесь — прогоните локально и снимите цифру покрытия._

## Линтинг
- `analysis_options.yaml` включает `flutter_lints`.  
- Команда: `flutter analyze` (снимите скриншот/лог «до/после», если нужно).

## Supabase (обязательно заполнить `lib/config.dart` или dart-define)
1) Таблицы:
```sql
alter table public_dishes add column if not exists description text;
alter table user_dishes add column if not exists description text;
-- если таблиц ещё нет:
create table public_dishes (
  id text primary key,
  name text not null,
  calories int not null,
  proteins double precision not null,
  fats double precision not null,
  carbs double precision not null,
  description text,
  image_url text,
  usage_count int default 0,
  created_at timestamptz default now()
);
create table user_dishes (
  user_id uuid references auth.users(id) on delete cascade,
  id text not null,
  name text not null,
  calories int not null,
  proteins double precision not null,
  fats double precision not null,
  carbs double precision not null,
  description text,
  image_url text,
  usage_count int default 0,
  created_at timestamptz default now(),
  primary key (user_id, id)
);
create table user_logs (
  user_id uuid references auth.users(id) on delete cascade,
  date text not null,
  entries jsonb not null,
  created_at timestamptz default now(),
  primary key (user_id, date)
);
create or replace function increment_usage(dish_id text) returns void language plpgsql as $$
begin update public_dishes set usage_count = usage_count + 1 where id = dish_id; end; $$;
```
2) RLS для user_*: включить и добавить policy «own read/write/update» (auth.uid() = user_id).  
3) Storage: bucket `dish_photos` — публичное чтение, запись для authenticated.  
4) Auth: email+password, подтвердить email после регистрации (приложение покажет подсказку).

## Команды для проверки
- Получить зависимости: `flutter pub get`
- Линт: `flutter analyze`
- Тесты: `flutter test --coverage`
- (Опционально) сборка iOS/Android: `flutter build ios` / `flutter build apk`
- (По заданию) профилирование: `flutter run --profile` + DevTools Performance/Memory; анализ размера: `flutter build apk --release --analyze-size`

## Что снять/добавить в отчёт (по заданию)
- Скрины `flutter analyze` и `flutter test` (покрытие % из `coverage/lcov.info`).
- Скрины DevTools/Overlay до/после оптимизаций (скролл списка, добавление блюда).
- Табличку «Оптимизация → Зачем → Как → Эффект» (например: const/вынос поддеревьев, сортировка builder, кэш фото, разгрузка списков).
- Скрин отчёта Analyze Size и меры снижения (split-per-abi, tree-shake icons и т.п.).
- Скрин экрана ошибки (у нас есть глобальный перехват через MaterialApp — можно дополнить кастомный ErrorWidget при желании).

## Краткие инструкции по функционалу
- Вкладка «День»: выбрать дату, добавить блюдо в приём, итоги БЖУ по дню.
- Вкладка «Блюда»: мои блюда (переключатель публикации), каталог пользователей с сортировкой по популярности/адекватности, детальная карточка с описанием и кнопкой «Добавить в дневник».
- Публикация требует фото; при входе через Supabase данные дневника/блюд привязаны к аккаунту.

## Осталось сделать вручную
- Внести реальные метрики (анализ, тесты, профилирование, размер) в отчёт и приложить скриншоты.
- При необходимости добавить описание/рецепты в существующие блюда, обновить сиды.

# ПЗ №15 — подготовка к публикации

## Что настроено
- Имя приложения: `Счётчик калорий` (MaterialApp title), bundle id пока стандартный; можно сменить в `android/app/build.gradle` (`applicationId`) и `ios/Runner.xcodeproj` при необходимости.
- Разрешения: камера/фотогалерея (iOS) для загрузки фото блюд; Android оставлены базовые (проверь Manifest перед релизом).
- Документация для публикации добавлена в репо (см. ниже).

## Что нужно сделать перед релизом
- Прописать `supabaseUrl`/`supabaseAnonKey` (или dart-define).
- Подготовить иконку и сплэш:
  - Добавить ассеты `assets/icon.png`, `assets/splash.png` и секции `flutter_launcher_icons`, `flutter_native_splash` в `pubspec.yaml`.
  - Сгенерировать:  
    `flutter pub run flutter_launcher_icons`  
    `flutter pub run flutter_native_splash:create`
- Проверить зависимости: `flutter pub outdated`, удалить лишние пакеты.
- Версии: обновить `version:` в `pubspec.yaml` (build number +1 на релиз).
- Подпись Android:
  - `keytool -genkey -v -keystore android/app/release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias release`
  - Файл `android/key.properties` с паролями; подключить в `android/app/build.gradle` (`signingConfigs.release`, `buildTypes.release`).
- Сборки:
  - Android AAB с анализом размера:  
    `flutter build appbundle --release --analyze-size --target-platform android-arm64`
  - APK по ABI:  
    `flutter build apk --release --target-platform android-arm64 --analyze-size`
  - iOS релиз (на устройстве/архив): `flutter build ios --release`
- Профильная проверка (на устройстве/эмуляторе Android):  
  `flutter run --profile`
- Очистка: убрать `print/debugPrint/assert` перед релизом, убедиться в минимуме разрешений.

## Сопроводительные файлы (в репо)
- `README.md` — этот отчёт и инструкция.
- `user_guide.md` — краткое руководство пользователя (можно конвертировать в PDF).
- `privacy_policy.txt` — базовая политика конфиденциальности для приложения.
- `changelog.md` — история версий (v1.0.0 текущая).

## Подготовка пакета релиза
- Собрать `release/` папку (AAB/APK/IPA, скриншоты, иконка, splash, политика, changelog, user guide PDF).
- Сделать скрины:
  - Настроек иконки/сплэша (pubspec + ассеты).
  - Успешной сборки AAB/APK, проверку подписи (скрин консоли).
  - Скрины приложения на устройстве (дневник, каталог блюд, детальная карточка).
  - Скрин DevTools profile и Analyze Size отчёта.

## Чек-лист магазинов
- API level: Android target SDK ≥ 30 (по умолчанию в текущем Flutter SDK).
- Размер: AAB ≤ 200 МБ, иконки/splash оптимизированы.
- Политика конфиденциальности: опубликовать `privacy_policy.txt` на отдельном URL и указать в консоле.
- Метаданные: описание, категория «Здоровье/Фитнес», 2–3 скриншота, локализация RU/EN по желанию.
- Внутреннее тестирование: создать тест-трек в Play Console / TestFlight.

## Команды (напоминание)
- `flutter pub get`
- `flutter analyze`
- `flutter test --coverage`
- `flutter run --profile` (Android/реальное устройство)
- `flutter build appbundle --release --analyze-size --target-platform android-arm64`
- `flutter build ios --release` (на macOS с подключенным устройством/симулятором для отладки)

## Выводы/готовность
- Функционал и Supabase-интеграция готовы; остаётся подготовить иконки/сплэш, выполнить релизные сборки, сделать скриншоты и загрузить политику конфиденциальности на внешний ресурс для публикации в сторах.

# pls_lab14
# pls_lab15
