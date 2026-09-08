import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/app_state.dart';
import '../../core/journal.dart';
import '../../core/strings.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.dart';
import '../../ui/atmosphere.dart';
import '../../ui/glass.dart';
import '../counsellor/engine.dart';
import '../counsellor/safety.dart';

final _untangleProvider =
    FutureProvider.autoDispose.family<Untangled, String>((ref, vent) {
  final ctx = ref.watch(counsellorContextProvider);
  return ref.read(counsellorEngineProvider).untangle(vent, ctx);
});

class UntangleScreen extends ConsumerStatefulWidget {
  const UntangleScreen({super.key, required this.vent});

  final String vent;

  @override
  ConsumerState<UntangleScreen> createState() => _UntangleScreenState();
}

class _UntangleScreenState extends ConsumerState<UntangleScreen> {
  bool _savedOnce = false;

  @override
  void initState() {
    super.initState();
    // The guardrail runs on this entry point too. A disclosure typed into a
    // vent used to come back as a tidy four-column breakdown.
    if (safetyClassifier.fires(widget.vent)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.pushReplacement(Routes.safety);
      });
    }
  }

  Future<void> _save(Untangled u) async {
    final s = S.of(context, ref);
    await ref.read(journalProvider.notifier).add(
          kind: JournalKind.untangle,
          title: u.happened,
          body: [
            '${s.whatHappened}: ${u.happened}',
            '${s.whatIAssumed}: ${u.assumed}',
            '${s.whatIFelt}: ${u.felt}',
            '${s.whatINeed}: ${u.need}',
          ].join('\n\n'),
          ask: u.sentence,
          themes: u.themes,
        );
    if (!mounted) return;
    setState(() => _savedOnce = true);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(s.saved),
        action: SnackBarAction(
          label: s.openJournal,
          onPressed: () => context.push(Routes.journal),
        ),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context, ref);
    final app = ref.watch(appStateProvider);
    final t = Theme.of(context).textTheme;
    final surface = context.surface;
    final dark = context.isDark;
    final hasVent = widget.vent.trim().isNotEmpty;
    final result = hasVent ? ref.watch(_untangleProvider(widget.vent)) : null;

    return StageTheme(
      stage: ResolutionStage.working,
      child: Scaffold(
        body: Atmosphere(
          background: Backgrounds.working,
          child: Column(
            children: [
              GlassTopBar(title: s.untangled, onBack: () => context.pop()),
              Expanded(
                child: switch (result) {
                  // A restored route (Android process death drops `extra`) or a
                  // stray deep link lands here rather than on an error.
                  null => _Message(
                      text: s.nothingToUntangle,
                      action: s.talkToSaath,
                      onAction: () => context.pushReplacement(Routes.talk),
                    ),
                  AsyncValue(:final error?) => _Message(
                      text: error is CounsellorException
                          ? s.nothingToUntangle
                          : s.untangleFailed,
                      action: s.retry,
                      onAction: () =>
                          ref.invalidate(_untangleProvider(widget.vent)),
                    ),
                  AsyncValue(hasValue: false) =>
                    _Loading(text: s.untangleSorting),
                  AsyncValue(:final value?) => ListView(
                      padding: const EdgeInsets.fromLTRB(24, 6, 24, 40),
                      children: [
                        Text(s.simpleVersion,
                            style: t.headlineMedium?.copyWith(fontSize: 26)),
                        const SizedBox(height: 6),
                        Text(s.untangleSub,
                            style: t.bodySmall
                                ?.copyWith(fontSize: 15, color: surface.ink2)),
                        const SizedBox(height: 16),
                        _Grid(children: [
                          TintPanel(
                              label: s.whatHappened,
                              color: surface.ink2,
                              child: Text(value.happened)),
                          TintPanel(
                              label: s.whatIAssumed,
                              color: surface.gold,
                              child: Text(value.assumed)),
                          TintPanel(
                              label: s.whatIFelt,
                              color: dark ? Palette.roseDark : Palette.rose,
                              child: Text(value.felt)),
                          TintPanel(
                              label: s.whatINeed,
                              color: dark ? Palette.sageDark : Palette.sage,
                              child: Text(value.need)),
                        ]),
                        const SizedBox(height: 16),
                        GlassPanel(
                          strong: true,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Eyebrow(s.oneSentence),
                              const SizedBox(height: 8),
                              SelectableText(
                                value.sentence,
                                style: t.bodyLarge?.copyWith(
                                    fontSize: 18, fontStyle: FontStyle.italic),
                              ),
                              const SizedBox(height: 12),
                              GlassChip(
                                label: s.copyTheAsk,
                                icon: Icons.content_copy_rounded,
                                onTap: () async {
                                  await Clipboard.setData(
                                      ClipboardData(text: value.sentence));
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context)
                                    ..hideCurrentSnackBar()
                                    ..showSnackBar(
                                        SnackBar(content: Text(s.copied)));
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              flex: 6,
                              child: GlassButton(
                                label: s.sendTo(app.partnerOrDefault),
                                onPressed: () => ScaffoldMessenger.of(context)
                                  ..hideCurrentSnackBar()
                                  ..showSnackBar(SnackBar(
                                      content: Text(s.pairingComingSoon))),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 4,
                              child: GlassButton(
                                // "Save" used to pop the screen and drop the
                                // result on the floor. It now writes to the
                                // on-device journal.
                                label: _savedOnce ? s.done : s.save,
                                primary: false,
                                icon: _savedOnce
                                    ? Icons.check_rounded
                                    : Icons.bookmark_border_rounded,
                                onPressed: _savedOnce
                                    ? () => context.pop()
                                    : () => _save(value),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Center(
                          child: Text(
                            s.notRight,
                            textAlign: TextAlign.center,
                            style: t.bodySmall
                                ?.copyWith(fontSize: 13, color: surface.ink2),
                          ),
                        ),
                      ],
                    ),
                  _ => _Loading(text: s.untangleSorting),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
              color: context.stage.accent, strokeWidth: 2),
          const SizedBox(height: 16),
          Text(text,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: context.surface.ink2)),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(
      {required this.text, required this.action, required this.onAction});

  final String text;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 20),
            GlassButton(label: action, expand: false, onPressed: onAction),
          ],
        ),
      ),
    );
  }
}

/// Two-column grid where each row's cells share a height.
class _Grid extends StatelessWidget {
  const _Grid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    // Past ~1.3× text scale the four columns stop being columns; one per row
    // is the honest layout rather than four slivers of clipped text.
    final stacked = MediaQuery.textScalerOf(context).scale(15) > 20;
    if (stacked) {
      return Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            children[i],
          ],
        ],
      );
    }

    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += 2) {
      rows.add(IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: children[i]),
            const SizedBox(width: 10),
            Expanded(
                child: i + 1 < children.length
                    ? children[i + 1]
                    : const SizedBox()),
          ],
        ),
      ));
      if (i + 2 < children.length) rows.add(const SizedBox(height: 10));
    }
    return Column(children: rows);
  }
}
