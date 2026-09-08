import 'package:flutter_test/flutter_test.dart';
import 'package:vyuhbhed/core/key_value_store.dart';
import 'package:vyuhbhed/features/coach/coach_engine.dart';
import 'package:vyuhbhed/features/coach/profile.dart';
import 'package:vyuhbhed/features/coach/tracker.dart';

void main() {
  final engine = MockCoachEngine(delay: Duration.zero);
  const profile = CoachProfile(
      name: 'Asha', targetRole: 'Senior Flutter Developer', yearsExperience: 6);

  test('the mock produces questions, a score and a resume review', () async {
    final qs = await engine.questions(const QuestionsRequest(
        profile: profile, round: InterviewRound.hr, hindi: false));
    expect(qs, hasLength(5));
    final score = await engine.score(
        question: qs.first,
        answer: 'I am a Flutter dev.',
        profile: profile,
        hindi: false);
    expect(score.total, inInclusiveRange(2, 10));
    final review = await engine.reviewResume(ResumeRequest(
        resume: 'x' * 400, jobDescription: '', profile: profile, hindi: true));
    expect(review.fixes, isNotEmpty);
    expect(await engine.ask(question: 'help', profile: profile, hindi: false),
        isNotEmpty);
  });

  test('AnswerScore clamps garbage into 1..5', () {
    final s = AnswerScore.fromJson({
      'structure': 9,
      'specificity': -3,
      'feedback': 'x',
      'strongerAnswer': 'y'
    });
    expect(s?.structure, 5);
    expect(s?.specificity, 1);
  });

  test('profile round-trips through the store, including the notice date',
      () async {
    final store = InMemoryStore();
    final p = ProfileStore(store);
    await p.save(profile.copyWith(
        noticeEnd: DateTime(2026, 10, 31), applicationsPerDay: 7));
    final loaded = ProfileStore.load(store);
    expect(loaded.targetRole, 'Senior Flutter Developer');
    expect(loaded.noticeEnd, DateTime(2026, 10, 31));
    expect(loaded.applicationsPerDay, 7);
    expect(loaded, equals(p.state));
  });

  test('applications and mocks persist; stage moves update the funnel',
      () async {
    final store = InMemoryStore();
    final apps = ApplicationStore(store);
    final a = await apps.add(company: 'Zeta', role: 'Flutter Lead');
    await apps.setStage(a.id, AppStage.offer);
    expect(ApplicationStore.load(store).single.stage, AppStage.offer);

    final mocks = MockStore(store);
    await mocks.add(
        round: InterviewRound.technical,
        inApp: true,
        questions: 6,
        scores: [7, 8, 9]);
    expect(MockStore.load(store).single.average, 8.0);
  });

  test('the daily plan asks for check-in first, then applications', () {
    const plan = DailyPlan(
      applicationsTarget: 5,
      applicationsDone: 0,
      mockDone: false,
      learnDone: false,
      checkedIn: false,
      offers: 0,
      targetOffers: 10,
      daysLeft: 30,
      openPipeline: 0,
    );
    expect(plan.next, NextAction.checkIn);
    const plan2 = DailyPlan(
      applicationsTarget: 5,
      applicationsDone: 5,
      mockDone: true,
      learnDone: true,
      checkedIn: true,
      offers: 1,
      targetOffers: 10,
      daysLeft: 30,
      openPipeline: 3,
    );
    expect(plan2.next, NextAction.rest);
    expect(plan2.stepsDone, 4);
  });
}
