import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/addfood.dart';
import 'screens/dayview.dart';
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
      child: MaterialApp(
        title: 'Eco',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          scaffoldBackgroundColor: t.bg,
          colorScheme: ColorScheme.fromSeed(seedColor: t.dark, surface: t.bg),
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
                mealKey: (ModalRoute.of(ctx)!.settings.arguments as String?) ?? 'lunch',
              ),
          '/meallog': (ctx) => MealLogScreen(
                mealKey: (ModalRoute.of(ctx)!.settings.arguments as String?) ?? 'lunch',
              ),
          '/stats': (_) => const StatsScreen(),
          '/nutrition': (_) => const StubScreen(title: 'Питательность'),
          '/profile': (_) => const ProfileScreen(),
          '/body': (_) => const StubScreen(title: 'Параметры тела'),
          '/water': (_) => const StubScreen(title: 'Вода'),
          '/onboarding': (_) => const OnboardingScreen(),
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
    return Scaffold(
      backgroundColor: t.bg,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EcoTopBar(t: t, title: title, onBack: () => Navigator.of(context).pop()),
            Expanded(
              child: Center(
                child: EcoCard(
                  t: t,
                  child: const Text(
                    'Этот экран в работе — появится в следующей фазе порта.',
                    style: TextStyle(fontSize: 15, color: EcoColors.sub),
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
