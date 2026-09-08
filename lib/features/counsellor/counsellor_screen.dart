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
import 'chat_controller.dart';
import 'say_it_kinder_sheet.dart';
import 'voice/voice_service.dart';
import 'engine.dart';

class CounsellorScreen extends ConsumerStatefulWidget {
  const CounsellorScreen({super.key, this.seed, this.embedded = false});

  /// Optional opening line (from a Today chip).
  final String? seed;

  /// True when shown inside the tab shell.
  final bool embedded;

  @override
  ConsumerState<CounsellorScreen> createState() => _CounsellorScreenState();
}

class _CounsellorScreenState extends ConsumerState<CounsellorScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _seedSent = false;

  @override
  void initState() {
    super.initState();
    final seed = widget.seed;
    if (seed != null && seed.trim().isNotEmpty) {
      // Guarded: without this, a rebuild of this route (a theme change, a
      // locale switch) re-sent the seed and the conversation grew a duplicate.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _seedSent) return;
        _seedSent = true;
        _send(seed);
      });
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send(String text) {
    if (text.trim().isEmpty) return;
    ref.read(chatControllerProvider.notifier).send(text);
    _input.clear();
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context, ref);
    final chat = ref.watch(chatControllerProvider);
    final surface = context.surface;

    // Keep the newest tokens in view while the reply streams.
    ref.listen(chatControllerProvider.select((c) => c.messages.length),
        (_, __) {
      _scrollToEnd();
    });

    ref.listen(chatControllerProvider.select((c) => c.pendingSafety),
        (prev, next) async {
      if (next == null) return;
      final hindi = ref.read(appStateProvider).isHindi;
      await context.push(Routes.safety);
      if (!mounted) return;
      // Only after the interrupt has actually been seen: the counsellor then
      // says something, so returning from the helplines is not a dead end.
      ref.read(chatControllerProvider.notifier).acknowledgeSafety(hindi: hindi);
      _scrollToEnd();
    });

    final lastIsAi = chat.messages.isNotEmpty && !chat.messages.last.fromUser;
    final showFollowUps =
        lastIsAi && !chat.streaming && !chat.messages.last.failed;

    return StageTheme(
      stage: ResolutionStage.aware,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: Atmosphere(
          background: Backgrounds.aware,
          veilOpacity: context.isDark ? 0.35 : 0.62,
          child: Column(
            children: [
              GlassTopBar(
                title: s.appName,
                // A tab is not a pushed route; showing a back arrow that jumps
                // to Today was a navigation lie. Inside the shell there is
                // simply no back button.
                showBack: !widget.embedded,
                onBack: () => context.pop(),
                trailing: widget.embedded
                    ? _ChatMenu(s: s, hasMessages: chat.messages.isNotEmpty)
                    : StatusPill(
                        label: s.onThisPhoneOnly,
                        icon: Icons.lock_outline_rounded),
              ),
              Expanded(
                child: ListView(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    if (chat.messages.isEmpty) _EmptyState(s: s, onPick: _send),
                    for (final m in chat.messages) ...[
                      m.fromUser ? _MeBubble(m) : _AiBubble(m, s: s),
                      const SizedBox(height: 18),
                    ],
                    if (chat.canRetry)
                      Padding(
                        padding: const EdgeInsets.only(left: 38),
                        child: GlassChip(
                          label: s.retry,
                          icon: Icons.refresh_rounded,
                          active: true,
                          onTap: () =>
                              ref.read(chatControllerProvider.notifier).retry(),
                        ),
                      ),
                    if (showFollowUps)
                      Padding(
                        padding: const EdgeInsets.only(left: 38),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            GlassChip(
                              label: s.untangleIt,
                              active: true,
                              // `firstWhere` here threw if the conversation
                              // somehow opened with a counsellor message.
                              onTap: () {
                                final vent = chat.firstUserMessage;
                                if (vent == null) return;
                                context.push(Routes.untangle, extra: vent);
                              },
                            ),
                            GlassChip(
                              label: s.helpMeSaySorry,
                              onTap: () => _send(s.helpMeSaySorry),
                            ),
                            GlassChip(
                              label: s.sayItKinder,
                              icon: Icons.edit_note_rounded,
                              onTap: () => showSayItKinderSheet(context),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              _Composer(
                s: s,
                controller: _input,
                streaming: chat.streaming,
                bottomInset: MediaQuery.paddingOf(context).bottom +
                    (widget.embedded ? 96 : 12),
                hintColor: surface.ink2,
                onSend: _send,
                onStop: () => ref.read(chatControllerProvider.notifier).stop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatMenu extends ConsumerWidget {
  const _ChatMenu({required this.s, required this.hasMessages});

  final S s;
  final bool hasMessages;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!hasMessages) {
      return StatusPill(
          label: s.onThisPhoneOnly, icon: Icons.lock_outline_rounded);
    }
    return IconButton(
      tooltip: s.clearConversation,
      icon: Icon(Icons.delete_outline_rounded, color: context.surface.ink2),
      onPressed: () {
        // Clearing used to be one tap and final. The conversation is kept in
        // hand for the length of the snackbar so a mis-tap can be undone.
        final n = ref.read(chatControllerProvider.notifier);
        final kept = ref.read(chatControllerProvider).messages;
        n.clear();
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(s.conversationCleared),
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: s.undo,
              onPressed: () => n.restore(kept),
            ),
          ));
      },
    );
  }
}

class _Composer extends ConsumerStatefulWidget {
  const _Composer({
    required this.s,
    required this.controller,
    required this.streaming,
    required this.bottomInset,
    required this.hintColor,
    required this.onSend,
    required this.onStop,
  });

  final S s;
  final TextEditingController controller;
  final bool streaming;
  final double bottomInset;
  final Color hintColor;
  final ValueChanged<String> onSend;
  final VoidCallback onStop;

  @override
  ConsumerState<_Composer> createState() => _ComposerState();
}

class _ComposerState extends ConsumerState<_Composer> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  Future<void> _toggleMic() async {
    final voice = ref.read(voiceInputProvider.notifier);
    if (ref.read(voiceInputProvider).isListening) {
      await voice.stop();
      return;
    }
    await voice.start(seed: widget.controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final hasText = widget.controller.text.trim().isNotEmpty;
    final voice = ref.watch(voiceInputProvider);

    // Speech fills the field as it is heard, so the person can see they were
    // understood before they send it.
    ref.listen(voiceInputProvider.select((v) => v.transcript), (_, next) {
      if (next.isEmpty) return;
      widget.controller.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
      );
    });

    ref.listen(voiceInputProvider.select((v) => v.status), (prev, next) {
      if (!context.mounted) return;
      if (next == VoiceStatus.unavailable) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(s.voiceUnavailable)));
        ref.read(voiceInputProvider.notifier).reset();
      }
    });

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, widget.bottomInset),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: GlassPanel(
              strong: true,
              radius: 25,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(minHeight: 44, maxHeight: 140),
                child: Center(
                  child: TextField(
                    controller: widget.controller,
                    onSubmitted: widget.onSend,
                    textInputAction: TextInputAction.send,
                    keyboardType: TextInputType.multiline,
                    maxLines: null,
                    minLines: 1,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontSize: 15),
                    decoration: InputDecoration.collapsed(
                      hintText: s.sayItMessy,
                      hintStyle: TextStyle(color: widget.hintColor),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // A real microphone, next to a real send button. These used to be
          // one control that drew a send arrow and was called `_MicButton`.
          if (!widget.streaming)
            _RoundButton(
              icon: voice.isListening
                  ? Icons.stop_rounded
                  : Icons.mic_none_rounded,
              label: voice.isListening ? s.voiceStop : s.voiceStart,
              enabled: true,
              filled: voice.isListening,
              onTap: _toggleMic,
            ),
          if (!widget.streaming) const SizedBox(width: 8),
          _RoundButton(
            icon: widget.streaming ? Icons.stop_rounded : Icons.send_rounded,
            label: widget.streaming ? s.stopGenerating : s.sendMessage,
            enabled: widget.streaming || hasText,
            onTap: widget.streaming
                ? widget.onStop
                : () {
                    ref.read(voiceInputProvider.notifier).cancel();
                    widget.onSend(widget.controller.text);
                  },
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
    this.filled = true,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  /// False for the idle microphone, so the send button stays the one obvious
  /// primary action.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final st = context.stage;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: st.accent.withValues(
          alpha: !enabled ? 0.3 : (filled ? 0.85 : 0.18),
        ),
        shape: CircleBorder(
          side: BorderSide(
              color: Colors.white.withValues(alpha: enabled ? 0.45 : 0.2)),
        ),
        child: InkWell(
          onTap: enabled ? onTap : null,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 50,
            height: 50,
            child: Icon(
              icon,
              color: filled ? Colors.white : st.accent,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.s, required this.onPick});

  final S s;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 40, 4, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.counsellorEmptyTitle, style: t.headlineSmall),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final prompt in [
                s.promptSameFight,
                s.promptRegret,
                s.promptStoppedTalking,
              ])
                GlassChip(label: prompt, onTap: () => onPick(prompt)),
            ],
          ),
        ],
      ),
    );
  }
}

class _AiBubble extends ConsumerWidget {
  const _AiBubble(this.m, {required this.s});

  final ChatMessage m;
  final S s;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = context.stage;
    final surface = context.surface;
    final body =
        m.failed && m.text.trim().isEmpty ? s.counsellorFailed : m.text;
    final speaking = ref.watch(readAloudProvider);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: st.accentSoft,
            shape: BoxShape.circle,
            border: Border.all(color: st.accent.withValues(alpha: 0.35)),
          ),
          child: Icon(Icons.auto_awesome_rounded, size: 15, color: st.accent),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                body.isEmpty ? s.thinking : body,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: m.failed ? surface.ink2 : null,
                  // The reply sits directly on the photo; a soft ground-colour
                  // halo is what keeps it legible over a light patch.
                  shadows: [Shadow(color: surface.bg, blurRadius: 12)],
                ),
              ),
              // For the times someone cannot look at the screen — driving home
              // after the argument, or crying.
              if (body.trim().length > 40 && !m.failed) ...[
                const SizedBox(height: 8),
                GlassChip(
                  label: speaking ? s.readAloudStop : s.readAloud,
                  icon:
                      speaking ? Icons.stop_rounded : Icons.volume_up_outlined,
                  active: speaking,
                  onTap: () => ref.read(readAloudProvider.notifier).speak(body),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MeBubble extends StatelessWidget {
  const _MeBubble(this.m);

  final ChatMessage m;

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        child: GlassPanel(
          strong: true,
          radius: 16,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            m.text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 15,
                  height: 1.5,
                  color: surface.ink,
                ),
          ),
        ),
      ),
    );
  }
}
