import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_lock.dart';
import '../core/strings.dart';
import '../theme/theme.dart';
import '../theme/tokens.dart';
import '../ui/atmosphere.dart';
import '../ui/glass.dart';

/// Covers the whole app while it is locked, and re-arms the lock whenever the
/// app is backgrounded.
///
/// Sits above the router rather than on a route, for two reasons: a lock a
/// deep link can route around is not a lock, and the screen underneath must
/// never render — the app switcher screenshot is exactly what someone
/// searching a partner's phone will see.
class LockGate extends ConsumerStatefulWidget {
  const LockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<LockGate> createState() => _LockGateState();
}

class _LockGateState extends ConsumerState<LockGate>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _promptIfLocked());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A lock that only applies at cold start protects nobody: the phone gets
    // picked up while the app is still in the switcher.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      ref.read(appLockProvider.notifier).lock();
    }
    if (state == AppLifecycleState.resumed) {
      _promptIfLocked();
    }
  }

  Future<void> _promptIfLocked() async {
    final lock = ref.read(appLockProvider);
    if (!lock.isBlocking || lock.checking) return;
    if (!mounted) return;
    await ref
        .read(appLockProvider.notifier)
        .authenticate(reason: S.readWidget(ref).appLockPrompt);
  }

  @override
  Widget build(BuildContext context) {
    final lock = ref.watch(appLockProvider);
    if (!lock.isBlocking) return widget.child;

    return _LockScreen(onUnlock: _promptIfLocked, checking: lock.checking);
  }
}

class _LockScreen extends ConsumerWidget {
  const _LockScreen({required this.onUnlock, required this.checking});

  final Future<void> Function() onUnlock;
  final bool checking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context, ref);

    // Its own Theme and Directionality: this sits above MaterialApp, so there
    // is nothing inherited to lean on.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Theme(
        data: buildTheme(MediaQuery.platformBrightnessOf(context)),
        child: StageTheme(
          stage: ResolutionStage.calm,
          child: Builder(
            builder: (context) => Scaffold(
              body: Atmosphere(
                background: Backgrounds.calm,
                child: SafeArea(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.lock_outline_rounded,
                            size: 36,
                            color: context.stage.accent,
                          ),
                          const SizedBox(height: 18),
                          Text(
                            s.appLockLocked,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 24),
                          GlassButton(
                            label: s.appLockUnlock,
                            expand: false,
                            onPressed: checking ? null : () => onUnlock(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
