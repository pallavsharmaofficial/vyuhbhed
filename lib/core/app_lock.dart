import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import 'app_state.dart';
import 'key_value_store.dart';

@immutable
class AppLockState {
  const AppLockState({
    this.enabled = false,
    this.unlocked = false,
    this.available = true,
    this.checking = false,
  });

  /// Whether the user has asked for the lock.
  final bool enabled;

  /// Whether this session has been unlocked.
  final bool unlocked;

  /// False when the phone has no biometric or device credential set up.
  final bool available;

  final bool checking;

  /// True when the lock screen should be covering everything.
  bool get isBlocking => enabled && available && !unlocked;

  AppLockState copyWith({
    bool? enabled,
    bool? unlocked,
    bool? available,
    bool? checking,
  }) =>
      AppLockState(
        enabled: enabled ?? this.enabled,
        unlocked: unlocked ?? this.unlocked,
        available: available ?? this.available,
        checking: checking ?? this.checking,
      );
}

const _appLockKey = 'saath.appLock';

/// Biometric (or device passcode) lock over the whole app.
///
/// This is a safety feature before it is a privacy one. Saath is aimed partly
/// at people whose partner reads their phone, and a journal of everything
/// wrong with a relationship is exactly the thing that must not open with a
/// swipe.
///
/// The lock re-arms whenever the app is backgrounded — a lock that only
/// applies at cold start protects nobody.
class AppLock extends StateNotifier<AppLockState> {
  AppLock(this._store, {Authenticator? auth})
      : _auth = auth ?? const DeviceAuthenticator(),
        super(AppLockState(enabled: _store.getBool(_appLockKey) ?? false));

  final KeyValueStore _store;
  final Authenticator _auth;

  Future<bool> supported() async {
    try {
      return await _auth.isSupported();
    } on Object catch (error) {
      debugPrint('Saath: local_auth unavailable: $error');
      return false;
    }
  }

  Future<void> setEnabled(bool value) async {
    if (value) {
      // Prove it works before turning it on, so nobody discovers at the worst
      // moment that their phone cannot actually do this.
      if (!await supported()) {
        if (mounted) state = state.copyWith(available: false);
        return;
      }
      final ok = await authenticate(reason: 'Turn on the lock');
      if (!ok) return;
    }
    if (!mounted) return;
    state = state.copyWith(enabled: value, unlocked: true);
    await _store.setBool(_appLockKey, value);
  }

  Future<bool> authenticate({required String reason}) async {
    if (state.checking) return false;
    if (mounted) state = state.copyWith(checking: true);
    try {
      final ok = await _auth.authenticate(reason);
      if (mounted) state = state.copyWith(unlocked: ok, checking: false);
      return ok;
    } on Object catch (error) {
      debugPrint('Saath: authentication failed: $error');
      if (mounted) {
        state =
            state.copyWith(checking: false, available: false, unlocked: true);
      }
      return false;
    }
  }

  /// Called when the app goes to the background.
  void lock() {
    if (!state.enabled || !mounted) return;
    state = state.copyWith(unlocked: false);
  }

  /// Settings → Delete everything also clears the lock.
  Future<void> reset() async {
    await _store.remove(_appLockKey);
    if (mounted) state = const AppLockState(unlocked: true);
  }
}

/// The bit of local_auth the lock touches, behind an interface so it is
/// testable without a fingerprint sensor.
abstract class Authenticator {
  Future<bool> isSupported();
  Future<bool> authenticate(String reason);
}

class DeviceAuthenticator implements Authenticator {
  const DeviceAuthenticator();

  @override
  Future<bool> isSupported() => LocalAuthentication().isDeviceSupported();

  @override
  Future<bool> authenticate(String reason) =>
      LocalAuthentication().authenticate(
        localizedReason: reason,
        // Survives the OS backgrounding the app during the prompt rather than
        // failing the attempt.
        persistAcrossBackgrounding: true,
        // The device passcode is a fine fallback; requiring biometrics would lock
        // out anyone whose fingerprint sensor has stopped recognising them, which
        // is common on cheap hardware.
        biometricOnly: false,
      );
}

final appLockProvider = StateNotifierProvider<AppLock, AppLockState>(
  (ref) => AppLock(ref.watch(keyValueStoreProvider)),
);
