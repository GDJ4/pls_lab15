# Счётчик калорий — отчёт по ПЗ №15 (публикация)

## Задача работы
Подготовить Flutter‑приложение к релизу: иконка, сплэш, подпись, релизные сборки (AAB/APK), документация (README/user guide/changelog/privacy policy), чек‑лист требований Play/App Store.

## Что сделано
- Добавил конфиги для иконки и сплэша в `pubspec.yaml` (flutter_launcher_icons, flutter_native_splash).
- Создан релизный ключ `android/app/release-key.jks`, шаблон `android/key.properties.sample`, `.gitignore` закрывает ключи. `android/app/build.gradle.kts` читает key.properties, включает подпись, shrinkResources/minify и proguard.
- Подготовлены документы: `user_guide.md`, `privacy_policy.txt`, `changelog.md` (v1.0.0).
- Инструкции и команды для сборок/публикации сведены ниже.

## Что осталось сделать (перед сдачей)
- Положить свои ассеты:
  - `assets/icon.png` — иконка (квадрат, без фона или с фоном).
  - `assets/splash.png` — логотип 1024×1024 с прозрачным фоном (сплэш).
- Сгенерировать иконку/сплэш:
  - `flutter pub get`
  - `flutter pub run flutter_launcher_icons`
  - `flutter pub run flutter_native_splash:create`
- Обновить версию в `pubspec.yaml` (build number +1), при необходимости поменять `applicationId` в `android/app/build.gradle.kts`.
- Прописать `supabaseUrl`/`supabaseAnonKey` (или через `--dart-define`).
- Прогнать проверки и собрать релиз:
  - `flutter analyze`
  - `flutter test --coverage`
  - `flutter run --profile` (Android/реальное устройство) + скрины DevTools
  - `flutter build appbundle --release --analyze-size --target-platform android-arm64`
  - (опц.) `flutter build apk --release --target-platform android-arm64 --analyze-size`
- Скрины для отчёта: analyze, test, DevTools profile, Analyze Size отчёт, экран приложения, настройки иконки/сплэша, консоль сборки AAB/APK.
- Политику (`privacy_policy.txt`) выложить на внешний URL и указать в магазине.

## Материалы в репо
- `user_guide.md` — краткое руководство (можно в PDF).
- `privacy_policy.txt` — политика конфиденциальности (email замените на свой).
- `changelog.md` — история версий (v1.0.0).
- `android/key.properties.sample` — заполнить своими паролями, рабочий файл `android/key.properties` не коммитим.

## Команды (релизный трек)
- Зависимости: `flutter pub get`
- Генерация ассетов:  
  `flutter pub run flutter_launcher_icons`  
  `flutter pub run flutter_native_splash:create`
- Линт/тесты:  
  `flutter analyze`  
  `flutter test --coverage`
- Профиль: `flutter run --profile` (на устройстве/эмуляторе Android)
- Релизная сборка:  
  `flutter build appbundle --release --analyze-size --target-platform android-arm64`
  (при необходимости APK: `flutter build apk --release --target-platform android-arm64 --analyze-size`)

## Чек‑лист перед публикацией
- API level: target SDK ≥ 30 (по умолчанию в текущем Flutter SDK).
- Нет лишних разрешений и debug‑логов.
- Версия/код обновлены.
- Иконка и сплэш применены.
- Подпись настроена (key.properties + release-key.jks).
- Скриншоты/описание/политика конфиденциальности готовы для консоли магазина.
