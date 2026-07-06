import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'ai/ai_advice_screen.dart';
import 'data/products.dart';
import 'firebase/firebase_backend.dart';
import 'l10n/app_language.dart';
import 'l10n/app_strings.dart';
import 'notifications/notification_service.dart';
import 'screens/addfood.dart';
import 'screens/consent.dart';
import 'screens/dayview.dart';
import 'screens/health.dart';
import 'screens/home.dart';
import 'screens/meallog.dart';
import 'screens/notification_settings.dart';
import 'screens/onboarding.dart';
import 'screens/profile.dart';
import 'screens/stats.dart';
import 'screens/steps.dart';
import 'state/store.dart';
import 'theme/tokens.dart';
import 'ui/ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await FirebaseBackend.initialize();
  } catch (e) {
    debugPrint(
        'Warning: Firebase initialization failed: $e. App will run without Firebase.');
  }
  runApp(const EcoBootstrap());
}

class EcoBootstrap extends StatefulWidget {
  const EcoBootstrap({super.key});

  @override
  State<EcoBootstrap> createState() => _EcoBootstrapState();
}

class _EcoBootstrapState extends State<EcoBootstrap> {
  // null до первого кадра: пока заставка-щит не отрисована, загрузку не
  // запускаем — это принципиально для тайминга (см. initState).
  Future<AppStore>? _bootFuture;
  AppLifecycleListener? _lifecycleListener;

  @override
  void initState() {
    super.initState();
    // ВАЖНО: и тяжёлую загрузку базы, и отсчёт 2 секунд запускаем только ПОСЛЕ
    // первого кадра, когда щит Эко-комитета уже виден на экране. Если стартовать
    // прямо в initState (как было), 2 секунды тикают ещё во время нативной
    // заставки-яблока, пока загрузка базы блокирует первый кадр, — и щит в
    // итоге мелькает меньше секунды. Отсчёт от первого кадра гарантирует, что
    // щит виден полные 2 секунды.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _bootFuture == null) {
        // Блочный body обязателен: стрелочный `() => _bootFuture = _bootstrap()`
        // возвращает значение присваивания (Future), из-за чего debug-ассерт
        // прерывает setState ещё до markNeedsBuild — и FutureBuilder навсегда
        // остаётся на заставке.
        final bootFuture = _bootstrap();
        setState(() {
          _bootFuture = bootFuture;
        });
      }
    });
  }

  // Грузим стор и одновременно держим заставку минимум 2 секунды (отсчёт от
  // первого кадра); что дольше — то и определяет длительность заставки.
  Future<AppStore> _bootstrap() async {
    final minSplash = Future<void>.delayed(const Duration(milliseconds: 2000));
    final store = await _loadStore();
    await minSplash;
    return store;
  }

  Future<AppStore> _loadStore() async {
    final store = AppStore();
    await store.init();
    await FoodDb.instance.load(localeCode: store.language.productLocale);
    // Pull today's steps on launch and on every return to the foreground.
    unawaited(store.syncSteps());
    // Локальные напоминания: подписка на стор + первичное расписание.
    // syncSteps при каждом возврате в форграунд дёргает notifyListeners, так
    // что планировщик заодно перепроверяет расписание (смена дня, OEM-киллеры).
    unawaited(NotificationService.instance.init(store));
    _lifecycleListener = AppLifecycleListener(
      onResume: () {
        // Процесс мог пережить ночь в фоне — утро начинаем с нулевой воды.
        store.rolloverWaterIfNeeded();
        store.syncSteps();
      },
    );
    return store;
  }

  @override
  void dispose() {
    _lifecycleListener?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppStore>(
      future: _bootFuture,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return EcoApp(store: snapshot.data!);
        }
        if (snapshot.hasError) {
          return _StartupError(
            error: snapshot.error,
            onRetry: () {
              setState(() {
                _lifecycleListener?.dispose();
                _lifecycleListener = null;
                _bootFuture = _bootstrap();
              });
            },
          );
        }
        return const _StartupScreen();
      },
    );
  }
}

class _StartupScreen extends StatelessWidget {
  const _StartupScreen();

  @override
  Widget build(BuildContext context) {
    const t = EcoTheme.meadow;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      scrollBehavior: const _EcoScrollBehavior(),
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(seedColor: t.dark, surface: Colors.white),
        useMaterial3: true,
      ),
      home: const _SplashContent(),
    );
  }
}

class _SplashContent extends StatefulWidget {
  const _SplashContent();

  @override
  State<_SplashContent> createState() => _SplashContentState();
}

class _SplashContentState extends State<_SplashContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FadeTransition(
        opacity: _fade,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/branding/ecology_logo.png',
                  width: 160,
                  fit: BoxFit.contain,
                  // Логотип Эко-комитета (щит с деревом, прозрачный фон).
                  // Фолбэк нейтральный — если ассет вдруг не найдётся, под
                  // текстом просто не будет картинки, без посторонней графики.
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 28),
                const Text(
                  'O‘zbekiston Respublikasi\nEkologiya va iqlim o‘zgarishi\nmilliy qo‘mitasi',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Onest',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1B3A6B),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StartupError extends StatelessWidget {
  final Object? error;
  final VoidCallback onRetry;

  const _StartupError({required this.error, required this.onRetry});

  // Стор не загрузился, поэтому Provider выше нет и context.l10n недоступен.
  // Язык выбираем по системной локали из мини-карты — иначе экран ошибки был бы
  // всегда английским (как и было с захардкоженными строками).
  static AppLanguage _localeLanguage() {
    final code = WidgetsBinding.instance.platformDispatcher.locale.languageCode
        .toLowerCase();
    return switch (code) {
      'ru' => AppLanguage.ru,
      'uz' => AppLanguage.uzLatn,
      _ => AppLanguage.en,
    };
  }

  @override
  Widget build(BuildContext context) {
    const t = EcoTheme.meadow;
    final l = AppStrings(_localeLanguage());
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      scrollBehavior: const _EcoScrollBehavior(),
      theme: ThemeData(
        scaffoldBackgroundColor: t.bg,
        colorScheme: ColorScheme.fromSeed(seedColor: t.dark, surface: t.bg),
        useMaterial3: true,
      ),
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l.t('startup.error'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: EcoColors.sub),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: onRetry,
                  child: Text(l.t('startup.retry')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class EcoApp extends StatelessWidget {
  final AppStore store;
  const EcoApp({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: store,
      child: const _EcoAppView(),
    );
  }
}

/// Корневой [MaterialApp]. Подписан ТОЧЕЧНО на тему и язык (а не на весь стор
/// через Consumer, как было раньше): шагомер дёргает notifyListeners несколько
/// раз в секунду при ходьбе, и Consumer пересобирал MaterialApp + генерировал
/// новый ThemeData через дорогой [ColorScheme.fromSeed] на КАЖДЫЙ тик, обесценивая
/// точечные select-подписки экранов. Теперь MaterialApp пересобирается лишь при
/// реальной смене темы или языка, а ThemeData берётся из кеша по идентичности темы.
class _EcoAppView extends StatelessWidget {
  const _EcoAppView();

  @override
  Widget build(BuildContext context) {
    final t = context.select<AppStore, EcoTheme>((s) => s.theme);
    final lang = context.select<AppStore, AppLanguage>((s) => s.language);
    final l = AppStrings(lang);
    // initialRoute влияет только на первом кадре, поэтому флаги читаем разово
    // (read, не select) — их смена не должна пересобирать MaterialApp.
    final store = context.read<AppStore>();
    final onboarded = store.onboarded;
    // Профиль заполнен, но согласие ИИ/политики ещё не принято (новый гейт или
    // обновление для уже установленных пользователей) → сначала экран согласия.
    final needsConsent = onboarded && !store.consentAccepted;
    return MaterialApp(
      title: 'Eco health',
      // Тап по уведомлению открывает экран через этот ключ.
      navigatorKey: ecoNavigatorKey,
      debugShowCheckedModeBanner: false,
      scrollBehavior: const _EcoScrollBehavior(),
      locale: lang.locale,
      supportedLocales: AppLanguage.supportedLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: _ecoThemeData(t),
      // Язык теперь выбирается первым шагом онбординга, поэтому
      // непройденный онбординг ведёт сразу в его flow. После онбординга, но до
      // принятия согласия — экран согласия и разрешений.
      initialRoute: !onboarded
          ? '/onboarding'
          : needsConsent
              ? '/consent'
              : '/',
      // Все маршруты идут через единый EcoPageRoute — одинаковый быстрый
      // слайд открытия/закрытия ([kEcoMotionDuration]) для каждого экрана
      // (включая профиль, который раньше открывался мгновенно).
      onGenerateRoute: (settings) {
        // Главная ↔ профиль — мгновенно, без анимации (поведение вкладок).
        if (settings.name == '/profile') {
          return EcoInstantRoute<void>(
            settings: settings,
            builder: (_) => const ProfileScreen(),
          );
        }
        final mealKey = (settings.arguments as String?) ?? 'lunch';
        final WidgetBuilder builder;
        switch (settings.name) {
          case '/':
            builder = (_) => const HomeScreen();
          case '/dayview':
            builder = (_) => const DayViewScreen();
          case '/addfood':
            builder = (_) => AddFoodScreen(mealKey: mealKey);
          case '/meallog':
            builder = (_) => MealLogScreen(mealKey: mealKey);
          case '/stats':
            builder = (_) => const StatsScreen();
          case '/aiAdvice':
            builder = (_) => const AiAdviceScreen();
          case '/nutrition':
            builder = (_) => StubScreen(title: l.t('home.nutrition'));
          case '/body':
            builder = (_) => const BodyScreen();
          case '/bodyEntry':
            builder = (_) => const BodyEntryScreen();
          case '/water':
            builder = (_) => const WaterScreen();
          case '/steps':
            builder = (_) => const StepsScreen();
          case '/notifications':
            builder = (_) => const NotificationSettingsScreen();
          case '/onboarding':
            builder = (_) => const OnboardingScreen();
          case '/consent':
            builder = (_) => const ConsentScreen();
          default:
            return null;
        }
        return EcoPageRoute<void>(settings: settings, builder: builder);
      },
    );
  }
}

/// Кеш [ThemeData] по идентичности [EcoTheme]. Тем всего две (meadow/night) и
/// они — const-канонические инстансы, поэтому Map по идентичности держит максимум
/// два значения. Смысл кеша — не звать дорогой [ColorScheme.fromSeed] (генерация
/// палитры) на каждый build MaterialApp.
final Map<EcoTheme, ThemeData> _ecoThemeCache = {};

ThemeData _ecoThemeData(EcoTheme t) =>
    _ecoThemeCache.putIfAbsent(t, () => _buildEcoThemeData(t));

ThemeData _buildEcoThemeData(EcoTheme t) {
  return ThemeData(
    brightness: t.isDark ? Brightness.dark : Brightness.light,
    scaffoldBackgroundColor: t.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: t.olive,
      brightness: t.isDark ? Brightness.dark : Brightness.light,
      surface: t.bg,
    ),
    // Анимация перехода между экранами по всему приложению — стандартный
    // горизонтальный пуш: нижний экран уезжает влево с параллаксом, новый
    // приезжает справа; на закрытии зеркально. Штатный Cupertino-билдер на всех
    // платформах (двигает и нижний экран, и верхний).
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: _CupertinoSlide(),
        TargetPlatform.iOS: _CupertinoSlide(),
        TargetPlatform.fuchsia: _CupertinoSlide(),
        TargetPlatform.windows: _CupertinoSlide(),
        TargetPlatform.macOS: _CupertinoSlide(),
        TargetPlatform.linux: _CupertinoSlide(),
      },
    ),
    // Bundled Onest (assets/fonts) — works fully offline.
    fontFamily: 'Onest',
    // Базовая типографика по яркости темы (светлый текст в тёмной), плюс явные
    // ink-цвета. Чинит дефолтный цвет TextField/текста.
    textTheme: (t.isDark
            ? Typography.whiteMountainView
            : Typography.blackMountainView)
        .apply(
      fontFamily: 'Onest',
      bodyColor: t.ink,
      displayColor: t.ink,
    ),
    useMaterial3: true,
  );
}

/// Стандартный горизонтальный пуш (как в iOS): новый экран приезжает справа,
/// нижний уезжает влево с параллаксом; на возврате — зеркально. Делегирует
/// штатному [CupertinoPageTransition], который двигает оба экрана сразу.
class _CupertinoSlide extends PageTransitionsBuilder {
  const _CupertinoSlide();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return CupertinoPageTransition(
      primaryRouteAnimation: animation,
      secondaryRouteAnimation: secondaryAnimation,
      linearTransition: false,
      child: child,
    );
  }
}

class _EcoScrollBehavior extends MaterialScrollBehavior {
  const _EcoScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const AlwaysScrollableScrollPhysics(
      parent: ClampingScrollPhysics(),
    );
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return _EcoStretchOverscroll(
      axisDirection: details.direction,
      child: child,
    );
  }
}

/// Temporary stub for screens that are ported in upcoming phases — keeps every
/// button navigable until its real screen lands.
class _EcoStretchOverscroll extends StatefulWidget {
  final AxisDirection axisDirection;
  final Widget child;

  const _EcoStretchOverscroll({
    required this.axisDirection,
    required this.child,
  });

  @override
  State<_EcoStretchOverscroll> createState() => _EcoStretchOverscrollState();
}

class _EcoStretchOverscrollState extends State<_EcoStretchOverscroll> {
  double _overscroll = 0;
  bool _leading = true;

  bool get _isVertical =>
      widget.axisDirection == AxisDirection.down ||
      widget.axisDirection == AxisDirection.up;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final extent =
              _isVertical ? constraints.maxHeight : constraints.maxWidth;
          final stretch =
              extent <= 0 ? 0.0 : (_overscroll / extent).clamp(0.0, 0.055);
          return TweenAnimationBuilder<double>(
            tween: Tween<double>(end: stretch),
            duration: Duration(milliseconds: _overscroll == 0 ? 110 : 40),
            curve: Curves.easeOutCubic,
            child: widget.child,
            builder: (context, animatedStretch, child) {
              // Без оттяга (stretch==0) отдаём контент как есть — ни Transform,
              // ни лишнего слоя. Во время «резинки» оборачиваем в
              // RepaintBoundary: весь скролл-контент масштабируется из кэша
              // (композит), а не перерисовывается покадрово. Это и был главный
              // источник лагов скролла на коротких экранах (каждый свайп бьёт
              // в край → постоянный оверскролл → полная перерисовка).
              if (animatedStretch == 0) return child!;
              return Transform.scale(
                alignment: _alignment,
                scaleX: _isVertical ? 1.0 : 1.0 + animatedStretch,
                scaleY: _isVertical ? 1.0 + animatedStretch : 1.0,
                child: RepaintBoundary(child: child),
              );
            },
          );
        },
      ),
    );
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is OverscrollNotification) {
      setState(() {
        _leading = notification.overscroll < 0;
        _overscroll =
            (_overscroll + notification.overscroll.abs()).clamp(0.0, 76.0);
      });
    } else if (notification is ScrollEndNotification ||
        notification is UserScrollNotification &&
            notification.direction == ScrollDirection.idle) {
      if (_overscroll != 0) {
        setState(() => _overscroll = 0);
      }
    }
    return false;
  }

  Alignment get _alignment {
    return switch (widget.axisDirection) {
      AxisDirection.down =>
        _leading ? Alignment.topCenter : Alignment.bottomCenter,
      AxisDirection.up =>
        _leading ? Alignment.bottomCenter : Alignment.topCenter,
      AxisDirection.right =>
        _leading ? Alignment.centerLeft : Alignment.centerRight,
      AxisDirection.left =>
        _leading ? Alignment.centerRight : Alignment.centerLeft,
    };
  }
}

class StubScreen extends StatelessWidget {
  final String title;
  const StubScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final t = context.select<AppStore, EcoTheme>((s) => s.theme);
    final l = context.l10n;
    return Scaffold(
      backgroundColor: t.bg,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EcoTopBar(
              t: t,
              title: title,
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: Center(
                child: EcoCard(
                  t: t,
                  child: Text(
                    l.t('common.stubInProgress'),
                    style: TextStyle(fontSize: 16, color: t.sub),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
