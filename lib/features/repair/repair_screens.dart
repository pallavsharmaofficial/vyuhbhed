import 'dart:async';

import 'package:flutter/foundation.dart';
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

/// Repair Room, single-device rehearsal mode: until pairing ships, the
/// partner's side is typed on the same phone (handed over), which is also
/// how the feature will demo in the beta.
class RepairIntroScreen extends ConsumerStatefulWidget {
  const RepairIntroScreen({super.key});

  @override
  ConsumerState<RepairIntroScreen> createState() => _RepairIntroScreenState();
}

enum _RepairStep { mySide, handover, theirSide }

class _RepairIntroScreenState extends ConsumerState<RepairIntroScreen> {
  final _mine = TextEditingController();
  final _theirs = TextEditingController();
  _RepairStep _step = _RepairStep.mySide;

  @override
  void initState() {
    super.initState();
    _mine.addListener(_refresh);
    _theirs.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _mine
      ..removeListener(_refresh)
      ..dispose();
    _theirs
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  TextEditingController get _active =>
      _step == _RepairStep.theirSide ? _theirs : _mine;

  bool get _canAdvance => _active.text.trim().length >= 10;

  void _next() {
    if (_step == _RepairStep.mySide) {
      setState(() => _step = _RepairStep.handover);
      return;
    }
    final sides = RepairSides(_mine.text.trim(), _theirs.text.trim());

    // Both accounts go through the guardrail before either is merged. A room
    // is exactly the wrong place to be doing "who said what" if one side has
    // just disclosed being hit.
    if (safetyClassifier.fires(sides.a) || safetyClassifier.fires(sides.b)) {
      context.pushReplacement(Routes.safety);
      return;
    }
    context.pushReplacement(Routes.repairMerged, extra: sides);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context, ref);
    final app = ref.watch(appStateProvider);
    final t = Theme.of(context).textTheme;
    final surface = context.surface;
    final theirTurn = _step == _RepairStep.theirSide;
    final who = theirTurn ? app.partnerOrDefault : app.userOrDefault;

    return StageTheme(
      stage: ResolutionStage.working,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: Atmosphere(
          background: Backgrounds.working,
          child: Column(
            children: [
              GlassTopBar(title: s.repairRoom, onBack: () => context.pop()),
              Expanded(
                child: _step == _RepairStep.handover
                    ? _Handover(
                        s: s,
                        partner: app.partnerOrDefault,
                        onReady: () =>
                            setState(() => _step = _RepairStep.theirSide),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(24, 6, 24, 24),
                        children: [
                          Eyebrow(theirTurn
                              ? s.partnerSidePrivate(app.partnerOrDefault)
                              : s.yourSidePrivate),
                          const SizedBox(height: 8),
                          Text(s.whatHappenedAs(who),
                              style: t.headlineMedium?.copyWith(fontSize: 26)),
                          const SizedBox(height: 8),
                          Text(s.onlySaathReads,
                              style: t.bodySmall?.copyWith(
                                  fontSize: 15, color: surface.ink2)),
                          const SizedBox(height: 18),
                          GlassPanel(
                            strong: true,
                            child: TextField(
                              // A fresh controller per side; the partner never
                              // sees what the first person typed.
                              key: ValueKey(_step),
                              controller: _active,
                              minLines: 6,
                              maxLines: 12,
                              autocorrect: false,
                              textCapitalization: TextCapitalization.sentences,
                              style: t.bodyLarge,
                              decoration: InputDecoration.collapsed(
                                hintText: s.startAnywhere,
                                hintStyle: TextStyle(color: surface.ink2),
                              ),
                            ),
                          ),
                          if (!_canAdvance &&
                              _active.text.trim().isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(s.needBothSides,
                                style: t.bodySmall?.copyWith(
                                    fontSize: 13, color: surface.ink2)),
                          ],
                        ],
                      ),
              ),
              if (_step != _RepairStep.handover)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                      24, 0, 24, MediaQuery.paddingOf(context).bottom + 20),
                  child: GlassButton(
                    label: theirTurn ? s.bothSidesMerge : s.submitMySide,
                    // Was unconditionally enabled, so an empty room merged two
                    // empty strings into a confident fabricated summary.
                    onPressed: _canAdvance ? _next : null,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Handover extends StatelessWidget {
  const _Handover(
      {required this.s, required this.partner, required this.onReady});

  final S s;
  final String partner;
  final VoidCallback onReady;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 40, 28, 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline_rounded,
              size: 36, color: context.stage.accent),
          const SizedBox(height: 18),
          Text(s.sideSealed, style: t.headlineMedium),
          const SizedBox(height: 10),
          Text(s.handToPartner(partner),
              style: t.bodyLarge?.copyWith(color: context.surface.ink2)),
          const SizedBox(height: 32),
          GlassButton(label: s.iAmPartner(partner), onPressed: onReady),
        ],
      ),
    );
  }
}

final _mergeProvider =
    FutureProvider.autoDispose.family<RepairMerge, RepairSides>((ref, sides) {
  final ctx = ref.watch(counsellorContextProvider);
  return ref.read(counsellorEngineProvider).mergeRepair(sides, ctx);
});

class RepairMergedScreen extends ConsumerStatefulWidget {
  const RepairMergedScreen({super.key, required this.sides});

  final RepairSides sides;

  @override
  ConsumerState<RepairMergedScreen> createState() => _RepairMergedScreenState();
}

class _RepairMergedScreenState extends ConsumerState<RepairMergedScreen> {
  static const _turnLength = Duration(minutes: 2);
  static const _totalTurns = 4;

  int _turn = 0;
  Duration _left = _turnLength;
  Timer? _timer;

  bool get _running => _timer?.isActive ?? false;
  bool get _turnFinished => !_running && _left == Duration.zero;
  bool get _allTurnsDone => _turn >= _totalTurns - 1 && _turnFinished;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTurn() {
    _timer?.cancel();
    setState(() => _left = _turnLength);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // The old version navigated from inside the tick and only checked
      // `mounted` after calling setState, so a backgrounded room could push a
      // route onto a dead context.
      if (!mounted) {
        timer.cancel();
        return;
      }
      final next = _left - const Duration(seconds: 1);
      if (next <= Duration.zero) {
        timer.cancel();
        setState(() => _left = Duration.zero);
        // Two people talking to each other are not watching the screen.
        HapticFeedback.mediumImpact();
        SystemSound.play(SystemSoundType.alert);
      } else {
        setState(() => _left = next);
      }
    });
  }

  /// The merge is the most expensive thing the app produces and used to be
  /// thrown away when the room closed. The neutralised summary is saved; the
  /// two raw sides never are.
  void _saveToJournal(S s) {
    final m = ref.read(_mergeProvider(widget.sides)).asData?.value;
    if (m == null) return;
    ref.read(journalProvider.notifier).add(
          kind: JournalKind.repair,
          title: m.title,
          body: '${s.youBothAgree}: ${m.agreed}\n\n${s.storiesSplit}: ${m.split}',
          ask: m.firstTurn,
        );
  }

  void _nextTurn() {
    setState(() {
      _turn = (_turn + 1).clamp(0, _totalTurns - 1);
      _left = _turnLength;
    });
  }

  static String _mmss(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final s = S.of(context, ref);
    final app = ref.watch(appStateProvider);
    final merge = ref.watch(_mergeProvider(widget.sides));
    final t = Theme.of(context).textTheme;
    final surface = context.surface;
    final dark = context.isDark;
    final me = app.userOrDefault;
    final p = app.partnerOrDefault;

    // The partner speaks first: the person who opened the room has already had
    // their say, in writing.
    final speakers = [(p, me), (me, p), (p, me), (me, p)];
    final (speaker, listener) = speakers[_turn];

    return StageTheme(
      stage: ResolutionStage.working,
      child: Scaffold(
        body: Atmosphere(
          background: Backgrounds.working,
          child: Column(
            children: [
              GlassTopBar(
                title: s.repairRoom,
                onBack: () => context.pop(),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.timer_outlined, size: 18, color: surface.ink2),
                    const SizedBox(width: 6),
                    Text(_mmss(_left),
                        style: t.labelLarge?.copyWith(
                          fontSize: 13,
                          color: _running ? context.stage.accent : surface.ink2,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        )),
                  ],
                ),
              ),
              Expanded(
                child: merge.when(
                  loading: () => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                            color: context.stage.accent, strokeWidth: 2),
                        const SizedBox(height: 16),
                        Text(s.repairMerging,
                            style: t.bodyMedium?.copyWith(color: surface.ink2)),
                      ],
                    ),
                  ),
                  error: (e, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            e is CounsellorException
                                ? s.needBothSides
                                : s.repairMergeFailed,
                            textAlign: TextAlign.center,
                            style: t.bodyLarge,
                          ),
                          const SizedBox(height: 20),
                          GlassButton(
                            label: s.retry,
                            expand: false,
                            onPressed: () =>
                                ref.invalidate(_mergeProvider(widget.sides)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  data: (m) => ListView(
                    padding: const EdgeInsets.fromLTRB(24, 6, 24, 40),
                    children: [
                      Eyebrow(s.bothSidesIn),
                      const SizedBox(height: 6),
                      Text(m.title,
                          style: t.headlineMedium?.copyWith(fontSize: 26)),
                      const SizedBox(height: 16),
                      TintPanel(
                        label: s.youBothAgree,
                        color: dark ? Palette.sageDark : Palette.sage,
                        child: Text(m.agreed),
                      ),
                      const SizedBox(height: 10),
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: TintPanel(
                                label: s.heardLabel(me),
                                color: surface.ink2,
                                // The engine returns the neutralised phrase
                                // itself now; the screen used to strip an
                                // English prefix with replaceFirst, which
                                // silently did nothing in Hindi.
                                child: Text(m.sideA),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TintPanel(
                                label: s.saidLabel(p),
                                color: surface.ink2,
                                child: Text(m.sideB),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      TintPanel(
                          label: s.storiesSplit,
                          color: surface.gold,
                          child: Text(m.split)),
                      const SizedBox(height: 16),
                      GlassPanel(
                        strong: true,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Eyebrow(s.turnHeader(
                                _turn + 1, _totalTurns, speaker, listener)),
                            const SizedBox(height: 8),
                            Text(
                              _turn == 0
                                  ? m.firstTurn
                                  : s.turnInstruction(listener),
                              style: t.bodyMedium,
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
                              label: switch ((
                                _running,
                                _turnFinished,
                                _allTurnsDone
                              )) {
                                (true, _, _) => s.turnRunning,
                                (_, true, true) => s.finishRepair,
                                (_, true, false) => s.continueLabel,
                                _ => s.startTurn,
                              },
                              onPressed: switch ((
                                _running,
                                _turnFinished,
                                _allTurnsDone
                              )) {
                                (true, _, _) => null,
                                (_, true, true) => () {
                                    _saveToJournal(s);
                                    context.pushReplacement(Routes.repairClose);
                                  },
                                (_, true, false) => _nextTurn,
                                _ => _startTurn,
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 4,
                            child: GlassButton(
                              label: s.coolDown,
                              primary: false,
                              icon: Icons.timer_outlined,
                              onPressed: () =>
                                  context.push(Routes.repairCoolDown),
                            ),
                          ),
                        ],
                      ),
                      // A shortcut past the whole feature does not belong in a
                      // build a beta couple is holding.
                      if (kDebugMode) ...[
                        const SizedBox(height: 12),
                        Center(
                          child: TextButton(
                            onPressed: () =>
                                context.pushReplacement(Routes.repairClose),
                            child: Text('Skip to closing (debug)',
                                style:
                                    t.bodySmall?.copyWith(color: surface.ink2)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CoolDownScreen extends ConsumerStatefulWidget {
  const CoolDownScreen({super.key});

  @override
  ConsumerState<CoolDownScreen> createState() => _CoolDownScreenState();
}

class _CoolDownScreenState extends ConsumerState<CoolDownScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath =
      AnimationController(vsync: this, duration: const Duration(seconds: 8));
  Duration _left = const Duration(minutes: 20);
  int _preset = 20;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTicking();
  }

  void _restart(Duration length) {
    setState(() {
      _left = length;
      _preset = length.inMinutes;
    });
    _startTicking();
  }

  void _startTicking() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_left <= Duration.zero) {
        // The old timer kept ticking and rebuilding at 00:00 for as long as the
        // screen stayed open.
        timer.cancel();
        setState(() => _left = Duration.zero);
        HapticFeedback.mediumImpact();
        return;
      }
      setState(() => _left -= const Duration(seconds: 1));
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Honour "reduce motion": an 8-second pulsing circle is exactly the kind of
    // ambient animation that setting exists for.
    if (context.reduceMotion) {
      _breath.stop();
      _breath.value = 0.5;
    } else if (!_breath.isAnimating) {
      _breath.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context, ref);
    final t = Theme.of(context).textTheme;
    final done = _left == Duration.zero;
    final mm = _left.inMinutes.toString().padLeft(2, '0');
    final ss = (_left.inSeconds % 60).toString().padLeft(2, '0');

    return StageTheme(
      stage: ResolutionStage.calm,
      child: Scaffold(
        body: Atmosphere(
          background: Backgrounds.calm,
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
                child: ConstrainedBox(
                  constraints:
                      BoxConstraints(minHeight: constraints.maxHeight - 48),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      AnimatedBuilder(
                        animation: _breath,
                        builder: (context, _) {
                          final v = Curves.easeInOut.transform(_breath.value);
                          return Container(
                            width: 160 + 80 * v,
                            height: 160 + 80 * v,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: context.stage.accent
                                  .withValues(alpha: 0.10 + 0.10 * v),
                              border: Border.all(
                                  color: context.stage.accent
                                      .withValues(alpha: 0.4)),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              v < 0.5 ? s.breatheIn : s.breatheOut,
                              style: t.labelLarge
                                  ?.copyWith(color: context.stage.accent),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      Text(
                        '$mm:$ss',
                        style: t.displayLarge?.copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        done ? s.coolDownDone : s.coolDownBody,
                        textAlign: TextAlign.center,
                        style:
                            t.bodyMedium?.copyWith(color: context.surface.ink2),
                      ),
                      const SizedBox(height: 16),
                      // Twenty minutes is the evidence-based default, not a
                      // sentence. Shorter presets for when that is what the
                      // room can afford.
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          for (final m in const [5, 10, 20])
                            GlassChip(
                              label: s.coolDownPreset(m),
                              active: _preset == m,
                              selectable: true,
                              onTap: () => _restart(Duration(minutes: m)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      GlassButton(
                        label: s.backToRoom,
                        primary: done,
                        onPressed: () => context.pop(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RepairCloseScreen extends ConsumerWidget {
  const RepairCloseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context, ref);
    final app = ref.watch(appStateProvider);
    final t = Theme.of(context).textTheme;
    final surface = context.surface;

    return StageTheme(
      stage: ResolutionStage.calm,
      child: Scaffold(
        body: Atmosphere(
          background: Backgrounds.calm,
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
                child: ConstrainedBox(
                  constraints:
                      BoxConstraints(minHeight: constraints.maxHeight - 48),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: context.stage.accentSoft,
                          border: Border.all(
                              color:
                                  context.stage.accent.withValues(alpha: 0.35)),
                        ),
                        child: Icon(Icons.check_rounded,
                            color: context.stage.accent, size: 26),
                      ),
                      const SizedBox(height: 18),
                      Eyebrow(s.repaired),
                      const SizedBox(height: 10),
                      Text(s.repairedTitle,
                          style: t.headlineMedium?.copyWith(fontSize: 30)),
                      const SizedBox(height: 12),
                      Text(s.repairedBody,
                          style: t.bodyLarge?.copyWith(color: surface.ink2)),
                      const SizedBox(height: 18),
                      GlassPanel(
                        strong: true,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Eyebrow('${s.whyWeStarted} · ${s.inYourWords}'),
                            const SizedBox(height: 8),
                            Text(
                              app.originStory.isEmpty
                                  ? s.originNotWritten
                                  : '“${app.originStory}”',
                              style: t.bodyLarge?.copyWith(
                                  fontSize: 18, fontStyle: FontStyle.italic),
                            ),
                            if (app.originStory.isEmpty) ...[
                              const SizedBox(height: 12),
                              GlassChip(
                                label: s.editOriginStory,
                                icon: Icons.edit_outlined,
                                onTap: () => context.push(Routes.editOrigin),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Icon(Icons.auto_stories_outlined,
                              size: 16, color: surface.ink2),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(s.repairSavedToJournal,
                                style: t.bodySmall?.copyWith(
                                    fontSize: 13, color: surface.ink2)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      GlassButton(
                          label: s.closeRoom,
                          onPressed: () => context.go(Routes.today)),
                      const SizedBox(height: 10),
                      GlassButton(
                        label: s.planSmallThing,
                        primary: false,
                        onPressed: () => context.go(Routes.us),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
