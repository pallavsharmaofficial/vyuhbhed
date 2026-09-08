import 'package:flutter/foundation.dart';

/// Why the safety interrupt fired. Kept separate from the phrase list so the
/// interrupt can eventually lead with the right helpline.
enum SafetyConcern { violence, coercion, selfHarm }

@immutable
class SafetySignal {
  const SafetySignal(this.concern, this.matched);
  final SafetyConcern concern;

  /// The phrase that matched. Never shown to the user and never leaves the
  /// device — it exists so the eval set can assert on *why* a line tripped.
  final String matched;
}

/// On-device screen for abuse, coercion and self-harm disclosures.
///
/// Two things about how this is tuned:
///
/// 1. **It is deliberately over-sensitive.** Showing helplines to someone who
///    is fine costs them one tap. Missing a disclosure costs something we
///    cannot get back. Where the two trade off, this errs toward firing.
/// 2. **It runs on every text the user writes**, not just chat. A disclosure
///    typed into an Untangle vent or a Repair Room side used to get a cheerful
///    four-column breakdown of an assault.
///
/// This is a keyword screen, not a classifier, and it is the weakest link in
/// the safety story: it will miss anything phrased indirectly. It is a floor
/// under the on-device model, not a substitute for one. The launch checklist
/// item "safety interrupt tested with a scripted list of 40 phrases in both
/// languages" is what actually validates it — see
/// `test/safety_classifier_test.dart`.
class SafetyClassifier {
  const SafetyClassifier();

  static const _violence = [
    'hit me',
    'hits me',
    'hit her',
    'hit him',
    'beat me',
    'beats me',
    'beat her',
    'slapped me',
    'slaps me',
    'slap me',
    'pushed me',
    'punched me',
    'hurts me',
    'hurt me physically',
    'raised his hand',
    'raised her hand',
    'marks on my',
    'bruise',
    'bruises',
    'forced me',
    'forces me',
    'मारता है',
    'मारती है',
    'मारता हूँ',
    'पीटता है',
    'पीटती है',
    'हाथ उठाया',
    'थप्पड़',
    'ज़बरदस्ती',
    'जबरदस्ती',
  ];

  static const _coercion = [
    'afraid of him',
    'afraid of her',
    'afraid of my husband',
    'afraid of my wife',
    'scared of him',
    'scared of her',
    'scared of my husband',
    'scared of my wife',
    'terrified of him',
    'terrified of her',
    "won't let me",
    'wont let me',
    'will not let me',
    'not allowed to',
    "doesn't let me",
    'does not let me',
    'controls my',
    'controls me',
    'takes my phone',
    'checks my phone',
    'reads my messages',
    'threatens',
    'threatened me',
    'threatens me',
    'threatens to',
    'locks me',
    'locked me in',
    'takes my salary',
    'no money of my own',
    'walking on eggshells',
    'डर लगता है',
    'डरती हूँ',
    'डरता हूँ',
    'धमकी',
    'धमकाता',
    'धमकाती',
    'बाहर नहीं जाने देता',
    'जाने नहीं देता',
    'इजाज़त नहीं',
  ];

  static const _selfHarm = [
    'hurt myself',
    'harm myself',
    'kill myself',
    'killing myself',
    'end it all',
    'end my life',
    'ending my life',
    'no reason to live',
    'better off without me',
    'want to die',
    'wish i was dead',
    'wish i were dead',
    'suicide',
    'suicidal',
    'cut myself',
    'जान दे',
    'जान देने',
    'ख़ुदकुशी',
    'खुदकुशी',
    'आत्महत्या',
    'मरना चाहता',
    'मरना चाहती',
    'जीने का मन नहीं',
  ];

  /// Returns the first signal found, or null. Case-insensitive; Devanagari has
  /// no case, so `toLowerCase` is a no-op there and the phrases match as-is.
  SafetySignal? screen(String input) {
    final text = input.toLowerCase();
    if (text.trim().isEmpty) return null;

    for (final entry in <(SafetyConcern, List<String>)>[
      (SafetyConcern.selfHarm, _selfHarm),
      (SafetyConcern.violence, _violence),
      (SafetyConcern.coercion, _coercion),
    ]) {
      for (final phrase in entry.$2) {
        if (text.contains(phrase)) return SafetySignal(entry.$1, phrase);
      }
    }
    return null;
  }

  bool fires(String input) => screen(input) != null;
}

const safetyClassifier = SafetyClassifier();
