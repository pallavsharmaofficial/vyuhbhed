# Accessibility notes

## What is done

- Every interactive element carries an explicit semantics role. The check-in
  scale is a mutually-exclusive group, so it reads as "3 of 5, selected"
  rather than as five unrelated buttons.
- Eyebrow labels are visually uppercased but announced in their real casing —
  the `Semantics` label on `TintPanel` carries the written form.
- Buttons and chips use minimum heights, not fixed ones, so a longer
  translation or a larger text size grows the control instead of clipping it.
- Touch targets are at least 40–52 px.
- The Untangle grid collapses from two columns to one above ~1.3× text scale.
- Long screens (welcome, cool-down, repair close, safety) scroll rather than
  overflowing.
- `Atmosphere` marks its background photo `excludeFromSemantics` — it is
  decoration and should not be announced.
- Reduced motion is honoured: the cool-down breathing circle stops, the stage
  cross-fade is skipped, and route transitions become instant.

## Known ceiling: text scale is clamped at 1.6×

`lib/app/app.dart` clamps `textScaler` to 0.85–1.6. This is deliberate.

Past roughly 1.6×, the glass panels stop reading as panels: the four Untangle
columns, the repair merged view and the tab bar were designed around a
particular density, and simply letting type grow turns them into overlapping
rectangles rather than into a larger, still-legible layout.

Clamping is the honest interim answer — the layouts degrade predictably instead
of breaking. The real fix is a set of large-type layouts for the four signature
screens, and that is a design task, not a code one. Until then this is a real
limitation for users who run their phone at maximum text size.

## Not done

- No VoiceOver / TalkBack pass on a real device yet. The semantics tree is
  right in tests; how it actually *sounds* in Hindi is unverified.
- Colour contrast has not been measured. The glass surfaces sit on photographs,
  so contrast varies with the background; the veil and gradient fades are what
  currently guarantee legibility, and that guarantee is by eye, not by number.
- No reduced-transparency handling. iOS users with "Reduce Transparency" on
  still get the full frosted-glass treatment.
