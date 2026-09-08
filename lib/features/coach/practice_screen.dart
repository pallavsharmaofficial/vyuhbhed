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
import '../../ui/text_prompt.dart';
import 'coach_engine.dart';
import 'coach_strings.dart';
import 'motivation.dart';
import 'profile.dart';
import 'tracker.dart';

/// Practice tab: pick a round, start a mock, or log one done elsewhere.
class PracticeScreen extends ConsumerStatefulWidget {
  const PracticeScreen({super.key});

  @override
  ConsumerState<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends ConsumerState<PracticeScreen> {
  InterviewRound _round = InterviewRound.hr;

  Future<void> _logExternal() async {
    final t = T.readWidget(ref);
    final s = S.readWidget(ref);
    final company = await promptForText(context,
        title: t.externalCompany,
        saveLabel: s.continueLabel,
        cancelLabel: s.cancel);
    if (company == null || !mounted) return;
    final notes = await promptForText(context,
        title: t.externalNotes,
        saveLabel: s.save,
        cancelLabel: s.cancel,
        maxLines: 5);
    if (notes == null || !mounted) return;
    await ref.read(mocksProvider.notifier).add(
        round: _round,
        inApp: false,
        questions: 0,
        company: company,
        notes: notes);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(s.saved)));
  }

  @override
  Widget build(BuildContext context) {
    final t = T.of(context, ref);
    final tt = Theme.of(context).textTheme;
    final surface = context.surface;
    final mocks = ref.watch(mocksProvider);
    final lang = ref.watch(appStateProvider.select((a) => a.language.code));
    final format = DateFormat('d MMM', lang);

    return StageTheme(
      stage: ResolutionStage.aware,
      child: Atmosphere(
        background: Backgrounds.aware,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
              24, MediaQuery.paddingOf(context).top + 12, 24, 140),
          children: [
            Text(t.practiceTitle, style: tt.headlineMedium),
            const SizedBox(height: 6),
            Text(t.practiceBody,
                style:
                    tt.bodySmall?.copyWith(fontSize: 15, color: surface.ink2)),
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final r in InterviewRound.values)
                GlassChip(
                    label: t.round(r),
                    active: _round == r,
                    selectable: true,
                    onTap: () => setState(() => _round = r)),
            ]),
            const SizedBox(height: 16),
            GlassButton(
              label: t.startMock,
              icon: Icons.play_arrow_rounded,
              onPressed: () => context.push(Routes.mock, extra: _round),
            ),
            const SizedBox(height: 10),
            GlassButton(
                label: t.logExternal,
                primary: false,
                icon: Icons.edit_calendar_outlined,
                onPressed: _logExternal),
            if (mocks.isNotEmpty) ...[
              const SizedBox(height: 22),
              Eyebrow(t.history, color: surface.ink2),
              const SizedBox(height: 10),
              for (final m in mocks.take(20)) ...[
                GlassPanel(
                  child: Row(children: [
                    Icon(
                        m.inApp
                            ? Icons.smartphone_rounded
                            : Icons.people_outline_rounded,
                        size: 20,
                        color: surface.ink2),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${format.format(m.at)} · ${t.round(m.round)}${m.company.isEmpty ? '' : ' · ${m.company}'}',
                              style: tt.bodyMedium,
                            ),
                            Text(m.inApp ? t.inApp : t.external,
                                style: tt.bodySmall?.copyWith(
                                    fontSize: 12, color: surface.ink2)),
                            if (m.notes.isNotEmpty)
                              Text(m.notes,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: tt.bodySmall?.copyWith(
                                      fontSize: 13, color: surface.ink2)),
                          ]),
                    ),
                    if (m.average != null)
                      Text('${m.average!.toStringAsFixed(1)}/10',
                          style: tt.titleMedium?.copyWith(fontFeatures: const [
                            FontFeature.tabularFigures()
                          ])),
                  ]),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// One mock: six generated questions, typed answers, a score each.
class MockScreen extends ConsumerStatefulWidget {
  const MockScreen({super.key, required this.round});
  final InterviewRound round;

  @override
  ConsumerState<MockScreen> createState() => _MockScreenState();
}

class _MockScreenState extends ConsumerState<MockScreen> {
  final _answer = TextEditingController();
  int _i = 0;
  AnswerScore? _score;
  bool _scoring = false;
  final _scores = <int>[];
  bool _finished = false;

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  QuestionsRequest get _req => QuestionsRequest(
        profile: ref.read(profileProvider),
        round: widget.round,
        hindi: ref.read(appStateProvider).isHindi,
      );

  Future<void> _scoreAnswer(MockQuestion q) async {
    if (_answer.text.trim().isEmpty || _scoring) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _scoring = true);
    try {
      final r = await ref.read(coachEngineProvider).score(
            question: q,
            answer: _answer.text,
            profile: ref.read(profileProvider),
            hindi: ref.read(appStateProvider).isHindi,
          );
      if (!mounted) return;
      setState(() {
        _score = r;
        _scores.add(r.total);
      });
    } on Object catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(T.readWidget(ref).coachFailed)));
    } finally {
      if (mounted) setState(() => _scoring = false);
    }
  }

  Future<void> _next(int total) async {
    if (_i + 1 >= total) {
      await ref.read(mocksProvider.notifier).add(
            round: widget.round,
            inApp: true,
            questions: total,
            scores: List.of(_scores),
          );
      if (mounted) setState(() => _finished = true);
      return;
    }
    setState(() {
      _i++;
      _score = null;
      _answer.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = T.of(context, ref);
    final s = S.of(context, ref);
    final tt = Theme.of(context).textTheme;
    final surface = context.surface;
    final sage = Theme.of(context).colorScheme.secondary;
    final questions = ref.watch(questionsProvider(_req));

    return StageTheme(
      stage: ResolutionStage.aware,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: Atmosphere(
          background: Backgrounds.aware,
          child: Column(children: [
            GlassTopBar(
                title: t.round(widget.round), onBack: () => context.pop()),
            Expanded(
              child: questions.when(
                loading: () => Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: context.stage.accent)),
                    const SizedBox(height: 16),
                    Text(t.preparing, style: tt.titleMedium),
                  ]),
                ),
                error: (_, __) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(t.coachFailed,
                          textAlign: TextAlign.center, style: tt.bodyLarge),
                      const SizedBox(height: 16),
                      GlassButton(
                          label: s.retry,
                          expand: false,
                          onPressed: () =>
                              ref.invalidate(questionsProvider(_req))),
                    ]),
                  ),
                ),
                data: (qs) {
                  if (_finished) {
                    final avg = _scores.isEmpty
                        ? 0.0
                        : _scores.reduce((a, b) => a + b) / _scores.length;
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.check_circle_rounded,
                              size: 40, color: sage),
                          const SizedBox(height: 14),
                          Text(t.mockDone(avg.toStringAsFixed(1)),
                              textAlign: TextAlign.center,
                              style: tt.headlineSmall),
                          const SizedBox(height: 20),
                          GlassButton(
                              label: s.done,
                              expand: false,
                              onPressed: () => context.pop()),
                        ]),
                      ),
                    );
                  }
                  final q = qs[_i.clamp(0, qs.length - 1)];
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(24, 6, 24, 40),
                    children: [
                      Eyebrow(t.questionOf(_i + 1, qs.length),
                          color: surface.ink2),
                      const SizedBox(height: 10),
                      Text(q.question, style: tt.titleLarge),
                      const SizedBox(height: 14),
                      GlassPanel(
                        strong: true,
                        child: TextField(
                          controller: _answer,
                          minLines: 5,
                          maxLines: 12,
                          enabled: _score == null,
                          textCapitalization: TextCapitalization.sentences,
                          onChanged: (_) => setState(() {}),
                          style: tt.bodyLarge,
                          decoration: InputDecoration.collapsed(
                              hintText: t.answerHint,
                              hintStyle: TextStyle(color: surface.ink2)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_score == null)
                        Row(children: [
                          Expanded(
                            child: GlassButton(
                              label: _scoring ? t.scoring : t.scoreIt,
                              icon: Icons.auto_awesome_rounded,
                              onPressed: _answer.text.trim().isEmpty || _scoring
                                  ? null
                                  : () => _scoreAnswer(q),
                            ),
                          ),
                          const SizedBox(width: 10),
                          GlassChip(
                              label: t.skipQuestion,
                              onTap: _scoring ? null : () => _next(qs.length)),
                        ])
                      else ...[
                        Row(children: [
                          Expanded(
                              child: _ScoreTile(
                                  label: t.structure,
                                  value: _score!.structure)),
                          const SizedBox(width: 10),
                          Expanded(
                              child: _ScoreTile(
                                  label: t.specificity,
                                  value: _score!.specificity)),
                        ]),
                        const SizedBox(height: 12),
                        if (_score!.feedback.isNotEmpty)
                          TintPanel(
                              label: t.feedback,
                              color: context.stage.accent,
                              child: Text(_score!.feedback)),
                        if (q.lookingFor.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          TintPanel(
                              label: t.lookingFor,
                              color: surface.gold,
                              child: Text(q.lookingFor)),
                        ],
                        if (_score!.strongerAnswer.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          TintPanel(
                              label: t.strongerAnswer,
                              color: sage,
                              child: Text(_score!.strongerAnswer)),
                        ],
                        const SizedBox(height: 10),
                        MotivationBanner(
                            moment: _score!.total >= 7
                                ? Moment.mockHigh
                                : Moment.mockLow),
                        const SizedBox(height: 16),
                        GlassButton(
                          label: _i + 1 >= qs.length
                              ? t.finishMock
                              : t.nextQuestion,
                          onPressed: () => _next(qs.length),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _ScoreTile extends StatelessWidget {
  const _ScoreTile({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$value / 5',
            style: tt.headlineSmall
                ?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
        const SizedBox(height: 2),
        Text(label,
            style: tt.bodySmall
                ?.copyWith(fontSize: 12, color: context.surface.ink2)),
      ]),
    );
  }
}
