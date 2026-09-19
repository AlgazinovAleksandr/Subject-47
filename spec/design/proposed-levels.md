# Proposed levels — specced, not built

> ⚠️ Nothing here exists in the game. This file is the "do not forget it" home for levels that have
> a design but no code, kept deliberately **outside `spec/levels/`** so nothing in that folder can
> be mistaken for something shipped.
>
> Their authoritative designs live in `spec/design/SCARY.md` §5. This file is the index and the
> renumbering plan, not a second copy of those designs.

## The three unbuilt levels

| Level | Design lives in | One line |
|---|---|---|
| **OBSERVATION** | `spec/design/SCARY.md` §5 | Slots between the Lab and the House |
| **THE ANECHOIC CHAMBER** | `spec/design/SCARY.md` §5 | Slots between the Corridor and the Backrooms |
| **THE RETURN** | `spec/design/SCARY.md` §5 | Slots after the Void, before the Twist Ending |

⚠️ **THE NIGHTMARE is no longer on this list — it shipped as Level 7** (`dungeon.gd`, redesigned
2026-09-12). Its design is `spec/design/DUNGEON_NIGHTMARES.md` Part B plus the D1–D8 deviations, and
its shipped-state summary is `spec/levels/07-nightmare.md`. `CLAUDE.md` described it as unbuilt for
some time after it shipped; corrected 2026-09-19.

## The agreed target order

```
0 Intro · 1 Lab · 2 OBSERVATION · 3 House · 4 Corridor · 5 ANECHOIC CHAMBER · 6 Backrooms
· 7 KONTUR · 8 THE BREACH · 9 THE NIGHTMARE · 10 The Void · 11 THE RETURN · Twist Ending
```

Current shipped order, for comparison:

```
0 Intro · 1 Lab · 2 House · 3 Corridor · 4 Backrooms · 5 KONTUR · 6 The Breach
· 7 THE NIGHTMARE · 8 The Void · 9 Ending
```

## ⚠️ The renumbering must land as ONE commit

Inserting a level shifts every index after it, and the indices are read in several places that must
move together or the game breaks silently between them:

- `GameState`'s level map + the `SCENE_*` constants
- `Screamer.LEVEL_SCREAMERS` (the per-level fatal image/audio pairs)
- the `level_progress` rows
- `level_3.gd`'s `current_level` (the Void sets its own index)
- the back-door chain (each level's back door names its predecessor)

with `tests/check_level_resume.gd` extended to assert the full chain **in both directions** before
the commit lands.

## Also on the curve

⚠️ The escalating-unreality curve is currently **non-monotonic and deliberately unresolved**: the
Backrooms is fully unreal, then KONTUR and The Breach drop back to coherent real-world Soviet
facility interiors before the Void goes unreal again. The user's call (2026-07-27) is **note it,
decide later** — the options are degrading 5–6 in place, accepting it as a deliberate breather, or
reordering (expensive: KONTUR's eight gates are answered by hints planted in the Lab, House,
Corridor and Backrooms, and the Flood holds its roster-code digits).
**Do not resolve this silently in an implementation session.**
