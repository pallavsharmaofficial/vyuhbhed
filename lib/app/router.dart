import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/app_state.dart';
import '../core/strings.dart';
import '../features/counsellor/counsellor_screen.dart';
import '../features/counsellor/engine.dart';
import '../features/counsellor/model/model_screen.dart';
import '../features/couple/couple_space_screen.dart';
import '../features/home/today_screen.dart';
import '../features/journal/journal_screen.dart';
import '../features/learn/learn_screen.dart';
import '../features/onboarding/onboarding_screens.dart';
import '../features/pulse/weekly_pulse_screen.dart';
import '../features/repair/repair_screens.dart';
import '../features/safety/safety_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/untangle/untangle_screen.dart';
import '../theme/theme.dart';
import '../theme/tokens.dart';
import '../ui/atmosphere.dart';
import '../ui/glass.dart';
import 'shell.dart';

class Routes {
  Routes._();
  static const onboarding = '/onboarding';
  static const onboardingNames = '/onboarding/names';
  static const onboardingOrigin = '/onboarding/origin';
  static const onboardingModel = '/onboarding/model';
  static const today = '/';
  static const counsellor = '/counsellor';
  static const us = '/us';
  static const learn = '/learn';
  static const talk = '/talk';
  static const untangle = '/untangle';
  static const repair = '/repair';
  static const repairMerged = '/repair/merged';
  static const repairCoolDown = '/repair/cooldown';
  static const repairClose = '/repair/close';
  static const safety = '/safety';
  static const settings = '/settings';
  static const model = '/settings/model';
  static const editOrigin = '/settings/origin';
  static const journal = '/journal';
  static const weeklyPulse = '/week';
}

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _shellKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

/// Bridges Riverpod state into go_router's refresh mechanism.
///
/// The router used to `ref.watch` the onboarding flag directly, which rebuilt
/// the entire [GoRouter] the moment onboarding completed — while the screen
/// that completed it was calling `context.go('/')` on the router being thrown
/// away. A `refreshListenable` re-runs the redirect against the same router
/// instance, which is what go_router is designed for.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    _removeListener = ref
        .listen<bool>(
          appStateProvider.select((s) => s.onboarded),
          (_, __) => notifyListeners(),
        )
        .close;
  }

  late final void Function() _removeListener;

  @override
  void dispose() {
    _removeListener();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootKey,
    refreshListenable: refresh,
    initialLocation:
        ref.read(appStateProvider).onboarded ? Routes.today : Routes.onboarding,
    // Deep links and process-death restoration both land here; the redirect is
    // the only gate, so there is no path into the app that skips onboarding.
    redirect: (context, state) {
      final onboarded = ref.read(appStateProvider).onboarded;
      final inOnboarding = state.matchedLocation.startsWith(Routes.onboarding);
      if (!onboarded && !inOnboarding) return Routes.onboarding;
      if (onboarded && inOnboarding) return Routes.today;
      return null;
    },
    errorBuilder: (context, state) => const _RouteNotFound(),
    routes: [
      GoRoute(
        path: Routes.onboarding,
        pageBuilder: (c, s) => _fade(const WelcomeScreen(), s),
        routes: [
          GoRoute(
              path: 'names',
              pageBuilder: (c, s) => _fade(const NamesScreen(), s)),
          GoRoute(
              path: 'origin',
              pageBuilder: (c, s) => _fade(const OriginStoryScreen(), s)),
          GoRoute(
              path: 'model',
              pageBuilder: (c, s) =>
                  _fade(const ModelScreen(duringOnboarding: true), s)),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            navigatorKey: _shellKey,
            routes: [
              GoRoute(
                  path: Routes.today, builder: (c, s) => const TodayScreen())
            ],
          ),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.counsellor,
              builder: (c, s) => const CounsellorScreen(embedded: true),
            ),
          ]),
          StatefulShellBranch(
            routes: [
              GoRoute(
                  path: Routes.us, builder: (c, s) => const CoupleSpaceScreen())
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                  path: Routes.learn, builder: (c, s) => const LearnScreen())
            ],
          ),
        ],
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: Routes.untangle,
        // `extra` does not survive Android process death, so a restored route
        // arrives with a null vent rather than crashing; the screen shows its
        // "nothing to untangle yet" state.
        pageBuilder: (c, s) =>
            _fade(UntangleScreen(vent: s.extra as String? ?? ''), s),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: Routes.repair,
        pageBuilder: (c, s) => _fade(const RepairIntroScreen(), s),
        routes: [
          GoRoute(
            path: 'merged',
            pageBuilder: (c, s) => _fade(
              RepairMergedScreen(
                  sides: s.extra as RepairSides? ?? const RepairSides('', '')),
              s,
            ),
          ),
          GoRoute(
              path: 'cooldown',
              pageBuilder: (c, s) => _fade(const CoolDownScreen(), s)),
          GoRoute(
              path: 'close',
              pageBuilder: (c, s) => _fade(const RepairCloseScreen(), s)),
        ],
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: Routes.talk,
        pageBuilder: (c, s) =>
            _fade(CounsellorScreen(seed: s.extra as String?), s),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: Routes.safety,
        pageBuilder: (c, s) => _fade(const SafetyScreen(), s),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: Routes.settings,
        pageBuilder: (c, s) => _fade(const SettingsScreen(), s),
        routes: [
          GoRoute(
              path: 'origin',
              pageBuilder: (c, s) => _fade(const EditOriginScreen(), s)),
          GoRoute(
              path: 'model',
              pageBuilder: (c, s) => _fade(const ModelScreen(), s)),
        ],
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: Routes.weeklyPulse,
        pageBuilder: (c, s) => _fade(const WeeklyPulseScreen(), s),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: Routes.journal,
        pageBuilder: (c, s) => _fade(const JournalScreen(), s),
      ),
    ],
  );
});

/// Cross-fade between atmospheres — a push slide would tear the photo layer.
CustomTransitionPage<void> _fade(Widget child, GoRouterState state) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 420),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    transitionsBuilder: (context, animation, secondary, child) {
      if (context.reduceMotion) return child;
      final curved =
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.02), end: Offset.zero)
              .animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _RouteNotFound extends ConsumerWidget {
  const _RouteNotFound();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context, ref);
    return StageTheme(
      stage: ResolutionStage.calm,
      child: Scaffold(
        body: Atmosphere(
          background: Backgrounds.calm,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(s.routeNotFound,
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 20),
                  GlassButton(
                    label: s.goHome,
                    expand: false,
                    onPressed: () => context.go(Routes.today),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
