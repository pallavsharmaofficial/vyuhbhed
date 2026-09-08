import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_state.dart';
import '../../core/strings.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.dart';
import '../../ui/atmosphere.dart';
import '../../ui/glass.dart';
import 'coach_engine.dart';
import 'coach_strings.dart';
import 'profile.dart';

/// Paste resume (+ optional job description) → verdict, fixes, rewritten
/// bullets, missing keywords. One call.
class ResumeScreen extends ConsumerStatefulWidget {
  const ResumeScreen({super.key});

  @override
  ConsumerState<ResumeScreen> createState() => _ResumeScreenState();
}

class _ResumeScreenState extends ConsumerState<ResumeScreen> {
  final _resume = TextEditingController();
  final _jd = TextEditingController();
  ResumeRequest? _request;

  static const _minChars = 300;

  @override
  void dispose() {
    _resume.dispose();
    _jd.dispose();
    super.dispose();
  }

  void _review() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _request = ResumeRequest(
          resume: _resume.text.trim(),
          jobDescription: _jd.text.trim(),
          profile: ref.read(profileProvider),
          hindi: ref.read(appStateProvider).isHindi,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final t = T.of(context, ref);
    final s = S.of(context, ref);
    final tt = Theme.of(context).textTheme;
    final surface = context.surface;
    final ready = _resume.text.trim().length >= _minChars;
    final req = _request;

    return StageTheme(
      stage: ResolutionStage.working,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: Atmosphere(
          background: Backgrounds.today,
          child: Column(children: [
            GlassTopBar(title: t.resumeTitle, onBack: () => context.pop()),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 6, 24, 40),
                children: [
                  GlassPanel(
                    strong: true,
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: TextField(
                      controller: _resume,
                      minLines: 6,
                      maxLines: 14,
                      onChanged: (_) => setState(() {}),
                      style: tt.bodyMedium,
                      decoration: InputDecoration.collapsed(
                          hintText: t.resumeHint,
                          hintStyle: TextStyle(color: surface.ink2)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  GlassPanel(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: TextField(
                      controller: _jd,
                      minLines: 3,
                      maxLines: 8,
                      style: tt.bodyMedium,
                      decoration: InputDecoration.collapsed(
                          hintText: t.jdHint,
                          hintStyle: TextStyle(color: surface.ink2)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_resume.text.isNotEmpty && !ready)
                    Text(t.resumeTooShort,
                        style: tt.bodySmall?.copyWith(color: surface.ink2)),
                  const SizedBox(height: 10),
                  GlassButton(
                      label: t.reviewResume,
                      icon: Icons.auto_awesome_rounded,
                      onPressed: ready ? _review : null),
                  if (req != null) ...[
                    const SizedBox(height: 18),
                    ref.watch(resumeReviewProvider(req)).when(
                          loading: () => Row(children: [
                            SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: context.stage.accent)),
                            const SizedBox(width: 12),
                            Text(t.reviewing, style: tt.bodyMedium),
                          ]),
                          error: (_, __) => Row(children: [
                            Expanded(
                                child: Text(t.coachFailed,
                                    style: tt.bodySmall?.copyWith(
                                        fontSize: 14, color: surface.ink2))),
                            GlassChip(
                                label: s.retry,
                                icon: Icons.refresh_rounded,
                                onTap: () =>
                                    ref.invalidate(resumeReviewProvider(req))),
                          ]),
                          data: (r) => _Review(r: r, t: t, s: s),
                        ),
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

class _Review extends StatelessWidget {
  const _Review({required this.r, required this.t, required this.s});
  final ResumeReview r;
  final T t;
  final S s;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final surface = context.surface;
    final sage = Theme.of(context).colorScheme.secondary;
    Widget bullets(List<String> items) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final x in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('•  ', style: tt.bodyMedium),
                      Expanded(child: Text(x, style: tt.bodyMedium)),
                    ]),
              ),
          ],
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (r.verdict.isNotEmpty)
          TintPanel(
              label: t.verdict,
              color: context.stage.accent,
              child: Text(r.verdict)),
        if (r.fixes.isNotEmpty) ...[
          const SizedBox(height: 10),
          GlassPanel(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Eyebrow(t.fixes),
                const SizedBox(height: 8),
                bullets(r.fixes)
              ])),
        ],
        if (r.rewrittenBullets.isNotEmpty) ...[
          const SizedBox(height: 10),
          GlassPanel(
            strong: true,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Eyebrow(t.rewritten, color: sage),
              const SizedBox(height: 8),
              bullets(r.rewrittenBullets),
              const SizedBox(height: 6),
              GlassChip(
                label: s.copy,
                icon: Icons.copy_rounded,
                onTap: () async {
                  await Clipboard.setData(ClipboardData(
                      text: r.rewrittenBullets.map((b) => '• $b').join('\n')));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(SnackBar(content: Text(s.copied)));
                },
              ),
            ]),
          ),
        ],
        if (r.missingKeywords.isNotEmpty) ...[
          const SizedBox(height: 10),
          Eyebrow(t.missingKeywords, color: surface.ink2),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final k in r.missingKeywords) GlassChip(label: k)
          ]),
        ],
      ],
    );
  }
}
