import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/coach/coach_strings.dart';
import '../ui/glass.dart';

/// Tab shell: Today, Track, Practice, Coach.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = T.of(context, ref);
    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: GlassTabBar(
        index: navigationShell.currentIndex,
        onChanged: (i) => navigationShell.goBranch(
          i,
          initialLocation: i == navigationShell.currentIndex,
        ),
        items: [
          (icon: Icons.today_outlined, label: t.tabToday),
          (icon: Icons.view_kanban_outlined, label: t.tabTrack),
          (icon: Icons.record_voice_over_outlined, label: t.tabPractice),
          (icon: Icons.support_agent_rounded, label: t.tabCoach),
        ],
      ),
    );
  }
}
