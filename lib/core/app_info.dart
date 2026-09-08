/// Build identity, kept in one place.
///
/// [version] and [buildNumber] must match `version:` in pubspec.yaml.
/// `test/app_info_test.dart` asserts that, because a Settings screen quietly
/// reporting the wrong version turns every beta bug report into a guess.
class AppInfo {
  AppInfo._();

  static const version = '0.2.0';
  static const buildNumber = 2;

  static const displayVersion = '$version ($buildNumber)';

  /// Shown in Settings → About, as the Gemma Terms of Use require once the
  /// model ships. Kept here now so it cannot be forgotten at launch.
  static const modelAttribution =
      'The on-device counsellor will run Gemma, provided by Google under the '
      'Gemma Terms of Use. Saath is not affiliated with or endorsed by Google.';
}
