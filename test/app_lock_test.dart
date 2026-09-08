import 'package:flutter_test/flutter_test.dart';
import 'package:vyuhbhed/core/app_lock.dart';
import 'package:vyuhbhed/core/key_value_store.dart';

/// Stand-in for the platform authenticator.
class _FakeAuth implements Authenticator {
  _FakeAuth({this.supported = true, this.succeeds = true, this.throws = false});

  bool supported;
  bool succeeds;
  bool throws;
  int prompts = 0;

  @override
  Future<bool> isSupported() async {
    if (throws) throw StateError('no secure hardware');
    return supported;
  }

  @override
  Future<bool> authenticate(String reason) async {
    prompts++;
    if (throws) throw StateError('no secure hardware');
    return succeeds;
  }
}

void main() {
  test('is off by default, so nothing is blocking', () {
    final lock = AppLock(InMemoryStore(), auth: _FakeAuth());
    addTearDown(lock.dispose);
    expect(lock.state.enabled, isFalse);
    expect(lock.state.isBlocking, isFalse);
  });

  test('turning it on proves it works first', () async {
    final auth = _FakeAuth();
    final store = InMemoryStore();
    final lock = AppLock(store, auth: auth);
    addTearDown(lock.dispose);

    await lock.setEnabled(true);

    // Nobody should discover at the worst moment that their phone cannot do
    // this: the prompt runs before the setting sticks.
    expect(auth.prompts, 1);
    expect(lock.state.enabled, isTrue);
    expect(store.getBool('saath.appLock'), isTrue);
  });

  test('a refused prompt leaves the lock off', () async {
    final store = InMemoryStore();
    final lock = AppLock(store, auth: _FakeAuth(succeeds: false));
    addTearDown(lock.dispose);

    await lock.setEnabled(true);

    expect(lock.state.enabled, isFalse);
    expect(store.getBool('saath.appLock'), isNull);
  });

  test('a phone with no screen lock says so instead of failing silently',
      () async {
    final lock = AppLock(InMemoryStore(), auth: _FakeAuth(supported: false));
    addTearDown(lock.dispose);

    await lock.setEnabled(true);

    expect(lock.state.enabled, isFalse);
    expect(lock.state.available, isFalse);
    expect(lock.state.isBlocking, isFalse, reason: 'never lock someone out');
  });

  test('backgrounding re-arms the lock', () async {
    final store = InMemoryStore({'saath.appLock': true});
    final lock = AppLock(store, auth: _FakeAuth());
    addTearDown(lock.dispose);

    await lock.authenticate(reason: 'test');
    expect(lock.state.isBlocking, isFalse);

    // A lock that only applies at cold start protects nobody.
    lock.lock();
    expect(lock.state.isBlocking, isTrue);
  });

  test('an enabled lock blocks on a fresh launch', () {
    final lock = AppLock(
      InMemoryStore({'saath.appLock': true}),
      auth: _FakeAuth(),
    );
    addTearDown(lock.dispose);
    expect(lock.state.isBlocking, isTrue);
  });

  test('a throwing authenticator unlocks rather than bricking the app',
      () async {
    final lock = AppLock(
      InMemoryStore({'saath.appLock': true}),
      auth: _FakeAuth(throws: true),
    );
    addTearDown(lock.dispose);

    await lock.authenticate(reason: 'test');

    // Losing the journal behind a broken sensor is worse than the lock being
    // unavailable.
    expect(lock.state.isBlocking, isFalse);
  });

  test('reset clears the setting', () async {
    final store = InMemoryStore({'saath.appLock': true});
    final lock = AppLock(store, auth: _FakeAuth());
    addTearDown(lock.dispose);

    await lock.reset();

    expect(lock.state.enabled, isFalse);
    expect(store.getBool('saath.appLock'), isNull);
  });
}
