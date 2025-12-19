# Отчёт по практическому занятию №11

## Выполнил: Лазарев Г.С.

## Группа: ЭФБО-10-23

## Задача работы
Подготовить Flutter‑приложение к релизу: иконка, сплэш, подпись, релизные сборки (AAB/APK), документация (README/user guide/changelog/privacy policy), чек‑лист требований Play/App Store.

## Что сделано
- Добавил конфиги для иконки и сплэша в `pubspec.yaml` (flutter_launcher_icons, flutter_native_splash).
- Создан релизный ключ `android/app/release-key.jks`, шаблон `android/key.properties.sample`, `.gitignore` закрывает ключи. `android/app/build.gradle.kts` читает key.properties, включает подпись, shrinkResources/minify и proguard.
- Подготовлены документы: `user_guide.md`, `privacy_policy.txt`, `changelog.md` (v1.0.0).
- Инструкции и команды для сборок/публикации сведены ниже.


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
- Релизная сборка:  
  `flutter build appbundle --release --analyze-size --target-platform android-arm64`
  `flutter build apk --release --target-platform android-arm64 --analyze-size`

## Чек‑лист перед публикацией
- API level: target SDK ≥ 30 (по умолчанию в текущем Flutter SDK).
- Нет лишних разрешений и debug‑логов.
- Версия/код обновлены.
- Иконка и сплэш применены.
- Подпись настроена (key.properties + release-key.jks).
- Скриншоты/описание/политика конфиденциальности готовы для консоли магазина.
<img width="1087" height="146" alt="image" src="https://github.com/user-attachments/assets/1fe7cbbb-8b30-4656-bd2b-aa41f8aaff9f" />
<img width="948" height="427" alt="image" src="https://github.com/user-attachments/assets/a686f457-f27e-41d0-99f3-5fe3ff186125" />
