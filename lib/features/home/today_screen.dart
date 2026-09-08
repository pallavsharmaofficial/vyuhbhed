import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/router.dart';
import '../../app/web_frame.dart';
import '../../core/app_state.dart';
import '../../core/journal.dart';
import '../../core/strings.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.dart';
import '../../ui/atmosphere.dart';
import '../../ui/glass.dart';
import '../counsellor/engine.dart';
import '../counsellor/say_it_kinder_sheet.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context, ref);
    final app = ref.watch(appStateProvider);
    final entries = ref.watch(journalProvider);
    final t = Theme.of(context).textTheme;
    final surface = context.surface;
    final dark = context.isDark;

    return StageTheme(
      stage: ResolutionStage.working,
      child: Atmosphere(
        background: Backgrounds.today,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
              24, MediaQuery.paddingOf(context).top + 12, 24, 140),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Eyebrow(
                        // The date reads in the user's language, not always en_US.
                        DateFormat('EEEE, d MMM', app.language.code)
                            .format(DateTime.now()),
                        color: surface.ink2,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        s.greeting(
                            app.userName.isEmpty ? s.friend : app.userName),
                        style: t.headlineMedium?.copyWith(fontSize: 26),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => context.push(Routes.journal),
                  tooltip: s.openJournal,
                  icon: Icon(Icons.auto_stories_outlined, color: surface.ink2),
                ),
                IconButton(
                  onPressed: () => context.push(Routes.settings),
                  tooltip: s.openSettings,
                  icon: Icon(Icons.tune_rounded, color: surface.ink2),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (app.pulses.isEmpty && entries.isEmpty) ...[
              // A brand-new user sees a full screen of tools and no hint of
              // where to begin. Disappears after the first check-in or entry.
              GlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Eyebrow(s.firstDayTitle, color: context.stage.accent),
                    const SizedBox(height: 6),
                    Text(s.firstDayBody,
                        style: t.bodyMedium?.copyWith(color: surface.ink2)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            const _CheckIn(),
            const SizedBox(height: 12),
            _TalkCard(s: s, partner: app.partnerOrDefault),
            const SizedBox(height: 12),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: TintPanel(
                      label: s.fromPartner(app.partnerOrDefault),
                      color: dark ? Palette.roseDark : Palette.rose,
                      child: Text(s.notPairedYet),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Semantics(
                      button: true,
                      label: s.openWeeklyPulse,
                      child: InkWell(
                        onTap: () => context.push(Routes.weeklyPulse),
                        borderRadius:
                            BorderRadius.circular(context.stage.radius),
                        child: TintPanel(
                          label: s.thisWeek,
                          color: surface.gold,
                          // Counted from stored check-ins. This card used to be
                          // hardcoded to "0 of 7" / "1 of 7" no matter what the
                          // user had actually done all week — and it led
                          // nowhere.
                          child: Text(
                            '${s.checkinsThisWeek(app.checkInsThisWeek)}\n${s.openWeeklyPulse} →',
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (entries.isNotEmpty) ...[
              const SizedBox(height: 12),
              GlassButton(
                label: '${s.openJournal} · ${entries.length}',
                primary: false,
                icon: Icons.auto_stories_outlined,
                onPressed: () => context.push(Routes.journal),
              ),
            ],
          ],
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
  // Built eagerly, not `late`. A lazily-initialised controller that reads from
  // `ref` is forced into existence by dispose() if the branch that uses it
  // never rendered — and `ref` is already gone by then.
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
    final s = S.of(context, ref);
    final app = ref.watch(appStateProvider);
    final t = Theme.of(context).textTheme;
    final surface = context.surface;
    final st = context.stage;
    final sage = Theme.of(context).colorScheme.secondary;
    final score = app.todayConnection;

    // The controller was seeded once in initState and never followed state:
    // after Settings → Delete everything it kept showing yesterday's word.
    ref.listen(appStateProvider.select((a) => a.todayWord), (_, next) {
      if (next != _word.text) _word.text = next;
    });

    return GlassPanel(
      strong: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow(s.checkinLabel, color: sage),
          const SizedBox(height: 8),
          Text(s.checkinQ, style: t.titleMedium),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 1; i <= 5; i++) ...[
                Expanded(
                  child: Semantics(
                    inMutuallyExclusiveGroup: true,
                    selected: score == i,
                    button: true,
                    label: '$i',
                    // "3 of 5, close" reads far better than a bare "3".
                    value: i == 1
                        ? s.connectionLow
                        : (i == 5 ? s.connectionHigh : null),
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
                            width: score == i ? 1.5 : 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$i',
                          style: t.labelLarge?.copyWith(
                            fontSize: 15,
                            color: score == i ? st.accent : surface.ink2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (i < 5) const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(s.connectionLow,
                  style:
                      t.bodySmall?.copyWith(fontSize: 12, color: surface.ink2)),
              Text(s.connectionHigh,
                  style:
                      t.bodySmall?.copyWith(fontSize: 12, color: surface.ink2)),
            ],
          ),
          const SizedBox(height: 12),
          // The "one word" prompt used to be a label with nothing to type into.
          if (score == null)
            Text(s.oneWord, style: t.bodySmall?.copyWith(color: surface.ink2))
          else
            TextField(
              controller: _word,
              textCapitalization: TextCapitalization.none,
              textInputAction: TextInputAction.done,
              maxLength: 24,
              buildCounter: (_,
                      {required currentLength,
                      required isFocused,
                      maxLength}) =>
                  null,
              style: t.bodyMedium,
              onSubmitted: (v) =>
                  ref.read(appStateProvider.notifier).setTodayWord(v),
              onTapOutside: (_) {
                FocusManager.instance.primaryFocus?.unfocus();
                ref.read(appStateProvider.notifier).setTodayWord(_word.text);
              },
              decoration: InputDecoration(
                isDense: true,
                labelText: s.oneWord,
                hintText: s.oneWordHint,
                labelStyle: TextStyle(color: surface.ink2),
                hintStyle: TextStyle(color: surface.ink2),
                filled: true,
                fillColor: surface.glassSoft,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: surface.glassBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: surface.glassBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: st.accent),
                ),
              ),
            ),
          if (score != null) ...[
            const SizedBox(height: 8),
            Text(s.savedForToday,
                style: t.bodySmall?.copyWith(fontSize: 13, color: sage)),
          ],
        ],
      ),
    );
  }
}

class _TalkCard extends ConsumerWidget {
  const _TalkCard({required this.s, required this.partner});

  final S s;
  final String partner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final r = BorderRadius.circular(context.stage.radius);
    // Nothing on this screen used to say the counsellor was still the
    // scripted preview; people found out three messages in.
    final preview = ref.watch(counsellorEngineProvider).isPreview;

    // Deliberately the one dark surface on a light screen: the counsellor's
    // voice should not look like another card.
    return Frost(
      borderRadius: r,
      color: Palette.bgDark.withValues(alpha: context.isDark ? 0.55 : 0.72),
      border: BoxSide(Colors.white.withValues(alpha: 0.18)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.go(Routes.counsellor),
          borderRadius: r,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded,
                        size: 18, color: Palette.roseDark),
                    const SizedBox(width: 8),
                    Flexible(
                        child: Eyebrow(s.talkToSaath, color: Palette.roseDark)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(s.talkPrompt(partner),
                    style: t.bodyLarge?.copyWith(color: Palette.inkDark)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _DarkChip(s.promptSameFight,
                        onTap: () => context.push(Routes.talk,
                            extra: s.promptSameFight)),
                    // Straight to the rewrite sheet rather than into a
                    // conversation: someone with their thumb over Send has
                    // seconds, not minutes.
                    _DarkChip(s.promptRegret,
                        onTap: () => showSayItKinderSheet(context)),
                  ],
                ),
                if (preview && modelSupportedHere) ...[
                  const SizedBox(height: 12),
                  _DarkChip(s.talkPreviewChip,
                      onTap: () => context.push(Routes.model)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DarkChip extends StatelessWidget {
  const _DarkChip(this.label, {required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: Colors.white.withValues(alpha: 0.08),
        shape: StadiumBorder(
            side: BorderSide(color: Colors.white.withValues(alpha: 0.3))),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Center(
                widthFactor: 1,
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        letterSpacing: 0,
                        fontSize: 12,
                        color: Palette.inkDark,
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
