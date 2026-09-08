import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/strings.dart';
import '../theme/tokens.dart';

/// Wraps the app for the browser.
///
/// Two jobs, both only on web:
///
/// * **Frame it.** Saath is a phone app. Stretched across a 1280 px desktop
///   window it reads as a broken website rather than a product, and the
///   Untangle columns in particular stop meaning anything.
/// * **Say what this is.** The web build has no model — a 3.7 GB download into
///   a browser tab is not a thing to do to someone — so the counsellor here is
///   the scripted preview. A relationship app that let you type a real problem
///   and answered with a canned line, without saying so, would be a lie told
///   to someone at a bad moment. The banner is not decoration.
///
/// On a phone browser this frames nothing but still shows the banner. Off web
/// it returns the child untouched.
class WebFrame extends StatelessWidget {
  const WebFrame({super.key, required this.child});

  final Widget child;

  /// Above this width the app is framed rather than stretched.
  static const frameAbove = 560.0;

  /// Roughly a large phone, which is what every layout was drawn for.
  static const phoneWidth = 420.0;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return child;

    final width = MediaQuery.sizeOf(context).width;
    if (width < frameAbove) {
      return Column(
        children: [
          const _PreviewBanner(),
          Expanded(child: child),
        ],
      );
    }

    final surface = context.surface;
    return ColoredBox(
      color: surface.bg,
      child: Column(
        children: [
          const _PreviewBanner(),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: phoneWidth),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: surface.shadow,
                        blurRadius: 60,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewBanner extends ConsumerWidget {
  const _PreviewBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context, ref);
    final narrow = MediaQuery.sizeOf(context).width < WebFrame.frameAbove;

    return Material(
      color: Palette.bgDark,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: narrow ? 8 : 10,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 15,
                color: Palette.roseDark,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  narrow ? s.webPreviewShort : s.webPreviewBanner,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 12.5,
                        height: 1.35,
                        color: Palette.ink2Dark,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// False where the on-device model cannot exist at all.
///
/// The browser is not a place to put a 3.7 GB download, and flutter_gemma's
/// web support is an early preview besides. Anywhere the UI would offer the
/// model, it checks this first rather than offering something that cannot work.
bool get modelSupportedHere => !kIsWeb;
