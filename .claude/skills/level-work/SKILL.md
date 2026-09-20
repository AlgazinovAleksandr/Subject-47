---
name: level-work
description: Fix, change, tune or improve an EXISTING level of the horror game, or work through several levels after a playtest. Use whenever the user names a level and wants something done to it — a bug, a tuning pass, a new beat, a backlog, "the Breach feels wrong", "we played 3 and 4" — or asks to act on J-captures or a playtest log. For creating a level that does not exist yet, use `new-level`.
---

# Working on an existing level

A level number or a name is enough to start. Grill out the rest — do not guess the intent.

⚠️ **Two rules outrank everything below.**
1. **The spec is the level.** Plan into `spec/levels/NN-*.md` *before* code, record into it after.
   A change is not finished until its spec says so.
2. **You must run the game.** Not headless asserts — see step 3. This is non-negotiable at
   **diagnosis** and again at **verification**. The suite has been fully green while ~40 real
   defects were live; that is the repo's most expensive recorded lesson.

---

## 1 · Scope

One level, or several? Several changes nothing about steps 2–5 except that you do them per level.
It changes step 6 (fan-out) and step 7 (byte-accounting).

⚠️ If the request touches a **shared** file — `player.gd`, `game_state.gd`, `screamer.gd`,
`room_builder.gd`, `door.gd`, `note_ui.gd` — stop and read the **Shared-file protocol** at the
bottom. `level-improver` is forbidden from shared files, so a shared change is *yours*, not a
subagent's.

## 2 · Read the spec

`CLAUDE.md`'s per-level index names it. Read the **whole** file, both `## SPEC` and
`## DECISIONS & GOTCHAS`.

⚠️ **Newest-dated ⭐ entries override the prose beneath them.** These files are chronologically
layered; a paragraph that contradicts a dated entry above it is history, not current behaviour. Do
not act on the older statement.

⚠️ **Check `## DECISIONS & GOTCHAS` before proposing anything** — it carries rulings that must not be
re-litigated (the Corridor's `CLOCK_INTENSITY` and `FALSE_DOOR_PANIC`, the House maze constants,
KONTUR's "the answers are not inside this level"). Re-proposing one of these is the specific failure
the section exists to stop.

Also read `docs/ISSUES_SOLUTIONS.md` before diagnosing any bug — 217 diagnosed bugs, and re-solving
one is pure waste.

## 3 · ⚠️ RUN THE GAME — mandatory, and the reason this skill exists

**Invoking this skill is the authorisation to launch Godot.** The standing "never launch unasked"
rule still holds for everything outside it.

Two different things, and you need to be clear which you are doing:

### 3a · The agent-driven run — ALWAYS, every time, before you diagnose

You cannot play the game, so drive it:

```bash
# re-import first if any asset or class_name changed
/Applications/Godot.app/Contents/MacOS/Godot --headless --path game --import

# ⚠️ screenshot_* tests need a render target — NO --headless
/Applications/Godot.app/Contents/MacOS/Godot --path game --script res://tests/screenshot_kontur.gd

# a driver that actually walks the level, with its log
/Applications/Godot.app/Contents/MacOS/Godot --headless --path game \
  --script res://tests/walk_level6_breach.gd 2>&1 | tee /tmp/walk.log
```

**Then `Read` the PNGs as images and read the log text.** A screenshot test that "passed" is not
evidence — the evidence is the picture. Everything about how a level *looks* is invisible to the
assert suite, which is why every spec carries a `## NEEDS A PLAYTEST` section.

⚠️ Do not trust a clean screenshot run as proof the geometry is sound — coincident-surface bugs are
camera-dependent and resolve differently per angle. Run `check_wall_overlap.gd` as well.
⚠️ For THE NIGHTMARE, pin the generator: `-- --dungeon-seed N`. It differs every load.

### 3b · The human playtest — only when the user has one, or offers

If the user has just played, or has J-captures / a `playtest_log.txt`: **follow the `game-testing`
skill's protocol** — do not re-derive it. It owns the launch commands, the log clearing, the **J**
briefing, the panic-%→constant tables and the known false positives.

From it, the one rule worth repeating here: **triage `DEBUG CAPTURE` lines first, and `Read` the PNG
before anything else in the log.** That is the user pointing at an exact frame in their own words —
the highest-signal input that exists.

⚠️ **Never start a human playtest unasked.** Offer it. Your own driven runs above need no asking.

## 4 · Grill

Use `grill-me`. One question at a time, your recommendation on each, an option to answer freely.

For a new beat, gate it the way `new-level` does: does it push **further** along the escalating
unreality curve (never back), and does it hit any of the eleven anti-patterns in
`spec/design/SCARY.md` §8 — a second pursuer (§8.4), a HUD readout of progress toward a solution
(§8.2), an emissive scary prop (§8.8)?

⚠️ And audit it against **Issue 18**: if the change *requires* a posture — stand still, torch off,
don't sprint — prove no zone charges panic for it. `player.gd:_update_panic` is an if/elif chain and
DarkZone suppresses decay; this has drawn blood more than once.

## 5 · ⚠️ Write the spec, show the diff, STOP

Write the intended change into that level's `## SPEC` section marked **`🔨 PLANNED`** — what it will
do, what it replaces, what proves it. Then:

```bash
git diff spec/levels/NN-<level>.md
```

**Show that diff and stop. No code until the user approves it.** This is the review gate; it is the
only point where a wrong plan costs a sentence instead of a session.

⚠️ **Never write a second spec for a level.** If the design lives in `spec/design/`, point at it.
Level 7's design is `spec/design/DUNGEON_NIGHTMARES.md` Part B and `07-nightmare.md` must stay a
pointer.

## 6 · Implement

- **One level** → `level-improver` in `implement` mode.
- **Several levels** → one `level-improver` **per level**, in parallel, in a single message.
  Generic agents only for non-level files (`spec/systems/*`, `docs/*`).

Brief each agent with: the level number and name, its scene + script paths, **its spec path**, the
approved backlog items, and the capture/log evidence. ⚠️ It cannot talk to the user — it returns
`## OPEN QUESTIONS` and **you relay them**, answer them, and send them back.

⚠️ `level-improver` is forbidden from: difficulty constants, new fail states, shared files, level
renumbering. If an approved item needs one of those, **you do it**, not the agent.

⚠️ **Before a bulk subagent pass over spec files, snapshot them:**
```bash
cp -R spec "$SCRATCH/spec-snapshot"
# …agents run…
python3 tools/check_spec_audit.py "$SCRATCH/spec-snapshot"
```
It proves the agents *moved* text rather than rewrote it. Content accounting alone will not — it was
silent through an ordering mistake that inverted ten files' override semantics.

### Mid-build, if the approved spec turns out to be wrong

**Stop. Amend the spec. Show the amended diff. Then continue.** Do not build the better thing and
document it afterwards — that is exactly how the specs went stale in the first place.

## 7 · Verify

All four, in this order:

1. **Run the game again** (3a) with fresh captures, and `Read` them. Same bar as diagnosis.
2. `tools/run_tests.sh` — green, or every failure explained.
3. `python3 tools/check_spec_claims.py` on each touched spec — no new DRIFTED rows.
4. If a bulk pass ran, `check_spec_audit.py` against the snapshot.

⚠️ A guard only proves what it points at. Before trusting one, check it actually covers the level
you changed — `check_dungeon_hunter.gd` greps two files by name and cannot see a third, and
`walk_level6_breach` could not fail at all for an era.

## 8 · Close the spec

Drop the `🔨 PLANNED` marker so the text becomes plain SPEC prose describing what the level **is**.
Move rationale, measured numbers and rejected alternatives into `## DECISIONS & GOTCHAS`. Add
anything still unproven to `## NEEDS A PLAYTEST`. **Re-read the whole spec** for what the change now
contradicts.

Report what changed, what you measured, and what to watch. **Never `git commit` — the user commits.**

---

## The backlog schema (inlined — `backlogs/` is gitignored and not in the repo)

For a playtest pass, write `backlogs/NN-<level>.md`. Header:
`**Playtested:** <date> · **Scene:** … · **Status:** draft | approved | built | verified`.
**You** flip `draft → approved` only on the user's word; `built` after step 6; `verified` after 7.

| § | Section | Contents |
|---|---|---|
| 1 | **Evidence** | Facts only, no interpretation. J-capture table (#, screenshot, **the user's words verbatim**, position) · Log (deaths + coords, panic spikes as *+N % = N points = which constant*, route, time, toggles, notes read) · **Anything that did not happen** — scares that never fired, rooms never entered |
| 2 | **Diagnosis** | `MEASURED` (a number or query proves it) and `INFERRED` (say what would confirm or kill each) |
| 3 | **Items** | `id · class · what · why · files · needs your call? · effort` |
| 4 | **Big swings** | Max 2 |
| 5 | **Deferred** | Cross-post to `spec/GAME_MECHANICS_IDEAS.md` **§5.6** so it survives the pass |
| 6 | **Rejected** | Cross-post to **§5.1** *in the user's own words*, so no future session re-pitches it |
| 7 | **Verification** | How each built item was proven |
| 8 | **Cross-level observations** | → `backlogs/00-cross-level.md`, the parking lot. **Never acted on during a level pass.** |

⚠️ **Do not merge §1 into §2.** The project has a standing case of an analysis correct in every
measured detail whose recommendation was still rejected, and keeping that easy is the point.

## Shared-file protocol — when the user approves touching `player.gd` & co.

1. Update `spec/systems/scripts.md` **first** — it is the spec for these files.
2. **Grep every reader of the symbol before changing when it is written.** ⚠️ A latched value is a
   de-facto guard: Issue 182's standstill panic became reachable only because a *correct* fix
   removed protection nobody knew was load-bearing.
3. Run the **full** suite, never a filter. A shared change can redden any level.
4. ⚠️ `git status` first — multiple sessions edit this repo at once. Prefer `Edit` over `Write` on
   `player.gd` / `screamer.gd` / `game_state.gd`.
5. ⚠️ Torch geometry is coupled: `level_6_breach.gd:LIGHT_WEAPON_DOT` is `cos(FLASH_ANGLE)`. Changing
   the default cone changes whether light works as a weapon in the Breach.

## Dispatch allow-list

**Skills:** `grill-me` (design decisions) · `game-testing` (human playtest protocol) ·
`idea-generator` (⚠️ writes into `GAME_MECHANICS_IDEAS.md` §4/§5 and **never implements**) ·
`diagnose`.
**Agents:** `level-improver` (per level) · `game-tester` (whole suite once) · `maze-tester` (House
minigame across seeds) · `dungeon-tester` (THE NIGHTMARE across seeds).

⚠️ `game-tester`, `maze-tester` and `dungeon-tester` may **not** change difficulty constants either —
that is always the user's call.
⚠️ **Never** `nano-banana-pro` — the Gemini API path is dead (2026-08-15).
⚠️ Prefer `check_shell_sealed.gd` over the retired `fix-void` skill (now in `drafts/`).
