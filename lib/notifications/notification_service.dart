import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../l10n/app_strings.dart';
import '../state/store.dart';

/// Глобальный ключ навигатора — тап по уведомлению открывает нужный экран
/// (добавление еды, вода, итог дня, замеры) из любого состояния приложения.
final ecoNavigatorKey = GlobalKey<NavigatorState>();

/// Локальные напоминания (offline-first, без серверных пушей): еда
/// (завтрак/обед/ужин — «после приёма и до следующего», перекусы не трогаем),
/// вода, вечерний итог дня и еженедельное взвешивание. Шаговые уведомления
/// считает нативный StepSampleWorker — сюда лишь зеркалируются его настройки
/// и локализованные тексты через канал 'eco/steps'.
///
/// Модель планирования — «окно на 7 дней» одноразовых уведомлений, полностью
/// перестраиваемое при каждом значимом изменении стора (запуск приложения,
/// запись еды/воды, смена времени приёма, языка, настроек). Так «умные»
/// правила — пропустить напоминание, если приём уже записан; замолчать при
/// выполненной цели воды — работают без фонового доступа к Hive, а тексты
/// всегда актуального языка. Перестройка на каждом открытии заодно спасает от
/// OEM-киллеров фона (Xiaomi/Oppo), сносящих алармы вместе с процессом.
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  static const _stepsChannel = MethodChannel('eco/steps');

  AppStore? _store;
  String? _lastSignature;
  Timer? _debounce;
  bool _ready = false;
  bool _replanning = false;
  bool _replanDirty = false;
  String? _pendingTapPayload;
  Timer? _pendingTapTimer;

  // ID-диапазоны (окно 7 дней, id = база + смещение дня):
  // еда 100/110/120, вода 200 + день*10 + слот, итог 300+, взвешивание 350.
  // Нативные шаговые уведомления живут в 900/901 (StepNotifier.java) — не
  // пересекаться!
  static const _mealIdBase = {'breakfast': 100, 'lunch': 110, 'dinner': 120};
  static const _waterIdBase = 200;
  static const _summaryIdBase = 300;
  static const _weighId = 350;
  static const _windowDays = 7;

  /// Главные приёмы — по решению владельца перекусы не напоминаем.
  static const _mainMeals = ['breakfast', 'lunch', 'dinner'];

  /// Слоты напоминаний о воде (между окнами напоминаний о еде).
  static const _waterSlots = [(11, 30), (15, 30), (18, 30)];

  Future<void> init(AppStore store) async {
    _store = store;
    if (kIsWeb) return; // web-сборка живёт без плагина уведомлений
    try {
      tzdata.initializeTimeZones();
      try {
        final name = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(name));
      } catch (_) {
        // Не узнали имя зоны — tz.local останется UTC. Расписание строится от
        // локальных полей времени, так что просадка только при смене зоны.
      }
      final launch = await _plugin.getNotificationAppLaunchDetails();
      final initialized = await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
        onDidReceiveNotificationResponse: (response) =>
            _openPayload(response.payload),
      );
      if (initialized != true) return;
      _ready = true;
      // Холодный старт тапом по уведомлению: навигатор ещё не создан (сплэш),
      // поэтому payload откладывается и доигрывается, когда он появится.
      if (launch?.didNotificationLaunchApp ?? false) {
        _openPayload(launch!.notificationResponse?.payload);
      }
    } on MissingPluginException {
      return; // платформа без плагина (десктоп-прогон) — тихий no-op
    } catch (e) {
      debugPrint('NotificationService: init failed: $e');
      return;
    }
    store.addListener(_onStoreChanged);
    _lastSignature = _signature(store);
    // Первый план — сразу, чтобы расписание пережило перезапуск/ребут.
    unawaited(_replan());
  }

  /// Запрос системного разрешения (Android 13+). Возвращает актуальный статус.
  /// Вызывается тумблером настроек; после включения перепланирует расписание.
  Future<bool> requestPermission() async {
    if (!_ready) return false;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return false;
    _store?.markNotifPermAsked();
    var granted = await android.areNotificationsEnabled() ?? false;
    if (!granted) {
      granted = await android.requestNotificationsPermission() ?? false;
    }
    if (granted) unawaited(_replan());
    return granted;
  }

  // ── Реакция на изменения стора ──

  /// Лёгкая «подпись» всего, что влияет на расписание. Стор дёргает
  /// notifyListeners на каждый тик шагомера — сравнение подписи отсекает
  /// нерелевантные тики, дебаунс склеивает пачки изменений.
  String _signature(AppStore s) {
    final buf = StringBuffer()
      ..write(s.onboarded)
      ..write('|')
      ..write(s.notifEnabled)
      ..write(s.notifMeals)
      ..write(s.notifWater)
      ..write(s.notifSummary)
      ..write(s.notifSteps)
      ..write(s.notifWeight)
      ..write('|')
      ..write(s.language.code)
      ..write('|');
    for (final key in _mainMeals) {
      buf
        ..write(s.mealTime(key))
        ..write(',');
    }
    buf
      ..write('|')
      ..write(s.diaryRevision)
      ..write('|')
      // Сырое значение воды (не только «цель достигнута»): сегодняшние тексты
      // запекают живой прогресс, и каждый «+250 мл» должен их освежать.
      ..write(s.water)
      ..write('/')
      ..write(s.waterGoal)
      ..write('|')
      ..write(s.goalKcal)
      ..write('|')
      ..write(s.stepsGoal)
      ..write('|')
      ..write(s.bodyHistory.isEmpty
          ? ''
          : AppStore.ymd(s.bodyHistory.last.date))
      ..write('|')
      ..write(AppStore.ymd());
    return buf.toString();
  }

  void _onStoreChanged() {
    final store = _store;
    if (!_ready || store == null) return;
    final sig = _signature(store);
    if (sig == _lastSignature) return;
    _lastSignature = sig;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), () => unawaited(_replan()));
  }

  // ── Планирование ──

  Future<void> _replan() async {
    final store = _store;
    if (!_ready || store == null) return;
    if (_replanning) {
      _replanDirty = true;
      return;
    }
    _replanning = true;
    try {
      do {
        _replanDirty = false;
        await _replanOnce(store);
      } while (_replanDirty);
    } catch (e) {
      debugPrint('NotificationService: replan failed: $e');
    } finally {
      _replanning = false;
    }
  }

  Future<void> _replanOnce(AppStore store) async {
    final l = AppStrings(store.language);
    final active = store.onboarded && store.notifEnabled;
    // Нативный шаговый воркер всегда получает свежие флаги/тексты — включая
    // «выключено», иначе он продолжит уведомлять по старым настройкам.
    await _configureNativeSteps(store, l, active: active && store.notifSteps);
    // Отменяем только ЗАПЛАНИРОВАННЫЕ (pending) уведомления: cancelAll() у
    // плагина заодно смахивает уже показанные — включая нативные шаговые
    // (StepNotifier 900/901), которые в тот день больше не повторятся.
    await _cancelScheduled();
    if (!active) return;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;
    var granted = await android.areNotificationsEnabled() ?? false;
    if (!granted && !store.notifPermAsked) {
      // Единственный автоматический показ системного диалога — при первом
      // плане после онбординга; дальше только явно из настроек.
      store.markNotifPermAsked();
      granted = await android.requestNotificationsPermission() ?? false;
    }
    if (!granted) return;
    // Точные алармы на API 34+ по умолчанию запрещены — тихо падаем в
    // неточные (±15 мин), для наших окон этого достаточно.
    final exact = await android.canScheduleExactNotifications() ?? false;
    final mode = exact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    final details = _details(l);
    final now = tz.TZDateTime.now(tz.local);

    if (store.notifMeals) {
      await _scheduleMeals(store, l, details, mode, now);
    }
    if (store.notifWater) {
      await _scheduleWater(store, l, details, mode, now);
    }
    if (store.notifSummary) {
      await _scheduleSummary(store, l, details, mode, now);
    }
    if (store.notifWeight) {
      await _scheduleWeighIn(store, l, details, mode, now);
    }
  }

  Future<void> _cancelScheduled() async {
    final pending = await _plugin.pendingNotificationRequests();
    for (final request in pending) {
      await _plugin.cancel(request.id);
    }
  }

  /// zonedSchedule с защитой от гонки: между снимком `now` и этим вызовом
  /// слот мог уйти в прошлое (перестройка — ~50 последовательных вызовов
  /// канала), а плагин на прошедшую дату бросает ArgumentError. Пропускаем
  /// только этот экземпляр, не роняя всю перестройку после отмены.
  Future<void> _schedule(
    int id,
    String title,
    String body,
    tz.TZDateTime when,
    NotificationDetails details,
    AndroidScheduleMode mode,
    String payload,
  ) async {
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        when,
        details,
        androidScheduleMode: mode,
        payload: payload,
      );
    } on ArgumentError {
      // Слот проскочил в прошлое за время перестройки — просто пропускаем.
    }
  }

  NotificationDetails _details(AppStrings l) => NotificationDetails(
        android: AndroidNotificationDetails(
          'eco_reminders',
          l.t('notif.channel.reminders'),
          channelDescription: l.t('notif.channel.remindersDesc'),
          importance: Importance.high,
          priority: Priority.high,
        ),
      );

  // ── Еда: «после приёма и до следующего» ──

  /// Минута дня (0–1439) для напоминания каждого главного приёма: время
  /// приёма + 90 минут, но не позже чем за 60 минут до следующего главного
  /// приёма (для ужина потолок 21:45). Если окна нет (приёмы вплотную) —
  /// напоминание этого приёма пропускается. Всё зажато в «тихие часы»
  /// 08:00–22:00.
  List<(String, int)> _mealReminderMinutes(AppStore store) {
    final entries = [
      for (final key in _mainMeals) (key, _minutesOf(store.mealTime(key))),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    final out = <(String, int)>[];
    for (var i = 0; i < entries.length; i++) {
      final (key, start) = entries[i];
      final cap =
          i + 1 < entries.length ? entries[i + 1].$2 - 60 : 21 * 60 + 45;
      var at = start + 90;
      if (at > cap) at = cap;
      // Тихие часы применяем ДО проверок окна: иначе клампование могло снова
      // вытолкнуть напоминание за границу следующего приёма.
      at = at.clamp(8 * 60, 22 * 60);
      if (at > cap || at < start + 30) continue; // окна между приёмами нет
      out.add((key, at));
    }
    return out;
  }

  Future<void> _scheduleMeals(
    AppStore store,
    AppStrings l,
    NotificationDetails details,
    AndroidScheduleMode mode,
    tz.TZDateTime now,
  ) async {
    final reminders = _mealReminderMinutes(store);
    for (var d = 0; d < _windowDays; d++) {
      for (final (key, minute) in reminders) {
        final when = _at(now, d, minute ~/ 60, minute % 60);
        if (!when.isAfter(now)) continue;
        // Умный пропуск: приём уже записан сегодня — не напоминаем; запись
        // еды меняет diaryRevision, и план перестраивается сам.
        if (d == 0 && store.itemsFor(key).isNotEmpty) continue;
        await _schedule(
          _mealIdBase[key]! + d,
          l.t('notif.meal.$key.title'),
          l.t('notif.meal.$key.body'),
          when,
          details,
          mode,
          'meal:$key',
        );
      }
    }
  }

  // ── Вода ──

  Future<void> _scheduleWater(
    AppStore store,
    AppStrings l,
    NotificationDetails details,
    AndroidScheduleMode mode,
    tz.TZDateTime now,
  ) async {
    final goalReached = store.water >= store.waterGoal;
    for (var d = 0; d < _windowDays; d++) {
      if (d == 0 && goalReached) continue; // цель дня выполнена — молчим
      for (var i = 0; i < _waterSlots.length; i++) {
        final (h, m) = _waterSlots[i];
        final when = _at(now, d, h, m);
        if (!when.isAfter(now)) continue;
        // Сегодняшние тексты с живым прогрессом; будущие дни — без цифр
        // (прогресс на момент срабатывания неизвестен заранее).
        final body = d == 0
            ? l.format('notif.water.body',
                {'current': store.water, 'goal': store.waterGoal})
            : l.format('notif.water.bodyGeneric', {'goal': store.waterGoal});
        await _schedule(
          _waterIdBase + d * 10 + i,
          l.t('notif.water.title'),
          body,
          when,
          details,
          mode,
          'water',
        );
      }
    }
  }

  // ── Вечерний итог дня (21:00) ──

  Future<void> _scheduleSummary(
    AppStore store,
    AppStrings l,
    NotificationDetails details,
    AndroidScheduleMode mode,
    tz.TZDateTime now,
  ) async {
    for (var d = 0; d < _windowDays; d++) {
      final when = _at(now, d, 21, 0);
      if (!when.isAfter(now)) continue;
      final body =
          d == 0 ? _summaryBody(store, l) : l.t('notif.summary.bodyGeneric');
      await _schedule(
        _summaryIdBase + d,
        l.t('notif.summary.title'),
        body,
        when,
        details,
        mode,
        'summary',
      );
    }
  }

  /// Адаптивный текст итога: пустой дневник → «ничего не записано», зелёная
  /// зона (92–105% цели, пороги как в dayview) → похвала, перебор → мягкая
  /// констатация, иначе — сколько осталось. Текст запекается при планировании
  /// и освежается на каждом изменении дневника.
  String _summaryBody(AppStore store, AppStrings l) {
    final consumed = store.consumed;
    if (consumed <= 0) return l.t('notif.summary.bodyEmpty');
    final goal = store.goalKcal;
    if (goal <= 0) return l.t('notif.summary.bodyGeneric');
    final ratio = consumed / goal;
    if (ratio >= 0.92 && ratio <= 1.05) {
      return l.format('notif.summary.bodyGreen', {'consumed': consumed});
    }
    if (ratio > 1.05) {
      return l.format('notif.summary.bodyOver',
          {'consumed': consumed, 'over': consumed - goal});
    }
    return l.format(
        'notif.summary.bodyLeft', {'left': goal - consumed, 'goal': goal});
  }

  // ── Взвешивание (раз в неделю, утро 09:00) ──

  Future<void> _scheduleWeighIn(
    AppStore store,
    AppStrings l,
    NotificationDetails details,
    AndroidScheduleMode mode,
    tz.TZDateTime now,
  ) async {
    final last =
        store.bodyHistory.isEmpty ? null : store.bodyHistory.last.date;
    var when = last == null
        ? _at(now, 0, 9, 0)
        : tz.TZDateTime(tz.local, last.year, last.month, last.day + 7, 9, 0);
    if (!when.isAfter(now)) {
      // Просрочено — ближайшее утро 09:00 (сегодняшнее, если оно ещё впереди).
      final todayNine = _at(now, 0, 9, 0);
      when = todayNine.isAfter(now) ? todayNine : _at(now, 1, 9, 0);
    }
    // +1 день запаса: замер «сегодня» до 09:00 даёт срок чуть дальше окна,
    // а перестройки происходят достаточно часто, чтобы алярм не потерялся.
    if (when.difference(now) > const Duration(days: _windowDays + 1)) return;
    await _schedule(
      _weighId,
      l.t('notif.weight.title'),
      l.t('notif.weight.body'),
      when,
      details,
      mode,
      'weight',
    );
  }

  // ── Нативные шаговые уведомления (StepNotifier.java) ──

  Future<void> _configureNativeSteps(
    AppStore store,
    AppStrings l, {
    required bool active,
  }) async {
    try {
      await _stepsChannel.invokeMethod('configureStepNotifications', {
        'enabled': active,
        'goal': store.stepsGoal,
        'channelName': l.t('notif.channel.steps'),
        'channelDesc': l.t('notif.channel.stepsDesc'),
        'celebrationTitle': l.t('notif.steps.goal.title'),
        'celebrationBody':
            l.format('notif.steps.goal.body', {'goal': store.stepsGoal}),
        'nudgeTitle': l.t('notif.steps.nudge.title'),
        // '{left}' подставляет натив в момент показа (остаток до цели).
        'nudgeBody': l.t('notif.steps.nudge.body'),
      });
    } on MissingPluginException {
      // Нет нативной стороны (web/desktop) — шаговые уведомления недоступны.
    } on PlatformException {
      // Натив без этого метода (старая сборка) — не критично.
    }
  }

  // ── Навигация по тапу ──

  void _openPayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    _pendingTapPayload = payload;
    _drainPendingTap();
  }

  void _drainPendingTap() {
    if (_pendingTapPayload == null) return;
    final nav = ecoNavigatorKey.currentState;
    if (nav == null) {
      // Приложение ещё на сплэше — навигатор появится после bootstrap.
      _pendingTapTimer?.cancel();
      _pendingTapTimer =
          Timer(const Duration(milliseconds: 400), _drainPendingTap);
      return;
    }
    final payload = _pendingTapPayload!;
    _pendingTapPayload = null;
    if (payload.startsWith('meal:')) {
      nav.pushNamed('/addfood', arguments: payload.substring(5));
    } else if (payload == 'water') {
      nav.pushNamed('/water');
    } else if (payload == 'summary') {
      nav.pushNamed('/dayview');
    } else if (payload == 'weight') {
      nav.pushNamed('/bodyEntry');
    }
  }

  // ── Время ──

  static int _minutesOf(String hhmm) {
    final parts = hhmm.split(':');
    final h = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
    final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return (h.clamp(0, 23)) * 60 + m.clamp(0, 59);
  }

  /// Локальное время «через [dayOffset] календарных дней в hour:minute».
  /// Календарная арифметика (day + offset нормализуется конструктором), а не
  /// +24 часа: при сдвиге смещения зоны абсолютные сутки меняют дату.
  tz.TZDateTime _at(tz.TZDateTime now, int dayOffset, int hour, int minute) =>
      tz.TZDateTime(
          tz.local, now.year, now.month, now.day + dayOffset, hour, minute);
}
