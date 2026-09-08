import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_state.dart';
import '../theme/theme.dart';
import 'lock_gate.dart';
import 'web_frame.dart';
import 'router.dart';

class SaathApp extends ConsumerWidget {
  const SaathApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(appStateProvider.select((s) => s.themeMode));
    final language = ref.watch(appStateProvider.select((s) => s.language));

    return MaterialApp.router(
      title: 'Saath',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: themeMode,
      routerConfig: router,

      // Without these, a Hindi user still got English text-selection menus,
      // "Cut / Copy / Paste", and English semantics announcements — the app was
      // half-translated at the framework level no matter what our copy said.
      locale: language.locale,
      supportedLocales: const [Locale('en'), Locale('hi')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      builder: (context, child) {
        // Several screens are vertically tight by design (the cool-down timer,
        // the repair close). They scroll, but past ~1.6× the glass panels stop
        // reading as panels. Clamping here is a deliberate ceiling, not an
        // oversight — see docs/ACCESSIBILITY.md.
        return MediaQuery.withClampedTextScaling(
          minScaleFactor: 0.85,
          maxScaleFactor: 1.6,
          // Above the router, so no deep link can route around the lock.
          child: WebFrame(
            child: LockGate(child: child ?? const SizedBox.shrink()),
          ),
        );
      },
    );
  }
}
