import 'package:flutter_test/flutter_test.dart';
import 'package:vyuhbhed/features/counsellor/safety.dart';

/// The launch checklist says "safety interrupt tested with a scripted list of
/// 40 phrases in both languages". This is that list.
///
/// The classifier is tuned to over-fire: a false positive costs one tap, a
/// false negative costs something we cannot get back. The `mustFire` list is
/// therefore the one that must never regress. `mustNotFire` only guards
/// against tuning so loose that every ordinary argument becomes an interrupt —
/// if a line ever has to move between the lists, it moves into `mustFire`.
void main() {
  const classifier = SafetyClassifier();

  const mustFire = <String, SafetyConcern>{
    // ── Violence, English ──
    'he hit me last night': SafetyConcern.violence,
    'she hits me when she drinks': SafetyConcern.violence,
    'he beat me in front of the kids': SafetyConcern.violence,
    'he slapped me and walked out': SafetyConcern.violence,
    'he pushed me into the wall': SafetyConcern.violence,
    'there are bruises on my arm': SafetyConcern.violence,
    'he raised his hand at me again': SafetyConcern.violence,
    'he forced me even after I said no': SafetyConcern.violence,
    // ── Violence, Hindi ──
    'वो मुझे मारता है': SafetyConcern.violence,
    'उसने मुझ पर हाथ उठाया': SafetyConcern.violence,
    'कल रात थप्पड़ मारा': SafetyConcern.violence,
    'वो ज़बरदस्ती करता है': SafetyConcern.violence,

    // ── Coercion, English ──
    'I am afraid of him': SafetyConcern.coercion,
    'I am scared of my husband': SafetyConcern.coercion,
    'I am terrified of her when she is like this': SafetyConcern.coercion,
    "he won't let me see my sister": SafetyConcern.coercion,
    'I am not allowed to go out alone': SafetyConcern.coercion,
    'he checks my phone every night': SafetyConcern.coercion,
    'he reads my messages while I sleep': SafetyConcern.coercion,
    'he threatens to leave with the kids': SafetyConcern.coercion,
    'he takes my salary every month': SafetyConcern.coercion,
    'I have no money of my own': SafetyConcern.coercion,
    'I am walking on eggshells all day': SafetyConcern.coercion,
    'he locked me in the bedroom': SafetyConcern.coercion,
    // ── Coercion, Hindi ──
    'मुझे उससे डर लगता है': SafetyConcern.coercion,
    'वो धमकी देता है': SafetyConcern.coercion,
    'वो मुझे बाहर नहीं जाने देता': SafetyConcern.coercion,
    'मुझे कहीं जाने की इजाज़त नहीं है': SafetyConcern.coercion,

    // ── Self-harm, English ──
    'I want to hurt myself': SafetyConcern.selfHarm,
    'sometimes I think about killing myself': SafetyConcern.selfHarm,
    'I just want to end it all': SafetyConcern.selfHarm,
    'they would be better off without me': SafetyConcern.selfHarm,
    'I want to die': SafetyConcern.selfHarm,
    'I wish I was dead': SafetyConcern.selfHarm,
    'I have no reason to live': SafetyConcern.selfHarm,
    'I have been having suicidal thoughts': SafetyConcern.selfHarm,
    // ── Self-harm, Hindi ──
    'मैं जान दे दूँगी': SafetyConcern.selfHarm,
    'आत्महत्या का ख़याल आता है': SafetyConcern.selfHarm,
    'अब जीने का मन नहीं करता': SafetyConcern.selfHarm,
    'मैं मरना चाहता हूँ': SafetyConcern.selfHarm,
  };

  const mustNotFire = <String>[
    'we had the same fight about the dishes again',
    'he never helps with the housework',
    'my mother-in-law comments on everything I cook',
    'we have not talked properly in three weeks',
    'I am so angry I could scream',
    'money is tight and we keep snapping at each other',
    'he works late and I feel alone',
    'हम फिर उसी बात पर झगड़ पड़े',
    'वो देर से घर आता है और मैं अकेली रह जाती हूँ',
    'सास हर बात पर टोकती हैं',
    '',
    '   ',
  ];

  group('fires on disclosures', () {
    test('the scripted list is at least 40 phrases across both languages', () {
      expect(mustFire.length, greaterThanOrEqualTo(40 - mustNotFire.length));
      expect(mustFire.length + mustNotFire.length, greaterThanOrEqualTo(40));
    });

    mustFire.forEach((phrase, concern) {
      test('"$phrase"', () {
        final signal = classifier.screen(phrase);
        expect(signal, isNotNull,
            reason: 'this must show the safety interrupt');
        expect(signal!.concern, concern);
      });
    });

    test('is case-insensitive', () {
      expect(classifier.fires('HE HIT ME'), isTrue);
      expect(classifier.fires('I Want To Die'), isTrue);
    });

    test('matches mid-sentence, not just at the start', () {
      expect(
        classifier.fires('we argued about money and then he hit me and left'),
        isTrue,
      );
    });
  });

  group('stays quiet on ordinary conflict', () {
    for (final phrase in mustNotFire) {
      test('"$phrase"', () => expect(classifier.fires(phrase), isFalse));
    }
  });

  group('precedence', () {
    test('self-harm wins when a line contains more than one signal', () {
      // Whoever answers the phone should be answering the most urgent thing.
      final signal = classifier.screen('he hits me and I want to die');
      expect(signal!.concern, SafetyConcern.selfHarm);
    });
  });
}
