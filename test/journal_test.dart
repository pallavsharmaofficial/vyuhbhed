import 'package:flutter_test/flutter_test.dart';
import 'package:vyuhbhed/core/journal.dart';
import 'package:vyuhbhed/core/key_value_store.dart';

void main() {
  late InMemoryStore store;
  late JournalStore journal;

  setUp(() {
    store = InMemoryStore();
    journal = JournalStore(store);
  });

  test('starts empty', () {
    expect(journal.state, isEmpty);
  });

  test('adds an entry and persists it', () async {
    await journal.add(
      kind: JournalKind.untangle,
      title: 'The dishes again',
      body: 'What happened: he left the room',
      ask: 'Can we pick a time tonight?',
      themes: [JournalTheme.time],
    );

    expect(journal.state, hasLength(1));
    expect(JournalStore.load(store), hasLength(1),
        reason: 'a saved entry must survive a relaunch');
  });

  test('keeps entries newest first', () async {
    await journal.add(
        kind: JournalKind.note,
        title: 'older',
        body: '',
        at: DateTime(2026, 1, 1));
    await journal.add(
        kind: JournalKind.note,
        title: 'newer',
        body: '',
        at: DateTime(2026, 6, 1));

    expect(journal.state.first.title, 'newer');
    expect(JournalStore.load(store).first.title, 'newer');
  });

  test('gives every entry a distinct id', () async {
    final a = await journal.add(kind: JournalKind.note, title: 'a', body: '');
    final b = await journal.add(kind: JournalKind.note, title: 'b', body: '');
    expect(a.id, isNot(b.id));
  });

  test('removes one entry without touching the rest', () async {
    final a = await journal.add(kind: JournalKind.note, title: 'a', body: '');
    await journal.add(kind: JournalKind.note, title: 'b', body: '');

    await journal.remove(a.id);

    expect(journal.state.map((e) => e.title), ['b']);
    expect(JournalStore.load(store).map((e) => e.title), ['b']);
  });

  test('clear wipes the stored blob too', () async {
    await journal.add(kind: JournalKind.note, title: 'a', body: '');
    await journal.clear();

    expect(journal.state, isEmpty);
    expect(store.getString('saath.journal'), isNull);
  });

  test('themeCounts only counts the recent window', () async {
    await journal.add(
      kind: JournalKind.untangle,
      title: 'recent',
      body: '',
      themes: [JournalTheme.money, JournalTheme.time],
    );
    await journal.add(
      kind: JournalKind.untangle,
      title: 'old',
      body: '',
      themes: [JournalTheme.money],
      at: DateTime.now().subtract(const Duration(days: 90)),
    );

    final counts = journal.themeCounts();
    expect(counts[JournalTheme.money], 1);
    expect(counts[JournalTheme.time], 1);
  });

  test('a corrupt blob degrades to empty rather than throwing on launch', () {
    expect(JournalStore.load(InMemoryStore({'saath.journal': 'nonsense'})),
        isEmpty);
  });

  test('drops malformed rows and keeps valid ones', () {
    final loaded = JournalStore.load(InMemoryStore({
      'saath.journal': '['
          '{"id":"1","createdAt":"2026-09-01T10:00:00.000","kind":"untangle","title":"ok","body":"b"},'
          '{"id":"2","createdAt":"not a date"},'
          '{"noId":true}'
          ']',
    }));

    expect(loaded, hasLength(1));
    expect(loaded.single.title, 'ok');
  });

  test('an unknown theme id is dropped, not turned into a wrong theme', () {
    final loaded = JournalStore.load(InMemoryStore({
      'saath.journal': '['
          '{"id":"1","createdAt":"2026-09-01T10:00:00.000","kind":"untangle",'
          '"title":"t","body":"b","themes":["money","astrology"]}'
          ']',
    }));

    expect(loaded.single.themes, [JournalTheme.money]);
  });
}
