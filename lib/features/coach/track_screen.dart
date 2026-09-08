import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_state.dart';
import '../../core/strings.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.dart';
import '../../ui/atmosphere.dart';
import '../../ui/glass.dart';
import '../../ui/text_prompt.dart';
import 'coach_strings.dart';
import 'motivation.dart';
import 'tracker.dart';

/// Every application, as a pipeline. Logging here is what makes the daily plan
/// count it.
class TrackScreen extends ConsumerWidget {
  const TrackScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = T.of(context, ref);
    final apps = ref.watch(applicationsProvider);
    final lang = ref.watch(appStateProvider.select((a) => a.language.code));
    final tt = Theme.of(context).textTheme;
    final surface = context.surface;
    final format = DateFormat('d MMM', lang);

    int count(AppStage s) => apps.where((a) => a.stage == s).length;

    return StageTheme(
      stage: ResolutionStage.working,
      child: Atmosphere(
        background: Backgrounds.working,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
              24, MediaQuery.paddingOf(context).top + 12, 24, 140),
          children: [
            Row(children: [
              Expanded(child: Text(t.trackTitle, style: tt.headlineMedium)),
              GlassChip(
                  label: t.addApplication,
                  icon: Icons.add_rounded,
                  onTap: () => _add(context, ref, t)),
            ]),
            const SizedBox(height: 14),
            if (apps.isNotEmpty) ...[
              GlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Eyebrow(t.funnel, color: surface.ink2),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final s in AppStage.values)
                        if (count(s) > 0)
                          GlassChip(label: '${t.stage(s)} · ${count(s)}'),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (apps.isEmpty)
              GlassPanel(
                  strong: true, child: Text(t.trackEmpty, style: tt.bodyLarge))
            else
              for (final a in apps) ...[
                _AppCard(a: a, t: t, when: format.format(a.createdAt)),
                const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref, T t) async {
    final s = S.readWidget(ref);
    final company = await promptForText(context,
        title: t.company, saveLabel: s.continueLabel, cancelLabel: s.cancel);
    if (company == null || company.trim().isEmpty || !context.mounted) return;
    final role = await promptForText(context,
        title: t.role, saveLabel: s.continueLabel, cancelLabel: s.cancel);
    if (role == null || !context.mounted) return;
    final link = await promptForText(context,
        title: t.link, saveLabel: s.save, cancelLabel: s.cancel);
    if (!context.mounted) return;
    await ref
        .read(applicationsProvider.notifier)
        .add(company: company, role: role, link: link ?? '');
  }
}

class _AppCard extends ConsumerWidget {
  const _AppCard({required this.a, required this.t, required this.when});
  final JobApplication a;
  final T t;
  final String when;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = Theme.of(context).textTheme;
    final surface = context.surface;
    final sage = Theme.of(context).colorScheme.secondary;
    final accent = context.stage.accent;
    final stageColor = switch (a.stage) {
      AppStage.offer => sage,
      AppStage.rejected => surface.ink2,
      _ => accent,
    };

    return GlassPanel(
      strong: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Eyebrow(when, color: surface.ink2)),
            StatusPill(label: t.stage(a.stage), icon: Icons.flag_outlined),
            IconButton(
              tooltip: t.removeApplication,
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.close_rounded, size: 18, color: surface.ink2),
              onPressed: () async {
                final store = ref.read(applicationsProvider.notifier);
                await store.remove(a.id);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(
                    content: Text(t.removed),
                    duration: const Duration(seconds: 6),
                    action: SnackBarAction(
                      label: t.undo,
                      onPressed: () => store.add(
                          company: a.company,
                          role: a.role,
                          link: a.link,
                          stage: a.stage,
                          at: a.createdAt,
                          id: a.id),
                    ),
                  ));
              },
            ),
          ]),
          Text(a.company, style: tt.titleMedium),
          if (a.role.isNotEmpty)
            Text(a.role,
                style:
                    tt.bodySmall?.copyWith(fontSize: 15, color: surface.ink2)),
          const SizedBox(height: 10),
          Eyebrow(t.moveTo, color: stageColor),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final s in AppStage.values)
              GlassChip(
                label: t.stage(s),
                active: a.stage == s,
                selectable: true,
                onTap: () async {
                  await ref
                      .read(applicationsProvider.notifier)
                      .setStage(a.id, s);
                  if (!context.mounted) return;
                  final moment = switch (s) {
                    AppStage.rejected => Moment.rejected,
                    AppStage.offer => Moment.offer,
                    _ => null,
                  };
                  if (moment == null) return;
                  final hindi = ref.read(appStateProvider).isHindi;
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(SnackBar(
                      duration: const Duration(seconds: 6),
                      content: Text(Motivation.line(moment, hindi: hindi)),
                    ));
                },
              ),
          ]),
          if (a.link.isNotEmpty) ...[
            const SizedBox(height: 10),
            GlassChip(
              label: t.openLink,
              icon: Icons.open_in_new_rounded,
              onTap: () async {
                final uri = Uri.tryParse(
                    a.link.startsWith('http') ? a.link : 'https://${a.link}');
                if (uri == null) return;
                final ok =
                    await launchUrl(uri, mode: LaunchMode.externalApplication)
                        .catchError((Object _) => false);
                if (ok || !context.mounted) return;
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(content: Text(t.couldNotOpen)));
              },
            ),
          ],
        ],
      ),
    );
  }
}
