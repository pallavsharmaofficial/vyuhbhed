import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

/// Marks a subtree as already sitting behind a [BackdropFilter].
///
/// Every glass element used to run its own filter, so a chip inside a panel
/// inside the tab shell forced three full-screen `saveLayer`s for one row of
/// pixels. On a 4 GB Android phone — the device this app is aimed at — that is
/// the difference between 60 fps and visible jank while scrolling Today.
///
/// [Frost] reads this: the outermost element blurs, the ones nested inside it
/// paint their tint and border only. The result is visually near-identical
/// because the backdrop they would sample is already blurred.
class FrostScope extends InheritedWidget {
  const FrostScope({super.key, required this.blurred, required super.child});

  final bool blurred;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FrostScope>()?.blurred ??
      false;

  @override
  bool updateShouldNotify(FrostScope old) => old.blurred != blurred;
}

/// A rounded, blurred, tinted surface — the one primitive every glass widget
/// here is built from.
class Frost extends StatelessWidget {
  const Frost({
    super.key,
    required this.child,
    required this.color,
    required this.borderRadius,
    this.border,
    this.blur,
    this.boxShadow,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final Color color;
  final BorderRadius borderRadius;
  final BoxSide? border;
  final double? blur;
  final List<BoxShadow>? boxShadow;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final alreadyBlurred = FrostScope.of(context);
    final sigma = blur ?? context.stage.blur;

    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: borderRadius,
        border: border == null
            ? null
            : Border.all(color: border!.color, width: border!.width),
        boxShadow: boxShadow,
      ),
      child: child,
    );

    if (alreadyBlurred || sigma <= 0) {
      return ClipRRect(borderRadius: borderRadius, child: content);
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: FrostScope(blurred: true, child: content),
      ),
    );
  }
}

/// Border description for [Frost]. (Named to avoid colliding with
/// Flutter's own `BorderSide`, which does not carry a nullable colour.)
@immutable
class BoxSide {
  const BoxSide(this.color, [this.width = 1]);
  final Color color;
  final double width;
}

/// Frosted panel. Radius and blur come from the current [StageTokens].
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.strong = false,
    this.padding = const EdgeInsets.all(18),
    this.radius,
  });

  final Widget child;
  final bool strong;
  final EdgeInsets padding;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final s = context.surface;
    final st = context.stage;
    return Frost(
      borderRadius: BorderRadius.circular(radius ?? st.radius),
      color: strong ? s.glass : s.glassSoft,
      border: BoxSide(s.glassBorder),
      padding: padding,
      boxShadow: [
        BoxShadow(color: s.shadow, blurRadius: 30, offset: const Offset(0, 8))
      ],
      child: child,
    );
  }
}

/// Tinted glass panel for labelled content (Untangle columns, agreements).
class TintPanel extends StatelessWidget {
  const TintPanel({
    super.key,
    required this.label,
    required this.child,
    required this.color,
  });

  final String label;
  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final st = context.stage;
    final dark = context.isDark;
    return Semantics(
      container: true,
      label: label,
      child: Frost(
        borderRadius:
            BorderRadius.circular((st.radius - 4).clamp(12, 40).toDouble()),
        color: color.withValues(alpha: dark ? 0.22 : 0.16),
        border: BoxSide(color.withValues(alpha: 0.3)),
        blur: 14,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(child: Eyebrow(label, color: color)),
            const SizedBox(height: 6),
            DefaultTextStyle.merge(
              style:
                  Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 15),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

/// Uppercase tracked label.
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    // Devanagari has no case, and `toUpperCase()` on it is a no-op that also
    // strips nothing — but the wide tracking that flatters small caps hurts
    // conjuncts, so Hindi gets the label at its natural tracking.
    final devanagari = _hasDevanagari(text);
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color ?? context.stage.accent,
          letterSpacing: devanagari ? 0.2 : 1.5,
          fontSize: devanagari ? 12 : null,
        );
    return Text(devanagari ? text : text.toUpperCase(), style: style);
  }
}

final _devanagari = RegExp(r'[ऀ-ॿ]');
bool _hasDevanagari(String s) => _devanagari.hasMatch(s);

/// Primary (tinted glass) or secondary (clear glass) button.
///
/// Height is a *minimum*, not a fixed value: at 200 % text scale a 52 px box
/// clips the label, and the accessibility pass is not optional on a screen
/// whose only action is "Continue".
class GlassButton extends StatelessWidget {
  const GlassButton({
    super.key,
    required this.label,
    this.onPressed,
    this.primary = true,
    this.icon,
    this.expand = true,
    this.semanticsLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final IconData? icon;
  final bool expand;
  final String? semanticsLabel;

  bool get _enabled => onPressed != null;

  @override
  Widget build(BuildContext context) {
    final s = context.surface;
    final st = context.stage;
    final r = BorderRadius.circular(st.buttonRadius);

    // A disabled button used to render at full accent with its glow intact —
    // indistinguishable from an enabled one, so "Continue" looked broken rather
    // than not-yet-ready.
    final fg = primary
        ? (_enabled ? Colors.white : Colors.white.withValues(alpha: 0.6))
        : (_enabled ? s.ink : s.ink2);
    final bg = primary
        ? st.accent.withValues(alpha: _enabled ? 0.82 : 0.28)
        : (_enabled ? s.glass : s.glassSoft);

    final child = Frost(
      borderRadius: r,
      color: bg,
      border: BoxSide(
        primary
            ? Colors.white.withValues(alpha: _enabled ? 0.45 : 0.18)
            : s.glassBorder,
      ),
      boxShadow: primary && _enabled
          ? [
              BoxShadow(
                color: st.accent.withValues(alpha: 0.28),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ]
          : null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: r,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: fg),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(color: fg),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      enabled: _enabled,
      label: semanticsLabel ?? label,
      excludeSemantics: true,
      child: expand ? SizedBox(width: double.infinity, child: child) : child,
    );
  }
}

/// Small pill chip; [active] uses the stage accent.
class GlassChip extends StatelessWidget {
  const GlassChip({
    super.key,
    required this.label,
    this.active = false,
    this.onTap,
    this.icon,
    this.selectable = false,
  });

  final String label;
  final bool active;
  final VoidCallback? onTap;
  final IconData? icon;

  /// True for chips that pick one of a set (relationship stage, language), so
  /// a screen reader announces them as selectable rather than as buttons.
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final s = context.surface;
    final st = context.stage;
    final color = active ? st.accent : s.ink;

    return Semantics(
      button: onTap != null && !selectable,
      selected: selectable ? active : null,
      enabled: onTap != null,
      label: label,
      excludeSemantics: true,
      child: Frost(
        borderRadius: BorderRadius.circular(999),
        color: active ? st.accentSoft : s.glassSoft,
        border:
            BoxSide(active ? st.accent.withValues(alpha: 0.35) : s.glassBorder),
        blur: 10,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            customBorder: const StadiumBorder(),
            child: ConstrainedBox(
              // 44 pt is the smallest comfortable touch target on both stores.
              constraints: const BoxConstraints(minHeight: 40),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 14, color: color),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        style: AppFonts.sora(
                          size: 12,
                          weight: active ? 600 : 500,
                          letterSpacing: 0,
                        ).copyWith(color: color),
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
  }
}

/// Floating glass tab bar.
class GlassTabBar extends StatelessWidget {
  const GlassTabBar({
    super.key,
    required this.index,
    required this.onChanged,
    required this.items,
  });

  final int index;
  final ValueChanged<int> onChanged;
  final List<({IconData icon, String label})> items;

  @override
  Widget build(BuildContext context) {
    final s = context.surface;
    final st = context.stage;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 0, 16, MediaQuery.paddingOf(context).bottom + 8),
      child: GlassPanel(
        strong: true,
        radius: 22,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: Semantics(
                  selected: i == index,
                  button: true,
                  label: items[i].label,
                  excludeSemantics: true,
                  child: InkWell(
                    onTap: () => onChanged(i),
                    borderRadius: BorderRadius.circular(16),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 56),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 8),
                          Icon(items[i].icon,
                              size: 22, color: i == index ? st.accent : s.ink2),
                          const SizedBox(height: 4),
                          Text(
                            items[i].label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.sora(
                              size: 11,
                              weight: i == index ? 600 : 500,
                              letterSpacing: 0,
                            ).copyWith(color: i == index ? st.accent : s.ink2),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Back-arrow top bar used by inner screens.
class GlassTopBar extends StatelessWidget implements PreferredSizeWidget {
  const GlassTopBar({
    super.key,
    required this.title,
    this.trailing,
    this.onBack,
    this.backTooltip,
    this.showBack = true,
  });

  final String title;
  final Widget? trailing;
  final VoidCallback? onBack;
  final String? backTooltip;

  /// False on tab roots. A back arrow there is a claim about the navigation
  /// stack that is not true, and tapping it jumps sideways to another tab.
  final bool showBack;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 20, 8),
        child: Row(
          children: [
            if (showBack)
              IconButton(
                onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                tooltip: backTooltip ??
                    MaterialLocalizations.of(context).backButtonTooltip,
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              )
            else
              const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

/// Small status pill like "On this phone only". Not interactive.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => GlassChip(label: label, icon: icon);
}
