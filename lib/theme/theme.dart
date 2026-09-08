import 'package:flutter/material.dart';

import 'tokens.dart';
import 'typography.dart';

/// Builds the app theme for a brightness. The [ResolutionStage] is applied
/// per screen with [StageTheme], so the app-level default is `working`.
ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final surface = dark ? SurfaceTokens.dark : SurfaceTokens.light;
  final stage = StageTokens.of(ResolutionStage.working, brightness);

  final textTheme = TextTheme(
    displayLarge:
        AppFonts.sora(size: 36, weight: 700, height: 1.1, letterSpacing: -0.7),
    headlineMedium:
        AppFonts.sora(size: 28, weight: 700, height: 1.15, letterSpacing: -0.3),
    headlineSmall: AppFonts.sora(size: 22, weight: 600, height: 1.2),
    titleMedium: AppFonts.sora(size: 17, weight: 600, height: 1.3),
    labelLarge: AppFonts.sora(size: 16, weight: 600),
    labelSmall: AppFonts.sora(size: 11, weight: 600, letterSpacing: 1.5),
    bodyLarge: AppFonts.sourceSerif(size: 17, height: 1.5),
    bodyMedium: AppFonts.sourceSerif(size: 16, height: 1.5),
    bodySmall: AppFonts.sourceSerif(size: 14, height: 1.45),
  ).apply(bodyColor: surface.ink, displayColor: surface.ink);

  final scheme = ColorScheme(
    brightness: brightness,
    primary: stage.accent,
    onPrimary: Colors.white,
    secondary: dark ? Palette.sageDark : Palette.sage,
    onSecondary: Colors.white,
    // No red anywhere in Saath. Errors speak in the counsellor's own rose.
    error: dark ? Palette.roseDark : Palette.rose,
    onError: Colors.white,
    surface: surface.bg,
    onSurface: surface.ink,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: surface.bg,
    textTheme: textTheme,
    fontFamily: AppFonts.serifFamily,
    fontFamilyFallback: const [AppFonts.devanagariFamily],
    splashFactory: InkSparkle.splashFactory,
    extensions: [surface, stage],
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? Palette.bgLight : Palette.bgDark,
      contentTextStyle: AppFonts.sourceSerif(size: 15)
          .copyWith(color: dark ? Palette.inkLight : Palette.inkDark),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(stage.radius)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface.bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: AppFonts.sora(size: 20, weight: 600, height: 1.25)
          .copyWith(color: surface.ink),
      contentTextStyle: AppFonts.sourceSerif(size: 15, height: 1.5)
          .copyWith(color: surface.ink2),
    ),
  );
}

/// Re-themes a subtree for a resolution stage. Wrap a screen in this to
/// move its accent, radii and blur along the arc.
class StageTheme extends StatelessWidget {
  const StageTheme({super.key, required this.stage, required this.child});

  final ResolutionStage stage;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = StageTokens.of(stage, theme.brightness);
    final surface = theme.extension<SurfaceTokens>() ??
        (theme.brightness == Brightness.dark
            ? SurfaceTokens.dark
            : SurfaceTokens.light);
    final data = theme.copyWith(
      colorScheme: theme.colorScheme.copyWith(primary: tokens.accent),
      extensions: [surface, tokens],
    );

    // AnimatedTheme rebuilds this whole subtree every frame while it runs, and
    // the subtree is full of BackdropFilters. Skip the cross-fade when the
    // platform asks for reduced motion, and when the stage is unchanged.
    if (context.reduceMotion) return Theme(data: data, child: child);

    return AnimatedTheme(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      data: data,
      child: child,
    );
  }
}
