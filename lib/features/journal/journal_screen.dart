import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/router.dart';
import '../../core/app_state.dart';
import '../../core/journal.dart';
import '../../core/strings.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.dart';
import '../../ui/atmosphere.dart';
import '../../ui/glass.dart';
import '../../ui/text_prompt.dart';
import '../counsellor/engine.dart';

/// Everything the user chose to keep. Local only — this screen exists because
/// Untangle's "Save" button had nowhere to save to.
class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key});

  static String themeLabel(S s, JournalTheme theme) => switch (theme) {
        JournalTheme.money => s.isHindi ? 'पैसा' : 'Money',
        JournalTheme.family => s.isHindi ? 'परिवार' : 'Family',
        JournalTheme.intimacy => s.isHindi ? 'नज़दीकी' : 'Intimacy',
        JournalTheme.time => s.isHindi ? 'वक़्त' : 'Time',
        JournalTheme.trust => s.isHindi ? 'भरोसा' : 'Trust',
      };

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen> {
  /// The trend chips used to be inert labels. Tapping one now filters.
  JournalTheme? _filter;

  Future<void> _writeNote() async {
    final s = S.readWidget(ref);
    final text = await promptForText(
      context,
      title: s.journalWriteNote,
      hint: s.journalNoteHint,
      saveLabel: s.save,
      cancelLabel: s.cancel,
      maxLines: 6,
    );
    final body = text?.trim() ?? '';
    if (body.isEmpty) return;
    // First line becomes the list title; the whole text is the body.
    final firstLine = body.split('\n').first.trim();
    final title =
        firstLine.length > 80 ? '${firstLine.substring(0, 77)}…' : firstLine;
    await ref
        .read(journalProvider.notifier)
        .add(kind: JournalKind.note, title: title, body: body);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(s.saved)));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context, ref);
    final app = ref.watch(appStateProvider);
    final all = ref.watch(journalProvider);
    final counts = ref.read(journalProvider.notifier).themeCounts();
    final t = Theme.of(context).textTheme;
    final surface = context.surface;
    final format = DateFormat('d MMM, h:mm a', app.language.code);
    final entries = _filter == null
        ? all
        : [
            for (final e in all)
              if (e.themes.contains(_filter)) e
          ];
    // Month headers once the list is long enough to need orientation.
    final monthFormat = DateFormat('MMMM yyyy', app.language.code);
    final showMonths = entries.length > 8;

    return StageTheme(
      stage: ResolutionStage.calm,
      child: Scaffold(
        body: Atmosphere(
          background: Backgrounds.origin,
          child: Column(
            children: [
              GlassTopBar(
                title: s.journal,
                onBack: () => context.pop(),
                trailing: IconButton(
                  tooltip: s.journalWriteNote,
                  onPressed: _writeNote,
                  icon: Icon(Icons.edit_outlined, color: surface.ink2),
                ),
              ),
              Expanded(
                child: all.isEmpty
                    ? _Empty(s: s, onWrite: _writeNote)
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(24, 6, 24, 40),
                        children: [
                          Text(s.journalSub,
                              style: t.bodySmall?.copyWith(
                                  fontSize: 15, color: surface.ink2)),
                          if (counts.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Eyebrow(s.journalTrends, color: surface.ink2),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                GlassChip(
                                  label: '${s.journalShowAll} · ${all.length}',
                                  active: _filter == null,
                                  selectable: true,
                                  onTap: () => setState(() => _filter = null),
                                ),
                                for (final e in counts.entries)
                                  GlassChip(
                                    label:
                                        '${JournalScreen.themeLabel(s, e.key)} · ${e.value}',
                                    active: _filter == e.key,
                                    selectable: true,
                                    onTap: () => setState(() => _filter =
                                        _filter == e.key ? null : e.key),
                                  ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 16),
                          if (entries.isEmpty && _filter != null)
                            Text(
                              s.journalFilterEmpty(
                                  JournalScreen.themeLabel(s, _filter!)),
                              style:
                                  t.bodyMedium?.copyWith(color: surface.ink2),
                            ),
                          for (var i = 0; i < entries.length; i++) ...[
                            if (showMonths &&
                                (i == 0 ||
                                    monthFormat.format(entries[i].createdAt) !=
                                        monthFormat.format(
                                            entries[i - 1].createdAt))) ...[
                              Padding(
                                padding: EdgeInsets.only(
                                    top: i == 0 ? 0 : 8, bottom: 8),
                                child: Eyebrow(
                                    monthFormat.format(entries[i].createdAt),
                                    color: surface.ink2),
                              ),
                            ],
                            _EntryCard(
                                entry: entries[i],
                                s: s,
                                when: format.format(entries[i].createdAt)),
                            const SizedBox(height: 12),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.s, required this.onWrite});

  final S s;
  final VoidCallback onWrite;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_stories_outlined,
                size: 36, color: context.surface.ink2),
            const SizedBox(height: 16),
            Text(s.journalEmpty,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 20),
            GlassButton(
              label: s.talkToSaath,
              expand: false,
              onPressed: () => context.go(Routes.counsellor),
            ),
            const SizedBox(height: 10),
            GlassButton(
              label: s.journalWriteNote,
              icon: Icons.edit_outlined,
              primary: false,
              expand: false,
              onPressed: onWrite,
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryCard extends ConsumerStatefulWidget {
  const _EntryCard({required this.entry, required this.s, required this.when});

  final JournalEntry entry;
  final S s;
  final String when;

  @override
  ConsumerState<_EntryCard> createState() => _EntryCardState();
}

class _EntryCardState extends ConsumerState<_EntryCard> {
  bool _reflecting = false;

  Future<void> _reflect() async {
    final entry = widget.entry;
    setState(() => _reflecting = true);
    try {
      // No timeout meant the chip could read "Reading it back…" forever on a
      // model that never answered.
      final reflection = await ref
          .read(counsellorEngineProvider)
          .reflectOnEntry(
            title: entry.title,
            body: entry.body,
            ask: entry.ask,
            savedAt: entry.createdAt,
            ctx: ref.read(counsellorContextProvider),
          )
          .timeout(const Duration(seconds: 90));
      await ref
          .read(journalProvider.notifier)
          .setReflection(entry.id, reflection);
    } on TimeoutException {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(widget.s.journalReflectTimeout)));
    } on Object catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(widget.s.counsellorFailed)));
    } finally {
      if (mounted) setState(() => _reflecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final entry = widget.entry;
    final t = Theme.of(context).textTheme;
    final surface = context.surface;

    return GlassPanel(
      strong: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Eyebrow(widget.when, color: surface.ink2)),
              IconButton(
                tooltip: s.deleteEntry,
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.close_rounded, size: 18, color: surface.ink2),
                onPressed: () async {
                  final journal = ref.read(journalProvider.notifier);
                  await journal.remove(entry.id);
                  if (!context.mounted) return;
                  // Delete was one tap and final. The entry is still in hand,
                  // and `add(at:)` puts it back at its original position.
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(SnackBar(
                      content: Text(s.entryDeleted),
                      duration: const Duration(seconds: 6),
                      action: SnackBarAction(
                        label: s.undo,
                        onPressed: () => journal.add(
                          kind: entry.kind,
                          title: entry.title,
                          body: entry.body,
                          ask: entry.ask,
                          themes: entry.themes,
                          at: entry.createdAt,
                        ),
                      ),
                    ));
                },
              ),
            ],
          ),
          Text(entry.title, style: t.titleMedium),
          if (entry.body.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(entry.body, style: t.bodySmall?.copyWith(fontSize: 15)),
          ],
          if (entry.ask.isNotEmpty) ...[
            const SizedBox(height: 12),
            TintPanel(
              label: s.oneSentence,
              color: context.stage.accent,
              child: Text(entry.ask),
            ),
          ],
          const SizedBox(height: 12),
          // Themes are editable: the keyword pass guesses, the person knows.
          Eyebrow(s.journalTags, color: surface.ink2),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final theme in JournalTheme.values)
                GlassChip(
                  label: JournalScreen.themeLabel(s, theme),
                  active: entry.themes.contains(theme),
                  selectable: true,
                  onTap: () {
                    final next = [
                      for (final x in JournalTheme.values)
                        if (x == theme
                            ? !entry.themes.contains(x)
                            : entry.themes.contains(x))
                          x,
                    ];
                    ref
                        .read(journalProvider.notifier)
                        .setThemes(entry.id, next);
                  },
                ),
            ],
          ),
          if (entry.reflection.isNotEmpty) ...[
            const SizedBox(height: 12),
            TintPanel(
              label: s.journalReflection,
              color: Theme.of(context).colorScheme.secondary,
              child: Text(entry.reflection),
            ),
          ] else ...[
            const SizedBox(height: 12),
            GlassChip(
              label: _reflecting ? s.journalReflecting : s.journalReflect,
              icon: _reflecting ? null : Icons.auto_awesome_rounded,
              onTap: _reflecting ? null : _reflect,
            ),
          ],
        ],
      ),
    );
  }
}
