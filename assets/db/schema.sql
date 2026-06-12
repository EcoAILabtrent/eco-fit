PRAGMA foreign_keys = ON;

CREATE TABLE metadata (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE locales (
  code TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  native_name TEXT NOT NULL,
  is_default INTEGER NOT NULL DEFAULT 0 CHECK (is_default IN (0, 1)),
  sort_order INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE units (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  code TEXT NOT NULL UNIQUE,
  kind TEXT NOT NULL CHECK (kind IN ('mass', 'volume', 'count', 'portion')),
  base_code TEXT NOT NULL,
  symbol TEXT NOT NULL,
  to_grams REAL,
  to_ml REAL,
  sort_order INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE unit_translations (
  unit_id INTEGER NOT NULL REFERENCES units(id) ON DELETE CASCADE,
  locale_code TEXT NOT NULL REFERENCES locales(code) ON DELETE CASCADE,
  name TEXT NOT NULL,
  short_name TEXT NOT NULL,
  PRIMARY KEY (unit_id, locale_code)
);

CREATE TABLE food_types (
  code TEXT PRIMARY KEY,
  sort_order INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE food_type_translations (
  type_code TEXT NOT NULL REFERENCES food_types(code) ON DELETE CASCADE,
  locale_code TEXT NOT NULL REFERENCES locales(code) ON DELETE CASCADE,
  name TEXT NOT NULL,
  PRIMARY KEY (type_code, locale_code)
);

CREATE TABLE categories (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  slug TEXT NOT NULL UNIQUE,
  parent_id INTEGER REFERENCES categories(id) ON DELETE SET NULL,
  icon TEXT,
  color_hex TEXT,
  sort_order INTEGER NOT NULL DEFAULT 0,
  is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_categories_parent_id ON categories(parent_id);

CREATE TABLE category_translations (
  category_id INTEGER NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
  locale_code TEXT NOT NULL REFERENCES locales(code) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  search_text TEXT,
  translation_status TEXT NOT NULL DEFAULT 'source'
    CHECK (translation_status IN ('source', 'human', 'machine', 'missing')),
  PRIMARY KEY (category_id, locale_code)
);

CREATE INDEX idx_category_translations_locale_name
  ON category_translations(locale_code, name);

CREATE TABLE foods (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  slug TEXT NOT NULL UNIQUE,
  source_key TEXT,
  emoji TEXT,
  primary_category_id INTEGER REFERENCES categories(id) ON DELETE SET NULL,
  type_code TEXT NOT NULL DEFAULT 'food' REFERENCES food_types(code),
  default_unit_id INTEGER NOT NULL REFERENCES units(id),
  default_quantity REAL NOT NULL DEFAULT 100,
  grams_per_default_unit REAL NOT NULL DEFAULT 100,
  ml_per_default_unit REAL,
  pieces_per_default_unit REAL,
  density_g_per_ml REAL,
  edible_portion_percent REAL NOT NULL DEFAULT 100,
  is_recipe INTEGER NOT NULL DEFAULT 0 CHECK (is_recipe IN (0, 1)),
  is_drink INTEGER NOT NULL DEFAULT 0 CHECK (is_drink IN (0, 1)),
  is_verified INTEGER NOT NULL DEFAULT 0 CHECK (is_verified IN (0, 1)),
  is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_foods_category_id ON foods(primary_category_id);
CREATE INDEX idx_foods_type_code ON foods(type_code);
CREATE INDEX idx_foods_default_unit_id ON foods(default_unit_id);

CREATE TABLE food_translations (
  food_id INTEGER NOT NULL REFERENCES foods(id) ON DELETE CASCADE,
  locale_code TEXT NOT NULL REFERENCES locales(code) ON DELETE CASCADE,
  name TEXT NOT NULL,
  short_name TEXT,
  brand_name TEXT,
  description TEXT,
  search_text TEXT,
  translation_status TEXT NOT NULL DEFAULT 'source'
    CHECK (translation_status IN ('source', 'human', 'machine', 'missing')),
  PRIMARY KEY (food_id, locale_code)
);

CREATE INDEX idx_food_translations_locale_name
  ON food_translations(locale_code, name);

CREATE TABLE food_aliases (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  food_id INTEGER NOT NULL REFERENCES foods(id) ON DELETE CASCADE,
  locale_code TEXT NOT NULL REFERENCES locales(code) ON DELETE CASCADE,
  alias TEXT NOT NULL,
  normalized_alias TEXT NOT NULL,
  source TEXT NOT NULL DEFAULT 'manual',
  UNIQUE (food_id, locale_code, normalized_alias)
);

CREATE INDEX idx_food_aliases_locale_alias
  ON food_aliases(locale_code, normalized_alias);

CREATE TABLE food_category_links (
  food_id INTEGER NOT NULL REFERENCES foods(id) ON DELETE CASCADE,
  category_id INTEGER NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
  relation_type TEXT NOT NULL DEFAULT 'primary'
    CHECK (relation_type IN ('primary', 'secondary', 'tag')),
  PRIMARY KEY (food_id, category_id, relation_type)
);

CREATE TABLE food_nutrition_summary (
  food_id INTEGER PRIMARY KEY REFERENCES foods(id) ON DELETE CASCADE,
  kcal_per_100g REAL NOT NULL DEFAULT 0,
  protein_g_per_100g REAL NOT NULL DEFAULT 0,
  carbs_g_per_100g REAL NOT NULL DEFAULT 0,
  fat_g_per_100g REAL NOT NULL DEFAULT 0,
  fiber_g_per_100g REAL,
  sugar_g_per_100g REAL,
  saturated_fat_g_per_100g REAL,
  salt_g_per_100g REAL,
  sodium_mg_per_100g REAL,
  source TEXT NOT NULL DEFAULT 'foods_json',
  confidence REAL NOT NULL DEFAULT 0.7 CHECK (confidence >= 0 AND confidence <= 1)
);

CREATE TABLE nutrients (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  code TEXT NOT NULL UNIQUE,
  group_code TEXT NOT NULL,
  default_unit_code TEXT NOT NULL,
  sort_order INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE nutrient_translations (
  nutrient_id INTEGER NOT NULL REFERENCES nutrients(id) ON DELETE CASCADE,
  locale_code TEXT NOT NULL REFERENCES locales(code) ON DELETE CASCADE,
  name TEXT NOT NULL,
  short_name TEXT,
  PRIMARY KEY (nutrient_id, locale_code)
);

CREATE TABLE food_nutrients (
  food_id INTEGER NOT NULL REFERENCES foods(id) ON DELETE CASCADE,
  nutrient_id INTEGER NOT NULL REFERENCES nutrients(id) ON DELETE CASCADE,
  amount_per_100g REAL NOT NULL DEFAULT 0,
  source TEXT NOT NULL DEFAULT 'foods_json',
  confidence REAL NOT NULL DEFAULT 0.7 CHECK (confidence >= 0 AND confidence <= 1),
  PRIMARY KEY (food_id, nutrient_id)
);

CREATE INDEX idx_food_nutrients_nutrient_id ON food_nutrients(nutrient_id);

CREATE TABLE food_serving_units (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  food_id INTEGER NOT NULL REFERENCES foods(id) ON DELETE CASCADE,
  unit_id INTEGER NOT NULL REFERENCES units(id),
  grams_equivalent REAL,
  ml_equivalent REAL,
  pieces_equivalent REAL,
  default_quantity REAL NOT NULL DEFAULT 1,
  min_quantity REAL NOT NULL DEFAULT 0,
  max_quantity REAL,
  step_quantity REAL NOT NULL DEFAULT 1,
  is_default INTEGER NOT NULL DEFAULT 0 CHECK (is_default IN (0, 1)),
  sort_order INTEGER NOT NULL DEFAULT 0,
  UNIQUE (food_id, unit_id, default_quantity)
);

CREATE INDEX idx_food_serving_units_food_id ON food_serving_units(food_id);

CREATE TABLE food_serving_translations (
  serving_id INTEGER NOT NULL REFERENCES food_serving_units(id) ON DELETE CASCADE,
  locale_code TEXT NOT NULL REFERENCES locales(code) ON DELETE CASCADE,
  label TEXT NOT NULL,
  short_label TEXT NOT NULL,
  PRIMARY KEY (serving_id, locale_code)
);

CREATE TABLE food_images (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  food_id INTEGER NOT NULL REFERENCES foods(id) ON DELETE CASCADE,
  kind TEXT NOT NULL DEFAULT 'primary'
    CHECK (kind IN ('primary', 'gallery', 'thumbnail', 'barcode', 'generated')),
  asset_path TEXT,
  file_name TEXT,
  storage_path TEXT,
  remote_url TEXT,
  width INTEGER,
  height INTEGER,
  dominant_color_hex TEXT,
  blurhash TEXT,
  checksum TEXT,
  is_primary INTEGER NOT NULL DEFAULT 0 CHECK (is_primary IN (0, 1)),
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CHECK (
    asset_path IS NOT NULL
    OR storage_path IS NOT NULL
    OR remote_url IS NOT NULL
    OR file_name IS NOT NULL
  )
);

CREATE INDEX idx_food_images_food_id ON food_images(food_id);

CREATE TABLE food_barcodes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  food_id INTEGER NOT NULL REFERENCES foods(id) ON DELETE CASCADE,
  barcode TEXT NOT NULL UNIQUE,
  format TEXT,
  source TEXT NOT NULL DEFAULT 'manual'
);

CREATE TABLE recipes (
  food_id INTEGER PRIMARY KEY REFERENCES foods(id) ON DELETE CASCADE,
  servings REAL NOT NULL DEFAULT 1,
  preparation_minutes INTEGER,
  cooking_minutes INTEGER,
  instructions_json TEXT
);

CREATE TABLE recipe_ingredients (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  recipe_food_id INTEGER NOT NULL REFERENCES recipes(food_id) ON DELETE CASCADE,
  ingredient_food_id INTEGER REFERENCES foods(id) ON DELETE SET NULL,
  ingredient_name TEXT,
  quantity REAL NOT NULL DEFAULT 0,
  unit_id INTEGER REFERENCES units(id),
  grams REAL,
  sort_order INTEGER NOT NULL DEFAULT 0,
  CHECK (ingredient_food_id IS NOT NULL OR ingredient_name IS NOT NULL)
);

CREATE TABLE users (
  id TEXT PRIMARY KEY,
  display_name TEXT,
  locale_code TEXT NOT NULL DEFAULT 'ru' REFERENCES locales(code),
  gender TEXT CHECK (gender IN ('male', 'female', 'other')),
  birth_date TEXT,
  height_cm INTEGER,
  activity_level_code TEXT CHECK (activity_level_code IN ('low', 'mid', 'high')),
  goal_code TEXT CHECK (goal_code IN ('lose', 'keep', 'gain')),
  onboarded INTEGER NOT NULL DEFAULT 0 CHECK (onboarded IN (0, 1)),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE user_goal_profiles (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name TEXT NOT NULL DEFAULT 'Default',
  kcal_goal INTEGER NOT NULL,
  protein_g_goal REAL NOT NULL,
  carbs_g_goal REAL NOT NULL,
  fat_g_goal REAL NOT NULL,
  water_ml_goal INTEGER NOT NULL DEFAULT 2000,
  steps_goal INTEGER NOT NULL DEFAULT 10000,
  starts_on TEXT NOT NULL DEFAULT CURRENT_DATE,
  ends_on TEXT,
  is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_user_goal_profiles_user_active
  ON user_goal_profiles(user_id, is_active);

CREATE TABLE body_measurements (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  measured_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  weight_kg REAL,
  body_fat_percent REAL,
  skeletal_muscle_kg REAL,
  waist_cm REAL,
  hip_cm REAL,
  note TEXT
);

CREATE INDEX idx_body_measurements_user_time
  ON body_measurements(user_id, measured_at);

CREATE TABLE blood_pressure_logs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  measured_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  systolic INTEGER NOT NULL,
  diastolic INTEGER NOT NULL,
  pulse INTEGER,
  note TEXT
);

CREATE INDEX idx_blood_pressure_logs_user_time
  ON blood_pressure_logs(user_id, measured_at);

CREATE TABLE blood_sugar_logs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  measured_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  value_mg_dl REAL NOT NULL,
  context TEXT CHECK (context IN ('fasting', 'before_meal', 'after_meal', 'bedtime', 'other')),
  note TEXT
);

CREATE INDEX idx_blood_sugar_logs_user_time
  ON blood_sugar_logs(user_id, measured_at);

CREATE TABLE water_logs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  logged_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  amount_ml INTEGER NOT NULL,
  source TEXT NOT NULL DEFAULT 'manual'
);

CREATE INDEX idx_water_logs_user_time ON water_logs(user_id, logged_at);

CREATE TABLE step_daily_logs (
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  log_date TEXT NOT NULL,
  steps INTEGER NOT NULL DEFAULT 0,
  source TEXT NOT NULL DEFAULT 'sensor',
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id, log_date)
);

CREATE TABLE step_samples (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  sampled_at TEXT NOT NULL,
  raw_counter INTEGER NOT NULL
);

CREATE INDEX idx_step_samples_user_time ON step_samples(user_id, sampled_at);

CREATE TABLE meal_types (
  code TEXT PRIMARY KEY,
  default_time TEXT NOT NULL,
  sort_order INTEGER NOT NULL
);

CREATE TABLE meal_type_translations (
  meal_type_code TEXT NOT NULL REFERENCES meal_types(code) ON DELETE CASCADE,
  locale_code TEXT NOT NULL REFERENCES locales(code) ON DELETE CASCADE,
  name TEXT NOT NULL,
  PRIMARY KEY (meal_type_code, locale_code)
);

CREATE TABLE user_meal_preferences (
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  meal_type_code TEXT NOT NULL REFERENCES meal_types(code) ON DELETE CASCADE,
  preferred_time TEXT NOT NULL,
  is_enabled INTEGER NOT NULL DEFAULT 1 CHECK (is_enabled IN (0, 1)),
  PRIMARY KEY (user_id, meal_type_code)
);

CREATE TABLE meal_logs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  log_date TEXT NOT NULL,
  meal_type_code TEXT NOT NULL REFERENCES meal_types(code),
  note TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE (user_id, log_date, meal_type_code)
);

CREATE INDEX idx_meal_logs_user_date ON meal_logs(user_id, log_date);

CREATE TABLE meal_log_items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  meal_log_id INTEGER NOT NULL REFERENCES meal_logs(id) ON DELETE CASCADE,
  food_id INTEGER REFERENCES foods(id) ON DELETE SET NULL,
  custom_name TEXT,
  quantity REAL NOT NULL DEFAULT 1,
  unit_id INTEGER REFERENCES units(id),
  grams REAL,
  milliliters REAL,
  pieces REAL,
  kcal REAL NOT NULL DEFAULT 0,
  protein_g REAL NOT NULL DEFAULT 0,
  carbs_g REAL NOT NULL DEFAULT 0,
  fat_g REAL NOT NULL DEFAULT 0,
  added_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  sort_order INTEGER NOT NULL DEFAULT 0,
  CHECK (food_id IS NOT NULL OR custom_name IS NOT NULL)
);

CREATE INDEX idx_meal_log_items_meal_log_id ON meal_log_items(meal_log_id);
CREATE INDEX idx_meal_log_items_food_id ON meal_log_items(food_id);

CREATE TABLE favorite_foods (
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  food_id INTEGER NOT NULL REFERENCES foods(id) ON DELETE CASCADE,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id, food_id)
);

CREATE TABLE app_settings (
  key TEXT PRIMARY KEY,
  value_json TEXT NOT NULL,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE change_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  table_name TEXT NOT NULL,
  row_pk TEXT NOT NULL,
  operation TEXT NOT NULL CHECK (operation IN ('insert', 'update', 'delete')),
  payload_json TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  synced_at TEXT
);

CREATE VIEW v_foods_for_app AS
SELECT
  f.id,
  f.slug,
  f.emoji,
  f.type_code,
  f.is_recipe,
  f.is_drink,
  f.grams_per_default_unit,
  u.code AS default_unit_code,
  c.slug AS category_slug,
  ft.name AS name,
  ct.name AS category_name,
  n.kcal_per_100g,
  n.protein_g_per_100g,
  n.carbs_g_per_100g,
  n.fat_g_per_100g,
  img.asset_path AS primary_image_asset_path,
  img.storage_path AS primary_image_storage_path,
  img.remote_url AS primary_image_remote_url
FROM foods f
LEFT JOIN units u ON u.id = f.default_unit_id
LEFT JOIN categories c ON c.id = f.primary_category_id
LEFT JOIN food_translations ft
  ON ft.food_id = f.id AND ft.locale_code = 'uz_latn'
LEFT JOIN category_translations ct
  ON ct.category_id = c.id AND ct.locale_code = 'uz_latn'
LEFT JOIN food_nutrition_summary n ON n.food_id = f.id
LEFT JOIN food_images img
  ON img.food_id = f.id AND img.is_primary = 1;
