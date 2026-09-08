import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/app_state.dart';
import '../../core/couple_space.dart';
import '../../core/strings.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.dart';
import '../../ui/atmosphere.dart';
import '../../ui/glass.dart';
import '../../ui/text_prompt.dart';

class CoupleSpaceScreen extends ConsumerWidget {
  const CoupleSpaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context, ref);
    final app = ref.watch(appStateProvider);
    final t = Theme.of(context).textTheme;
    final surface = context.surface;
    final me = app.userOrDefault;
    final p = app.partnerOrDefault;

    return StageTheme(
      stage: ResolutionStage.calm,
      child: Atmosphere(
        background: Backgrounds.calm,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            24,
            MediaQuery.paddingOf(context).top + 12,
            24,
            140,
          ),
          children: [
            Eyebrow(s.usLabel, color: surface.ink2),
            const SizedBox(height: 4),
            Text('$me & $p', style: t.headlineMedium),
            const SizedBox(height: 18),
            _OriginCard(s: s, app: app),
            const SizedBox(height: 12),
            _LoveMapCard(s: s, partner: p),
            const SizedBox(height: 12),
            _DatesCard(s: s),
            const SizedBox(height: 12),
            _GoalsCard(s: s),
            const SizedBox(height: 12),
            GlassButton(
              label: s.openRepairRoom,
              primary: false,
              icon: Icons.meeting_room_outlined,
              onPressed: () => context.push(Routes.repair),
            ),
          ],
        ),
      ),
    );
  }
}

class _OriginCard extends StatelessWidget {
  const _OriginCard({required this.s, required this.app});

  final S s;
  final AppState app;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = app.partnerOrDefault;

    return GlassPanel(
      strong: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: Eyebrow(s.whyWeStarted)),
              Icon(Icons.lock_outline_rounded,
                  size: 16, color: context.stage.accent),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            app.originStory.isEmpty
                ? s.originRevealHintUnwritten(p)
                : s.originRevealHintWritten(p),
            style: t.bodyMedium,
          ),
          const SizedBox(height: 12),
          GlassButton(
            label:
                app.originStory.isEmpty ? s.editOriginStory : s.planTheReveal,
            primary: false,
            icon: app.originStory.isEmpty ? Icons.edit_outlined : null,
            onPressed: app.originStory.isEmpty
                ? () => context.push(Routes.editOrigin)
                : () => ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(content: Text(s.needsPairing))),
          ),
        ],
      ),
    );
  }
}

/// The love map, as ten questions rather than three placeholder rows.
class _LoveMapCard extends ConsumerWidget {
  const _LoveMapCard({required this.s, required this.partner});

  final S s;
  final String partner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final surface = context.surface;
    final store = ref.watch(coupleSpaceProvider.notifier);
    ref.watch(coupleSpaceProvider);
    final prompts = s.loveMapPrompts(partner);
    final known =
        prompts.where((p) => (store.answerFor(p) ?? '').isNotEmpty).length;

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: Eyebrow(s.loveMap)),
              Text(
                s.loveMapProgress(known, prompts.length),
                style: t.labelSmall?.copyWith(
                  letterSpacing: 0,
                  fontSize: 12,
                  color: known == 0 ? surface.ink2 : context.stage.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            s.loveMapSub,
            style: t.bodySmall?.copyWith(fontSize: 13, color: surface.ink2),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < prompts.length; i++) ...[
            if (i > 0) Divider(color: surface.hairline, height: 16),
            _LoveMapRow(
              s: s,
              prompt: prompts[i],
              answer: store.answerFor(prompts[i]) ?? '',
            ),
          ],
        ],
      ),
    );
  }
}

class _LoveMapRow extends ConsumerWidget {
  const _LoveMapRow(
      {required this.s, required this.prompt, required this.answer});

  final S s;
  final String prompt;
  final String answer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 15);
    final surface = context.surface;
    final answered = answer.trim().isNotEmpty;

    return Semantics(
      button: true,
      label: '$prompt. ${answered ? answer : s.loveMapUnanswered}',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => _edit(context, ref),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(prompt, style: t?.copyWith(color: surface.ink2)),
                    if (answered) ...[
                      const SizedBox(height: 2),
                      Text(answer, style: t?.copyWith(color: surface.ink)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (!answered)
                Text(
                  s.loveMapUnanswered,
                  style: t?.copyWith(fontSize: 13, color: surface.ink2),
                )
              else
                Icon(Icons.edit_outlined, size: 16, color: surface.ink2),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final saved = await promptForText(
      context,
      title: prompt,
      label: s.loveMapAnswer,
      helper: s.loveMapAsk,
      initialValue: answer,
      maxLines: 3,
      saveLabel: s.save,
      cancelLabel: s.cancel,
    );
    if (saved == null || !context.mounted) return;
    await ref
        .read(coupleSpaceProvider.notifier)
        .setFact(prompt: prompt, answer: saved);
  }
}

class _DatesCard extends ConsumerWidget {
  const _DatesCard({required this.s});

  final S s;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final surface = context.surface;
    final space = ref.watch(coupleSpaceProvider);
    final sorted = [...space.dates]
      ..sort((a, b) => a.daysUntil().compareTo(b.daysUntil()));

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow(s.dates),
          const SizedBox(height: 10),
          if (sorted.isEmpty)
            Text(
              s.datesEmpty,
              style: t.bodySmall?.copyWith(fontSize: 15, color: surface.ink2),
            )
          else
            for (final d in sorted) ...[
              _DateRow(s: s, date: d),
              if (d != sorted.last)
                Divider(color: surface.hairline, height: 16),
            ],
          const SizedBox(height: 12),
          GlassChip(
            label: s.dateAdd,
            icon: Icons.event_outlined,
            onTap: () => _add(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    // Label first: cancelling the label after picking a date used to throw
    // the pick away, and the label is the part people know instantly.
    final label = await promptForText(
      context,
      title: s.dateLabel,
      hint: s.dateLabelHint,
      saveLabel: s.save,
      cancelLabel: s.cancel,
    );
    if (label == null || label.trim().isEmpty || !context.mounted) return;

    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime(DateTime.now().year + 5),
      helpText: label.trim(),
    );
    if (picked == null || !context.mounted) return;
    await ref.read(coupleSpaceProvider.notifier).addDate(
          label: label,
          month: picked.month,
          day: picked.day,
          // A past date is an anniversary worth counting; a future one is
          // just a date.
          year: picked.isBefore(DateTime.now()) ? picked.year : null,
        );
  }
}

class _DateRow extends ConsumerWidget {
  const _DateRow({required this.s, required this.date});

  final S s;
  final ImportantDate date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 15);
    final surface = context.surface;
    final days = date.daysUntil();
    final count = date.nextCount();
    final soon = days <= 7;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(date.label, style: t),
              Text(
                [
                  s.daysAway(days),
                  if (count != null && count > 0) s.nthYear(count),
                ].join(' · '),
                style: t?.copyWith(
                  fontSize: 13,
                  color: soon ? context.stage.accent : surface.ink2,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: s.remove,
          visualDensity: VisualDensity.compact,
          icon: Icon(Icons.close_rounded, size: 18, color: surface.ink2),
          onPressed: () =>
              ref.read(coupleSpaceProvider.notifier).removeDate(date.id),
        ),
      ],
    );
  }
}

class _GoalsCard extends ConsumerWidget {
  const _GoalsCard({required this.s});

  final S s;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final surface = context.surface;
    final space = ref.watch(coupleSpaceProvider);

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow(s.goals),
          const SizedBox(height: 10),
          if (space.goals.isEmpty)
            Text(
              '${s.goalsEmpty} ${s.goalHint}',
              style: t.bodySmall?.copyWith(fontSize: 15, color: surface.ink2),
            )
          else ...[
            // Open goals first; finished ones stayed interleaved forever.
            for (final g in space.openGoals) _GoalRow(s: s, goal: g),
            if (space.goals.any((g) => g.isDone)) ...[
              const SizedBox(height: 8),
              Eyebrow(s.goalsCompleted, color: surface.ink2),
              const SizedBox(height: 4),
              for (final g in space.goals)
                if (g.isDone) _GoalRow(s: s, goal: g),
            ],
          ],
          const SizedBox(height: 12),
          GlassChip(
            label: s.goalAdd,
            icon: Icons.add_rounded,
            onTap: () => _add(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final text = await promptForText(
      context,
      title: s.goalAdd,
      helper: s.goalHint,
      maxLines: 2,
      saveLabel: s.save,
      cancelLabel: s.cancel,
    );
    if (text == null || !context.mounted) return;
    await ref.read(coupleSpaceProvider.notifier).addGoal(text);
  }
}

class _GoalRow extends ConsumerWidget {
  const _GoalRow({required this.s, required this.goal});

  final S s;
  final SharedGoal goal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 15);
    final surface = context.surface;

    return Semantics(
      checked: goal.isDone,
      label: goal.text,
      excludeSemantics: true,
      child: Row(
        children: [
          IconButton(
            tooltip: s.goalDone,
            visualDensity: VisualDensity.compact,
            icon: Icon(
              goal.isDone
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 20,
              color: goal.isDone ? context.stage.accent : surface.ink2,
            ),
            onPressed: () =>
                ref.read(coupleSpaceProvider.notifier).toggleGoal(goal.id),
          ),
          Expanded(
            child: InkWell(
              onTap: () async {
                final text = await promptForText(
                  context,
                  title: s.goalEdit,
                  initialValue: goal.text,
                  maxLines: 2,
                  saveLabel: s.save,
                  cancelLabel: s.cancel,
                );
                if (text == null || !context.mounted) return;
                await ref
                    .read(coupleSpaceProvider.notifier)
                    .editGoal(goal.id, text);
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  goal.text,
                  style: t?.copyWith(
                    color: goal.isDone ? surface.ink2 : surface.ink,
                    decoration:
                        goal.isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: s.goalRemove,
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.close_rounded, size: 18, color: surface.ink2),
            onPressed: () =>
                ref.read(coupleSpaceProvider.notifier).removeGoal(goal.id),
          ),
        ],
      ),
    );
  }
}
