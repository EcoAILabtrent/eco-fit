# -*- coding: utf-8 -*-
"""Build the Eco Fit offline SQLite database from assets/foods.json."""

from __future__ import annotations

import argparse
import json
import re
import sqlite3
import unicodedata
from collections import OrderedDict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_INPUT = ROOT / "assets" / "foods.json"
DEFAULT_SCHEMA = ROOT / "assets" / "db" / "schema.sql"
DEFAULT_OUTPUT = ROOT / "assets" / "db" / "eco_fit.db"


LOCALES = [
    ("uz_latn", "Uzbek (Latin)", "O'zbekcha", 1, 10),
    ("uz_cyrl", "Uzbek (Cyrillic)", "Узбекча", 0, 20),
    ("ru", "Russian", "Русский", 0, 30),
    ("en", "English", "English", 0, 40),
]

UNITS = [
    ("g", "mass", "g", "g", 1.0, None, 10),
    ("kg", "mass", "g", "kg", 1000.0, None, 20),
    ("ml", "volume", "ml", "ml", None, 1.0, 30),
    ("l", "volume", "ml", "l", None, 1000.0, 40),
    ("piece", "count", "piece", "pcs", None, None, 50),
    ("portion", "portion", "portion", "portion", None, None, 60),
]

UNIT_TRANSLATIONS = {
    "g": {
        "uz_latn": ("gramm", "g"),
        "uz_cyrl": ("грамм", "г"),
        "ru": ("грамм", "г"),
        "en": ("gram", "g"),
    },
    "kg": {
        "uz_latn": ("kilogramm", "kg"),
        "uz_cyrl": ("килограмм", "кг"),
        "ru": ("килограмм", "кг"),
        "en": ("kilogram", "kg"),
    },
    "ml": {
        "uz_latn": ("millilitr", "ml"),
        "uz_cyrl": ("миллилитр", "мл"),
        "ru": ("миллилитр", "мл"),
        "en": ("milliliter", "ml"),
    },
    "l": {
        "uz_latn": ("litr", "l"),
        "uz_cyrl": ("литр", "л"),
        "ru": ("литр", "л"),
        "en": ("liter", "l"),
    },
    "piece": {
        "uz_latn": ("dona", "dona"),
        "uz_cyrl": ("дона", "дона"),
        "ru": ("штука", "шт"),
        "en": ("piece", "pcs"),
    },
    "portion": {
        "uz_latn": ("porsiya", "porsiya"),
        "uz_cyrl": ("порция", "порция"),
        "ru": ("порция", "порция"),
        "en": ("portion", "portion"),
    },
}

FOOD_TYPES = [
    ("food", 10),
    ("drink", 20),
    ("fruit", 30),
    ("vegetable", 40),
    ("dish", 50),
    ("national_dish", 60),
    ("recipe", 70),
    ("supplement", 80),
    ("spice", 90),
    ("other", 100),
]

FOOD_TYPE_TRANSLATIONS = {
    "food": {
        "uz_latn": "Oziq-ovqat",
        "uz_cyrl": "Озиқ-овқат",
        "ru": "Еда",
        "en": "Food",
    },
    "drink": {
        "uz_latn": "Ichimlik",
        "uz_cyrl": "Ичимлик",
        "ru": "Напиток",
        "en": "Drink",
    },
    "fruit": {
        "uz_latn": "Meva",
        "uz_cyrl": "Мева",
        "ru": "Фрукт",
        "en": "Fruit",
    },
    "vegetable": {
        "uz_latn": "Sabzavot",
        "uz_cyrl": "Сабзавот",
        "ru": "Овощ",
        "en": "Vegetable",
    },
    "dish": {
        "uz_latn": "Taom",
        "uz_cyrl": "Таом",
        "ru": "Блюдо",
        "en": "Dish",
    },
    "national_dish": {
        "uz_latn": "Milliy taom",
        "uz_cyrl": "Миллий таом",
        "ru": "Национальное блюдо",
        "en": "National dish",
    },
    "recipe": {
        "uz_latn": "Retsept",
        "uz_cyrl": "Рецепт",
        "ru": "Рецепт",
        "en": "Recipe",
    },
    "supplement": {
        "uz_latn": "Qo'shimcha",
        "uz_cyrl": "Қўшимча",
        "ru": "Добавка",
        "en": "Supplement",
    },
    "spice": {
        "uz_latn": "Ziravor",
        "uz_cyrl": "Зиравор",
        "ru": "Специя",
        "en": "Spice",
    },
    "other": {
        "uz_latn": "Boshqa",
        "uz_cyrl": "Бошқа",
        "ru": "Другое",
        "en": "Other",
    },
}

# Full nutrient dictionary. Codes, groups and default units mirror the rich
# offline DB history (commit 8f5e262) and the Dart unit map in
# lib/nutrition/micronutrients.dart. default_unit_code MUST stay in sync with
# that Dart `_microDefaultUnits` map: mcg for the trace minerals
# se/i/f/cr/mo/co and vitamins a/d/k/b9/b12/h, mg for everything else. Every
# micro code emitted by assets/foods.json must have a row here, otherwise its
# amounts are silently dropped when building food_nutrients.
NUTRIENTS = [
    ("energy_kcal", "energy", "kcal", 10, {"ru": "Калории", "en": "Calories", "uz_latn": "Kaloriya", "uz_cyrl": "Калория"}),
    ("protein", "macro", "g", 20, {"ru": "Белки", "en": "Protein", "uz_latn": "Oqsil", "uz_cyrl": "Оқсил"}),
    ("carbs", "macro", "g", 30, {"ru": "Углеводы", "en": "Carbohydrates", "uz_latn": "Uglevodlar", "uz_cyrl": "Углеводлар"}),
    ("fat", "macro", "g", 40, {"ru": "Жиры", "en": "Fat", "uz_latn": "Yog'lar", "uz_cyrl": "Ёғлар"}),
    ("fiber", "macro", "g", 50, {"ru": "Клетчатка", "en": "Fiber", "uz_latn": "Kletchatka", "uz_cyrl": "Клетчатка"}),
    ("sugar", "macro", "g", 60, {"ru": "Сахар", "en": "Sugar", "uz_latn": "Shakar", "uz_cyrl": "Шакар"}),
    # Minerals and trace elements.
    ("fe", "micro", "mg", 110, {"ru": "Железо", "en": "Iron", "uz_latn": "Temir", "uz_cyrl": "Темир"}),
    ("mg", "micro", "mg", 120, {"ru": "Магний", "en": "Magnesium", "uz_latn": "Magniy", "uz_cyrl": "Магний"}),
    ("ca", "micro", "mg", 130, {"ru": "Кальций", "en": "Calcium", "uz_latn": "Kalsiy", "uz_cyrl": "Кальций"}),
    ("p", "micro", "mg", 140, {"ru": "Фосфор", "en": "Phosphorus", "uz_latn": "Fosfor", "uz_cyrl": "Фосфор"}),
    ("k", "micro", "mg", 150, {"ru": "Калий", "en": "Potassium", "uz_latn": "Kaliy", "uz_cyrl": "Калий"}),
    ("na", "micro", "mg", 160, {"ru": "Натрий", "en": "Sodium", "uz_latn": "Natriy", "uz_cyrl": "Натрий"}),
    ("zn", "micro", "mg", 170, {"ru": "Цинк", "en": "Zinc", "uz_latn": "Rux", "uz_cyrl": "Рух"}),
    ("cu", "micro", "mg", 172, {"ru": "Медь", "en": "Copper", "uz_latn": "Mis", "uz_cyrl": "Мис"}),
    ("mn", "micro", "mg", 174, {"ru": "Марганец", "en": "Manganese", "uz_latn": "Marganets", "uz_cyrl": "Марганец"}),
    ("se", "micro", "mcg", 176, {"ru": "Селен", "en": "Selenium", "uz_latn": "Selen", "uz_cyrl": "Селен"}),
    ("i", "micro", "mcg", 178, {"ru": "Йод", "en": "Iodine", "uz_latn": "Yod", "uz_cyrl": "Йод"}),
    ("f", "micro", "mcg", 180, {"ru": "Фтор", "en": "Fluorine", "uz_latn": "Ftor", "uz_cyrl": "Фтор"}),
    ("cr", "micro", "mcg", 182, {"ru": "Хром", "en": "Chromium", "uz_latn": "Xrom", "uz_cyrl": "Хром"}),
    ("mo", "micro", "mcg", 184, {"ru": "Молибден", "en": "Molybdenum", "uz_latn": "Molibden", "uz_cyrl": "Молибден"}),
    ("co", "micro", "mcg", 186, {"ru": "Кобальт", "en": "Cobalt", "uz_latn": "Kobalt", "uz_cyrl": "Кобальт"}),
    ("cl", "micro", "mg", 188, {"ru": "Хлор", "en": "Chlorine", "uz_latn": "Xlor", "uz_cyrl": "Хлор"}),
    ("s", "micro", "mg", 190, {"ru": "Сера", "en": "Sulfur", "uz_latn": "Oltingugurt", "uz_cyrl": "Олтингугурт"}),
    # Vitamins.
    ("vit_c", "vitamin", "mg", 210, {"ru": "Витамин C", "en": "Vitamin C", "uz_latn": "C vitamini", "uz_cyrl": "C витамини"}),
    ("vit_a", "vitamin", "mcg", 220, {"ru": "Витамин A", "en": "Vitamin A", "uz_latn": "A vitamini", "uz_cyrl": "A витамини"}),
    ("vit_d", "vitamin", "mcg", 230, {"ru": "Витамин D", "en": "Vitamin D", "uz_latn": "D vitamini", "uz_cyrl": "D витамини"}),
    ("vit_e", "vitamin", "mg", 240, {"ru": "Витамин E", "en": "Vitamin E", "uz_latn": "E vitamini", "uz_cyrl": "E витамини"}),
    ("vit_k", "vitamin", "mcg", 250, {"ru": "Витамин K", "en": "Vitamin K", "uz_latn": "K vitamini", "uz_cyrl": "K витамини"}),
    ("vit_b1", "vitamin", "mg", 260, {"ru": "Витамин B1 (тиамин)", "en": "Vitamin B1 (Thiamine)", "uz_latn": "B1 vitamini (tiamin)", "uz_cyrl": "B1 витамини (тиамин)"}),
    ("vit_b2", "vitamin", "mg", 270, {"ru": "Витамин B2 (рибофлавин)", "en": "Vitamin B2 (Riboflavin)", "uz_latn": "B2 vitamini (riboflavin)", "uz_cyrl": "B2 витамини (рибофлавин)"}),
    ("vit_b3", "vitamin", "mg", 280, {"ru": "Витамин B3 (ниацин, PP)", "en": "Vitamin B3 (Niacin)", "uz_latn": "B3 vitamini (niatsin, PP)", "uz_cyrl": "B3 витамини (ниацин, PP)"}),
    ("vit_b4", "vitamin", "mg", 290, {"ru": "Витамин B4 (холин)", "en": "Vitamin B4 (Choline)", "uz_latn": "B4 vitamini (xolin)", "uz_cyrl": "B4 витамини (холин)"}),
    ("vit_b5", "vitamin", "mg", 300, {"ru": "Витамин B5 (пантотеновая кислота)", "en": "Vitamin B5 (Pantothenic acid)", "uz_latn": "B5 vitamini (pantoten kislotasi)", "uz_cyrl": "B5 витамини (пантотен кислотаси)"}),
    ("vit_b6", "vitamin", "mg", 310, {"ru": "Витамин B6 (пиридоксин)", "en": "Vitamin B6 (Pyridoxine)", "uz_latn": "B6 vitamini (piridoksin)", "uz_cyrl": "B6 витамини (пиридоксин)"}),
    ("vit_b9", "vitamin", "mcg", 320, {"ru": "Витамин B9 (фолат)", "en": "Vitamin B9 (Folate)", "uz_latn": "B9 vitamini (folat)", "uz_cyrl": "B9 витамини (фолат)"}),
    ("vit_b12", "vitamin", "mcg", 330, {"ru": "Витамин B12 (кобаламин)", "en": "Vitamin B12 (Cobalamin)", "uz_latn": "B12 vitamini (kobalamin)", "uz_cyrl": "B12 витамини (кобаламин)"}),
    ("vit_h", "vitamin", "mcg", 340, {"ru": "Витамин H (биотин)", "en": "Vitamin H (Biotin)", "uz_latn": "H vitamini (biotin)", "uz_cyrl": "H витамини (биотин)"}),
]

MEAL_TYPES = [
    ("breakfast", "08:30", 10, {"ru": "Завтрак", "en": "Breakfast", "uz_latn": "Nonushta", "uz_cyrl": "Нонушта"}),
    ("snack_morning", "11:00", 20, {"ru": "Утренний перекус", "en": "Morning snack", "uz_latn": "Ertalabki tamaddi", "uz_cyrl": "Эрталабки тамадди"}),
    ("lunch", "14:30", 30, {"ru": "Обед", "en": "Lunch", "uz_latn": "Tushlik", "uz_cyrl": "Тушлик"}),
    ("snack_day", "16:30", 40, {"ru": "Дневной перекус", "en": "Afternoon snack", "uz_latn": "Kunduzgi tamaddi", "uz_cyrl": "Кундузги тамадди"}),
    ("dinner", "19:00", 50, {"ru": "Ужин", "en": "Dinner", "uz_latn": "Kechki ovqat", "uz_cyrl": "Кечки овқат"}),
    ("snack_evening", "21:30", 60, {"ru": "Вечерний перекус", "en": "Evening snack", "uz_latn": "Kechki tamaddi", "uz_cyrl": "Кечки тамадди"}),
]

CATEGORY_TRANSLATIONS = {
    "asosiy_taomlar": {"en": "Main dishes", "ru": "Основные блюда", "uz_latn": "Asosiy taomlar", "uz_cyrl": "Асосий таомлар"},
    "bakery": {"en": "Bakery", "ru": "Выпечка", "uz_latn": "Non va pishiriqlar", "uz_cyrl": "Нон ва пишириқлар"},
    "baliq_va_dengiz_mahsulotlari": {"en": "Fish and seafood", "ru": "Рыба и морепродукты", "uz_latn": "Baliq va dengiz mahsulotlari", "uz_cyrl": "Балиқ ва денгиз маҳсулотлари"},
    "bolalar_ozuqalari": {"en": "Baby food", "ru": "Детское питание", "uz_latn": "Bolalar ozuqalari", "uz_cyrl": "Болалар озуқалари"},
    "boshqalar": {"en": "Other", "ru": "Другое", "uz_latn": "Boshqalar", "uz_cyrl": "Бошқалар"},
    "breakfast": {"en": "Breakfast", "ru": "Завтраки", "uz_latn": "Nonushta", "uz_cyrl": "Нонушта"},
    "dairy": {"en": "Dairy", "ru": "Молочные продукты", "uz_latn": "Sut mahsulotlari", "uz_cyrl": "Сут маҳсулотлари"},
    "don_va_dukkakli_mahsulotlar": {"en": "Grains and legumes", "ru": "Крупы и бобовые", "uz_latn": "Don va dukkakli mahsulotlar", "uz_cyrl": "Дон ва дуккакли маҳсулотлар"},
    "drinks": {"en": "Drinks", "ru": "Напитки", "uz_latn": "Ichimliklar", "uz_cyrl": "Ичимликлар"},
    "dukkaklilar": {"en": "Legumes", "ru": "Бобовые", "uz_latn": "Dukkaklilar", "uz_cyrl": "Дуккаклилар"},
    "fastfood": {"en": "Fast food", "ru": "Фастфуд", "uz_latn": "Fastfud", "uz_cyrl": "Фастфуд"},
    "fats": {"en": "Fats", "ru": "Жиры", "uz_latn": "Yog'lar", "uz_cyrl": "Ёғлар"},
    "fish": {"en": "Fish", "ru": "Рыба", "uz_latn": "Baliq", "uz_cyrl": "Балиқ"},
    "fruits": {"en": "Fruits", "ru": "Фрукты", "uz_latn": "Mevalar", "uz_cyrl": "Мевалар"},
    "gosht_mahsulotlari": {"en": "Meat products", "ru": "Мясные продукты", "uz_latn": "Go'sht mahsulotlari", "uz_cyrl": "Гўшт маҳсулотлари"},
    "grains": {"en": "Grains", "ru": "Крупы", "uz_latn": "Don mahsulotlari", "uz_cyrl": "Дон маҳсулотлари"},
    "ichimliklar": {"en": "Drinks", "ru": "Напитки", "uz_latn": "Ichimliklar", "uz_cyrl": "Ичимликлар"},
    "kaboblar_va_shashliklar": {"en": "Kebabs and shashlik", "ru": "Кебабы и шашлыки", "uz_latn": "Kaboblar va shashliklar", "uz_cyrl": "Кабоблар ва шашликлар"},
    "kokatlar": {"en": "Greens", "ru": "Зелень", "uz_latn": "Ko'katlar", "uz_cyrl": "Кўкатлар"},
    "kokatlar_va_sabzavotlar": {"en": "Greens and vegetables", "ru": "Зелень и овощи", "uz_latn": "Ko'katlar va sabzavotlar", "uz_cyrl": "Кўкатлар ва сабзавотлар"},
    "konservalar": {"en": "Canned foods", "ru": "Консервы", "uz_latn": "Konservalar", "uz_cyrl": "Консервалар"},
    "legumes": {"en": "Legumes", "ru": "Бобовые", "uz_latn": "Dukkaklilar", "uz_cyrl": "Дуккаклилар"},
    "main": {"en": "Main dishes", "ru": "Основные блюда", "uz_latn": "Asosiy taomlar", "uz_cyrl": "Асосий таомлар"},
    "manti_va_barak": {"en": "Manti and barak", "ru": "Манты и барак", "uz_latn": "Manti va barak", "uz_cyrl": "Манти ва барак"},
    "meat": {"en": "Meat", "ru": "Мясо", "uz_latn": "Go'sht", "uz_cyrl": "Гўшт"},
    "mevalar": {"en": "Fruits", "ru": "Фрукты", "uz_latn": "Mevalar", "uz_cyrl": "Мевалар"},
    "mevalar_va_rezavorlar": {"en": "Fruits and berries", "ru": "Фрукты и ягоды", "uz_latn": "Mevalar va rezavorlar", "uz_cyrl": "Мевалар ва резаворлар"},
    "milliy_taomlar": {"en": "National dishes", "ru": "Национальные блюда", "uz_latn": "Milliy taomlar", "uz_cyrl": "Миллий таомлар"},
    "non_mahsulotlari": {"en": "Bread products", "ru": "Хлебные изделия", "uz_latn": "Non mahsulotlari", "uz_cyrl": "Нон маҳсулотлари"},
    "non_va_pishiriqlar": {"en": "Bread and pastries", "ru": "Хлеб и выпечка", "uz_latn": "Non va pishiriqlar", "uz_cyrl": "Нон ва пишириқлар"},
    "nuts": {"en": "Nuts", "ru": "Орехи", "uz_latn": "Yong'oqlar", "uz_cyrl": "Ёнғоқлар"},
    "palov_va_uning_turlari": {"en": "Pilaf and varieties", "ru": "Плов и его виды", "uz_latn": "Palov va uning turlari", "uz_cyrl": "Палов ва унинг турлари"},
    "parranda_goshti": {"en": "Poultry", "ru": "Мясо птицы", "uz_latn": "Parranda go'shti", "uz_cyrl": "Парранда гўшти"},
    "quruq_mevalar": {"en": "Dried fruits", "ru": "Сухофрукты", "uz_latn": "Quruq mevalar", "uz_cyrl": "Қуруқ мевалар"},
    "sabzavotlar": {"en": "Vegetables", "ru": "Овощи", "uz_latn": "Sabzavotlar", "uz_cyrl": "Сабзавотлар"},
    "salatlar": {"en": "Salads", "ru": "Салаты", "uz_latn": "Salatlar", "uz_cyrl": "Салатлар"},
    "salatlar_va_gazaklar": {"en": "Salads and appetizers", "ru": "Салаты и закуски", "uz_latn": "Salatlar va gazaklar", "uz_cyrl": "Салатлар ва газаклар"},
    "shirinliklar": {"en": "Sweets", "ru": "Сладости", "uz_latn": "Shirinliklar", "uz_cyrl": "Ширинликлар"},
    "shirinliklar_va_desertlar": {"en": "Sweets and desserts", "ru": "Сладости и десерты", "uz_latn": "Shirinliklar va desertlar", "uz_cyrl": "Ширинликлар ва десертлар"},
    "snack": {"en": "Snacks", "ru": "Перекусы", "uz_latn": "Tamaddilar", "uz_cyrl": "Тамаддилар"},
    "somsa": {"en": "Somsa", "ru": "Самса", "uz_latn": "Somsa", "uz_cyrl": "Сомса"},
    "soup": {"en": "Soups", "ru": "Супы", "uz_latn": "Suyuq taomlar", "uz_cyrl": "Суюқ таомлар"},
    "spices": {"en": "Spices", "ru": "Специи", "uz_latn": "Ziravorlar", "uz_cyrl": "Зираворлар"},
    "sport_ozuqalari": {"en": "Sports nutrition", "ru": "Спортивное питание", "uz_latn": "Sport ozuqalari", "uz_cyrl": "Спорт озуқалари"},
    "subproduktlar": {"en": "Offal", "ru": "Субпродукты", "uz_latn": "Subproduktlar", "uz_cyrl": "Субпродуктлар"},
    "supplements": {"en": "Supplements", "ru": "Добавки", "uz_latn": "Qo'shimchalar", "uz_cyrl": "Қўшимчалар"},
    "sut_mahsulotlari": {"en": "Dairy products", "ru": "Молочные продукты", "uz_latn": "Sut mahsulotlari", "uz_cyrl": "Сут маҳсулотлари"},
    "suyuq_taomlar": {"en": "Soups", "ru": "Супы", "uz_latn": "Suyuq taomlar", "uz_cyrl": "Суюқ таомлар"},
    "sweets": {"en": "Sweets", "ru": "Сладости", "uz_latn": "Shirinliklar", "uz_cyrl": "Ширинликлар"},
    "taomlar": {"en": "Dishes", "ru": "Блюда", "uz_latn": "Taomlar", "uz_cyrl": "Таомлар"},
    "tuxum": {"en": "Eggs", "ru": "Яйца", "uz_latn": "Tuxum", "uz_cyrl": "Тухум"},
    "un_va_non_mahsulotlari": {"en": "Flour and bread products", "ru": "Мука и хлебные изделия", "uz_latn": "Un va non mahsulotlari", "uz_cyrl": "Ун ва нон маҳсулотлари"},
    "uruglar": {"en": "Seeds", "ru": "Семена", "uz_latn": "Urug'lar", "uz_cyrl": "Уруғлар"},
    "vegetables": {"en": "Vegetables", "ru": "Овощи", "uz_latn": "Sabzavotlar", "uz_cyrl": "Сабзавотлар"},
    "xamirli_taomlar": {"en": "Dough dishes", "ru": "Блюда из теста", "uz_latn": "Xamirli taomlar", "uz_cyrl": "Хамирли таомлар"},
    "yoglar": {"en": "Oils and fats", "ru": "Масла и жиры", "uz_latn": "Yog'lar", "uz_cyrl": "Ёғлар"},
    "yongoqlar": {"en": "Nuts", "ru": "Орехи", "uz_latn": "Yong'oqlar", "uz_cyrl": "Ёнғоқлар"},
    "yongoqlar_va_quruq_mevalar": {"en": "Nuts and dried fruits", "ru": "Орехи и сухофрукты", "uz_latn": "Yong'oqlar va quruq mevalar", "uz_cyrl": "Ёнғоқлар ва қуруқ мевалар"},
    "ziravor_va_qoshimchalar": {"en": "Spices and additives", "ru": "Специи и добавки", "uz_latn": "Ziravor va qo'shimchalar", "uz_cyrl": "Зиравор ва қўшимчалар"},
    "ziravorlar": {"en": "Spices", "ru": "Специи", "uz_latn": "Ziravorlar", "uz_cyrl": "Зираворлар"},
}


def slugify(value: str) -> str:
    value = value.strip().lower()
    value = value.replace("o'", "o").replace("g'", "g").replace("'", "")
    value = unicodedata.normalize("NFKD", value)
    value = value.encode("ascii", "ignore").decode("ascii")
    value = re.sub(r"[^a-z0-9]+", "_", value).strip("_")
    return value or "item"


def normalized(value: str) -> str:
    return re.sub(r"\s+", " ", value.strip().lower())


def uz_latn_to_cyrl(text: str) -> str:
    replacements = [
        ("Oʻ", "Ў"), ("O'", "Ў"), ("O`", "Ў"), ("oʻ", "ў"), ("o'", "ў"), ("o`", "ў"),
        ("Gʻ", "Ғ"), ("G'", "Ғ"), ("G`", "Ғ"), ("gʻ", "ғ"), ("g'", "ғ"), ("g`", "ғ"),
        ("Sh", "Ш"), ("SH", "Ш"), ("sh", "ш"),
        ("Ch", "Ч"), ("CH", "Ч"), ("ch", "ч"),
        ("Yo", "Ё"), ("YO", "Ё"), ("yo", "ё"),
        ("Yu", "Ю"), ("YU", "Ю"), ("yu", "ю"),
        ("Ya", "Я"), ("YA", "Я"), ("ya", "я"),
        ("Ye", "Е"), ("YE", "Е"), ("ye", "е"),
    ]
    out = text
    for src, dst in replacements:
        out = out.replace(src, dst)

    table = str.maketrans(
        {
            "A": "А", "a": "а",
            "B": "Б", "b": "б",
            "D": "Д", "d": "д",
            "E": "Е", "e": "е",
            "F": "Ф", "f": "ф",
            "G": "Г", "g": "г",
            "H": "Ҳ", "h": "ҳ",
            "I": "И", "i": "и",
            "J": "Ж", "j": "ж",
            "K": "К", "k": "к",
            "L": "Л", "l": "л",
            "M": "М", "m": "м",
            "N": "Н", "n": "н",
            "O": "О", "o": "о",
            "P": "П", "p": "п",
            "Q": "Қ", "q": "қ",
            "R": "Р", "r": "р",
            "S": "С", "s": "с",
            "T": "Т", "t": "т",
            "U": "У", "u": "у",
            "V": "В", "v": "в",
            "X": "Х", "x": "х",
            "Y": "Й", "y": "й",
            "Z": "З", "z": "з",
        }
    )
    return out.translate(table)


def infer_food_type(category: str, per_type: str | None) -> str:
    c = category.lower()
    if per_type == "recipe":
        return "recipe"
    if any(token in c for token in ("ichimlik", "drink", "suv", "sharbat")):
        return "drink"
    if any(token in c for token in ("meva", "fruit", "rezavor")):
        return "fruit"
    if any(token in c for token in ("sabzavot", "vegetable", "ko'kat")):
        return "vegetable"
    if any(token in c for token in ("milliy", "palov", "kabob", "somsa", "manti", "barak")):
        return "national_dish"
    if any(token in c for token in ("taom", "soup", "salat", "main", "breakfast", "fastfood")):
        return "dish"
    if any(token in c for token in ("supplement", "sport")):
        return "supplement"
    if any(token in c for token in ("ziravor", "spice")):
        return "spice"
    return "food"


def get_num(value: Any, default: float = 0.0) -> float:
    if isinstance(value, (int, float)):
        return float(value)
    return default


def insert_reference_data(conn: sqlite3.Connection) -> dict[str, dict[str, int]]:
    cur = conn.cursor()
    cur.executemany(
        "INSERT INTO locales(code, name, native_name, is_default, sort_order) VALUES (?, ?, ?, ?, ?)",
        LOCALES,
    )

    for code, kind, base_code, symbol, to_grams, to_ml, sort_order in UNITS:
        cur.execute(
            """
            INSERT INTO units(code, kind, base_code, symbol, to_grams, to_ml, sort_order)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            (code, kind, base_code, symbol, to_grams, to_ml, sort_order),
        )
        unit_id = cur.lastrowid
        for locale, (name, short_name) in UNIT_TRANSLATIONS[code].items():
            cur.execute(
                """
                INSERT INTO unit_translations(unit_id, locale_code, name, short_name)
                VALUES (?, ?, ?, ?)
                """,
                (unit_id, locale, name, short_name),
            )

    cur.executemany("INSERT INTO food_types(code, sort_order) VALUES (?, ?)", FOOD_TYPES)
    for type_code, translations in FOOD_TYPE_TRANSLATIONS.items():
        for locale, name in translations.items():
            cur.execute(
                "INSERT INTO food_type_translations(type_code, locale_code, name) VALUES (?, ?, ?)",
                (type_code, locale, name),
            )

    nutrient_ids: dict[str, int] = {}
    for code, group_code, unit_code, sort_order, translations in NUTRIENTS:
        cur.execute(
            """
            INSERT INTO nutrients(code, group_code, default_unit_code, sort_order)
            VALUES (?, ?, ?, ?)
            """,
            (code, group_code, unit_code, sort_order),
        )
        nutrient_id = cur.lastrowid
        nutrient_ids[code] = nutrient_id
        for locale, name in translations.items():
            cur.execute(
                """
                INSERT INTO nutrient_translations(nutrient_id, locale_code, name, short_name)
                VALUES (?, ?, ?, ?)
                """,
                (nutrient_id, locale, name, name),
            )

    for code, default_time, sort_order, translations in MEAL_TYPES:
        cur.execute(
            "INSERT INTO meal_types(code, default_time, sort_order) VALUES (?, ?, ?)",
            (code, default_time, sort_order),
        )
        for locale, name in translations.items():
            cur.execute(
                """
                INSERT INTO meal_type_translations(meal_type_code, locale_code, name)
                VALUES (?, ?, ?)
                """,
                (code, locale, name),
            )

    unit_ids = {
        row["code"]: row["id"]
        for row in cur.execute("SELECT id, code FROM units").fetchall()
    }

    return {"units": unit_ids, "nutrients": nutrient_ids}


def insert_category(
    conn: sqlite3.Connection,
    category_ids: dict[str, int],
    source_name: str,
    sort_order: int,
) -> int:
    slug_base = slugify(source_name)
    slug = slug_base
    suffix = 2
    while slug in category_ids:
        if category_ids[slug] == -1:
            slug = f"{slug_base}_{suffix}"
            suffix += 1
        else:
            return category_ids[slug]

    category_ids[slug] = -1
    cur = conn.cursor()
    cur.execute(
        """
        INSERT INTO categories(slug, icon, color_hex, sort_order)
        VALUES (?, ?, ?, ?)
        """,
        (slug, None, None, sort_order),
    )
    category_id = cur.lastrowid
    category_ids[slug] = category_id

    translations = CATEGORY_TRANSLATIONS.get(slug)
    if translations is None:
        translations = {
            "uz_latn": source_name,
            "uz_cyrl": uz_latn_to_cyrl(source_name),
        }
        statuses = {"uz_latn": "source", "uz_cyrl": "machine"}
    else:
        statuses = {locale: "human" for locale in translations}

    for locale, name in translations.items():
        cur.execute(
            """
            INSERT INTO category_translations(
              category_id, locale_code, name, search_text, translation_status
            )
            VALUES (?, ?, ?, ?, ?)
            """,
            (category_id, locale, name, normalized(name), statuses[locale]),
        )
    return category_id


def add_serving(
    conn: sqlite3.Connection,
    food_id: int,
    unit_id: int,
    grams: float | None,
    milliliters: float | None,
    pieces: float | None,
    quantity: float,
    is_default: bool,
    sort_order: int,
    labels: dict[str, tuple[str, str]],
) -> None:
    cur = conn.cursor()
    cur.execute(
        """
        INSERT OR IGNORE INTO food_serving_units(
          food_id, unit_id, grams_equivalent, ml_equivalent, pieces_equivalent,
          default_quantity, min_quantity, step_quantity, is_default, sort_order
        )
        VALUES (?, ?, ?, ?, ?, ?, 0, 1, ?, ?)
        """,
        (
            food_id,
            unit_id,
            grams,
            milliliters,
            pieces,
            quantity,
            1 if is_default else 0,
            sort_order,
        ),
    )
    serving_id = cur.lastrowid
    if serving_id == 0:
        return
    for locale, (label, short_label) in labels.items():
        cur.execute(
            """
            INSERT INTO food_serving_translations(serving_id, locale_code, label, short_label)
            VALUES (?, ?, ?, ?)
            """,
            (serving_id, locale, label, short_label),
        )


def image_fields(item: dict[str, Any]) -> tuple[str | None, str | None, str | None, str | None]:
    slug = str(item.get("slug") or "").strip()
    slug_asset_path = f"assets/foods/images/{slug}.webp" if slug else None
    slug_asset_exists = bool(slug_asset_path and (ROOT / slug_asset_path).exists())

    photo_url = item.get("photo_url")
    photo_file_name = Path(str(photo_url)).name if photo_url else None
    photo_asset_path = f"assets/foods/images/{photo_file_name}" if photo_file_name else None
    photo_asset_exists = bool(photo_asset_path and (ROOT / photo_asset_path).exists())

    asset_path = (
        item.get("image_asset_path")
        or item.get("image_asset")
        or item.get("asset_path")
        or item.get("image_path")
        or (slug_asset_path if slug_asset_exists else None)
        or (photo_asset_path if photo_asset_exists else None)
    )
    storage_path = item.get("image_storage_path") or item.get("storage_path") or photo_url
    remote_url = item.get("image_url") or item.get("remote_url")
    file_name = item.get("image_file_name") or item.get("file_name")
    if not file_name:
        source = asset_path or storage_path or remote_url
        if source:
            file_name = Path(str(source)).name
    return (
        str(asset_path).strip() if asset_path else None,
        str(storage_path).strip() if storage_path else None,
        str(remote_url).strip() if remote_url else None,
        str(file_name).strip() if file_name else None,
    )


def insert_foods(
    conn: sqlite3.Connection,
    foods: list[dict[str, Any]],
    ids: dict[str, dict[str, int]],
) -> None:
    cur = conn.cursor()
    unit_ids = ids["units"]
    nutrient_ids = ids["nutrients"]
    category_ids: dict[str, int] = {}
    category_order = OrderedDict((item.get("category") or "Boshqalar", None) for item in foods)

    for sort_order, category in enumerate(category_order.keys(), start=10):
        insert_category(conn, category_ids, category, sort_order)

    for item in foods:
        slug = item["slug"]
        name_uz = (item.get("name_uz") or item.get("name_uz_lat") or slug).strip()
        name_uz_cyrl = (
            item.get("name_uz_cyrl")
            or item.get("name_uz_kril")
            or item.get("name_uz_kiril")
            or ""
        ).strip()
        name_ru = (item.get("name_ru") or "").strip()
        name_en = (item.get("name_en") or "").strip()
        emoji = (item.get("emoji") or "").strip()
        if emoji == "??":
            emoji = None

        category_name = item.get("category") or "Boshqalar"
        category_id = insert_category(conn, category_ids, category_name, 9999)
        per = item.get("per_100g") or {}
        source_type = per.get("type")
        type_code = infer_food_type(category_name, source_type)
        is_recipe = 1 if type_code == "recipe" or source_type == "recipe" else 0
        is_drink = 1 if type_code == "drink" else 0

        grams_per_unit = get_num(item.get("grams_per_unit"), 100.0) or 100.0
        default_unit_code = "ml" if is_drink else (item.get("default_unit") or "g")
        if default_unit_code not in unit_ids:
            default_unit_code = "g"
        # Штучные продукты (яйца, целые фрукты/овощи, штучная выпечка) помечены
        # в foods.json как default_unit == "piece"; напитки всегда в ml.
        is_piece = default_unit_code == "piece"

        ml_per_default_unit = 100.0 if default_unit_code == "ml" else None
        density_g_per_ml = grams_per_unit / ml_per_default_unit if ml_per_default_unit else None

        cur.execute(
            """
            INSERT INTO foods(
              slug, source_key, emoji, primary_category_id, type_code,
              default_unit_id, default_quantity, grams_per_default_unit,
              ml_per_default_unit, density_g_per_ml, is_recipe, is_drink,
              is_verified
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                slug,
                "assets/foods.json",
                emoji,
                category_id,
                type_code,
                unit_ids[default_unit_code],
                100.0,
                grams_per_unit,
                ml_per_default_unit,
                density_g_per_ml,
                is_recipe,
                is_drink,
                0,
            ),
        )
        food_id = cur.lastrowid

        cur.execute(
            """
            INSERT INTO food_category_links(food_id, category_id, relation_type)
            VALUES (?, ?, 'primary')
            """,
            (food_id, category_id),
        )

        translations = [("uz_latn", name_uz, "source")]
        if name_uz_cyrl:
            translations.append(("uz_cyrl", name_uz_cyrl, "source"))
        else:
            translations.append(("uz_cyrl", uz_latn_to_cyrl(name_uz), "machine"))
        if name_ru:
            translations.append(("ru", name_ru, "source"))
        if name_en:
            translations.append(("en", name_en, "source"))
        for locale, name, status in translations:
            cur.execute(
                """
                INSERT INTO food_translations(
                  food_id, locale_code, name, search_text, translation_status
                )
                VALUES (?, ?, ?, ?, ?)
                """,
                (food_id, locale, name, normalized(name), status),
            )

        kcal = get_num(per.get("kcal"))
        protein = get_num(per.get("protein"))
        carbs = get_num(per.get("carbs"))
        fat = get_num(per.get("fat"))
        cur.execute(
            """
            INSERT INTO food_nutrition_summary(
              food_id, kcal_per_100g, protein_g_per_100g,
              carbs_g_per_100g, fat_g_per_100g
            )
            VALUES (?, ?, ?, ?, ?)
            """,
            (food_id, kcal, protein, carbs, fat),
        )

        nutrient_values = {
            "energy_kcal": kcal,
            "protein": protein,
            "carbs": carbs,
            "fat": fat,
        }
        nutrient_values.update(per.get("micros") or {})
        for nutrient_code, amount in nutrient_values.items():
            nutrient_id = nutrient_ids.get(nutrient_code)
            if nutrient_id is None:
                continue
            cur.execute(
                """
                INSERT INTO food_nutrients(food_id, nutrient_id, amount_per_100g)
                VALUES (?, ?, ?)
                """,
                (food_id, nutrient_id, get_num(amount)),
            )

        if is_drink:
            add_serving(
                conn,
                food_id,
                unit_ids["ml"],
                grams_per_unit,
                100.0,
                None,
                100.0,
                True,
                10,
                {
                    "uz_latn": ("100 ml", "100 ml"),
                    "uz_cyrl": ("100 мл", "100 мл"),
                    "ru": ("100 мл", "100 мл"),
                    "en": ("100 ml", "100 ml"),
                },
            )
            add_serving(
                conn,
                food_id,
                unit_ids["g"],
                100.0,
                None,
                None,
                100.0,
                False,
                20,
                {
                    "uz_latn": ("100 g", "100 g"),
                    "uz_cyrl": ("100 г", "100 г"),
                    "ru": ("100 г", "100 г"),
                    "en": ("100 g", "100 g"),
                },
            )
        else:
            add_serving(
                conn,
                food_id,
                unit_ids["g"],
                100.0,
                None,
                None,
                100.0,
                not is_piece,
                10,
                {
                    "uz_latn": ("100 g", "100 g"),
                    "uz_cyrl": ("100 г", "100 г"),
                    "ru": ("100 г", "100 г"),
                    "en": ("100 g", "100 g"),
                },
            )

        # Штучная порция — только для курируемых piece-продуктов, с реальным
        # весом одной штуки (grams_per_unit из foods.json) и как единица по
        # умолчанию. Раньше piece-порция вешалась на ВСЕ фрукты/овощи с весом-
        # заглушкой 100 г, что давало мусор (1 малина = 100 г и т.п.).
        if is_piece:
            add_serving(
                conn,
                food_id,
                unit_ids["piece"],
                grams_per_unit,
                None,
                1.0,
                1.0,
                True,
                5,
                {
                    "uz_latn": ("1 dona", "1 dona"),
                    "uz_cyrl": ("1 дона", "1 дона"),
                    "ru": ("1 шт", "1 шт"),
                    "en": ("1 piece", "1 pc"),
                },
            )
        if type_code in {"dish", "national_dish", "recipe"}:
            add_serving(
                conn,
                food_id,
                unit_ids["portion"],
                grams_per_unit,
                None,
                None,
                1.0,
                False,
                40,
                {
                    "uz_latn": ("1 porsiya", "1 porsiya"),
                    "uz_cyrl": ("1 порция", "1 порция"),
                    "ru": ("1 порция", "1 порция"),
                    "en": ("1 portion", "1 portion"),
                },
            )
        if is_recipe:
            cur.execute("INSERT INTO recipes(food_id, servings) VALUES (?, 1)", (food_id,))

        asset_path, storage_path, remote_url, file_name = image_fields(item)
        if asset_path or storage_path or remote_url or file_name:
            cur.execute(
                """
                INSERT INTO food_images(
                  food_id, kind, asset_path, storage_path, remote_url,
                  file_name, is_primary, sort_order
                )
                VALUES (?, 'primary', ?, ?, ?, ?, 1, 10)
                """,
                (food_id, asset_path, storage_path, remote_url, file_name),
            )


def build_database(input_path: Path, schema_path: Path, output_path: Path) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    if output_path.exists():
        output_path.unlink()

    foods = json.loads(input_path.read_text(encoding="utf-8"))
    schema = schema_path.read_text(encoding="utf-8")

    conn = sqlite3.connect(output_path)
    conn.row_factory = sqlite3.Row
    try:
        conn.execute("PRAGMA foreign_keys = ON")
        conn.executescript(schema)
        ids = insert_reference_data(conn)
        insert_foods(conn, foods, ids)
        conn.executemany(
            """
            INSERT INTO metadata(key, value)
            VALUES (?, ?)
            """,
            [
                ("schema_version", "1"),
                ("source_file", str(input_path.relative_to(ROOT)).replace("\\", "/")),
                ("generated_at", datetime.now(timezone.utc).isoformat()),
                ("food_count", str(len(foods))),
            ],
        )
        try:
            conn.execute(
                """
                CREATE VIRTUAL TABLE food_search_fts
                USING fts5(food_id UNINDEXED, locale_code UNINDEXED, name, category_name)
                """
            )
            conn.execute(
                """
                INSERT INTO food_search_fts(food_id, locale_code, name, category_name)
                SELECT ft.food_id, ft.locale_code, ft.name, COALESCE(ct.name, '')
                FROM food_translations ft
                JOIN foods f ON f.id = ft.food_id
                LEFT JOIN category_translations ct
                  ON ct.category_id = f.primary_category_id
                 AND ct.locale_code = ft.locale_code
                """
            )
            conn.execute(
                "INSERT INTO metadata(key, value) VALUES ('fts5_enabled', 'true')"
            )
        except sqlite3.DatabaseError:
            conn.execute(
                "INSERT INTO metadata(key, value) VALUES ('fts5_enabled', 'false')"
            )
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, default=DEFAULT_INPUT)
    parser.add_argument("--schema", type=Path, default=DEFAULT_SCHEMA)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()

    build_database(args.input, args.schema, args.output)
    print(f"Built {args.output}")


if __name__ == "__main__":
    main()
