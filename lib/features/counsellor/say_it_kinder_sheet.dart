import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/app_state.dart';
import '../../core/strings.dart';
import '../../theme/tokens.dart';
import '../../ui/glass.dart';
import 'engine.dart';
import 'safety.dart';

/// "Say it kinder": paste the message you are about to send, get three ways to
/// say the same thing.
///
/// The original is never taken away. Three options and a note on what was
/// worth keeping — because a rewrite that makes someone feel corrected for
/// having a need is worse than the message they were going to send.
Future<void> showSayItKinderSheet(BuildContext context, {String? draft}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.surface.bg,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: _SayItKinderSheet(draft: draft),
    ),
  );
}

class _SayItKinderSheet extends ConsumerStatefulWidget {
  const _SayItKinderSheet({this.draft});

  final String? draft;

  @override
  ConsumerState<_SayItKinderSheet> createState() => _SayItKinderSheetState();
}

class _SayItKinderSheetState extends ConsumerState<_SayItKinderSheet> {
  late final TextEditingController _draft;
  KinderRewrite? _result;
  bool _working = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _draft = TextEditingController(text: widget.draft ?? '');
  }

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  Future<void> _rewrite() async {
    final text = _draft.text.trim();
    if (text.isEmpty || _working) return;

    // The guardrail runs here too. Someone rewriting a message that describes
    // being hurt needs the helplines, not softer wording for it.
    if (safetyClassifier.fires(text)) {
      // Used to pop silently: the person typed something that tripped the
      // guardrail and got a closed sheet with no explanation. Take them to
      // the helplines the way Untangle does.
      if (mounted) {
        final router = GoRouter.of(context);
        Navigator.of(context).pop();
        router.push(Routes.safety);
      }
      return;
    }

    setState(() {
      _working = true;
      _error = null;
    });

    final app = ref.read(appStateProvider);
    try {
      final result = await ref.read(counsellorEngineProvider).sayItKinder(
            text,
            CounsellorContext(
              userName: app.userName,
              partnerName: app.partnerName,
              originStory: app.originStory,
              hindi: app.isHindi,
            ),
          );
      if (!mounted) return;
      setState(() {
        _result = result;
        _working = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _working = false;
        _error = error is CounsellorException ? error.message : '$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context, ref);
    final t = Theme.of(context).textTheme;
    final surface = context.surface;
    final result = _result;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.sayItKinderTitle, style: t.headlineSmall),
            const SizedBox(height: 6),
            Text(
              s.sayItKinderHint,
              style: t.bodySmall?.copyWith(fontSize: 14, color: surface.ink2),
            ),
            const SizedBox(height: 14),
            GlassPanel(
              strong: true,
              child: TextField(
                controller: _draft,
                minLines: 3,
                maxLines: 6,
                autofocus: widget.draft == null,
                textCapitalization: TextCapitalization.sentences,
                style: t.bodyLarge,
                decoration: InputDecoration.collapsed(
                  hintText: s.sayItMessy,
                  hintStyle: TextStyle(color: surface.ink2),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      s.counsellorFailed,
                      style: t.bodySmall
                          ?.copyWith(fontSize: 14, color: surface.ink2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GlassChip(
                    label: s.retry,
                    icon: Icons.refresh_rounded,
                    onTap: _rewrite,
                  ),
                ],
              ),
            ],
            if (_working) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.stage.accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    s.sayItKinderWorking,
                    style: t.bodyMedium?.copyWith(color: surface.ink2),
                  ),
                ],
              ),
            ],
            if (result != null) ...[
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final (label, text)
                          in result.options(s.isHindi)) ...[
                        _Option(label: label, text: text, s: s),
                        const SizedBox(height: 10),
                      ],
                      if (result.keep.trim().isNotEmpty)
                        TintPanel(
                          label: s.sayItKinderKeep,
                          color: Theme.of(context).colorScheme.secondary,
                          child: Text(result.keep),
                        ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            GlassButton(
              label: result == null ? s.sayItKinderAction : s.done,
              onPressed: _working
                  ? null
                  : (result != null
                      ? () => Navigator.of(context).pop()
                      : (_draft.text.trim().isEmpty ? null : _rewrite)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({required this.label, required this.text, required this.s});

  final String label;
  final String text;
  final S s;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return GlassPanel(
      strong: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: Eyebrow(label)),
              GlassChip(
                label: s.copy,
                icon: Icons.content_copy_rounded,
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: text));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(SnackBar(content: Text(s.copied)));
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(text, style: t.bodyLarge?.copyWith(fontSize: 16)),
        ],
      ),
    );
  }
}
