import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/router.dart';
import '../../core/app_state.dart';
import '../../core/strings.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.dart';
import '../../ui/atmosphere.dart';
import '../../ui/glass.dart';
import 'coach_strings.dart';
import 'motivation.dart';
import 'profile.dart';
import 'tracker.dart';

/// The campaign dashboard: days left, offers, the four daily steps, and the
/// one thing to do right now.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context, ref);
    final t = T.of(context, ref);
    final app = ref.watch(appStateProvider);
    final profile = ref.watch(profileProvider);
    final plan = ref.watch(dailyPlanProvider);
    final tt = Theme.of(context).textTheme;
    final surface = context.surface;
    final firstDay =
        ref.watch(applicationsProvider).isEmpty && app.pulses.isEmpty;

    final (nextTitle, nextRoute) = switch (plan.next) {
      NextAction.checkIn => (t.nextCheckIn(), null),
      NextAction.apply => (
          t.nextApply(plan.applicationsTarget - plan.applicationsDone),
          Routes.jobs
        ),
      NextAction.mock => (t.nextMock, Routes.practice),
      NextAction.learn => (t.nextLearn, null),
      NextAction.rest => (t.nextRest, null),
    };

    return StageTheme(
      stage: plan.next == NextAction.rest
          ? ResolutionStage.calm
          : ResolutionStage.working,
      child: Atmosphere(
        background:
            plan.next == NextAction.rest ? Backgrounds.calm : Backgrounds.today,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
              24, MediaQuery.paddingOf(context).top + 12, 24, 140),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Eyebrow(
                          DateFormat('EEEE, d MMM', app.language.code)
                              .format(DateTime.now()),
                          color: surface.ink2),
                      const SizedBox(height: 4),
                      Text(
                          t.greeting(
                              profile.name.isEmpty ? t.friend : profile.name),
                          style: tt.headlineMedium?.copyWith(fontSize: 26)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => context.push(Routes.journal),
                  tooltip: t.openJournal,
                  icon: Icon(Icons.auto_stories_outlined, color: surface.ink2),
                ),
                IconButton(
                  onPressed: () => context.push(Routes.settings),
                  tooltip: s.openSettings,
                  icon: Icon(Icons.tune_rounded, color: surface.ink2),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                if (plan.daysLeft != null)
                  Expanded(
                      child: _Stat(
                          label: t.daysLeft(plan.daysLeft!),
                          big: '${plan.daysLeft! < 0 ? 0 : plan.daysLeft}')),
                if (plan.daysLeft != null) const SizedBox(width: 10),
                Expanded(
                    child: _Stat(
                        label: t.offers(plan.offers, plan.targetOffers),
                        big: '${plan.offers}')),
                const SizedBox(width: 10),
                Expanded(
                    child: _Stat(
                        label: t.pipeline(plan.openPipeline),
                        big: '${plan.openPipeline}')),
              ],
            ),
            const SizedBox(height: 14),
            if (firstDay) ...[
              GlassPanel(
                child: Text(t.firstDay,
                    style: tt.bodyMedium?.copyWith(color: surface.ink2)),
              ),
              const SizedBox(height: 12),
            ],
            // The one thing.
            Frost(
              borderRadius: BorderRadius.circular(context.stage.radius),
              color: Palette.bgDark
                  .withValues(alpha: context.isDark ? 0.55 : 0.72),
              border: BoxSide(Colors.white.withValues(alpha: 0.18)),
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.bolt_rounded,
                        size: 18, color: Palette.goldDark),
                    const SizedBox(width: 8),
                    Eyebrow(t.rightNow, color: Palette.goldDark),
                    const Spacer(),
                    Text(t.stepsDone(plan.stepsDone, plan.stepsTotal),
                        style: tt.labelSmall?.copyWith(
                            letterSpacing: 0,
                            fontSize: 12,
                            color: Palette.ink2Dark)),
                  ]),
                  const SizedBox(height: 10),
                  Text(nextTitle,
                      style: tt.bodyLarge
                          ?.copyWith(color: Palette.inkDark, fontSize: 18)),
                  if (nextRoute != null) ...[
                    const SizedBox(height: 12),
                    GlassButton(
                        label: t.doIt,
                        expand: false,
                        onPressed: () => context.push(nextRoute)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            MotivationBanner(
              moment: firstDay
                  ? Moment.firstDay
                  : switch (plan.next) {
                      NextAction.checkIn => (app.pulses.isNotEmpty &&
                              app.pulses.first.connection <= 2)
                          ? Moment.lowEnergy
                          : Moment.needToApply,
                      NextAction.apply => (app.todayConnection ?? 3) <= 2
                          ? Moment.lowEnergy
                          : (app.todayConnection ?? 3) >= 4
                              ? Moment.highEnergy
                              : Moment.needToApply,
                      NextAction.mock => Moment.applicationsDone,
                      NextAction.learn => Moment.applicationsDone,
                      NextAction.rest => Moment.allDone,
                    },
            ),
            const SizedBox(height: 12),
            const _CheckIn(),
            const SizedBox(height: 12),
            GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Step(
                    done: plan.applicationsMet,
                    label: t.applicationsToday(
                        plan.applicationsDone, plan.applicationsTarget),
                    onTap: () => context.go(Routes.track),
                  ),
                  _Step(
                      done: plan.mockDone,
                      label: t.mockToday,
                      onTap: () => context.go(Routes.practice)),
                  _Step(
                    done: plan.learnDone,
                    label: t.learnToday,
                    trailing: plan.learnDone
                        ? null
                        : GlassChip(
                            label: t.markLearned,
                            icon: Icons.check_rounded,
                            onTap: () =>
                                ref.read(learnLogProvider.notifier).markToday(),
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: GlassButton(
                  label: t.openJobs,
                  primary: false,
                  icon: Icons.search_rounded,
                  onPressed: () => context.push(Routes.jobs),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GlassButton(
                  label: t.openResume,
                  primary: false,
                  icon: Icons.description_outlined,
                  onPressed: () => context.push(Routes.resume),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.big});
  final String label;
  final String big;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(big,
              style: tt.headlineMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()])),
          const SizedBox(height: 2),
          Text(label,
              style: tt.bodySmall
                  ?.copyWith(fontSize: 12, color: context.surface.ink2)),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step(
      {required this.done, required this.label, this.onTap, this.trailing});
  final bool done;
  final String label;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    final sage = Theme.of(context).colorScheme.secondary;
    return Semantics(
      checked: done,
      button: onTap != null,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(
                  done
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 22,
                  color: done ? sage : surface.ink2),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: done ? surface.ink2 : surface.ink,
                          decoration: done ? TextDecoration.lineThrough : null,
                        )),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckIn extends ConsumerStatefulWidget {
  const _CheckIn();
  @override
  ConsumerState<_CheckIn> createState() => _CheckInState();
}

class _CheckInState extends ConsumerState<_CheckIn> {
  // Eager, not lazy: a `late` initialiser that reads `ref` would be forced by
  // dispose() if the field was never touched, after `ref` is gone.
  late final TextEditingController _word;

  @override
  void initState() {
    super.initState();
    _word = TextEditingController(text: ref.read(appStateProvider).todayWord);
  }

  @override
  void dispose() {
    _word.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = T.of(context, ref);
    final app = ref.watch(appStateProvider);
    final tt = Theme.of(context).textTheme;
    final surface = context.surface;
    final st = context.stage;
    final sage = Theme.of(context).colorScheme.secondary;
    final score = app.todayConnection;
    ref.listen(appStateProvider.select((a) => a.todayWord), (_, next) {
      if (next != _word.text) _word.text = next;
    });

    return GlassPanel(
      strong: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow(t.checkInLabel, color: sage),
          const SizedBox(height: 8),
          Text(t.checkInQ, style: tt.titleMedium),
          const SizedBox(height: 12),
          Row(children: [
            for (var i = 1; i <= 5; i++) ...[
              Expanded(
                child: Semantics(
                  inMutuallyExclusiveGroup: true,
                  selected: score == i,
                  button: true,
                  label: '$i',
                  excludeSemantics: true,
                  child: InkWell(
                    onTap: () => ref
                        .read(appStateProvider.notifier)
                        .checkIn(connection: i),
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      constraints: const BoxConstraints(minHeight: 46),
                      decoration: BoxDecoration(
                        color: score == i ? st.accentSoft : surface.glassSoft,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: score == i ? st.accent : surface.glassBorder,
                            width: score == i ? 1.5 : 1),
                      ),
                      alignment: Alignment.center,
                      child: Text('$i',
                          style: tt.labelLarge?.copyWith(
                              fontSize: 15,
                              color: score == i ? st.accent : surface.ink2)),
                    ),
                  ),
                ),
              ),
              if (i < 5) const SizedBox(width: 8),
            ],
          ]),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(t.low,
                style:
                    tt.bodySmall?.copyWith(fontSize: 12, color: surface.ink2)),
            Text(t.high,
                style:
                    tt.bodySmall?.copyWith(fontSize: 12, color: surface.ink2)),
          ]),
          if (score != null) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _word,
              textInputAction: TextInputAction.done,
              maxLength: 24,
              buildCounter: (_,
                      {required currentLength,
                      required isFocused,
                      maxLength}) =>
                  null,
              style: tt.bodyMedium,
              onSubmitted: (v) =>
                  ref.read(appStateProvider.notifier).setTodayWord(v),
              onTapOutside: (_) {
                FocusManager.instance.primaryFocus?.unfocus();
                ref.read(appStateProvider.notifier).setTodayWord(_word.text);
              },
              decoration: InputDecoration(
                isDense: true,
                labelText: t.oneWord,
                labelStyle: TextStyle(color: surface.ink2),
                filled: true,
                fillColor: surface.glassSoft,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: surface.glassBorder)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: surface.glassBorder)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: st.accent)),
              ),
            ),
            const SizedBox(height: 8),
            Text(t.savedForToday,
                style: tt.bodySmall?.copyWith(fontSize: 13, color: sage)),
          ],
        ],
      ),
    );
  }
}
