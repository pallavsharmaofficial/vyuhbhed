import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/theme.dart';
import '../../theme/tokens.dart';
import '../../ui/atmosphere.dart';
import '../../ui/glass.dart';
import 'coach_strings.dart';
import 'profile.dart';

/// Every job board, one query. No scraping, no server: each button is a deep
/// link with the candidate's role and city already in the search box.
class JobsScreen extends ConsumerStatefulWidget {
  const JobsScreen({super.key});

  @override
  ConsumerState<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends ConsumerState<JobsScreen> {
  late final TextEditingController _role;
  late final TextEditingController _city;
  bool _remote = false;

  @override
  void initState() {
    super.initState();
    final p = ref.read(profileProvider);
    _role = TextEditingController(text: p.targetRole);
    _city = TextEditingController(text: p.location);
    _remote = p.location.toLowerCase().contains('remote');
  }

  @override
  void dispose() {
    _role.dispose();
    _city.dispose();
    super.dispose();
  }

  String get _q => _role.text.trim();
  String get _loc => _remote ? 'Remote' : _city.text.trim();

  /// Built from each site's public search URL shape. If a site changes its
  /// parameters the link still lands on its search page, just unfilled.
  List<(String, IconData, Uri)> _boards() {
    final q = _q;
    final loc = _loc;
    const enc = Uri.encodeComponent;
    final slug = q
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    final locSlug = loc
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return [
      (
        'LinkedIn',
        Icons.work_outline_rounded,
        Uri.parse(
            'https://www.linkedin.com/jobs/search/?keywords=${enc(q)}&location=${enc(loc.isEmpty ? 'India' : loc)}&f_TPR=r604800')
      ),
      (
        'Naukri',
        Icons.business_center_outlined,
        Uri.parse(
            'https://www.naukri.com/$slug-jobs${locSlug.isEmpty ? '' : '-in-$locSlug'}')
      ),
      (
        'Indeed',
        Icons.search_rounded,
        Uri.parse(
            'https://in.indeed.com/jobs?q=${enc(q)}&l=${enc(loc)}&fromage=7')
      ),
      (
        'Wellfound',
        Icons.rocket_launch_outlined,
        Uri.parse('https://wellfound.com/jobs?q=${enc(q)}')
      ),
      (
        'Instahyre',
        Icons.bolt_outlined,
        Uri.parse('https://www.instahyre.com/search-jobs/?q=${enc(q)}')
      ),
      (
        'Glassdoor',
        Icons.door_front_door_outlined,
        Uri.parse(
            'https://www.glassdoor.co.in/Job/jobs.htm?sc.keyword=${enc(q)}&locKeyword=${enc(loc)}')
      ),
      (
        'Google Jobs',
        Icons.travel_explore_rounded,
        Uri.parse(
            'https://www.google.com/search?q=${enc('$q jobs ${loc.isEmpty ? 'India' : loc}')}&ibp=htl;jobs')
      ),
      (
        'Cutshort',
        Icons.content_cut_rounded,
        Uri.parse('https://cutshort.io/jobs?q=${enc(q)}')
      ),
    ];
  }

  Future<void> _open(Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication)
        .catchError((Object _) => false);
    if (ok || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(T.readWidget(ref).couldNotOpen)));
  }

  @override
  Widget build(BuildContext context) {
    final t = T.of(context, ref);
    final tt = Theme.of(context).textTheme;
    final surface = context.surface;
    OutlineInputBorder border(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c));
    InputDecoration deco(String label) => InputDecoration(
          labelText: label,
          isDense: true,
          labelStyle: TextStyle(color: surface.ink2),
          filled: true,
          fillColor: surface.glassSoft,
          border: border(surface.glassBorder),
          enabledBorder: border(surface.glassBorder),
          focusedBorder: border(context.stage.accent),
        );

    return StageTheme(
      stage: ResolutionStage.working,
      child: Scaffold(
        body: Atmosphere(
          background: Backgrounds.working,
          child: Column(
            children: [
              GlassTopBar(title: t.jobsTitle, onBack: () => context.pop()),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 6, 24, 40),
                  children: [
                    Text(t.jobsBody,
                        style: tt.bodySmall
                            ?.copyWith(fontSize: 15, color: surface.ink2)),
                    const SizedBox(height: 14),
                    GlassPanel(
                      strong: true,
                      child: Column(children: [
                        TextField(
                            controller: _role,
                            decoration: deco(t.searchRole),
                            onChanged: (_) => setState(() {})),
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(
                            child: TextField(
                              controller: _city,
                              enabled: !_remote,
                              decoration: deco(t.searchCity),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 10),
                          GlassChip(
                            label: t.remoteOnly,
                            icon: Icons.home_work_outlined,
                            active: _remote,
                            selectable: true,
                            onTap: () => setState(() => _remote = !_remote),
                          ),
                        ]),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    for (final (name, icon, uri) in _boards()) ...[
                      GlassButton(
                        label: name,
                        icon: icon,
                        primary: false,
                        onPressed: _q.isEmpty ? null : () => _open(uri),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
