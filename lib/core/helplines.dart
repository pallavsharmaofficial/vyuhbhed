import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// A number the safety screen can dial.
///
/// [lastVerified] exists so the launch checklist item "helpline numbers
/// verified the week of launch" has something to check against, and so a stale
/// number is visible in code review rather than only when someone in trouble
/// dials it. Re-verify every release; see [Helplines.verifiedOn].
@immutable
class Helpline {
  const Helpline({
    required this.name,
    required this.nameHi,
    required this.number,
    required this.hours,
    required this.hoursHi,
  });

  final String name;
  final String nameHi;

  /// Digits only, no spaces or dashes — this is what gets dialled.
  final String number;
  final String hours;
  final String hoursHi;

  String displayName(bool hindi) => hindi ? nameHi : name;
  String displayHours(bool hindi) => hindi ? hoursHi : hours;

  /// Grouped in threes/fours for reading; never used for dialling.
  String get prettyNumber {
    if (number.length <= 5) return number;
    if (number.length == 10) {
      return '${number.substring(0, 5)} ${number.substring(5)}';
    }
    return number;
  }
}

class Helplines {
  Helplines._();

  /// Bump this whenever the numbers below are re-checked against the
  /// operators' own published pages. Shown in Settings → About.
  static final DateTime verifiedOn = DateTime(2026, 9, 6);

  /// Ordered by who is most likely to help first: a trained counsellor, then
  /// the 24×7 lines, then the state.
  static const all = <Helpline>[
    Helpline(
      name: 'Tele-MANAS',
      nameHi: 'टेली-मानस',
      number: '14416',
      hours: 'Free · 24×7 · 20 languages',
      hoursHi: 'मुफ़्त · 24×7 · 20 भाषाएँ',
    ),
    Helpline(
      name: 'iCall (TISS)',
      nameHi: 'आईकॉल (TISS)',
      number: '9152987821',
      hours: 'Counsellors · Mon–Sat, 10am–8pm',
      hoursHi: 'काउंसलर · सोम–शनि, सुबह 10 – रात 8',
    ),
    Helpline(
      name: 'Vandrevala Foundation',
      nameHi: 'वंद्रेवाला फ़ाउंडेशन',
      number: '9999666555',
      hours: 'Free · 24×7',
      hoursHi: 'मुफ़्त · 24×7',
    ),
    Helpline(
      name: 'Women’s Helpline (NCW)',
      nameHi: 'महिला हेल्पलाइन (NCW)',
      number: '7827170170',
      hours: '24×7',
      hoursHi: '24×7',
    ),
    Helpline(
      name: 'Emergency',
      nameHi: 'आपातकाल',
      number: '112',
      hours: 'Police, ambulance, fire',
      hoursHi: 'पुलिस, एम्बुलेंस, दमकल',
    ),
  ];
}

/// Opens the dialler with [number] pre-filled. Never places the call itself —
/// the last tap belongs to the person, who may be standing next to someone.
///
/// Returns false when no dialler is available (a tablet, an emulator), so the
/// caller can show the number as text instead of failing silently.
Future<bool> dialHelpline(String number,
    {Future<bool> Function(Uri)? launcher}) async {
  final uri = Uri(scheme: 'tel', path: number);
  try {
    return await (launcher ?? _defaultLauncher)(uri);
  } on Object {
    // A missing dialler throws PlatformException on some OEM Android builds
    // rather than returning false. Either way the caller shows the number.
    return false;
  }
}

Future<bool> _defaultLauncher(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);
