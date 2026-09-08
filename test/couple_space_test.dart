import 'package:flutter_test/flutter_test.dart';
import 'package:vyuhbhed/core/couple_space.dart';
import 'package:vyuhbhed/core/key_value_store.dart';

void main() {
  late InMemoryStore store;
  late CoupleSpaceStore couple;

  setUp(() {
    store = InMemoryStore();
    couple = CoupleSpaceStore(store);
    addTearDown(couple.dispose);
  });

  group('love map', () {
    test('stores an answer against its prompt and survives a relaunch',
        () async {
      await couple.setFact(
          prompt: 'What worries them?', answer: '  his mother  ');

      expect(couple.answerFor('What worries them?'), 'his mother');
      expect(
        CoupleSpaceStore.load(store).loveMap.single.answer,
        'his mother',
      );
    });

    test('editing replaces rather than duplicating', () async {
      await couple.setFact(prompt: 'q', answer: 'first');
      await couple.setFact(prompt: 'q', answer: 'second');

      expect(couple.state.loveMap, hasLength(1));
      expect(couple.answerFor('q'), 'second');
    });

    test('keeps its id across edits, so a future sync can match rows',
        () async {
      await couple.setFact(prompt: 'q', answer: 'first');
      final id = couple.state.loveMap.single.id;
      await couple.setFact(prompt: 'q', answer: 'second');

      expect(couple.state.loveMap.single.id, id);
    });

    test('an emptied answer removes the fact rather than storing a blank',
        () async {
      await couple.setFact(prompt: 'q', answer: 'something');
      await couple.setFact(prompt: 'q', answer: '   ');

      expect(couple.state.loveMap, isEmpty);
      expect(couple.answerFor('q'), isNull);
    });

    test(
        'stores the prompt text, so changing the list later does not rewrite '
        'what someone answered', () async {
      await couple.setFact(prompt: 'the original wording', answer: 'a');
      expect(
        CoupleSpaceStore.load(store).loveMap.single.prompt,
        'the original wording',
      );
    });
  });

  group('goals', () {
    test('adds, toggles and removes', () async {
      await couple.addGoal('One phone-free dinner');
      final id = couple.state.goals.single.id;
      expect(couple.state.openGoals, hasLength(1));

      await couple.toggleGoal(id);
      expect(couple.state.goals.single.isDone, isTrue);
      expect(couple.state.openGoals, isEmpty);

      await couple.toggleGoal(id);
      expect(couple.state.goals.single.isDone, isFalse);

      await couple.removeGoal(id);
      expect(couple.state.goals, isEmpty);
    });

    test('ignores an empty goal', () async {
      await couple.addGoal('   ');
      expect(couple.state.goals, isEmpty);
    });

    test('persists', () async {
      await couple.addGoal('walk after dinner');
      expect(
          CoupleSpaceStore.load(store).goals.single.text, 'walk after dinner');
    });
  });

  group('important dates', () {
    test('counts days to the next occurrence', () {
      final now = DateTime(2026, 9, 6);
      const date =
          ImportantDate(id: '1', label: 'Anniversary', month: 9, day: 10);
      expect(date.daysUntil(now), 4);
    });

    test('rolls over to next year once the day has passed', () {
      final now = DateTime(2026, 9, 6);
      const date = ImportantDate(id: '1', label: 'Birthday', month: 3, day: 1);
      // Not "-189 days ago".
      expect(date.daysUntil(now), greaterThan(0));
      expect(date.daysUntil(now), lessThan(366));
    });

    test('today is zero days away, not a year', () {
      final now = DateTime(2026, 9, 6, 23, 30);
      const date = ImportantDate(id: '1', label: 'Today', month: 9, day: 6);
      expect(date.daysUntil(now), 0);
    });

    test('counts which anniversary the next one will be', () {
      final now = DateTime(2026, 9, 6);
      const date = ImportantDate(
        id: '1',
        label: 'Married',
        month: 12,
        day: 2,
        year: 2018,
      );
      expect(date.nextCount(now), 8);
    });

    test('has no count when the year is unknown', () {
      const date = ImportantDate(id: '1', label: 'x', month: 1, day: 1);
      expect(date.nextCount(DateTime(2026)), isNull);
    });

    test('nextDate picks the soonest', () async {
      final now = DateTime.now();
      final soon = now.add(const Duration(days: 3));
      final later = now.add(const Duration(days: 200));
      await couple.addDate(label: 'later', month: later.month, day: later.day);
      await couple.addDate(label: 'soon', month: soon.month, day: soon.day);

      expect(couple.state.nextDate?.label, 'soon');
    });

    test('rejects a nonsense month or day on load', () {
      final loaded = CoupleSpaceStore.load(
        InMemoryStore({
          'saath.coupleSpace':
              '{"dates":[{"id":"1","label":"bad","month":13,"day":1},'
                  '{"id":"2","label":"good","month":12,"day":2}]}',
        }),
      );
      expect(loaded.dates.map((d) => d.label), ['good']);
    });
  });

  test('a corrupt blob degrades to empty rather than failing to launch', () {
    expect(
      CoupleSpaceStore.load(InMemoryStore({'saath.coupleSpace': 'not json'}))
          .loveMap,
      isEmpty,
    );
  });

  test('clear wipes everything', () async {
    await couple.addGoal('a');
    await couple.setFact(prompt: 'q', answer: 'a');
    await couple.clear();

    expect(couple.state.goals, isEmpty);
    expect(couple.state.loveMap, isEmpty);
    expect(store.getString('saath.coupleSpace'), isNull);
  });

  test('a goal can be edited in place without losing its done state', () async {
    await couple.addGoal('Sunday walk');
    final id = couple.state.goals.single.id;
    await couple.toggleGoal(id);
    await couple.editGoal(id, 'Sunday walk, phones at home');

    final g = CoupleSpaceStore.load(store).goals.single;
    expect(g.text, 'Sunday walk, phones at home');
    expect(g.isDone, isTrue);
  });

  test('editing a goal to nothing is ignored', () async {
    await couple.addGoal('Sunday walk');
    final id = couple.state.goals.single.id;
    await couple.editGoal(id, '   ');
    expect(couple.state.goals.single.text, 'Sunday walk');
  });

  test('an impossible calendar day is rejected on load', () {
    expect(
      ImportantDate.fromJson({'id': 'x', 'label': 'oops', 'month': 2, 'day': 30}),
      isNull,
    );
    expect(
      ImportantDate.fromJson({'id': 'x', 'label': 'leap', 'month': 2, 'day': 29}),
      isNotNull,
    );
  });
}
