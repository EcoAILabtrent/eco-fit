# Eco — гайд для агента (Flutter)

Оффлайн-first мобильное приложение для семейного трекинга питания, активности и
самочувствия. Портировано 1:1 с дизайна **Eco 1.1.3**.

## Главные правила (не нарушать без явной просьбы владельца)

- **Полностью оффлайн.** Никакого Supabase / сети / бэкенда. Всё хранится
  локально в **Hive**. База продуктов — вшитый ассет `assets/foods.json`.
- **Дизайн Eco** — эталон. Акцент `meadow`, поверхность `green`, скругление 20,
  шрифт **Onest** (вшит в `assets/fonts/Onest.ttf`). Палитра — `lib/theme/tokens.dart`.
- **Язык интерфейса — русский.**
- **Не добавлять Claude в соавторы коммитов.**

## Стек

Flutter (stable 3.44.1) · provider (state) · hive/hive_flutter (оффлайн-хранилище)
· google-шрифт не используется (Onest вшит).

## Структура `lib/`

- `theme/tokens.dart` — палитра `EcoColors` + тема `EcoTheme.meadow`.
- `ui/ui.dart` — UI-кит: `EcoScreen`, `EcoTopBar`, `EcoCard`, `EcoBtn`,
  `MacroRings`, `ValueBar`, `EcoBottomNav` (фигурная панель с вырезом под FAB),
  `FolderTabs`, `showEcoSheet`, `ecoIcon`.
- `state/store.dart` — `AppStore` (ChangeNotifier). **Дневник по датам:**
  `diary: ymd -> meal -> List<LogItem>`. Методы с `{String? date}` (null = сегодня):
  `addFood`, `removeFood`, `itemsFor`, `mealKcal`, `consumedOn`, `macrosOn`.
  Цели БЖУ в граммах (`carbGoal/fatGoal/protGoal`), считаются из нормы ккал 45/30/25.
- `data/products.dart` — `FoodDb` (загрузка `assets/foods.json`, 1122 продукта с
  КБЖУ + микро), поиск `FoodDb.instance.search(query, recipesOnly, limit)`.
- `screens/` — `home`, `onboarding` (8 шагов), `dayview` (дневник «Еда» с лентой
  дней), `meallog` (журнал приёма), `addfood` (поиск/добавление), `dish`
  (карточка продукта + порция), `profile`, `stats` (сон), `health` (вода/тело/
  давление/сахар).
- `steps/steps_service.dart` — мост к нативному шагомеру (MethodChannel
  `eco/steps`, EventChannel `eco/steps/live`).

## Нативный шагомер (Android)

`android/app/src/main/java/uz/ecokomitet/eco_mobile/`:
`StepSamples.java` (аппаратный TYPE_STEP_COUNTER + контрольные точки по дням, с
учётом перезагрузки и границы суток), `StepSampleWorker.java` (WorkManager,
15 мин), `BootReceiver.java`. Мост в `MainActivity.kt`. Разрешения:
`ACTIVITY_RECOGNITION`, `RECEIVE_BOOT_COMPLETED`. Зависимости: `work-runtime` +
`guava` (иначе падает на ListenableFuture).

## Сборка

```bash
flutter pub get
flutter analyze            # держать «No issues found»
flutter build apk --debug  # build/app/outputs/flutter-apk/app-debug.apk
# установка на телефон: adb install -r <apk>
```

> Сборку/установку **на физический телефон** делает только машина с подключённым
> устройством. Облачные/удалённые сессии меняют код и пушат в гит; APK для
> телефона собирается на ПК (или скачивается из GitHub Actions, см. ниже).

## Что готово

Онбординг, главный экран, дневник по датам с лентой дней, поиск/добавление еды
из оффлайн-базы (реальные КБЖУ + микро, пересчёт по порции), журнал питания,
профиль, аналитика сна, экраны здоровья, нативный шагомер. Шкалы БЖУ —
реальные граммы из дневника против целей.

## CI

`.github/workflows/build-apk.yml` — на каждый push собирает APK в облаке и кладёт
в артефакты (можно скачать с телефона из вкладки Actions).
