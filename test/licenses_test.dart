import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The three bundled typefaces are SIL OFL 1.1 with three different copyright
/// holders. Shipping the fonts without all three notices is a licence
/// violation, and it is the kind that nobody notices until someone does.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the bundled OFL covers every family that ships', () async {
    final text = await rootBundle.loadString('assets/fonts/OFL.txt');

    expect(text, contains('Sora Project Authors'));
    expect(text, contains('Source Serif 4 Project Authors'));
    expect(text, contains('Noto Project Authors'));

    // Three complete licences, not one with three names pasted on top.
    // (String implements Pattern, so this is a literal substring count.)
    expect('SIL OPEN FONT LICENSE Version 1.1'.allMatches(text).length, 3);
  });

  test('it explains that the files are subsets', () async {
    // The OFL allows modification; being silent about it is what invites the
    // question later.
    final text = await rootBundle.loadString('assets/fonts/OFL.txt');
    expect(text.toLowerCase(), contains('subset'));
  });
}
