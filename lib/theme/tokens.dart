import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// Brand palette. Names match the design canvas.
///
/// There is deliberately no red in the app — arguments are already red enough.
/// "Error" states borrow rose, which is the counsellor's own voice colour.
class Palette {
  Palette._();

  // Light ground
  static const bgLight = Color(0xFFF7F5F9);
  static const inkLight = Color(0xFF221D2B);
  static const ink2Light = Color(0xFF5B5468);

  // Dark ground
  static const bgDark = Color(0xFF171320);
  static const inkDark = Color(0xFFF1ECF5);
  static const ink2Dark = Color(0xFFB3A9C0);

  // Accents — one per resolution stage
  static const rose = Color(0xFFB5426E);
  static const roseDark = Color(0xFFE07AA0);
  static const plum = Color(0xFF7A4C8C);
  static const plumDark = Color(0xFFB58AC7);
  static const sage = Color(0xFF4F7A66);
  static const sageDark = Color(0xFF8FC2A6);

  // Highlight
  static const gold = Color(0xFF9A7A2E);
  static const goldDark = Color(0xFFD9B75E);
}

/// Where the user is in a resolution. The UI calms down as they move
/// from [aware] (vent, chat) through [working] (untangle, repair) to
/// [calm] (closing, couple space, weekly pulse).
enum ResolutionStage { aware, working, calm }

/// Tokens that move together with the stage. Everything else in the
/// theme stays fixed, so a screen switches mood by changing one value.
@immutable
class StageTokens extends ThemeExtension<StageTokens> {
  const StageTokens({
    required this.stage,
    required this.accent,
    required this.accentSoft,
    required this.radius,
    required this.buttonRadius,
    required this.blur,
  });

  final ResolutionStage stage;
  final Color accent;
  final Color accentSoft;
  final double radius;
  final double buttonRadius;
  final double blur;

  static StageTokens of(ResolutionStage stage, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    switch (stage) {
      case ResolutionStage.aware:
        return StageTokens(
          stage: stage,
          accent: dark ? Palette.roseDark : Palette.rose,
          accentSoft: Palette.rose.withValues(alpha: dark ? 0.22 : 0.14),
          radius: 12,
          buttonRadius: 12,
          blur: 14,
        );
      case ResolutionStage.working:
        return StageTokens(
          stage: stage,
          accent: dark ? Palette.plumDark : Palette.plum,
          accentSoft: Palette.plum.withValues(alpha: dark ? 0.22 : 0.14),
          radius: 18,
          buttonRadius: 16,
          blur: 18,
        );
      case ResolutionStage.calm:
        return StageTokens(
          stage: stage,
          accent: dark ? Palette.sageDark : Palette.sage,
          accentSoft: Palette.sage.withValues(alpha: dark ? 0.22 : 0.14),
          radius: 26,
          buttonRadius: 26,
          blur: 24,
        );
    }
  }

  @override
  StageTokens copyWith({
    ResolutionStage? stage,
    Color? accent,
    Color? accentSoft,
    double? radius,
    double? buttonRadius,
    double? blur,
  }) {
    return StageTokens(
      stage: stage ?? this.stage,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      radius: radius ?? this.radius,
      buttonRadius: buttonRadius ?? this.buttonRadius,
      blur: blur ?? this.blur,
    );
  }

  @override
  StageTokens lerp(ThemeExtension<StageTokens>? other, double t) {
    if (other is! StageTokens) return this;
    return StageTokens(
      stage: t < 0.5 ? stage : other.stage,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      radius: lerpDouble(radius, other.radius, t)!,
      buttonRadius: lerpDouble(buttonRadius, other.buttonRadius, t)!,
      blur: lerpDouble(blur, other.blur, t)!,
    );
  }
}

/// Fixed surface tokens per brightness (glass, veil, borders).
@immutable
class SurfaceTokens extends ThemeExtension<SurfaceTokens> {
  const SurfaceTokens({
    required this.bg,
    required this.ink,
    required this.ink2,
    required this.glass,
    required this.glassSoft,
    required this.glassBorder,
    required this.veil,
    required this.hairline,
    required this.gold,
    required this.shadow,
  });

  final Color bg;
  final Color ink;
  final Color ink2;
  final Color glass;
  final Color glassSoft;
  final Color glassBorder;
  final Color veil;
  final Color hairline;
  final Color gold;
  final Color shadow;

  static const light = SurfaceTokens(
    bg: Palette.bgLight,
    ink: Palette.inkLight,
    ink2: Palette.ink2Light,
    glass: Color(0x8CFFFFFF),
    glassSoft: Color(0x61FFFFFF),
    glassBorder: Color(0xBFFFFFFF),
    veil: Color(0x6BF7F5F9),
    hairline: Color(0x1F221D2B),
    gold: Palette.gold,
    shadow: Color(0x14140C1E),
  );

  static const dark = SurfaceTokens(
    bg: Palette.bgDark,
    ink: Palette.inkDark,
    ink2: Palette.ink2Dark,
    glass: Color(0x1AFFFFFF),
    glassSoft: Color(0x12FFFFFF),
    glassBorder: Color(0x38FFFFFF),
    veil: Color(0x80171320),
    hairline: Color(0x24F1ECF5),
    gold: Palette.goldDark,
    shadow: Color(0x59140C1E),
  );

  @override
  SurfaceTokens copyWith({
    Color? bg,
    Color? ink,
    Color? ink2,
    Color? glass,
    Color? glassSoft,
    Color? glassBorder,
    Color? veil,
    Color? hairline,
    Color? gold,
    Color? shadow,
  }) {
    return SurfaceTokens(
      bg: bg ?? this.bg,
      ink: ink ?? this.ink,
      ink2: ink2 ?? this.ink2,
      glass: glass ?? this.glass,
      glassSoft: glassSoft ?? this.glassSoft,
      glassBorder: glassBorder ?? this.glassBorder,
      veil: veil ?? this.veil,
      hairline: hairline ?? this.hairline,
      gold: gold ?? this.gold,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  SurfaceTokens lerp(ThemeExtension<SurfaceTokens>? other, double t) {
    if (other is! SurfaceTokens) return this;
    return SurfaceTokens(
      bg: Color.lerp(bg, other.bg, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      ink2: Color.lerp(ink2, other.ink2, t)!,
      glass: Color.lerp(glass, other.glass, t)!,
      glassSoft: Color.lerp(glassSoft, other.glassSoft, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      veil: Color.lerp(veil, other.veil, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      gold: Color.lerp(gold, other.gold, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}

extension ThemeTokensX on BuildContext {
  SurfaceTokens get surface =>
      Theme.of(this).extension<SurfaceTokens>() ?? SurfaceTokens.light;
  StageTokens get stage =>
      Theme.of(this).extension<StageTokens>() ??
      StageTokens.of(ResolutionStage.working, Brightness.light);
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  /// True when the platform asks for reduced motion. Long ambient animations
  /// (the cool-down breathing circle, the 600 ms stage cross-fade) honour it.
  bool get reduceMotion => MediaQuery.maybeDisableAnimationsOf(this) ?? false;
}
