import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/web_frame.dart';
import '../../core/app_info.dart';
import '../../core/app_lock.dart';
import '../../core/app_state.dart';
import '../../core/strings.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.dart';
import '../../ui/atmosphere.dart';
import '../../ui/glass.dart';
import '../../core/journal.dart';
import '../counsellor/model/model_manager.dart';
import 'coach_engine.dart';
import 'coach_strings.dart';
import 'profile.dart';
import 'tracker.dart';

class CoachSettingsScreen extends ConsumerWidget {
  const CoachSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context, ref);
    final t = T.of(context, ref);
    final app = ref.watch(appStateProvider);
    final engine = ref.watch(coachEngineProvider);
    final apiKey = ref.watch(apiKeyProvider);
    final profile = ref.watch(profileProvider);
    final model = ref.watch(modelManagerProvider);
    final lock = ref.watch(appLockProvider);
    final tt = Theme.of(context).textTheme;
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
                                onTap: () => ref
                                    .read(appStateProvider.notifier)
                                    .setLanguage(l),
                              ),
                          ]),
                          const SizedBox(height: 18),
                          Eyebrow(s.theme),
                          const SizedBox(height: 10),
                          Wrap(spacing: 8, runSpacing: 8, children: [
                            for (final (mode, label) in [
                              (ThemeMode.system, s.themeSystem),
                              (ThemeMode.light, s.themeLight),
                              (ThemeMode.dark, s.themeDark),
                            ])
                              GlassChip(
                                label: label,
                                active: app.themeMode == mode,
                                selectable: true,
                                onTap: () => ref
                                    .read(appStateProvider.notifier)
                                    .setThemeMode(mode),
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
                          Eyebrow(t.profile),
                          const SizedBox(height: 8),
                          Text(
                            profile.targetRole.isEmpty
                                ? t.targetRoleHint
                                : '${profile.targetRole} · ${t.offers(0, profile.targetOffers)} · ${t.applicationsPerDay} ${profile.applicationsPerDay}',
                            style: tt.bodySmall
                                ?.copyWith(fontSize: 15, color: surface.ink2),
                          ),
                          const SizedBox(height: 12),
                          GlassButton(
                            label: t.editProfile,
                            primary: false,
                            icon: Icons.edit_outlined,
                            onPressed: () => context.push(Routes.profile),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    GlassPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Eyebrow(t.engine),
                          const SizedBox(height: 8),
                          Text(t.engineKind(engine.kind),
                              style: tt.bodySmall?.copyWith(
                                  fontSize: 15, color: surface.ink2)),
                          const SizedBox(height: 12),
                          if (modelSupportedHere)
                            GlassButton(
                              label: model.hasModel
                                  ? s.modelRemove
                                  : '${s.modelDownload} · ${model.recommended.sizeLabel}',
                              primary: !model.hasModel && apiKey.isEmpty,
                              icon: model.hasModel
                                  ? Icons.check_circle_outline_rounded
                                  : Icons.download_rounded,
                              onPressed: () => context.push(Routes.model),
                            ),
                          const SizedBox(height: 16),
                          Eyebrow(t.apiKey),
                          const SizedBox(height: 6),
                          Text(t.apiKeyBody,
                              style: tt.bodySmall?.copyWith(
                                  fontSize: 14, color: surface.ink2)),
                          const SizedBox(height: 10),
                          _ApiKeyField(current: apiKey, t: t),
                          const SizedBox(height: 12),
                          GlassChip(
                            label: s.licences,
                            icon: Icons.description_outlined,
                            onTap: () => showLicensePage(
                              context: context,
                              applicationName: t.appName,
                              applicationVersion: AppInfo.displayVersion,
                              applicationLegalese: AppInfo.modelAttribution,
                            ),
                          ),
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
                              style: tt.bodySmall?.copyWith(
                                  fontSize: 15, color: surface.ink2)),
                          const SizedBox(height: 12),
                          if (!lock.available)
                            Text(s.appLockUnavailable,
                                style: tt.bodySmall?.copyWith(
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
                          Eyebrow(s.privacy),
                          const SizedBox(height: 8),
                          Text(t.privacyBody,
                              style: tt.bodySmall?.copyWith(
                                  fontSize: 15, color: surface.ink2)),
                          const SizedBox(height: 12),
                          GlassButton(
                            label: s.deleteEverything,
                            primary: false,
                            icon: Icons.delete_outline_rounded,
                            onPressed: () => _confirmDelete(context, ref, s, t),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '${t.appName} ${AppInfo.displayVersion}',
                      textAlign: TextAlign.center,
                      style: tt.bodySmall
                          ?.copyWith(fontSize: 12, color: surface.ink2),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t.disclaimer,
                      textAlign: TextAlign.center,
                      style: tt.bodySmall
                          ?.copyWith(fontSize: 12, color: surface.ink2),
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

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, S s, T t) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.deleteConfirmTitle),
        content: Text(t.deleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(s.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(s.deleteConfirmAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref.read(applicationsProvider.notifier).clear();
    await ref.read(mocksProvider.notifier).clear();
    await ref.read(learnLogProvider.notifier).clear();
    await ref.read(profileProvider.notifier).clear();
    await ref.read(journalProvider.notifier).clear();
    await ref.read(apiKeyProvider.notifier).set('');
    await ref.read(appLockProvider.notifier).reset();
    await ref.read(appStateProvider.notifier).reset();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(s.everythingDeleted)));
    context.go(Routes.onboarding);
  }
}

class _ApiKeyField extends ConsumerStatefulWidget {
  const _ApiKeyField({required this.current, required this.t});
  final String current;
  final T t;

  @override
  ConsumerState<_ApiKeyField> createState() => _ApiKeyFieldState();
}

class _ApiKeyFieldState extends ConsumerState<_ApiKeyField> {
  late final TextEditingController _c =
      TextEditingController(text: widget.current);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final key = _c.text.trim();
    await ref.read(apiKeyProvider.notifier).set(key);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
          content: Text(
              key.isEmpty ? widget.t.apiKeyRemoved : widget.t.apiKeySaved)));
  }

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    OutlineInputBorder border(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c));
    return Row(children: [
      Expanded(
        child: TextField(
          controller: _c,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          style: Theme.of(context).textTheme.bodyMedium,
          decoration: InputDecoration(
            isDense: true,
            hintText: 'AIza…',
            hintStyle: TextStyle(color: surface.ink2),
            filled: true,
            fillColor: surface.glassSoft,
            border: border(surface.glassBorder),
            enabledBorder: border(surface.glassBorder),
            focusedBorder: border(context.stage.accent),
          ),
        ),
      ),
      const SizedBox(width: 8),
      GlassChip(
          label: S.readWidget(ref).save,
          icon: Icons.check_rounded,
          onTap: _save),
    ]);
  }
}
