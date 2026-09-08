import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/router.dart';
import '../../core/app_info.dart';
import '../../core/app_lock.dart';
import '../../core/app_state.dart';
import '../../core/couple_space.dart';
import '../../core/helplines.dart';
import '../../core/journal.dart';
import '../../core/strings.dart';
import '../../core/support.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.dart';
import '../../ui/atmosphere.dart';
import '../../ui/glass.dart';
import '../counsellor/chat_controller.dart';
import '../counsellor/engine.dart';
import '../learn/learn_screen.dart';
import '../../app/web_frame.dart';
import '../counsellor/model/model_manager.dart';
import 'export.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context, ref);
    final app = ref.watch(appStateProvider);
    final n = ref.read(appStateProvider.notifier);
    final engine = ref.watch(counsellorEngineProvider);
    final model = ref.watch(modelManagerProvider);
    final lock = ref.watch(appLockProvider);
    final t = Theme.of(context).textTheme;
    final surface = context.surface;

    return StageTheme(
      stage: ResolutionStage.calm,
      child: Scaffold(
        body: Atmosphere(
          background: Backgrounds.today,
          child: Column(
            children: [
              GlassTopBar(title: s.settings, onBack: () => context.pop()),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 6, 24, 40),
                  children: [
                    GlassPanel(
                      strong: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Eyebrow(s.language),
                          const SizedBox(height: 10),
                          Wrap(spacing: 8, runSpacing: 8, children: [
                            for (final l in AppLanguage.values)
                              GlassChip(
                                label: l.label,
                                active: app.language == l,
                                selectable: true,
                                onTap: () => n.setLanguage(l),
                              ),
                          ]),
                          const SizedBox(height: 18),
                          Eyebrow(s.theme),
                          const SizedBox(height: 10),
                          Wrap(spacing: 8, runSpacing: 8, children: [
                            GlassChip(
                                label: s.themeSystem,
                                active: app.themeMode == ThemeMode.system,
                                selectable: true,
                                onTap: () => n.setThemeMode(ThemeMode.system)),
                            GlassChip(
                                label: s.themeLight,
                                active: app.themeMode == ThemeMode.light,
                                selectable: true,
                                onTap: () => n.setThemeMode(ThemeMode.light)),
                            GlassChip(
                                label: s.themeDark,
                                active: app.themeMode == ThemeMode.dark,
                                selectable: true,
                                onTap: () => n.setThemeMode(ThemeMode.dark)),
                          ]),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    GlassPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Eyebrow(s.you),
                          const SizedBox(height: 10),
                          Text(
                            app.originStory.isEmpty
                                ? s.originNotWritten
                                : '“${app.originStory}”',
                            style: t.bodySmall?.copyWith(
                                fontSize: 15,
                                fontStyle: app.originStory.isEmpty
                                    ? FontStyle.normal
                                    : FontStyle.italic),
                          ),
                          const SizedBox(height: 12),
                          Row(children: [
                            Expanded(
                              child: GlassButton(
                                label: s.editOriginStory,
                                primary: false,
                                icon: Icons.edit_outlined,
                                onPressed: () =>
                                    context.push(Routes.editOrigin),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: GlassButton(
                                label: s.journal,
                                primary: false,
                                icon: Icons.auto_stories_outlined,
                                onPressed: () => context.push(Routes.journal),
                              ),
                            ),
                          ]),
                          const SizedBox(height: 10),
                          // The week view was reachable from one tile on Today
                          // and nowhere else.
                          GlassButton(
                            label: s.openWeeklyPulse,
                            primary: false,
                            icon: Icons.show_chart_rounded,
                            onPressed: () => context.push(Routes.weeklyPulse),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    GlassPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Eyebrow(s.privacy),
                          const SizedBox(height: 8),
                          Text(s.privacyBody,
                              style: t.bodySmall?.copyWith(fontSize: 15)),
                          const SizedBox(height: 12),
                          Row(children: [
                            Expanded(
                              child: GlassButton(
                                label: s.exportData,
                                primary: false,
                                // Was `onPressed: () {}` — a button that did
                                // nothing at all, under a promise of "export
                                // all your data".
                                onPressed: () => showExportSheet(context, ref),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: GlassButton(
                                label: s.deleteEverything,
                                primary: false,
                                onPressed: () =>
                                    _confirmDelete(context, ref, s),
                              ),
                            ),
                          ]),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    GlassPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Eyebrow(s.appLock),
                          const SizedBox(height: 8),
                          Text(s.appLockBody,
                              style: t.bodySmall?.copyWith(
                                  fontSize: 15, color: surface.ink2)),
                          const SizedBox(height: 12),
                          if (!lock.available)
                            Text(s.appLockUnavailable,
                                style: t.bodySmall?.copyWith(
                                    fontSize: 14, color: surface.ink2))
                          else
                            Wrap(spacing: 8, runSpacing: 8, children: [
                              GlassChip(
                                label: s.appLockOn,
                                active: lock.enabled,
                                selectable: true,
                                onTap: () => ref
                                    .read(appLockProvider.notifier)
                                    .setEnabled(true),
                              ),
                              GlassChip(
                                label: s.appLockOff,
                                active: !lock.enabled,
                                selectable: true,
                                onTap: () => ref
                                    .read(appLockProvider.notifier)
                                    .setEnabled(false),
                              ),
                            ]),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    GlassPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Eyebrow(s.helplines),
                          const SizedBox(height: 8),
                          Text(s.safetyBody2,
                              style: t.bodySmall?.copyWith(
                                  fontSize: 15, color: surface.ink2)),
                          const SizedBox(height: 12),
                          GlassButton(
                            label: s.helplines,
                            primary: false,
                            icon: Icons.shield_outlined,
                            onPressed: () => context.push(Routes.safety),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    GlassPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Eyebrow(s.counsellorModel),
                          const SizedBox(height: 8),
                          Text(
                            engine.isPreview
                                ? s.modelPreviewBody
                                : AppInfo.modelAttribution,
                            style: t.bodySmall
                                ?.copyWith(fontSize: 15, color: surface.ink2),
                          ),
                          const SizedBox(height: 12),
                          if (modelSupportedHere)
                            GlassButton(
                              label: model.hasModel
                                  ? s.modelRemove
                                  : '${s.modelDownload} · ${model.recommended.sizeLabel}',
                              primary: !model.hasModel,
                              icon: model.hasModel
                                  ? Icons.check_circle_outline_rounded
                                  : Icons.download_rounded,
                              onPressed: () => context.push(Routes.model),
                            ),
                          const SizedBox(height: 12),
                          // The bundled typefaces are SIL OFL, and the Gemma
                          // Terms of Use will require attribution here too.
                          // Reachable beats "shipped in an asset nobody sees".
                          GlassChip(
                            label: s.licences,
                            icon: Icons.description_outlined,
                            onTap: () => showLicensePage(
                              context: context,
                              applicationName: s.appName,
                              applicationVersion: AppInfo.displayVersion,
                              applicationLegalese: AppInfo.modelAttribution,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Deliberately below the model card and above the legal
                    // footer: findable, never in the way, and nowhere near
                    // the helplines.
                    if (SupportLink.isSafe) ...[
                      const SizedBox(height: 12),
                      GlassPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Eyebrow(s.support),
                            const SizedBox(height: 8),
                            Text(
                              s.supportBody,
                              style: t.bodySmall?.copyWith(
                                fontSize: 15,
                                color: surface.ink2,
                              ),
                            ),
                            const SizedBox(height: 12),
                            GlassButton(
                              label: s.supportAction,
                              primary: false,
                              icon: Icons.favorite_border_rounded,
                              onPressed: () async {
                                final ok = await launchUrl(
                                  Uri.parse(SupportLink.url.trim()),
                                  mode: LaunchMode.externalApplication,
                                ).catchError((Object _) => false);
                                if (ok || !context.mounted) return;
                                ScaffoldMessenger.of(context)
                                  ..hideCurrentSnackBar()
                                  ..showSnackBar(
                                    SnackBar(content: Text(s.supportFailed)),
                                  );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Column(
                      children: [
                        Text(
                          s.versionLine(AppInfo.displayVersion),
                          textAlign: TextAlign.center,
                          style: t.bodySmall
                              ?.copyWith(fontSize: 12, color: surface.ink2),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          s.notTherapist,
                          textAlign: TextAlign.center,
                          style: t.bodySmall
                              ?.copyWith(fontSize: 12, color: surface.ink2),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          s.helplinesVerified(
                              DateFormat('d MMM yyyy', app.language.code)
                                  .format(Helplines.verifiedOn)),
                          textAlign: TextAlign.center,
                          style: t.bodySmall
                              ?.copyWith(fontSize: 12, color: surface.ink2),
                        ),
                      ],
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

  /// "Delete everything" used to wipe the journal, the origin story and every
  /// check-in on a single tap, with no confirmation and no undo.
  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, S s) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.deleteConfirmTitle),
        content: Text(s.deleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(s.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              s.deleteConfirmAction,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(journalProvider.notifier).clear();
    await ref.read(coupleSpaceProvider.notifier).clear();
    await ref.read(learnProgressProvider.notifier).clear();
    ref.read(chatControllerProvider.notifier).clear();
    await ref.read(appLockProvider.notifier).reset();
    await ref.read(appStateProvider.notifier).reset();
    if (!context.mounted) return;
    context.go(Routes.onboarding);
  }
}

/// Copy-to-clipboard helper shared by the export sheet.
Future<void> copyToClipboard(
    BuildContext context, String text, String toast) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(toast)));
}
