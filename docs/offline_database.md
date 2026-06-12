# Offline database

Eco Fit работает как offline-first приложение. Основной локальный формат базы:

- SQLite-файл: `assets/db/eco_fit.db`
- SQL-схема: `assets/db/schema.sql`
- генератор из текущего JSON: `tooling/build_offline_db.py`
- текущий источник продуктов: `assets/foods.json`

## Как пересобрать базу

```powershell
python tooling\build_offline_db.py
```

Скрипт удалит старый `assets/db/eco_fit.db` и создаст новый из `assets/foods.json`.

## Что уже хранится

- `foods` - продукты и блюда.
- `food_translations` - названия продуктов на разных языках.
- `categories` и `category_translations` - категории и их переводы.
- `units` и `unit_translations` - единицы измерения: `g`, `kg`, `ml`, `l`, `piece`, `portion`.
- `food_serving_units` - варианты измерения для продукта: граммы, миллилитры, штуки, порции.
- `food_nutrition_summary` - быстрые макро-поля на 100 г.
- `nutrients` и `food_nutrients` - нормализованные макро- и микроэлементы.
- `food_images` - будущие изображения продуктов.
- `recipes` и `recipe_ingredients` - будущие составные блюда и рецепты.
- `users`, `user_goal_profiles`, `meal_logs`, `meal_log_items`, `water_logs`, `step_daily_logs`, `body_measurements`, `blood_pressure_logs`, `blood_sugar_logs` - пользовательские offline-данные.

## Языки

База поддерживает:

- `uz_latn` - узбекский, латиница.
- `uz_cyrl` - узбекский, кириллица.
- `ru` - русский.
- `en` - английский.

В текущем `foods.json` заполнен только `name_uz`. Поэтому генератор переносит `name_uz` как `uz_latn`, а `uz_cyrl` создаёт машинной транслитерацией и помечает `translation_status = 'machine'`. Русский и английский готовы в схеме, но реальные переводы пока не заполнены.

## Изображения продуктов

Сейчас реальных картинок нет. Для будущего добавления используется таблица `food_images`.

Рекомендуемый вариант для полностью оффлайн-приложения:

1. Сложить изображения в assets, например `assets/foods/images/plov.png`.
2. Добавить путь в `food_images.asset_path`.
3. Отметить основную картинку `is_primary = 1`.

Поля `storage_path` и `remote_url` оставлены на будущее, если когда-нибудь понадобится импорт/экспорт или синхронизация, но для offline-only они не обязательны.

## Как открыть в DBeaver

1. Открой DBeaver.
2. `New Database Connection`.
3. Выбери `SQLite`.
4. В поле Database file выбери:

```text
C:\Users\User\Desktop\Projects\eco-fit\eco-fit\assets\db\eco_fit.db
```

5. Нажми `Finish`.

Полезные запросы:

```sql
select * from v_foods_for_app limit 50;
select locale_code, count(*) from food_translations group by locale_code;
select type_code, count(*) from foods group by type_code order by count(*) desc;
select * from food_images;
```
