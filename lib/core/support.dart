/// The one place Saath asks for money, and the rules around it.
///
/// **No ads, ever.** Not a stylistic preference — an ad SDK is a tracking SDK,
/// and "nothing leaves this phone" is not a marketing line here, it is the
/// reason someone types the truth into a relationship app. An ad network next
/// to a disclosure of abuse would also be indefensible on its own terms.
///
/// **No paywall on the core.** The counsellor runs on the device and costs
/// nothing to operate. There is no bill to pass on, so there is no honest
/// reason to charge for it.
///
/// What is left is asking, quietly, of people who are doing fine. So:
///
/// * It appears in Settings only. Never a popup, never an interstitial, never
///   at the end of a hard conversation, and never on or near the safety
///   screen — someone reading helpline numbers is not a conversion funnel.
/// * It is absent unless a URL is configured, rather than shipping a dead
///   button or a placeholder payment handle.
///
/// Configure at build time:
///
///     flutter build appbundle --release \
///       --dart-define=SAATH_SUPPORT_URL=https://your-payment-link
///
/// A hosted payment page works everywhere. A raw `upi://pay?pa=...` link opens
/// the UPI chooser on Android but does nothing on iOS or the web, so use that
/// only for an Android-only build.
class SupportLink {
  SupportLink._();

  static const url = String.fromEnvironment('SAATH_SUPPORT_URL');

  static bool get isConfigured => url.trim().isNotEmpty;

  /// Guards against a build defining something that is not a link we should
  /// open — `javascript:` on the web build in particular.
  static bool get isSafe {
    if (!isConfigured) return false;
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme) return false;
    return const {'https', 'upi'}.contains(uri.scheme.toLowerCase());
  }
}
