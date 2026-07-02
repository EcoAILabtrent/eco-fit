# T4 — новые ключи и API для волны 2

Задача T4 добавила локализованные ключи и хелперы в `lib/l10n/app_strings.dart`.
Экраны их пока **не потребляют** — это сделает волна 2. Здесь перечислено всё,
что появилось, чтобы задачи волны 2 знали, на что переключать инлайн-строки.

Все ключи заведены во всех 4 языках (en, ru, uzLatn, uzCyrl). Паритет ключей
проверяется тестом `test/l10n_parity_test.dart`.

## Новые методы `AppStrings`

| Метод | Назначение |
|---|---|
| `String plural(String keyBase, int n)` | выбирает `keyBase.one/.few/.many` по правилам языка и подставляет `{n}` |
| `String decimalSep()` | десятичный разделитель: `,` для ru/uz, `.` для en |
| `String num1(double v)` | одно знак после запятой, целые без хвоста: `66` / `66,5` |
| `String thousands(int v)` | разделение тысяч: `10 000` для ru/uz, `10,000` для en |

Правила `plural`: ru — 1→one, 2–4→few, иначе many (с исключениями 11–14→many);
en — 1→one, иначе many; uz (обе письменности) — всегда one (формы `.one/.few/.many`
у узбекского совпадают по значению, но заведены для паритета).

Также изменён фолбэк `t()`: теперь пропущенный ключ падает на **en**, а не на ru,
и в debug-сборке печатает `debugPrint('[l10n] Missing key ...')`.

## Плюрализованные ключи

Старые одиночные ключи (`profile.ageValue`, `notif.steps.nudge.body`,
`notif.steps.goal.body`) **оставлены** — их пока используют экраны. Волна 2
переключает вызовы на `plural(...)` и может удалить одиночные ключи.

| База (для `plural`) | one (ru) | few (ru) | many (ru) | en |
|---|---|---|---|---|
| `profile.age` | `{n} год` | `{n} года` | `{n} лет` | `{n} year` / `{n} years` |
| `notif.steps.goal.body` | `{n} шаг за сегодня…` | `{n} шага…` | `{n} шагов…` | `{n} step today…` / `{n} steps today…` |
| `notif.steps.nudge.body` | `До дневной цели остался {n} шаг` | `…{n} шага` | `…{n} шагов` | `{n} step to your daily goal` / `{n} steps…` |

Узбекский: `profile.age` → `{n} yosh` / `{n} ёш`; steps → `qadam` / `қадам`
(во всех трёх формах одинаково). Плейсхолдер везде `{n}` — вызывать
`l.plural('notif.steps.nudge.body', left)` и т.п.

## Новые простые ключи

| Ключ | en | ru | uzLatn | uzCyrl | Что заменяет в волне 2 |
|---|---|---|---|---|---|
| `common.totalAmount` | Total | Общее количество | Umumiy | Умумий | хардкод «Общее количество» в `dayview.dart`, `meallog.dart` |
| `common.all` | All | Все | Hammasi | Ҳаммаси | инлайн-switch `_allFilterLabel` в `addfood.dart` |
| `startup.error` | Could not start Eco Fit. | Не удалось запустить Eco Fit. | Eco Fit ishga tushmadi. | Eco Fit ишга тушмади. | хардкод в `main.dart` (`_StartupError`) |
| `startup.retry` | Retry | Повторить | Qayta urinish | Қайта уриниш | хардкод `Retry` в `main.dart` |

## AI-ошибки

Сейчас пользователю показываются английские серверные строки — заменить на:

| Ключ | Смысл |
|---|---|
| `ai.error.rateLimited` | слишком много запросов (429) |
| `ai.error.network` | нет сети |
| `ai.error.timeout` | таймаут запроса |
| `ai.error.generic` | прочие ошибки AI |

## Категории продуктов — `food.category.<slug>`

Slug = id группы из `_categoryGroupDefinitions` (`lib/data/products.dart`). Волна 2
удаляет `switch localeCode` в `_categoryGroupName` и берёт `l.t('food.category.$id')`.

| Slug | en | ru | uzLatn | uzCyrl |
|---|---|---|---|---|
| `dishes` | Dishes | Блюда | Taomlar | Таомлар |
| `drinks` | Drinks | Напитки | Ichimliklar | Ичимликлар |
| `produce` | Fruits & vegetables | Фрукты и овощи | Meva-sabzavot | Мева-сабзавот |
| `protein` | Protein foods | Белковые продукты | Oqsilli mahsulotlar | Оқсилли маҳсулотлар |
| `grains` | Grains & bread | Крупы и хлеб | Don va non | Дон ва нон |
| `other` | Sweets & other | Сладости и прочее | Shirinlik/boshqa | Ширинлик/бошқа |

## Размеры порций — `dish.portion*`

Заменяют `_portionStandardLabels` в `lib/screens/dish.dart`.

| Ключ | en | ru | uzLatn | uzCyrl |
|---|---|---|---|---|
| `dish.portionSmall` | small | маленький | kichik | кичик |
| `dish.portionMedium` | medium | средний | oʻrtacha | ўртача |
| `dish.portionLarge` | large | большой | katta | катта |

## Изменённые (не новые) ключи, важные для волны 2

- `stats.averageSleepRange` — из демо-строки с зашитыми датами превращён в
  шаблон `… · {from} – {to}` (тире `–` во всех языках). Волна 2 должна
  подставлять `{from}`/`{to}` через `format(...)`.
