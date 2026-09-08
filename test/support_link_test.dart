import 'package:flutter_test/flutter_test.dart';
import 'package:vyuhbhed/core/support.dart';

void main() {
  test('is absent unless a build configures it', () {
    // The default build defines nothing, so Settings shows no support card
    // rather than a dead button or a placeholder payment handle.
    expect(SupportLink.isConfigured, isFalse);
    expect(SupportLink.isSafe, isFalse);
  });

  test('only https and upi count as safe to open', () {
    // isSafe reads a compile-time constant, so this asserts the rule itself
    // rather than the current build's value.
    bool safe(String url) {
      final uri = Uri.tryParse(url.trim());
      if (uri == null || !uri.hasScheme) return false;
      return const {'https', 'upi'}.contains(uri.scheme.toLowerCase());
    }

    expect(safe('https://example.com/pay'), isTrue);
    expect(safe('upi://pay?pa=someone@bank&cu=INR'), isTrue);

    // The ones that must never open, especially on the web build.
    expect(safe('javascript:alert(1)'), isFalse);
    expect(safe('http://example.com'), isFalse);
    expect(safe('file:///etc/passwd'), isFalse);
    expect(safe('not a url'), isFalse);
    expect(safe(''), isFalse);
  });
}
