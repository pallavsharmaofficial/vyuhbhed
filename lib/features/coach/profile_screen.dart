import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/router.dart';
import '../../core/app_state.dart';
import '../../core/strings.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.dart';
import '../../ui/atmosphere.dart';
import '../../ui/glass.dart';
import 'coach_strings.dart';
import 'profile.dart';

/// The goal sheet. Onboarding step 2, and Settings → Edit profile.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, this.duringOnboarding = false});
  final bool duringOnboarding;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final TextEditingController _name;
  late final TextEditingController _current;
  late final TextEditingController _target;
  late final TextEditingController _location;
  late final TextEditingController _skills;
  late int _years;
  late int _offers;
  late int _perDay;
  DateTime? _noticeEnd;

  @override
  void initState() {
    super.initState();
    final p = ref.read(profileProvider);
    _name = TextEditingController(text: p.name);
    _current = TextEditingController(text: p.currentRole);
    _target = TextEditingController(text: p.targetRole);
    _location = TextEditingController(text: p.location);
    _skills = TextEditingController(text: p.skills);
    _years = p.yearsExperience;
    _offers = p.targetOffers;
    _perDay = p.applicationsPerDay;
    _noticeEnd = p.noticeEnd;
  }

  @override
  void dispose() {
    for (final c in [_name, _current, _target, _location, _skills]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _ready => _target.text.trim().isNotEmpty;

  Future<void> _save() async {
    await ref.read(profileProvider.notifier).save(CoachProfile(
          name: _name.text.trim(),
          currentRole: _current.text.trim(),
          targetRole: _target.text.trim(),
          yearsExperience: _years,
          location: _location.text.trim(),
          skills: _skills.text.trim(),
          noticeEnd: _noticeEnd,
          targetOffers: _offers,
          applicationsPerDay: _perDay,
        ));
    if (!mounted) return;
    if (widget.duringOnboarding) {
      context.push(Routes.onboardingModel);
    } else {
      context.pop();
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _noticeEnd ?? now.add(const Duration(days: 60)),
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _noticeEnd = picked);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context, ref);
    final t = T.of(context, ref);
    final tt = Theme.of(context).textTheme;
    final surface = context.surface;
    final lang = ref.watch(appStateProvider.select((a) => a.language.code));

    return StageTheme(
      stage: ResolutionStage.working,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: Atmosphere(
          background: Backgrounds.today,
          child: Column(
            children: [
              GlassTopBar(
                title: widget.duringOnboarding ? s.stepOf(2, 3) : t.editProfile,
                onBack: () => context.pop(),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  children: [
                    Text(t.profileTitle, style: tt.headlineMedium),
                    const SizedBox(height: 18),
                    GlassPanel(
                      strong: true,
                      child: Column(
                        children: [
                          _Field(
                              controller: _name,
                              label: t.yourName,
                              onChanged: (_) => setState(() {})),
                          const SizedBox(height: 12),
                          _Field(
                              controller: _target,
                              label: t.targetRole,
                              hint: t.targetRoleHint,
                              onChanged: (_) => setState(() {})),
                          const SizedBox(height: 12),
                          _Field(
                              controller: _current,
                              label: t.currentRole,
                              onChanged: (_) => setState(() {})),
                          const SizedBox(height: 12),
                          _Field(
                              controller: _location,
                              label: t.location,
                              onChanged: (_) => setState(() {})),
                          const SizedBox(height: 12),
                          _Field(
                              controller: _skills,
                              label: t.skills,
                              onChanged: (_) => setState(() {}),
                              maxLines: 2),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _Stepper(
                        label: t.years,
                        value: _years,
                        min: 0,
                        max: 40,
                        onChanged: (v) => setState(() => _years = v)),
                    const SizedBox(height: 10),
                    _Stepper(
                        label: t.applicationsPerDay,
                        value: _perDay,
                        min: 1,
                        max: 30,
                        onChanged: (v) => setState(() => _perDay = v)),
                    const SizedBox(height: 10),
                    _Stepper(
                        label: t.targetOffers,
                        value: _offers,
                        min: 1,
                        max: 30,
                        onChanged: (v) => setState(() => _offers = v)),
                    const SizedBox(height: 18),
                    Eyebrow(t.noticeEnd),
                    const SizedBox(height: 10),
                    GlassChip(
                      label: _noticeEnd == null
                          ? t.noticeEndPick
                          : DateFormat('d MMM yyyy', lang).format(_noticeEnd!),
                      icon: Icons.event_outlined,
                      active: _noticeEnd != null,
                      onTap: _pickDate,
                    ),
                    const SizedBox(height: 8),
                    Text(s.freePrivateOffline,
                        style: tt.bodySmall
                            ?.copyWith(fontSize: 12, color: surface.ink2)),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                    24, 0, 24, MediaQuery.paddingOf(context).bottom + 20),
                child: GlassButton(
                  label: widget.duringOnboarding ? t.startCampaign : s.save,
                  onPressed: _ready ? _save : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field(
      {required this.controller,
      required this.label,
      required this.onChanged,
      this.hint,
      this.maxLines = 1});
  final TextEditingController controller;
  final String label;
  final String? hint;
  final int maxLines;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    OutlineInputBorder border(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c));
    return TextField(
      controller: controller,
      onChanged: onChanged,
      maxLines: maxLines,
      textCapitalization: TextCapitalization.words,
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: surface.ink2),
        hintStyle: TextStyle(color: surface.ink2),
        filled: true,
        fillColor: surface.glassSoft,
        border: border(surface.glassBorder),
        enabledBorder: border(surface.glassBorder),
        focusedBorder: border(context.stage.accent),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper(
      {required this.label,
      required this.value,
      required this.min,
      required this.max,
      required this.onChanged});
  final String label;
  final int value, min, max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: tt.bodyLarge)),
          IconButton(
            tooltip: '−',
            onPressed: value > min ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove_rounded),
          ),
          SizedBox(
            width: 36,
            child: Text('$value',
                textAlign: TextAlign.center,
                style: tt.titleMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()])),
          ),
          IconButton(
            tooltip: '+',
            onPressed: value < max ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}
