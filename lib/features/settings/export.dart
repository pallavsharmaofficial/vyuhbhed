import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_info.dart';
import '../../core/app_state.dart';
import '../../core/couple_space.dart';
import '../../core/journal.dart';
import '../../core/strings.dart';
import '../../theme/tokens.dart';
import '../../ui/glass.dart';
import 'settings_screen.dart' show copyToClipboard;

/// Builds the complete export payload.
///
/// This is deliberately *everything* Saath holds, in one readable object: if
/// the privacy claim is real, the export has to be small enough to read and
/// complete enough to be the whole story.
String buildExportJson({
  required AppState app,
  required List<JournalEntry> journal,
  CoupleSpace couple = const CoupleSpace(),
}) {
  final payload = <String, Object?>{
    'app': 'Saath',
    'version': AppInfo.displayVersion,
    'exportedAt': DateTime.now().toIso8601String(),
    'note':
        'This is the complete contents of Saath on this device. Nothing is stored anywhere else.',
    'profile': app.toJson(),
    'journal': [for (final e in journal) e.toJson()],
    'us': couple.toJson(),
  };
  return const JsonEncoder.withIndent('  ').convert(payload);
}

Future<void> showExportSheet(BuildContext context, WidgetRef ref) {
  final s = S.of(context, ref);
  final json = buildExportJson(
    app: ref.read(appStateProvider),
    journal: ref.read(journalProvider),
    couple: ref.read(coupleSpaceProvider),
  );
  final surface = context.surface;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: surface.bg,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 0, 20, MediaQuery.paddingOf(context).bottom + 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.exportTitle,
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(s.exportBody,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontSize: 14, color: surface.ink2)),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: surface.glassSoft,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: surface.hairline),
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(14),
                  child: SelectableText(
                    json,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontFamilyFallback: const [
                        'Menlo',
                        'Roboto Mono',
                        'monospace'
                      ],
                      fontSize: 12,
                      height: 1.4,
                      color: surface.ink,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            GlassButton(
              label: s.copy,
              icon: Icons.content_copy_rounded,
              onPressed: () => copyToClipboard(context, json, s.copied),
            ),
          ],
        ),
      ),
    ),
  );
}
