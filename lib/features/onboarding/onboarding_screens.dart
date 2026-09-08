import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/app_state.dart';
import '../../core/strings.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.dart';
import '../../ui/atmosphere.dart';
import '../../ui/glass.dart';

/// Total onboarding steps: welcome, names, origin story, model download.
const _totalSteps = 4;

/// Step 1 — intro slides + language.
///
/// Four swipeable slides explain what Saath is; the two start buttons stay
/// visible under every slide, so reading them is optional and starting never
/// needs a scroll. Slide 1 is the tagline the app has always opened with.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  final _pages = PageController();
  int _page = 0;

  static const _slideCount = 4;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    if (context.reduceMotion) {
      _pages.jumpToPage(page);
    } else {
      _pages.animateToPage(page,
          duration: const Duration(milliseconds: 360),
          curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context, ref);
    final t = Theme.of(context).textTheme;
    final surface = context.surface;
    final sage = Theme.of(context).colorScheme.secondary;

    Future<void> start(AppLanguage language) async {
      await ref.read(appStateProvider.notifier).setLanguage(language);
      if (context.mounted) context.push(Routes.onboardingNames);
    }

    final slides = <Widget>[
      _IntroSlide(
        icon: Icons.favorite_border_rounded,
        title: s.tagline,
        body: s.taglineSub,
        bodyItalic: true,
      ),
      _IntroSlide(
        icon: Icons.phonelink_lock_outlined,
        title: s.introPrivateTitle,
        body: s.introPrivateBody,
      ),
      _IntroSlide(
        icon: Icons.auto_awesome_outlined,
        title: s.introToolsTitle,
        lines: [
          (Icons.psychology_alt_outlined, s.introUntangle),
          (Icons.swap_horiz_rounded, s.introRepair),
          (Icons.show_chart_rounded, s.introPulse),
        ],
      ),
      _IntroSlide(
        icon: Icons.history_edu_outlined,
        title: s.introOriginTitle,
        body: s.introOriginBody,
      ),
    ];

    return StageTheme(
      stage: ResolutionStage.aware,
      child: Scaffold(
        body: Atmosphere(
          background: Backgrounds.welcome,
          veilOpacity: context.isDark ? 0.35 : 0.30,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.end,
                    spacing: 10,
                    runSpacing: 4,
                    children: [
                      Text(s.appName, style: t.headlineSmall),
                      Text(s.appNameDevanagari,
                          style: t.bodyLarge?.copyWith(color: surface.ink2)),
                    ],
                  ),
                  Expanded(
                    child: Semantics(
                      label: s.introSlide(_page + 1, _slideCount),
                      child: PageView(
                        controller: _pages,
                        onPageChanged: (i) => setState(() => _page = i),
                        children: slides,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _Dots(count: _slideCount, index: _page, onTap: _goTo),
                      if (_page < _slideCount - 1)
                        TextButton(
                          onPressed: () => _goTo(_page + 1),
                          child: Text(s.introNext,
                              style: t.bodySmall?.copyWith(
                                  fontSize: 14, color: surface.ink2)),
                        )
                      else
                        const SizedBox(height: 40),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GlassButton(
                    label: s.startEnglish,
                    onPressed: () => start(AppLanguage.en),
                  ),
                  const SizedBox(height: 10),
                  GlassButton(
                    label: s.startHindi,
                    primary: false,
                    onPressed: () => start(AppLanguage.hi),
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      children: [
                        Icon(Icons.lock_outline_rounded, size: 14, color: sage),
                        Text(
                          s.freePrivateOffline,
                          style: t.labelSmall?.copyWith(
                              letterSpacing: 0, fontSize: 12, color: sage),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One intro slide: an icon in a glass disc, a heading, and either a body
/// paragraph or a short list of (icon, line) pairs.
class _IntroSlide extends StatelessWidget {
  const _IntroSlide({
    required this.icon,
    required this.title,
    this.body,
    this.bodyItalic = false,
    this.lines = const [],
  });

  final IconData icon;
  final String title;
  final String? body;
  final bool bodyItalic;
  final List<(IconData, String)> lines;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final surface = context.surface;
    final accent = context.stage.accent;
    // Bottom-aligned when there is room, scrollable when there is not (small
    // phones, large fonts). A bare scroll view would pin everything to the top.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Frost(
                color: surface.glassSoft,
                borderRadius: BorderRadius.circular(28),
                border: BoxSide(surface.glassBorder),
                padding: const EdgeInsets.all(14),
                child: Icon(icon, color: accent, size: 28),
              ),
              const SizedBox(height: 18),
              Semantics(
                header: true,
                child: Text(title, style: t.displayLarge),
              ),
              const SizedBox(height: 14),
              if (body != null)
                Text(
                  body!,
                  style: t.bodyLarge?.copyWith(
                    color: surface.ink2,
                    fontStyle: bodyItalic ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              for (final (i, line) in lines) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Icon(i, size: 18, color: accent),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(line,
                          style: t.bodyLarge?.copyWith(color: surface.ink2)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index, required this.onTap});

  final int count;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    final accent = context.stage.accent;
    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap(i),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 3, vertical: 12),
                child: AnimatedContainer(
                  duration: context.reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 240),
                  width: i == index ? 22 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: i == index ? accent : surface.glassBorder,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Step 2 — names + relationship stage.
class NamesScreen extends ConsumerStatefulWidget {
  const NamesScreen({super.key});

  @override
  ConsumerState<NamesScreen> createState() => _NamesScreenState();
}

class _NamesScreenState extends ConsumerState<NamesScreen> {
  final _me = TextEditingController();
  final _partner = TextEditingController();
  RelationshipStage? _stage;

  @override
  void initState() {
    super.initState();
    // Coming back to this step should show what was already entered.
    final app = ref.read(appStateProvider);
    _me.text = app.userName;
    _partner.text = app.partnerName;
    _stage = app.relationshipStage;
  }

  @override
  void dispose() {
    _me.dispose();
    _partner.dispose();
    super.dispose();
  }

  bool get _ready =>
      _me.text.trim().isNotEmpty &&
      _partner.text.trim().isNotEmpty &&
      _stage != null;

  Future<void> _continue() async {
    final n = ref.read(appStateProvider.notifier);
    await n.setNames(user: _me.text, partner: _partner.text);
    await n.setRelationshipStage(_stage!);
    if (mounted) context.push(Routes.onboardingOrigin);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context, ref);
    final t = Theme.of(context).textTheme;

    return StageTheme(
      stage: ResolutionStage.working,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: Atmosphere(
          background: Backgrounds.today,
          child: Column(
            children: [
              GlassTopBar(
                title: s.stepOf(2, _totalSteps),
                onBack: () => context.pop(),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  children: [
                    Text(s.namesTitle, style: t.headlineMedium),
                    const SizedBox(height: 20),
                    GlassPanel(
                      strong: true,
                      child: Column(
                        children: [
                          _Field(
                            controller: _me,
                            label: s.yourName,
                            textInputAction: TextInputAction.next,
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 12),
                          _Field(
                            controller: _partner,
                            label: s.partnerName,
                            textInputAction: TextInputAction.done,
                            onChanged: (_) => setState(() {}),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Eyebrow(s.whereAreYou),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final stage in RelationshipStage.values)
                          GlassChip(
                            label: s.stageLabel(stage),
                            active: _stage == stage,
                            selectable: true,
                            onTap: () => setState(() => _stage = stage),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                    24, 0, 24, MediaQuery.paddingOf(context).bottom + 20),
                child: GlassButton(
                  label: s.continueLabel,
                  onPressed: _ready ? _continue : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.onChanged,
    this.textInputAction,
  });

  final TextEditingController controller;
  final String label;
  final ValueChanged<String> onChanged;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color),
        );
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: textInputAction,
      textCapitalization: TextCapitalization.words,
      style: Theme.of(context).textTheme.bodyLarge,
      // Names are not passwords, but they are the two most identifying strings
      // in the app; keep them out of the keyboard's learned dictionary.
      autocorrect: false,
      enableSuggestions: false,
      maxLength: 40,
      buildCounter:
          (_, {required currentLength, required isFocused, maxLength}) => null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: surface.ink2),
        filled: true,
        fillColor: surface.glassSoft,
        border: border(surface.glassBorder),
        enabledBorder: border(surface.glassBorder),
        focusedBorder: border(context.stage.accent),
      ),
    );
  }
}

/// Step 3 — Why We Started. The anchor for everything after.
class OriginStoryScreen extends ConsumerStatefulWidget {
  const OriginStoryScreen({super.key});

  @override
  ConsumerState<OriginStoryScreen> createState() => _OriginStoryScreenState();
}

class _OriginStoryScreenState extends ConsumerState<OriginStoryScreen> {
  Future<void> _finish() async {
    // Onboarding is not complete yet — the model download is step 4, and it
    // is the one step the user is allowed to walk past.
    // `context` here is State.context, which is what `mounted` actually
    // guards — the build-method parameter is a different one.
    if (mounted) context.push(Routes.onboardingModel);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context, ref);
    return _OriginEditor(
      title: s.stepOf(3, _totalSteps),
      onBack: () => context.pop(),
      // Someone who cannot put it into words at 11pm should not be locked out
      // of the app that might help them at 11pm. The origin story stays the
      // anchor; it just stops being a gate.
      showSkip: true,
      onSaved: _finish,
    );
  }
}

/// Settings → "Why we started — edit". Same editor, no skip, pops when done.
class EditOriginScreen extends ConsumerWidget {
  const EditOriginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context, ref);
    return _OriginEditor(
      title: s.whyWeStarted,
      onBack: () => context.pop(),
      showSkip: false,
      onSaved: () async {
        if (context.mounted) context.pop();
      },
    );
  }
}

class _OriginEditor extends ConsumerStatefulWidget {
  const _OriginEditor({
    required this.title,
    required this.onBack,
    required this.showSkip,
    required this.onSaved,
  });

  final String title;
  final VoidCallback onBack;
  final bool showSkip;
  final Future<void> Function() onSaved;

  @override
  ConsumerState<_OriginEditor> createState() => _OriginEditorState();
}

class _OriginEditorState extends ConsumerState<_OriginEditor> {
  late final TextEditingController _c;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: ref.read(appStateProvider).originStory);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  int get _words {
    final t = _c.text.trim();
    return t.isEmpty ? 0 : t.split(RegExp(r'\s+')).length;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context, ref);
    final app = ref.watch(appStateProvider);
    final t = Theme.of(context).textTheme;
    final surface = context.surface;

    return StageTheme(
      stage: ResolutionStage.calm,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: Atmosphere(
          background: Backgrounds.origin,
          child: Column(
            children: [
              GlassTopBar(title: widget.title, onBack: widget.onBack),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Eyebrow(s.whyWeStarted),
                    const SizedBox(height: 12),
                    Text(s.whyChoose(app.partnerOrDefault),
                        style: t.headlineMedium),
                    const SizedBox(height: 12),
                    Text(s.originHint,
                        style: t.bodyMedium?.copyWith(color: surface.ink2)),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
                  child: GlassPanel(
                    strong: true,
                    child: Column(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _c,
                            maxLines: null,
                            expands: true,
                            textAlignVertical: TextAlignVertical.top,
                            onChanged: (_) => setState(() {}),
                            textCapitalization: TextCapitalization.sentences,
                            style: t.bodyLarge?.copyWith(
                                fontSize: 18, fontStyle: FontStyle.italic),
                            decoration: InputDecoration.collapsed(
                              hintText: s.originPlaceholder,
                              hintStyle: TextStyle(color: surface.ink2),
                            ),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                s.typedWords(_words),
                                style: t.labelSmall?.copyWith(
                                    letterSpacing: 0,
                                    fontSize: 12,
                                    color: surface.ink2),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                    24, 18, 24, MediaQuery.paddingOf(context).bottom + 20),
                child: Column(
                  children: [
                    GlassButton(
                      label: s.keepThis,
                      onPressed: _words == 0
                          ? null
                          : () async {
                              await ref
                                  .read(appStateProvider.notifier)
                                  .setOriginStory(_c.text);
                              await widget.onSaved();
                            },
                    ),
                    if (widget.showSkip) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: widget.onSaved,
                        child: Text(
                          s.originLater,
                          style: t.bodySmall
                              ?.copyWith(fontSize: 14, color: surface.ink2),
                        ),
                      ),
                    ] else
                      const SizedBox(height: 10),
                    Text(
                      s.originFooter,
                      textAlign: TextAlign.center,
                      style: t.bodySmall
                          ?.copyWith(fontSize: 13, color: surface.ink2),
                    ),
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
