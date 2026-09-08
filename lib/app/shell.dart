import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/strings.dart';
import '../ui/glass.dart';

/// Tab shell: the floating glass tab bar over whichever tab is active.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context, ref);
    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: GlassTabBar(
        index: navigationShell.currentIndex,
        onChanged: (i) => navigationShell.goBranch(
          i,
          // Tapping the tab you are already on pops that branch back to its
          // root, which is what both platforms' users expect.
          initialLocation: i == navigationShell.currentIndex,
        ),
        items: [
          (icon: Icons.home_outlined, label: s.tabToday),
          (icon: Icons.chat_bubble_outline_rounded, label: s.tabCounsellor),
          (icon: Icons.people_outline_rounded, label: s.tabUs),
          (icon: Icons.menu_book_outlined, label: s.tabLearn),
        ],
      ),
    );
  }
}
