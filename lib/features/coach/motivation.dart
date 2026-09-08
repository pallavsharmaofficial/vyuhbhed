import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_state.dart';
import '../../theme/tokens.dart';
import '../../ui/glass.dart';

/// Where the candidate is right now; the line is chosen to fit it.
enum Moment {
  firstDay,
  lowEnergy,
  highEnergy,
  needToApply,
  applicationsDone,
  mockLow,
  mockHigh,
  rejected,
  offer,
  allDone,
  stuck,
}

/// Short, situation-aware lines in the register of shōnen anime — the
/// never-give-up, "my crew is behind me", one-more-round voice of One Piece,
/// Naruto and their kind.
///
/// These are ORIGINAL lines written in that spirit, not quotations. Actual
/// dialogue from those series is copyrighted and the names are trademarks;
/// shipping a quote database would be a legal problem for a paid app on Play.
/// The candidate can add their own favourite lines in Settings, which stay on
/// their phone.
class Motivation {
  Motivation._();

  static const _lines = <Moment, List<(String, String)>>{
    Moment.firstDay: [
      (
        'Every captain was once someone who simply refused to stay on shore. Today you set sail.',
        'हर कप्तान पहले वो था जिसने किनारे पर रुकने से इनकार किया। आज पाल खोलो।'
      ),
      (
        'The first training arc is always the ugliest. That is how you know it is working.',
        'पहला ट्रेनिंग आर्क हमेशा सबसे बदसूरत होता है। यही सबूत है कि काम हो रहा है।'
      ),
    ],
    Moment.lowEnergy: [
      (
        'Even the loudest ninja has days he cannot get off the floor. Do one small thing. One.',
        'सबसे शोर करने वाले निंजा के भी ऐसे दिन होते हैं। एक छोटा काम करो। बस एक।'
      ),
      (
        'Low chakra is not no chakra. Send one application and call it a win.',
        'कम चक्र, शून्य चक्र नहीं है। एक आवेदन भेजो और जीत मान लो।'
      ),
      (
        'Rest is part of the arc, not a break from it. Log the check-in; that already counts.',
        'आराम भी आर्क का हिस्सा है, उससे छुट्टी नहीं। चेक-इन लॉग करो; वह भी गिनती में है।'
      ),
    ],
    Moment.highEnergy: [
      (
        'You have got the fire today. Point it at the pipeline before it fades — applications first, no thinking.',
        'आज तुम्हारे अंदर आग है। बुझने से पहले पाइपलाइन पर लगाओ — पहले आवेदन, बिना सोचे।'
      ),
      (
        'This is a power-up day. Do the hardest mock round first.',
        'यह पावर-अप का दिन है। सबसे कठिन मॉक राउंड पहले करो।'
      ),
    ],
    Moment.needToApply: [
      (
        'A dream without a wanted poster is just a nap. Put your name out there.',
        'बिना वॉन्टेड पोस्टर का सपना बस एक झपकी है। अपना नाम बाहर रखो।'
      ),
      (
        'You do not need to feel ready. You need to press Apply. The feeling shows up later.',
        'तैयार महसूस करना ज़रूरी नहीं। Apply दबाना ज़रूरी है। भावना बाद में आती है।'
      ),
      (
        'Every rejection you have not received yet is standing between you and the offer. Go collect them.',
        'हर रिजेक्शन जो अभी नहीं मिला, तुम्हारे और ऑफ़र के बीच खड़ा है। जाओ, उन्हें बटोरो।'
      ),
    ],
    Moment.applicationsDone: [
      (
        'Quota met. The crew would be proud. Now sharpen the blade — one mock.',
        'कोटा पूरा। क्रू को गर्व होता। अब तलवार तेज़ करो — एक मॉक।'
      ),
    ],
    Moment.mockLow: [
      (
        'A low score in practice is the cheapest lesson you will ever buy. Read the stronger version twice, then go again.',
        'अभ्यास में कम स्कोर सबसे सस्ता सबक है। बेहतर रूप दो बार पढ़ो, फिर दोबारा।'
      ),
      (
        'Nobody clears the exam on the first try in any story worth telling. Again.',
        'किसी भी अच्छी कहानी में कोई पहली बार में परीक्षा नहीं पास करता। दोबारा।'
      ),
    ],
    Moment.mockHigh: [
      (
        'That is a real answer. Say it exactly like that in the room.',
        'यह असली जवाब है। कमरे में बिलकुल ऐसे ही कहो।'
      ),
      (
        'You just levelled up. Do not stop at one — the next question is the boss.',
        'तुम अभी लेवल-अप हुए। एक पर मत रुको — अगला सवाल बॉस है।'
      ),
    ],
    Moment.rejected: [
      (
        'They said no. Write down one thing you learned, then send two more before the sting fades. That is how arcs turn.',
        'उन्होंने ना कहा। एक बात लिखो जो सीखी, फिर चुभन मिटने से पहले दो और भेजो। आर्क ऐसे ही मुड़ते हैं।'
      ),
      (
        'A closed door is data. Your target is ten offers, not zero rejections.',
        'बंद दरवाज़ा डेटा है। तुम्हारा लक्ष्य दस ऑफ़र है, शून्य रिजेक्शन नहीं।'
      ),
    ],
    Moment.offer: [
      (
        'An offer in hand. Breathe — then keep sailing. Leverage is having more than one.',
        'हाथ में ऑफ़र। साँस लो — फिर पाल खुला रखो। ताक़त एक से ज़्यादा में है।'
      ),
    ],
    Moment.allDone: [
      (
        'Four for four. Close the app. Heroes rest too — that is how they are still standing in the final arc.',
        'चार में चार। ऐप बंद करो। नायक भी आराम करते हैं — इसीलिए वे आख़िरी आर्क में खड़े रहते हैं।'
      ),
    ],
    Moment.stuck: [
      (
        'Silence from recruiters is weather, not verdict. Change the resume, change the boards, keep the count.',
        'रिक्रूटरों की चुप्पी मौसम है, फ़ैसला नहीं। रिज़्यूमे बदलो, बोर्ड बदलो, गिनती जारी रखो।'
      ),
      (
        'The wall is where everyone else stopped. That is exactly why it is worth climbing.',
        'दीवार वही जगह है जहाँ बाक़ी सब रुक गए। इसीलिए चढ़ने लायक है।'
      ),
    ],
  };

  /// Deterministic for a given day so the line does not change on every
  /// rebuild — a motivational slot machine is noise, not encouragement.
  static String line(Moment m, {required bool hindi, DateTime? on}) {
    final options = _lines[m] ?? const [('Keep going.', 'चलते रहो।')];
    final day = (on ?? DateTime.now()).difference(DateTime(2026)).inDays;
    final (en, hi) = options[day % options.length];
    return hindi ? hi : en;
  }
}

/// A quiet card that carries the line for the current moment.
class MotivationBanner extends ConsumerWidget {
  const MotivationBanner({super.key, required this.moment});
  final Moment moment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hindi = ref.watch(appStateProvider.select((a) => a.isHindi));
    final tt = Theme.of(context).textTheme;
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.local_fire_department_outlined,
              size: 18, color: context.stage.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              Motivation.line(moment, hindi: hindi),
              style: tt.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic, color: context.surface.ink2),
            ),
          ),
        ],
      ),
    );
  }
}
