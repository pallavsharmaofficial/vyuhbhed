import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vyuhbhed/core/app_info.dart';

void main() {
  test('the version shown in Settings matches the one that ships', () {
    // A Settings screen quietly reporting the wrong version turns every beta
    // bug report into a guess about which build it came from.
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(r'^version:\s*([\d.]+)\+(\d+)\s*$', multiLine: true)
        .firstMatch(pubspec);

    expect(match, isNotNull,
        reason: 'pubspec.yaml must declare version: x.y.z+n');
    expect(AppInfo.version, match!.group(1));
    expect(AppInfo.buildNumber.toString(), match.group(2));
  });

  test('the Gemma attribution is present for the Terms of Use', () {
    expect(AppInfo.modelAttribution, contains('Gemma'));
    expect(AppInfo.modelAttribution, contains('Google'));
  });
}
