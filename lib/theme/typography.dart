import 'package:flutter/widgets.dart';

/// Type system for Saath.
///
/// The three faces ship inside the app (`assets/fonts`); they are not fetched
/// at runtime. That matters twice over: the welcome screen promises "works
/// offline", and a font request to a third party on first launch would be the
/// one network call an otherwise on-device app makes.
///
/// All three files are *variable* fonts carrying a `wght` axis. Flutter does
/// not map [TextStyle.fontWeight] onto that axis on its own — it would render
/// the default instance and fake-bold it — so every style built here sets
/// [TextStyle.fontVariations] alongside `fontWeight`. Build styles with [sora]
/// and [sourceSerif] rather than writing `fontFamily` by hand, and change a
/// weight with [at] rather than `copyWith(fontWeight: …)`.
class AppFonts {
  AppFonts._();

  /// Sora. Headings, buttons, eyebrows — the "spoken" voice.
  static const soraFamily = 'Sora';

  /// Source Serif 4. Body copy and the counsellor's replies — a letter, not a
  /// chat bubble.
  static const serifFamily = 'SourceSerif';

  /// Noto Serif Devanagari. Never named directly: it is the fallback on every
  /// style, so a Hindi string inside an English paragraph still resolves.
  static const devanagariFamily = 'NotoSerifDevanagari';

  static const _fallback = <String>[devanagariFamily];

  /// Sora at [weight], with the Devanagari fallback attached.
  static TextStyle sora({
    required double size,
    int weight = 600,
    double? height,
    double? letterSpacing,
  }) =>
      TextStyle(
        fontFamily: soraFamily,
        fontFamilyFallback: _fallback,
        fontSize: size,
        height: height,
        letterSpacing: letterSpacing,
        fontWeight: weightOf(weight),
        fontVariations: [FontVariation('wght', weight.toDouble())],
      );

  /// Source Serif 4 at [weight], with the Devanagari fallback attached.
  static TextStyle sourceSerif({
    required double size,
    int weight = 400,
    double? height,
    bool italic = false,
  }) =>
      TextStyle(
        fontFamily: serifFamily,
        fontFamilyFallback: _fallback,
        fontSize: size,
        height: height,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        fontWeight: weightOf(weight),
        fontVariations: [FontVariation('wght', weight.toDouble())],
      );

  /// Re-weights an existing style. Plain `copyWith(fontWeight: …)` silently
  /// does nothing on a variable font, so anywhere the app wants a heavier run
  /// of text goes through here.
  static TextStyle at(TextStyle base, int weight) => base.copyWith(
        fontWeight: weightOf(weight),
        fontVariations: [FontVariation('wght', weight.toDouble())],
      );

  /// 100–900 to the matching [FontWeight] constant.
  static FontWeight weightOf(int w) =>
      FontWeight.values[(w ~/ 100).clamp(1, 9) - 1];
}
