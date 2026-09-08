import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/app_state.dart';
import '../../core/strings.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.dart';
import '../../ui/atmosphere.dart';
import '../../ui/glass.dart';
import 'coach_strings.dart';

/// Onboarding step 1: three intro slides and the language choice. Then the
/// profile, then the model download (skippable).
class CoachWelcomeScreen extends ConsumerStatefulWidget {
  const CoachWelcomeScreen({super.key});

  @override
  ConsumerState<CoachWelcomeScreen> createState() => _CoachWelcomeScreenState();
}

class _CoachWelcomeScreenState extends ConsumerState<CoachWelcomeScreen> {
  final _pages = PageController();
  int _page = 0;
  static const _count = 3;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    if (context.reduceMotion) {
      _pages.jumpToPage(page);
    } else {
      _pages.animateToPage(page,
          duration: const Duration(milliseconds: 360),
          curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context, ref);
    final t = T.of(context, ref);
    final tt = Theme.of(context).textTheme;
    final surface = context.surface;
    final sage = Theme.of(context).colorScheme.secondary;

    Future<void> start(AppLanguage language) async {
      await ref.read(appStateProvider.notifier).setLanguage(language);
      if (context.mounted) context.push(Routes.onboardingProfile);
    }

    final slides = [
      _Slide(icon: Icons.flag_outlined, title: t.tagline, body: t.taglineSub),
      _Slide(
          icon: Icons.checklist_rounded,
          title: t.introPlanTitle,
          body: t.introPlanBody),
      _Slide(
          icon: Icons.phonelink_lock_outlined,
          title: t.introPrivateTitle,
          body: t.introPrivateBody),
    ];

    return StageTheme(
      stage: ResolutionStage.aware,
      child: Scaffold(
        body: Atmosphere(
          background: Backgrounds.welcome,
          veilOpacity: context.isDark ? 0.35 : 0.30,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.end,
                    spacing: 10,
                    children: [
                      Text(t.appName, style: tt.headlineSmall),
                      Text(t.appNameDevanagari,
                          style: tt.bodyLarge?.copyWith(color: surface.ink2)),
                    ],
                  ),
                  Expanded(
                    child: PageView(
                      controller: _pages,
                      onPageChanged: (i) => setState(() => _page = i),
                      children: slides,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          for (var i = 0; i < _count; i++)
                            GestureDetector(
                              onTap: () => _goTo(i),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 3, vertical: 12),
                                child: Container(
                                  width: i == _page ? 22 : 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: i == _page
                                        ? context.stage.accent
                                        : surface.glassBorder,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (_page < _count - 1)
                        TextButton(
                          onPressed: () => _goTo(_page + 1),
                          child: Text(s.introNext,
                              style: tt.bodySmall?.copyWith(
                                  fontSize: 14, color: surface.ink2)),
                        )
                      else
                        const SizedBox(height: 40),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GlassButton(
                      label: s.startEnglish,
                      onPressed: () => start(AppLanguage.en)),
                  const SizedBox(height: 10),
                  GlassButton(
                      label: s.startHindi,
                      primary: false,
                      onPressed: () => start(AppLanguage.hi)),
                  const SizedBox(height: 14),
                  Center(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      children: [
                        Icon(Icons.lock_outline_rounded, size: 14, color: sage),
                        Text(s.freePrivateOffline,
                            style: tt.labelSmall?.copyWith(
                                letterSpacing: 0, fontSize: 12, color: sage)),
                      ],
                    ),
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

class _Slide extends StatelessWidget {
  const _Slide({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final surface = context.surface;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Frost(
                color: surface.glassSoft,
                borderRadius: BorderRadius.circular(28),
                border: BoxSide(surface.glassBorder),
                padding: const EdgeInsets.all(14),
                child: Icon(icon, color: context.stage.accent, size: 28),
              ),
              const SizedBox(height: 18),
              Semantics(
                  header: true, child: Text(title, style: tt.displayLarge)),
              const SizedBox(height: 14),
              Text(body, style: tt.bodyLarge?.copyWith(color: surface.ink2)),
            ],
          ),
        ),
      ),
    );
  }
}
