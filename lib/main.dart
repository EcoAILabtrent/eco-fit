import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'data/products.dart';
import 'firebase/firebase_backend.dart';
import 'l10n/app_language.dart';
import 'l10n/app_strings.dart';
import 'screens/addfood.dart';
import 'screens/dayview.dart';
import 'screens/health.dart';
import 'screens/home.dart';
import 'screens/meallog.dart';
import 'screens/onboarding.dart';
import 'screens/profile.dart';
import 'screens/stats.dart';
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
  late Future<AppStore> _storeFuture;
  AppLifecycleListener? _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _storeFuture = _loadStore();
  }

  Future<AppStore> _loadStore() async {
    final store = AppStore();
    await store.init();
    await FoodDb.instance.load(localeCode: store.language.productLocale);
    // Pull today's steps on launch and on every return to the foreground.
    unawaited(store.syncSteps());
    _lifecycleListener = AppLifecycleListener(
      onResume: () => store.syncSteps(),
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
      future: _storeFuture,
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
                _storeFuture = _loadStore();
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
        scaffoldBackgroundColor: t.bg,
        colorScheme: ColorScheme.fromSeed(seedColor: t.dark, surface: t.bg),
        useMaterial3: true,
      ),
      home: const Scaffold(body: Center(child: CircularProgressIndicator())),
    );
  }
}

class _StartupError extends StatelessWidget {
  final Object? error;
  final VoidCallback onRetry;

  const _StartupError({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    const t = EcoTheme.meadow;
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
                const Text(
                  'Could not start Eco Fit.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  '$error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: EcoColors.sub),
                ),
                const SizedBox(height: 16),
                FilledButton(onPressed: onRetry, child: const Text('Retry')),
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
    const t = EcoTheme.meadow;
    return ChangeNotifierProvider.value(
      value: store,
      child: Consumer<AppStore>(
        builder: (context, store, _) {
          final l = AppStrings(store.language);
          return MaterialApp(
            title: 'Eco',
            debugShowCheckedModeBanner: false,
            scrollBehavior: const _EcoScrollBehavior(),
            locale: store.language.locale,
            supportedLocales: AppLanguage.supportedLocales,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: ThemeData(
              scaffoldBackgroundColor: t.bg,
              colorScheme: ColorScheme.fromSeed(
                seedColor: t.dark,
                surface: t.bg,
              ),
              // Bundled Onest (assets/fonts) — works fully offline.
              fontFamily: 'Onest',
              textTheme: Typography.blackMountainView.apply(
                fontFamily: 'Onest',
                bodyColor: EcoColors.ink,
                displayColor: EcoColors.ink,
              ),
              useMaterial3: true,
            ),
            initialRoute: store.onboarded ? '/' : '/onboarding',
            routes: {
              '/': (_) => const HomeScreen(),
              '/dayview': (_) => const DayViewScreen(),
              '/addfood': (ctx) => AddFoodScreen(
                    mealKey:
                        (ModalRoute.of(ctx)!.settings.arguments as String?) ??
                            'lunch',
                  ),
              '/meallog': (ctx) => MealLogScreen(
                    mealKey:
                        (ModalRoute.of(ctx)!.settings.arguments as String?) ??
                            'lunch',
                  ),
              '/stats': (_) => const StatsScreen(),
              '/nutrition': (_) => StubScreen(title: l.t('home.nutrition')),
              '/body': (_) => const BodyScreen(),
              '/bodyEntry': (_) => const BodyEntryScreen(),
              '/water': (_) => const WaterScreen(),
              '/onboarding': (_) => const OnboardingScreen(),
            },
            onGenerateRoute: (settings) {
              if (settings.name == '/profile') {
                return PageRouteBuilder<void>(
                  settings: settings,
                  pageBuilder: (_, __, ___) => const ProfileScreen(),
                  transitionDuration: Duration.zero,
                  reverseTransitionDuration: Duration.zero,
                );
              }
              return null;
            },
          );
        },
      ),
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
            duration: Duration(milliseconds: _overscroll == 0 ? 220 : 80),
            curve: Curves.easeOutCubic,
            child: widget.child,
            builder: (context, animatedStretch, child) {
              return Transform.scale(
                alignment: _alignment,
                scaleX: _isVertical ? 1.0 : 1.0 + animatedStretch,
                scaleY: _isVertical ? 1.0 + animatedStretch : 1.0,
                child: child,
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
    const t = EcoTheme.meadow;
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
                    style: const TextStyle(fontSize: 16, color: EcoColors.sub),
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
