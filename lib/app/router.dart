import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/app_state.dart';
import '../core/strings.dart';
import '../features/counsellor/model/model_screen.dart';
import '../features/coach/coach_engine.dart';
import '../features/coach/coach_screen.dart';
import '../features/coach/jobs_screen.dart';
import '../features/coach/journal_screen.dart';
import '../features/coach/practice_screen.dart';
import '../features/coach/profile_screen.dart';
import '../features/coach/resume_screen.dart';
import '../features/coach/settings_screen.dart';
import '../features/coach/today_screen.dart';
import '../features/coach/track_screen.dart';
import '../features/coach/welcome_screen.dart';
import '../theme/theme.dart';
import '../theme/tokens.dart';
import '../ui/atmosphere.dart';
import '../ui/glass.dart';
import 'shell.dart';

/// Vyuhbhed's routes. The Saath constants at the bottom exist only so the
/// inherited screens keep compiling; nothing registers them.
class Routes {
  Routes._();
  static const onboarding = '/onboarding';
  static const onboardingProfile = '/onboarding/profile';
  static const onboardingModel = '/onboarding/model';
  static const today = '/';
  static const track = '/track';
  static const practice = '/practice';
  static const coach = '/coach';
  static const mock = '/mock';
  static const jobs = '/jobs';
  static const resume = '/resume';
  static const journal = '/journal';
  static const settings = '/settings';
  static const model = '/settings/model';
  static const profile = '/settings/profile';

  // Inherited, unregistered.
  static const onboardingNames = '/onboarding/names';
  static const onboardingOrigin = '/onboarding/origin';
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
  static const editOrigin = '/settings/origin';
  static const weeklyPulse = '/week';
}

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _shellKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

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
        pageBuilder: (c, s) => _fade(const CoachWelcomeScreen(), s),
        routes: [
          GoRoute(
              path: 'profile',
              pageBuilder: (c, s) =>
                  _fade(const ProfileScreen(duringOnboarding: true), s)),
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
                  path: Routes.today, builder: (c, s) => const TodayScreen()),
            ],
          ),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.track, builder: (c, s) => const TrackScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: Routes.practice,
                builder: (c, s) => const PracticeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.coach, builder: (c, s) => const CoachScreen()),
          ]),
        ],
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: Routes.mock,
        // `extra` does not survive process death; fall back to the HR round.
        pageBuilder: (c, s) => _fade(
          MockScreen(
              round: s.extra is InterviewRound
                  ? s.extra! as InterviewRound
                  : InterviewRound.hr),
          s,
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: Routes.jobs,
        pageBuilder: (c, s) => _fade(const JobsScreen(), s),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: Routes.resume,
        pageBuilder: (c, s) => _fade(const ResumeScreen(), s),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: Routes.journal,
        pageBuilder: (c, s) => _fade(const CoachJournalScreen(), s),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: Routes.settings,
        pageBuilder: (c, s) => _fade(const CoachSettingsScreen(), s),
        routes: [
          GoRoute(
              path: 'model',
              pageBuilder: (c, s) => _fade(const ModelScreen(), s)),
          GoRoute(
              path: 'profile',
              pageBuilder: (c, s) => _fade(const ProfileScreen(), s)),
        ],
      ),
    ],
  );
});

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
