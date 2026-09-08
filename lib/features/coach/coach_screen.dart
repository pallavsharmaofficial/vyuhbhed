import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_state.dart';
import '../../core/strings.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.dart';
import '../../ui/atmosphere.dart';
import '../../ui/glass.dart';
import '../counsellor/safety.dart';
import 'coach_engine.dart';
import 'coach_strings.dart';
import 'motivation.dart';
import 'profile.dart';

/// Ask the coach. One question, one answer, a few quick prompts for the
/// moments that come up in every notice period. The safety classifier from
/// the shared engine still runs: a bad week can be more than a bad week.
class CoachScreen extends ConsumerStatefulWidget {
  const CoachScreen({super.key});

  @override
  ConsumerState<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends ConsumerState<CoachScreen> {
  final _q = TextEditingController();
  final _thread = <(String, String)>[];
  bool _busy = false;
  bool _safety = false;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _ask([String? preset]) async {
    final question = (preset ?? _q.text).trim();
    if (question.isEmpty || _busy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (safetyClassifier.fires(question)) {
      setState(() => _safety = true);
      return;
    }
    setState(() {
      _busy = true;
      _q.clear();
    });
    try {
      final answer = await ref.read(coachEngineProvider).ask(
            question: question,
            profile: ref.read(profileProvider),
            hindi: ref.read(appStateProvider).isHindi,
          );
      if (!mounted) return;
      setState(() => _thread.insert(0, (question, answer)));
    } on Object catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(T.readWidget(ref).coachFailed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = T.of(context, ref);
    final s = S.of(context, ref);
    final tt = Theme.of(context).textTheme;
    final surface = context.surface;
    final engine = ref.watch(coachEngineProvider);

    return StageTheme(
      stage: ResolutionStage.calm,
      child: Atmosphere(
        background: Backgrounds.calm,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
              24, MediaQuery.paddingOf(context).top + 12, 24, 140),
          children: [
            Row(children: [
              Expanded(child: Text(t.coachTitle, style: tt.headlineMedium)),
              const SizedBox(width: 8),
              // Flexible, not bare: the pill was being handed a full sentence
              // of Saath's copy and overflowed the row by 308px.
              Flexible(
                child: StatusPill(
                  label: t.engineBadge(engine.kind),
                  icon: engine.kind == EngineKind.online
                      ? Icons.cloud_outlined
                      : Icons.lock_outline_rounded,
                ),
              ),
            ]),
            const SizedBox(height: 14),
            if (_safety)
              TintPanel(
                label: s.helplines,
                color: context.stage.accent,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.safetyBody1),
                      const SizedBox(height: 8),
                      Text(s.safetyBody2),
                      const SizedBox(height: 10),
                      GlassChip(
                          label: s.imOkayKeepTalking,
                          onTap: () => setState(() => _safety = false)),
                    ]),
              )
            else ...[
              GlassPanel(
                strong: true,
                padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                child:
                    Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Expanded(
                    child: TextField(
                      controller: _q,
                      minLines: 1,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _ask(),
                      style: tt.bodyLarge,
                      decoration: InputDecoration.collapsed(
                          hintText: t.coachHint,
                          hintStyle: TextStyle(color: surface.ink2)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: t.ask,
                    onPressed: _busy || _q.text.trim().isEmpty ? null : _ask,
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.arrow_upward_rounded),
                  ),
                ]),
              ),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final p in [
                  t.promptRejected,
                  t.promptStuck,
                  t.promptSalary,
                  t.promptBuyout,
                  t.promptCounter,
                  t.promptPanic
                ])
                  GlassChip(label: p, onTap: _busy ? null : () => _ask(p)),
              ]),
            ],
            if (_thread.isEmpty) ...[
              const SizedBox(height: 16),
              const MotivationBanner(moment: Moment.stuck),
            ],
            for (final (q, a) in _thread) ...[
              const SizedBox(height: 14),
              Text(q,
                  style: tt.bodyMedium?.copyWith(
                      color: surface.ink2, fontStyle: FontStyle.italic)),
              const SizedBox(height: 6),
              GlassPanel(
                strong: true,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a,
                          style: tt.bodyLarge
                              ?.copyWith(fontSize: 16, height: 1.5)),
                      const SizedBox(height: 10),
                      GlassChip(
                        label: s.copy,
                        icon: Icons.copy_rounded,
                        onTap: () async {
                          await Clipboard.setData(ClipboardData(text: a));
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(SnackBar(content: Text(s.copied)));
                        },
                      ),
                    ]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
