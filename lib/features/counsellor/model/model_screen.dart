import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/web_frame.dart';
import '../../../core/app_state.dart';
import '../../../core/strings.dart';
import '../../../theme/theme.dart';
import '../../../theme/tokens.dart';
import '../../../ui/atmosphere.dart';
import '../../../ui/glass.dart';
import 'model_catalogue.dart';
import 'model_manager.dart';

/// Onboarding step 4 and Settings → Counsellor model, one screen.
///
/// The download is never automatic and never silent. The user sees the exact
/// size before anything starts, is told to use Wi-Fi, can cancel mid-way, and
/// can walk past the whole thing — the rest of the app works without it, which
/// is the only reason it is honest to ask for 3.7 GB at all.
class ModelScreen extends ConsumerWidget {
  const ModelScreen({super.key, this.duringOnboarding = false});

  final bool duringOnboarding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context, ref);
    final model = ref.watch(modelManagerProvider);
    final t = Theme.of(context).textTheme;
    final surface = context.surface;

    Future<void> finish() async {
      if (duringOnboarding) {
        // Onboarding is only complete here — step 4 is the last one, whether
        // the user downloaded the model or walked past it.
        await ref.read(appStateProvider.notifier).completeOnboarding();
        if (context.mounted) context.go(Routes.today);
        return;
      }
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(Routes.today);
      }
    }

    return StageTheme(
      stage: ResolutionStage.working,
      child: Scaffold(
        body: Atmosphere(
          background: Backgrounds.working,
          child: Column(
            children: [
              GlassTopBar(
                title: duringOnboarding ? s.stepOf(4, 4) : s.counsellorModel,
                showBack: !duringOnboarding,
                onBack: () => context.pop(),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 6, 24, 24),
                  children: [
                    if (!modelSupportedHere)
                      // The browser cannot run this at all. Offering a
                      // download button that could never work would be worse
                      // than saying so.
                      GlassPanel(
                        strong: true,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Eyebrow(s.counsellorModel),
                            const SizedBox(height: 8),
                            Text(
                              s.webWhyNoModel,
                              style: t.bodyLarge?.copyWith(color: surface.ink2),
                            ),
                          ],
                        ),
                      )
                    else if (model.hasModel)
                      _Installed(s: s, state: model)
                    else ...[
                      Text(s.modelTitle, style: t.headlineMedium),
                      const SizedBox(height: 12),
                      Text(
                        s.modelBody,
                        style: t.bodyLarge?.copyWith(color: surface.ink2),
                      ),
                      const SizedBox(height: 20),
                      if (model.isDownloading)
                        _Progress(s: s, download: model.download!)
                      else ...[
                        _Chooser(s: s, state: model),
                        const SizedBox(height: 16),
                        _WifiNote(s: s),
                      ],
                      if (model.error != null) ...[
                        const SizedBox(height: 12),
                        TintPanel(
                          label: s.modelFailed,
                          color:
                              context.isDark ? Palette.roseDark : Palette.rose,
                          child: Text(model.error!),
                        ),
                      ],
                      if (model.unavailable ==
                          ModelUnavailable.notConfigured) ...[
                        const SizedBox(height: 12),
                        TintPanel(
                          label: s.counsellorModel,
                          color: surface.gold,
                          child: Text(s.modelNotConfigured),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  24,
                  0,
                  24,
                  MediaQuery.paddingOf(context).bottom + 20,
                ),
                child: Column(
                  children: [
                    if (!modelSupportedHere)
                      const SizedBox.shrink()
                    else if (model.isDownloading)
                      GlassButton(
                        label: s.modelCancel,
                        primary: false,
                        onPressed: () => ref
                            .read(modelManagerProvider.notifier)
                            .cancelDownload(),
                      )
                    else if (!model.hasModel)
                      GlassButton(
                        label:
                            '${s.modelDownload} · ${model.recommended.sizeLabel}',
                        icon: Icons.download_rounded,
                        onPressed:
                            model.unavailable == ModelUnavailable.notConfigured
                                ? null
                                : () => ref
                                    .read(modelManagerProvider.notifier)
                                    .install(model.recommended),
                      ),
                    const SizedBox(height: 10),
                    // Web/unsupported outside onboarding used to render no
                    // button at all — only the back arrow got you out.
                    if (model.hasModel ||
                        duringOnboarding ||
                        !modelSupportedHere)
                      GlassButton(
                        // "Not now" implies something to postpone. On web
                        // there is nothing to postpone.
                        label: !modelSupportedHere
                            ? s.continueLabel
                            : (model.hasModel ? s.done : s.modelLater),
                        primary: model.hasModel || !modelSupportedHere,
                        onPressed: finish,
                      ),
                    if (duringOnboarding &&
                        !model.hasModel &&
                        modelSupportedHere) ...[
                      const SizedBox(height: 10),
                      Text(
                        s.modelSkipNote,
                        textAlign: TextAlign.center,
                        style: t.bodySmall?.copyWith(
                          fontSize: 13,
                          color: surface.ink2,
                        ),
                      ),
                    ],
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

class _Chooser extends ConsumerWidget {
  const _Chooser({required this.s, required this.state});

  final S s;
  final ModelState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final surface = context.surface;

    return GlassPanel(
      strong: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow(s.modelChoose),
          const SizedBox(height: 10),
          for (final m in SaathModel.available) ...[
            _ModelRow(
              s: s,
              model: m,
              selected: state.recommended == m,
              onTap: () => ref.read(modelManagerProvider.notifier).choose(m),
            ),
            if (m != SaathModel.available.last)
              Divider(color: surface.hairline, height: 18),
          ],
          if (state.deviceRamMb != null) ...[
            const SizedBox(height: 12),
            Text(
              s.modelRamNote((state.deviceRamMb! / 1024).round()),
              style: t.bodySmall?.copyWith(fontSize: 13, color: surface.ink2),
            ),
          ],
        ],
      ),
    );
  }
}

class _ModelRow extends StatelessWidget {
  const _ModelRow({
    required this.s,
    required this.model,
    required this.selected,
    required this.onTap,
  });

  final S s;
  final SaathModel model;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final surface = context.surface;
    final st = context.stage;
    final label = switch (model) {
      SaathModel.gemma3nE2B => s.modelBigName,
      SaathModel.gemma31B => s.modelSmallName,
      SaathModel.qwen251_5B => s.modelOpenName,
    };

    return Semantics(
      inMutuallyExclusiveGroup: true,
      selected: selected,
      button: true,
      label: '$label, ${model.sizeLabel}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 20,
                color: selected ? st.accent : surface.ink2,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: t.titleMedium?.copyWith(fontSize: 15)),
                    Text(
                      model.sizeLabel,
                      style: t.bodySmall?.copyWith(
                        fontSize: 13,
                        color: surface.ink2,
                      ),
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

class _WifiNote extends StatelessWidget {
  const _WifiNote({required this.s});

  final S s;

  @override
  Widget build(BuildContext context) {
    return TintPanel(
      label: s.modelWifiLabel,
      color: context.surface.gold,
      child: Text(s.modelWifi),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.s, required this.download});

  final S s;
  final ModelDownload download;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final surface = context.surface;
    final st = context.stage;
    final remaining = download.remaining;

    return GlassPanel(
      strong: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow(s.modelDownloading),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: download.fraction,
              minHeight: 8,
              backgroundColor: surface.glassSoft,
              valueColor: AlwaysStoppedAnimation(st.accent),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                s.modelPercent(download.percent),
                style: t.labelLarge?.copyWith(fontSize: 15, color: st.accent),
              ),
              if (remaining != null)
                Flexible(
                  child: Text(
                    s.modelRemaining(_humanise(remaining)),
                    textAlign: TextAlign.right,
                    style: t.bodySmall?.copyWith(
                      fontSize: 13,
                      color: surface.ink2,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static String _humanise(Duration d) {
    if (d.inMinutes < 1) return '${d.inSeconds}s';
    if (d.inHours < 1) return '${d.inMinutes} min';
    return '${d.inHours}h ${d.inMinutes % 60}m';
  }
}

class _Installed extends ConsumerWidget {
  const _Installed({required this.s, required this.state});

  final S s;
  final ModelState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final surface = context.surface;
    final model = state.installed!;
    final name = switch (model) {
      SaathModel.gemma3nE2B => 'Gemma 3n E2B',
      SaathModel.gemma31B => 'Gemma 3 1B',
      SaathModel.qwen251_5B => 'Qwen 2.5 1.5B',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: context.stage.accentSoft,
            border: Border.all(
              color: context.stage.accent.withValues(alpha: 0.35),
            ),
          ),
          child: Icon(
            Icons.check_rounded,
            color: context.stage.accent,
            size: 26,
          ),
        ),
        const SizedBox(height: 18),
        Text(s.modelReady, style: t.headlineMedium),
        const SizedBox(height: 12),
        Text(
          s.modelReadyBody(name),
          style: t.bodyLarge?.copyWith(color: surface.ink2),
        ),
        const SizedBox(height: 20),
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Eyebrow(s.modelRemove),
              const SizedBox(height: 8),
              Text(
                s.modelRemoveBody(model.sizeLabel),
                style: t.bodySmall?.copyWith(fontSize: 15, color: surface.ink2),
              ),
              const SizedBox(height: 12),
              GlassButton(
                label: s.modelRemove,
                primary: false,
                icon: Icons.delete_outline_rounded,
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(s.modelRemoveConfirm),
                      content: Text(s.modelRemoveBody(model.sizeLabel)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: Text(s.cancel),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: Text(s.modelRemove),
                        ),
                      ],
                    ),
                  );
                  if (confirmed != true) return;
                  await ref.read(modelManagerProvider.notifier).uninstall();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
