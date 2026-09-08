import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_state.dart';
import '../../core/helplines.dart';
import '../../core/strings.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.dart';
import '../../ui/atmosphere.dart';
import '../../ui/glass.dart';

/// Shown instead of a reply when the safety classifier fires, and reachable
/// any time from Settings.
///
/// Always the dark, quiet screen regardless of theme mode: this is the one
/// place the app deliberately stops looking like the rest of itself.
class SafetyScreen extends ConsumerWidget {
  const SafetyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context, ref);
    return Theme(
      data: buildTheme(Brightness.dark),
      child: StageTheme(
        stage: ResolutionStage.calm,
        child: Builder(builder: (context) {
          final t = Theme.of(context).textTheme;
          final surface = context.surface;
          return Scaffold(
            body: Atmosphere(
              background: Backgrounds.welcome,
              veilOpacity: 0.72,
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
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Palette.sageDark.withValues(alpha: 0.16),
                              border: Border.all(
                                  color:
                                      Palette.sageDark.withValues(alpha: 0.35)),
                            ),
                            child: const Icon(Icons.shield_outlined,
                                color: Palette.sageDark, size: 26),
                          ),
                          const SizedBox(height: 18),
                          Text(s.safetyTitle,
                              style: t.headlineMedium?.copyWith(
                                  fontSize: 30, color: Palette.inkDark)),
                          const SizedBox(height: 14),
                          Text(s.safetyBody1,
                              style:
                                  t.bodyLarge?.copyWith(color: surface.ink2)),
                          const SizedBox(height: 10),
                          Text(s.safetyBody2,
                              style:
                                  t.bodyLarge?.copyWith(color: surface.ink2)),
                          const SizedBox(height: 18),
                          for (final line in Helplines.all) ...[
                            _HelplineRow(line: line, s: s),
                            const SizedBox(height: 8),
                          ],
                          const SizedBox(height: 20),
                          GlassButton(
                            label: s.imOkayKeepTalking,
                            primary: false,
                            onPressed: () {
                              // Was persisted but never written from anywhere.
                              ref
                                  .read(appStateProvider.notifier)
                                  .markSafetyNoticeSeen();
                              if (context.canPop()) {
                                context.pop();
                              } else {
                                context.go('/');
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: Text(
                              s.safetyAlwaysHere,
                              textAlign: TextAlign.center,
                              style: t.bodySmall
                                  ?.copyWith(fontSize: 13, color: surface.ink2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// A helpline the user can actually reach.
///
/// This row used to draw a phone icon and do nothing at all: the single most
/// important control in the app was decorative. Tapping now opens the dialler
/// with the number filled in — it never places the call, because the person
/// reading this may be standing next to someone.
class _HelplineRow extends StatelessWidget {
  const _HelplineRow({required this.line, required this.s});

  final Helpline line;
  final S s;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final hindi = s.isHindi;

    return Semantics(
      button: true,
      label: '${s.callLabel} ${line.displayName(hindi)}, ${line.number}',
      excludeSemantics: true,
      child: GlassPanel(
        strong: true,
        radius: 16,
        padding: EdgeInsets.zero,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () async {
              final ok = await dialHelpline(line.number);
              if (ok || !context.mounted) return;
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(s.dialFailed)));
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(line.displayName(hindi),
                            style: t.labelLarge?.copyWith(
                                fontSize: 15, color: Palette.inkDark)),
                        const SizedBox(height: 2),
                        Text(
                          '${line.prettyNumber} · ${line.displayHours(hindi)}',
                          style: t.bodySmall?.copyWith(
                              fontSize: 13, color: context.surface.ink2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.call_outlined,
                      color: Palette.sageDark, size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
