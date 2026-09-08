import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/app_state.dart';
import '../../core/journal.dart';
import '../../core/strings.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.dart';
import '../../ui/atmosphere.dart';
import '../../ui/glass.dart';
import '../../ui/text_prompt.dart';
import 'coach_strings.dart';

/// Plain notes on the shared JournalStore. Rejections, wins, patterns.
class CoachJournalScreen extends ConsumerWidget {
  const CoachJournalScreen({super.key});

  Future<void> _write(BuildContext context, WidgetRef ref) async {
    final t = T.readWidget(ref);
    final s = S.readWidget(ref);
    final text = await promptForText(context,
        title: t.writeEntry,
        saveLabel: s.save,
        cancelLabel: s.cancel,
        maxLines: 6);
    final body = text?.trim() ?? '';
    if (body.isEmpty) return;
    final first = body.split('\n').first.trim();
    await ref.read(journalProvider.notifier).add(
          kind: JournalKind.note,
          title: first.length > 80 ? '${first.substring(0, 77)}…' : first,
          body: body,
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = T.of(context, ref);
    final entries = ref.watch(journalProvider);
    final lang = ref.watch(appStateProvider.select((a) => a.language.code));
    final tt = Theme.of(context).textTheme;
    final surface = context.surface;
    final format = DateFormat('d MMM, h:mm a', lang);

    return StageTheme(
      stage: ResolutionStage.calm,
      child: Scaffold(
        body: Atmosphere(
          background: Backgrounds.origin,
          child: Column(children: [
            GlassTopBar(
              title: t.journalTitle,
              onBack: () => context.pop(),
              trailing: IconButton(
                tooltip: t.writeEntry,
                onPressed: () => _write(context, ref),
                icon: Icon(Icons.edit_outlined, color: surface.ink2),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 6, 24, 40),
                children: [
                  Text(t.journalBody,
                      style: tt.bodySmall
                          ?.copyWith(fontSize: 15, color: surface.ink2)),
                  const SizedBox(height: 14),
                  if (entries.isEmpty)
                    GlassPanel(
                      strong: true,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.journalEmpty, style: tt.bodyLarge),
                            const SizedBox(height: 12),
                            GlassButton(
                                label: t.writeEntry,
                                icon: Icons.edit_outlined,
                                expand: false,
                                onPressed: () => _write(context, ref)),
                          ]),
                    ),
                  for (final e in entries) ...[
                    GlassPanel(
                      strong: true,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Expanded(
                                  child: Eyebrow(format.format(e.createdAt),
                                      color: surface.ink2)),
                              IconButton(
                                tooltip: t.deleteEntry,
                                visualDensity: VisualDensity.compact,
                                icon: Icon(Icons.close_rounded,
                                    size: 18, color: surface.ink2),
                                onPressed: () async {
                                  final j = ref.read(journalProvider.notifier);
                                  await j.remove(e.id);
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context)
                                    ..hideCurrentSnackBar()
                                    ..showSnackBar(SnackBar(
                                      content: Text(t.removed),
                                      duration: const Duration(seconds: 6),
                                      action: SnackBarAction(
                                        label: t.undo,
                                        onPressed: () => j.add(
                                            kind: e.kind,
                                            title: e.title,
                                            body: e.body,
                                            ask: e.ask,
                                            themes: e.themes,
                                            at: e.createdAt),
                                      ),
                                    ));
                                },
                              ),
                            ]),
                            Text(e.body, style: tt.bodyMedium),
                          ]),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
