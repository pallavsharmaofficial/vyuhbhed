import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The page shell used by every screen: a full-bleed photo, a colour veil,
/// and a permanent gradient fade at the top and bottom so text always sits
/// on a quiet zone regardless of the photo behind it.
class Atmosphere extends StatelessWidget {
  const Atmosphere({
    super.key,
    required this.background,
    required this.child,
    this.veilOpacity,
    this.topFade = 200,
    this.bottomFade = 260,
  });

  /// Asset path, e.g. `assets/backgrounds/bg-today.jpg`.
  final String background;
  final Widget child;

  /// Overrides the theme veil opacity (0–1). Lower shows more photo.
  final double? veilOpacity;
  final double topFade;
  final double bottomFade;

  @override
  Widget build(BuildContext context) {
    final s = context.surface;
    final veil =
        veilOpacity == null ? s.veil : s.bg.withValues(alpha: veilOpacity!);

    return Stack(
      fit: StackFit.expand,
      children: [
        // The photo layer is static for the life of the screen; isolating it
        // keeps the blurred glass above from repainting it every frame.
        RepaintBoundary(
          child: Image.asset(
            background,
            fit: BoxFit.cover,
            excludeFromSemantics: true,
            filterQuality: FilterQuality.medium,
            // A missing or truncated asset must not red-screen a counselling
            // app mid-conversation. Fall back to the ground colour: every
            // screen stays readable because the veil and fades do the work.
            errorBuilder: (context, error, stack) => DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    context.stage.accentSoft,
                    s.bg,
                  ],
                ),
              ),
            ),
          ),
        ),
        ColoredBox(color: veil),
        _Fade(
            height: topFade, from: Alignment.topCenter, color: s.bg, peak: 0.7),
        _Fade(
            height: bottomFade,
            from: Alignment.bottomCenter,
            color: s.bg,
            peak: 0.75),
        child,
      ],
    );
  }
}

class _Fade extends StatelessWidget {
  const _Fade({
    required this.height,
    required this.from,
    required this.color,
    required this.peak,
  });

  final double height;
  final Alignment from;
  final Color color;
  final double peak;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: from,
      child: IgnorePointer(
        child: Container(
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: from,
              end: from == Alignment.topCenter
                  ? Alignment.bottomCenter
                  : Alignment.topCenter,
              stops: const [0, 0.45, 1],
              colors: [
                color,
                color.withValues(alpha: peak),
                color.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Background assets, named by the moment they belong to.
class Backgrounds {
  Backgrounds._();
  static const welcome = 'assets/backgrounds/bg-welcome.jpg';
  static const origin = 'assets/backgrounds/bg-origin.jpg';
  static const today = 'assets/backgrounds/bg-today.jpg';
  static const aware = 'assets/backgrounds/bg-aware.jpg';
  static const working = 'assets/backgrounds/bg-working.jpg';
  static const calm = 'assets/backgrounds/bg-calm.jpg';

  static const all = [welcome, origin, today, aware, working, calm];
}
