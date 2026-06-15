import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'data/products.dart';
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
  final store = AppStore();
  await store.init();
  await FoodDb.instance.load(
    localeCode: store.language.productLocale,
  ); // offline product database
  // Pull today's steps on launch and on every return to the foreground.
  unawaited(store.syncSteps());
  AppLifecycleListener(onResume: () => store.syncSteps());
  runApp(EcoApp(store: store));
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
              '/profile': (_) => const ProfileScreen(),
              '/body': (_) => const BodyScreen(),
              '/bodyEntry': (_) => const BodyEntryScreen(),
              '/water': (_) => const WaterScreen(),
              '/pressure': (_) => const PressureScreen(),
              '/sugar': (_) => const SugarScreen(),
              '/onboarding': (_) => const OnboardingScreen(),
            },
          );
        },
      ),
    );
  }
}

/// Temporary stub for screens that are ported in upcoming phases — keeps every
/// button navigable until its real screen lands.
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
                    style: const TextStyle(fontSize: 15, color: EcoColors.sub),
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
