import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/app_state.dart';
import 'core/key_value_store.dart';
import 'features/counsellor/model/model_catalogue.dart';
import 'features/counsellor/model/model_manager.dart';

/// Makes the bundled typefaces show up in Settings → About → Licences.
///
/// The three faces ship inside the app, and all three are SIL OFL 1.1 with
/// different copyright holders. `LicenseRegistry` only knows about licences
/// declared by packages, so a font added as a raw asset is invisible to it
/// unless it is registered by hand.
void _registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(
      const ['Sora', 'Source Serif 4', 'Noto Serif Devanagari'],
      text,
    );
  });
}

Future<void> main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // A framework error inside a build used to paint the grey/red error box
      // over whatever the user was writing. In release the app shows a quiet
      // panel instead and keeps the rest of the screen alive.
      final defaultOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        defaultOnError?.call(details);
        if (kReleaseMode) FlutterError.presentError(details);
      };
      if (kReleaseMode) {
        ErrorWidget.builder = (details) => const _QuietErrorBox();
      }

      _registerFontLicenses();

      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
      ));

      // If the preference store fails to open (a corrupt file, a full disk)
      // the app still has to start: an in-memory store loses settings between
      // launches but never blocks someone from reaching the counsellor or the
      // helplines.
      final (store, persistent) = await SharedPreferencesStore.open();
      if (!persistent) {
        debugPrint(
            'Saath: running with in-memory settings; nothing will persist.');
      }

      // Registering the inference engine does not load a model and does not
      // touch the network — it only tells flutter_gemma what a .litertlm file
      // is. A phone with no model downloaded starts exactly as fast as before.
      try {
        await FlutterGemma.initialize(
          inferenceEngines: const [LiteRtLmEngine()],
          huggingFaceToken: ModelHosting.huggingFaceToken.isEmpty
              ? null
              : ModelHosting.huggingFaceToken,
        );
        FlutterGemma.logLevel =
            kReleaseMode ? GemmaLogLevel.none : GemmaLogLevel.info;
      } on Object catch (error, stack) {
        // A runtime that will not initialise means the preview engine, not a
        // failed launch.
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'saath',
            context: ErrorDescription('initialising the on-device runtime'),
          ),
        );
      }

      final container = ProviderContainer(
        overrides: [keyValueStoreProvider.overrideWithValue(store)],
      );
      // Reconciles what we think is installed with what is actually on disk,
      // and reads physical RAM to pick the default model. Deliberately not
      // awaited: the first screen must not wait on it.
      unawaited(container.read(modelManagerProvider.notifier).initialise());

      runApp(
        UncontrolledProviderScope(
          container: container,
          child: const SaathApp(),
        ),
      );
    },
    (error, stack) {
      // Nothing is sent anywhere: crash reporting is opt-in and not wired yet.
      // Until it is, an uncaught async error at least reaches the device log
      // rather than vanishing.
      debugPrint('Uncaught error: $error\n$stack');
    },
  );
}

class _QuietErrorBox extends StatelessWidget {
  const _QuietErrorBox();

  @override
  Widget build(BuildContext context) {
    return const Material(
      color: Color(0xFFF7F5F9),
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Something broke on this screen. Nothing was lost.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF5B5468), fontSize: 15),
          ),
        ),
      ),
    );
  }
}
