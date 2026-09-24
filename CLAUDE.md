# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# Horror Game — Claude Context

## Project
3D first-person atmospheric horror prototype. Desktop macOS app (.app bundle).
Horror through atmosphere, lighting, sound, and environment storytelling.

⚠️ **The pillar is "AI is rationed", not "no AI".** This line used to read *"No active enemy AI"*;
that stopped being true when Level 6 shipped `creature_object12.gd`, a five-state pursuit AI with
search memory, and `DUNGEON_NIGHTMARES.md` §B4.2 specs a second (the Matron). The correct constraint
is `SCARY.md` §8.4's: **one chase level in twelve.** Outlast's chase-or-nothing binary is the failure
state of chase-led design. Do not add a third pursuer.

## ⚠️ SPEC-FIRST — how to work on a level

**The spec is the level.** `spec/levels/NN-<level>.md` is the live representation of that level,
not a record written afterwards. Work on a level in this order, every time:

1. **Write it down first.** Before changing any code — a fix, a tuning pass, a new feature —
   state the intended change in that level's spec, in its **SPEC** section, marked `🔨 PLANNED`:
   what it will do, what it replaces, what proves it.
2. **Build it.**
3. **Record it, then re-read the level.** Drop the `🔨 PLANNED` marker so the text becomes plain
   SPEC prose describing what the level *is* now, add the rationale to **DECISIONS & GOTCHAS**
   (measured numbers, what was rejected, anything that must not be re-litigated), and **re-read
   the whole spec** to confirm nothing else in it now contradicts the change.

⚠️ **A change is not finished until its spec says so.** A spec going stale is the exact failure
this structure exists to prevent — `drafts/KONTUR.md` is kept as the cautionary tale of a design
doc that silently disagreed with the shipped game.

⚠️ **Never write a second spec for a level.** Level 7's design lives in
`spec/design/DUNGEON_NIGHTMARES.md` Part B; `spec/levels/07-nightmare.md` points at it and must
never become a copy.

⚠️ **Nothing loads a spec for you — open it yourself.** The per-level index below names every
spec path; that index and this protocol are the mechanism. `.claude/rules/*.md` repeats the
script→spec mapping, but those files load **unconditionally in every session**, not on demand, so
they are a reminder rather than a delivery mechanism. (This paragraph claimed the opposite, and
named a `paths:` key the stubs do not use; corrected 2026-09-19 after measuring what actually
loads.)

## Where the docs live

| Doc | Path | What it is |
|---|---|---|
| `SCARY.md` | `spec/design/SCARY.md` | The authoritative fear document |
| `DUNGEON_NIGHTMARES.md` | `spec/design/DUNGEON_NIGHTMARES.md` | Level 7's design + the D1–D8 deviations |
| `INTRO.md` | `spec/design/INTRO.md` | The intro room's design dossier |
| `GAME_MECHANICS_IDEAS.md` | `spec/GAME_MECHANICS_IDEAS.md` | The entry point for **what to build next** |
| `ISSUES_SOLUTIONS.md` | `docs/ISSUES_SOLUTIONS.md` | 217 diagnosed bugs — read before diagnosing any bug |
| `TEXTURES.md` | `docs/TEXTURES.md` | Texture registry (step 1 of the texture audit rule) |
| `COMMENTS.md` | `docs/COMMENTS.md` | Developer retrospective |
| `BUG_FIX.md` | `docs/BUG_FIX.md` | Closed July triage — cited by section number as a stable ID space |
| `TODO_sounds.md` | `docs/TODO_sounds.md` | Audio/textures the game is wired for that do not exist yet |
| run backlogs | `backlogs/runs/` | ⚠️ **Local only, not in the repo.** The seven `BACKLOG_Sep_*.md` runs + `BACKLOG.md`, with `INDEX.md` carrying the built/to-review triage |

⚠️ Code and tool comments cite these by **bare name** (`SCARY.md §8.4`, `ISSUES_SOLUTIONS Issue 62`).
Those citations are still correct; this table is how a bare name resolves to a path.

## Commands

⚠️ **Memory (2026-09-13, Issue 203):** every texture imports VRAM-compressed and 3D renders at half
scale on HiDPI (`GameState.HIDPI_3D_SCALE`). A test that reads texture pixels must `decompress()`.
`tests/probe_memory.gd` prints the renderer's memory for a scene at both scales.

Godot lives at `/Applications/Godot.app/Contents/MacOS/Godot`; every test/tool honours a `GODOT`
env override. The Godot project root is `game/` — all commands take `--path game`. There is no
build, lint or package step: the game runs from source, and `--import` is the only "build".

```bash
# Run the game (starts at main_menu.tscn, per project.godot)
/Applications/Godot.app/Contents/MacOS/Godot --path game

# Run ONE level directly (skip the run-up) — see the Level scenes table for the list
/Applications/Godot.app/Contents/MacOS/Godot --path game res://scenes/kontur.tscn
/Applications/Godot.app/Contents/MacOS/Godot --path game res://scenes/dungeon.tscn -- --dungeon-seed 404

# Re-import after ANY new class_name, .wav/.ogg or texture (see the ⚠️ in Testing)
/Applications/Godot.app/Contents/MacOS/Godot --headless --path game --import

# Tests
tools/run_tests.sh                 # whole headless suite, one summary table; exit code = #failures
tools/run_tests.sh -q              # summary + failing output only
tools/run_tests.sh maze            # only tests whose NAME matches a substring

# One test, directly (this is all run_tests.sh does per row)
/Applications/Godot.app/Contents/MacOS/Godot --headless --path game \
  --script res://tests/check_kontur.gd

# Args go after a bare `--` (OS.get_cmdline_user_args)
/Applications/Godot.app/Contents/MacOS/Godot --headless --path game \
  --script res://tests/check_wall_overlap.gd -- res://scenes/dungeon.tscn --dungeon-seed 404

# screenshot_* tests need a render target — run them WITHOUT --headless
/Applications/Godot.app/Contents/MacOS/Godot --path game --script res://tests/screenshot_kontur.gd

# Procedural SFX (stdlib-only Python; re-run to regenerate, then --import)
python3 tools/make_sfx_dungeon.py
```

Playtest logs from `DebugLog` land at
`~/Library/Application Support/Godot/app_userdata/horror_game/playtest_log.txt`.

## Game Design

### Premise
The player wakes in a dark room as **Subject 47** — a participant in a psychological experiment testing their ability to conquer fear. A note explains: the entity they may encounter is a manifestation of their own mind, not real. Stay calm. Do not touch what you are not meant to touch.

### ⚠️ DESIGN PILLAR — ESCALATING UNREALITY
**The game starts with something ordinary and human, and gets further from reality the deeper the
player goes.** Every level must be stranger and more frightening than the one before it. Locations,
rules, and the player's own senses all degrade along that curve.

This is a **hard constraint on new content**, not a mood note. Any new level must know where it sits
on the curve and must be weirder than its predecessor; any change to an existing level should push it
further along the curve, never back. `SCARY.md` §6 holds the full ordering.

⚠️ **The curve is currently non-monotonic and that is a known, deliberately-unresolved issue.** The
Backrooms is fully unreal (impossible space, loops, mono-yellow void), and then KONTUR and The Breach
drop back to *coherent, real-world* Soviet facility interiors before the Void goes unreal again. The
user's call (2026-07-27) is **note it, decide later** — the options are degrading 5–6 in place,
accepting it as a deliberate breather, or reordering (expensive: KONTUR's eight gates are answered by
hints planted in the Lab, House, Corridor and Backrooms, and the Flood holds its roster-code digits).
**Do not resolve this silently in an implementation session.**

### Structure
```
Intro room → Level 1 (The Lab) → Level 2 (The House) → Level 3 (The Corridor) → Level 4 (The Backrooms) → Level 5 (KONTUR) → Level 6 (The Breach) → Level 7 (THE NIGHTMARE) → Level 8 (The Void) → Twist Ending
```

Each level: explore the environment, find clues/items, unlock the exit door. Fail = screamer + restart that level. Pass = enter the next door.

⚠️ **Three levels are specified but not yet built** — OBSERVATION, THE ANECHOIC CHAMBER and THE
RETURN, designed in `spec/design/SCARY.md` §5. The agreed target running order, the renumbering plan,
and the ⚠️ note on the non-monotonic unreality curve all live in **`spec/design/proposed-levels.md`**.
⚠️ The renumbering must land as **ONE commit**, and it is **12 items, not the 5 this paragraph used
to list** (corrected 2026-09-19 by counting them) — ⚠️ **none of which fail loudly**: a half-landed
renumber is a playable game with the wrong screamer faces and lost progress. `new-level` carries the
full list; the ones this file had missed are the **eleven `GameState.current_level = N` assignments
across ten scripts** (not just `level_3.gd` — and note `kontur.gd` has *two*: its own index at `:241`
and the banishment destination at `:1104`), the **eleven hard-coded-index `get_level_progress(N)` /
`get_level_attempts(N)` call sites**, `tests/lib/scenes.gd`, `check_level_resume.gd`, and every test
that pins a level by index. ⚠️ **Do NOT rename the asset folders** — `level_9_dungeon/` serves
level 7, because those numbers are identity, not index. (This paragraph said *four* levels and
listed THE NIGHTMARE until 2026-09-19; that one shipped as Level 7.)

### Making the game scarier — read `spec/design/SCARY.md`
`spec/design/SCARY.md` is the authoritative fear document: the diagnosis (predictable/habituating · no dread
between scares · an inert world), eleven costed retrofits, the audio-architecture overhaul, the
shadow rollout, the three new levels, the anti-patterns, and a phased roadmap.

⚠️ **`spec/GAME_MECHANICS_IDEAS.md` is the entry point for *what to build next*.** It carries the audited
build status of every accepted idea (2 built · 6 partial · 25 not built), the six live defects, the
rejection ledger, and the build order. It absorbed and replaced `REPORT.md` and `IDEA_HISTORY.md`,
which are now archived in `drafts/` and must not be built from. `SCARY.md` and
`DUNGEON_NIGHTMARES.md` remain authoritative for the *design* of what they spec.
Its governing finding, which constrains every new scare: **stop adding panic terms, start adding
channels** — nine of its eleven proposals add zero panic, because a scare with a number attached can
be optimised against and one without cannot.

### Levels

The full spec for each level is linked below. Each carries the measured numbers, the rejected
attempts, and the rulings that must not be re-litigated. **Read a level's spec before changing it**
(see SPEC-FIRST above).

**Intro Room** — a 12×18 m asylum ward built at runtime by `intro_room.gd`.
⚠️ **UNLOSEABLE, and it must stay that way** — nothing here calls `add_panic()`, and there is
deliberately **no jumpscare in this room**. `tests/check_intro_beats.gd` fails if the bar moves at all.
→ `spec/levels/00-intro.md`

**Level 1 — The Lab** — a 38-room institutional floor: a 10-room core (`ROOMS`) plus a **28-room
lightless wing** (`WING_ROOMS`) — three-breaker power quest, navigate-by-ear, a keycard guarded in
the morgue.
⚠️ Pitch black until the power is restored; the torch is narrowed to 11 m / 24° via
`set_torch_profile()` — **Lab and House only**, because `level_6_breach.gd:LIGHT_WEAPON_DOT` is
`cos(FLASH_ANGLE)`. Exactly ONE apparition, armed 3 s after the first breaker. Nothing fullscreen
before the keycard.
→ `spec/levels/01-lab.md`

**Level 2 — The House** — an 8-room ground floor plus a cellar: bathroom map minigame → cellar key
→ three safe notes → the combination lock (code **472**).
⚠️ Torch 11 m / 24°, ambient 0.0 until all three notes are read. **The maze minigame's difficulty
constants are the user's call** — re-run `check_maze_chase.gd` before touching any of them, and do
not re-tune `MONSTER_SPEED` without it. So are the **forest clock**'s three (`FOREST_RATE_EDGE` 3.5,
`FOREST_RATE_DEEP` 5.5, `FOREST_DEEP` 20 — a user-approved panic term, 2026-09-24), which must stay
**zero on the porch deck** where the guillotine is worked (Issue 18).
→ `spec/levels/02-house.md`

**Level 3 — The Corridor** — a 455 m zigzag hotel hallway, ten segments, three side passages, two
forks. No fetch quest: walking it without panicking **is** the test.
⚠️ `CLOCK_INTENSITY` 1.0 and `FALSE_DOOR_PANIC` 15 are **user-confirmed — do not re-tune**. Never
add a `DarkZone` over any part of the Zone C dread zone (they stack to +5/s with no way down).
→ `spec/levels/03-corridor.md`

**Level 4 — The Backrooms** — three zones in one scene: the Lobby (three down-turns), the Sprawl
(the crate and the runner), the Flood (six relics). Entered by a real noclip fall from the Corridor.
⚠️ You arrive with the torch **OFF**. The Sprawl's real wall is the end of the crate's own recess and
**never re-rolls**. Each zone gets exactly one `CalmZone` anchor.
→ `spec/levels/04-backrooms.md`

**Level 5 — KONTUR** — a 13-room Soviet facility. **Eight gates, each a different verb, each
answered by a hint planted in an EARLIER level.**
⚠️ The premise is that the answers are not inside this level — **do not add one**. A wrong action is
fatal (`_condemn()`). Every randomisation is RESTORED on a back-door return, never re-rolled.
→ `spec/levels/05-kontur.md`

**Level 6 — THE BREACH** — a Nemesis-style pursuit: Object 12 loose in a 13-room wing, with light
as a weapon, hiding spots, slam doors and the purge chamber.
⚠️ **This is the ONE chase level** (`SCARY.md` §8.4, one in twelve). Do not add a third pursuer
anywhere in the game.
→ `spec/levels/06-breach.md`

**Level 7 — THE NIGHTMARE** — a generated dungeon: a candle instead of the flashlight, seven
sconces, and a hunter that hunts by ear.
⚠️ **NOTHING IN THIS LEVEL KILLS — the panic bar is the only death.** Its authoritative design is
`spec/design/DUNGEON_NIGHTMARES.md` Part B plus its D1–D8 deviations; the spec file points there and
must never become a second copy. The dungeon differs every load — pin it with `-- --dungeon-seed N`.
→ `spec/levels/07-nightmare.md`

**Level 8 — The Void** — 15 abutting rooms, a seamless loop corridor, floating tiles over a pit,
six crowned stalkers.
⚠️ Rebuilt 2026-09-12 on `RoomBuilder`; **not yet hand-played**.
→ `spec/levels/08-void.md`

**Twist Ending** — the final door reloads the intro room, corrupted; the reveal is
`ending_scene.ogv`.
→ `spec/levels/09-ending.md`

**Shared across levels** — the Random Apparition system (`apparition.gd` + `ApparitionDirector`) and
the level-progress / backtracking contract (`save_progress()` / `_restore_progress()`):
→ `spec/levels/README.md`

**Systems** — `spec/systems/scripts.md` (every script, what it owns, its gotchas) ·
`spec/systems/testing.md` (the guards and what they actually prove) ·
`spec/systems/assets-and-audio.md` (folder layout, audio import, asset + image pipelines)

### Trigger Object Rules
- Trigger objects are **instant fail** on interaction (press E) OR after 3 continuous seconds of direct gaze; trap notes are **read-to-die** (panic +12/s while open — see Level 2)
- Screamer sequence: black flash → screamer image fullscreen → loud audio burst → 1.5s delay → scene reloads
- Visual hint: trigger objects have a faint pulse glow or subtle audio cue when player is close

### Win/Loss Flow
```
Interact with trap → Screamer.trigger() → reload current scene
Reach exit with condition met → GameState.advance_level() → load next scene
Interact with back door (goes_back=true) → GameState.go_back() → load previous scene (state preserved)
```

### Door Conventions
- **Exit doors** and **back doors** both glow **blood-red** (`Color(0.35, 0.02, 0.02)`, emission ×1.5)
- Back doors have `goes_back = true`, `advances_level = false`, `unlock_condition = NONE`
- `go_back()` sets `GameState.entered_from_ahead = true`, captures the level you are leaving into
  `GameState.level_progress`, and restores the destination's snapshot on arrival (see **Level
  progress & backtracking** below). The Backrooms gained a back door for this — it had none
- ⚠️ **There is no "back-door chain" in the sense the docs used to describe** (corrected 2026-09-19).
  A back door does **not** name its predecessor: `door.gd:217-222` carries no level index at all, and
  `go_back()` is literally `current_level -= 1` plus `start_current_level()`. The real chain is the
  `match current_level` in `start_current_level()` ↔ **each level script's own
  `GameState.current_level = N`** in `_ready()`, and the two must agree. `tests/check_level_resume.gd`
  exists precisely to catch them disagreeing

## Code Architecture

### Autoloads (global singletons, survive scene transitions)
Registered in `game/project.godot`. Access directly by name from any script.

| Autoload | File | What it owns |
|----------|------|-------------|
| `GameState` | `scripts/game_state.gd` | Level state (`current_level`: 0=intro, 1=lab, 2=house, **3=corridor, 4=backrooms, 5=kontur, 6=breach, 7=nightmare, 8=void, 9=ending**), `has_keycard`, `level2_code_correct`, `twist_read`, `is_ending`, `intro_note_read`, `apparition_taught`; `advance_level()` / `go_back()` / `restart_current_level()`; `go_to_main_menu()`; `load_audio(base_name)`. **Also owns the two cross-level systems added for BACKLOG #30:** `level_progress` (per-level snapshots — see below) and `journal` + `record_note()`. `set_objective()` / `set_carried()` drive the two HUD lines. |
| `Screamer` | `scripts/screamer.gd` | `trigger()` — ⭐ **and since 2026-09-03 it actually IS "black flash → image → audio burst"**, which this table had claimed for a long time while the code did something else: `_screamer_image` is a CHILD of `_black_panel`, so showing the panel put the black and the face on screen in the SAME frame, with `_audio.play()` on the next line and no `Ambience` duck at all (`flash_scare()` had ducked since HoldBreath landed; the FATAL path never had). It now goes through `_black_then_scream()`: duck to −30 dB → black with the image HIDDEN → `BLACK_HOLD` 0.2 s of nothing → image and scream together. ⚠️ The hold comes OUT of `RESTART_DELAY`, so death-to-reload does not get longer. That contrast is worth more than any re-master, because six of the eight fatal stings were already within ~1 dB of the ceiling. `process_mode = PROCESS_MODE_ALWAYS` (must not freeze during tree pause). `_is_triggering` / `_is_flashing` bools guard `trigger()`, `trigger_to_menu()` and `flash_scare()` against re-entry. **Per-level fatal AV**: `_apply_level_av()` picks the image + scream by `GameState.current_level` from `LEVEL_SCREAMERS` (1 lab `screamer_lab`, 2 house `screamer_house`, 3 corridor `screamer_hotel`/`screamer_corridor`, 4 backrooms `screamer_smiler`/`jumpscare`, 5 kontur `screamer_kontur`, 6 breach `level_6_jumpscare` — image **and** audio, user-supplied 2026-07-27, replacing the generated `screamer_breach` pair; the `.jpg` is real JPEG data so it imports fine, unlike the Issue-25 JPEG-named-`.png` trap — 7 nightmare `screamer_dungeon`, 8 void `screamer_void`); intro/ending fall back to a random `screamers/` `.png` (DirAccess scan at startup) + the shared `jumpscare`. **`flash_scare(image_path, audio_base, hold)`** — a SURVIVABLE scare: fullscreen image + sound for `hold` s, no pause/restart (the caller adds its own panic). Used by the House forest scare, the Corridor Manager, and the Corridor turn mirrors. |
| `NoteUI` | `scripts/note_ui.gd` | Fullscreen note overlay. `show_note(text, trap_rate := 0.0)` / `is_open` bool. ⚠️ Its footer reads **`[ Press E to close  ·  TAB anywhere — recovered documents ]`** (2026-08-16) on an IMMUTABLE label of its own — nothing writes to it, per `combination_lock.gd`'s lesson that a feedback line must never double as the instruction line. `JournalUI` had shipped for several sessions with **no mention anywhere in the game**, and the 2026-08-16 playtester asked for a notes journal as a NEW FEATURE while standing in front of an open note with the feature running. "anywhere" is load-bearing: TAB is refused while a note is open, so an instruction to press it *here* would be a lie. Built entirely in GDScript — no .tscn. Guard `is_open` in player before any interaction logic. While `trap_rate > 0` and the note is open, feeds `player.add_panic()` per frame and tints the text toward red; auto-drops the overlay if the tree unpauses (= a screamer fired) |
| `JournalUI` | `scripts/journal_ui.gd` | **TAB** — re-read any note already found. ⚠️ **The list takes keyboard focus on open (`focus_mode = FOCUS_ALL` + `grab_focus()` AFTER `_root.visible = true`), and the TAB/ESC close handler lives in `_input()` with `set_input_as_handled()`, not in `_unhandled_input()`** (2026-08-16, Issue 70, reported in two consecutive playtests). `ItemList.select()` neither emits `item_selected` nor takes focus, and `focus_mode` defaults to `FOCUS_NONE`, so the arrows did nothing until a click. And the fix has a trap: TAB is `ui_focus_next`, which the GUI layer consumes before `_unhandled_input` the moment ANY Control has focus — `grab_focus()` alone would have made the journal impossible to close. Two-pane overlay (level-grouped list + text), built entirely in GDScript like `note_ui.gd`, `PROCESS_MODE_ALWAYS`, pauses the tree, carries the Issue-9 self-drop guard. `can_open()` refuses while `NoteUI.is_open`, while the tree is already paused, or while `player.is_input_frozen()` (a free pause mid-QTE). ⚠️ **Trap notes are never archived** — `note.gd` only calls `GameState.record_note()` when `not is_trap`, because a safely re-readable copy would let the player learn a read-to-die note's text at no cost. |

### Level scenes
| Scene | Unlock condition | Notes |
|-------|-----------------|-------|
| `main_menu.tscn` | — | Game entry point; START loads `intro_room.tscn`. **Background is a looping video since 2026-08-17** (`menu_loop.ogv`, a static-camera corridor with one flickering tube) sitting between the still and the 0.78 dark overlay, so the title / blood notes / buttons land on top of it unchanged. ⚠️ `main_menu_bg.png` is NOT dead — it is the fallback layer, shown headless, if the `.ogv` is missing, or if playback silently fails to start (`main_menu.gd` copies `cutscene_player.gd`'s one-frame did-it-start guard). ⚠️ The `.ogv` is a **palindrome** (forward + reversed, `assets_src/README.md`), which is the whole reason `loop = true` is seamless: the last frame IS the first frame. ⚠️ The overlay alpha did not move, and that was measured — the clip's mean luminance is ~60/255 against the still's ~51, i.e. brighter. ⚠️ `_on_start()` frees the player: the START blackout is layer 85 over a layer-1 canvas, so the loop is hidden but would otherwise keep decoding under the whole intro cutscene |
| `intro_room.tscn` | NONE | Player spawn z=+1.5; table centered; ambient 0.15; walls size.y=3.0 |
| `level_1.tscn` | KEYCARD | **Minimal scene** (Session 10): only `Player`/`Environment`/audio/`HUDCanvas` survive — the whole 38-room Lab (10-room core + the 28-room wing) is built at runtime by `level_1.gd` via `RoomBuilder` (`_clear_old_scene()` frees the old hand-built nodes via the `PRESERVE` whitelist). Player spawn (0,0.1,−1.5) facing +z; `ExitDoor` built with `advances_level=true`; BackDoor returns to House. **Session 11:** brighter lamps (emergency 0.45 / restored 1.0, range 11) + `_boost_ambient()` duplicates the SHARED env to raise ambient and switch the background to BLACK (no procedural-sky leaks) for this scene only |
| `level_2_1.tscn` | CODE_ENTERED | **Minimal scene** (Session 10): same `.tscn`-minimal / `PRESERVE`-whitelist pattern — the 8-room ground floor + lowered cellar are built at runtime by `level_2.gd` via `RoomBuilder` + `_build_cellar()`. Player spawn (0,0.1,−2.0) facing +z; `ExitDoor` built with `advances_level=true`; BackDoor returns to Lab. **Session 11:** brighter lamps (rooms 0.9, range 10) + `_boost_ambient()` (raised ambient + BLACK background per-scene); fixed cellar headroom + sky-cap. **Note:** `GameState.SCENE_LEVEL_2` points to `level_2_1.tscn` (not `level_2.tscn`). |
| `corridor.tscn` | NONE (reach the door) | Minimal scene: root + Environment + AmbientPlayer + Player at (0,0,2) facing +z — everything else built by `corridor.gd` in `_ready()`. Exit door at d=455 m; the FALSE room 217 is the trap at the 230 m corner. BackDoor at the start returns to The House |
| `backrooms.tscn` | NONE (three down-turns → glitch wall) | Level 4. Minimal scene: root + Environment + AmbientPlayer + Player at (0,0,−5) facing +z — the cyclic maze, lights, arrows, zones, props all built by `backrooms.gd` in `_ready()`. Sets `current_level = 4` |
| `kontur.tscn` | `extra_lock` — all eight gates | Level 5 — KONTUR. Minimal scene: root + Environment + AmbientPlayer + Player at (0,0.1,−3) facing +z — the 8-room spine, gates, signs, creature and doors all built by `kontur.gd` in `_ready()`. Sets `current_level = 5`; BackDoor returns to the Backrooms |
| `level_6_breach.tscn` | `extra_lock` — creature defeated | Level 6 — THE BREACH. Minimal scene: root + Environment + AmbientPlayer + Player at (0,0.1,−2) facing +z — the 13-room spine + bypass loops, Object 12, hiding spots, slam doors and the purge chamber all built by `level_6_breach.gd` in `_ready()`. Sets `current_level = 6`; BackDoor returns to KONTUR |
| `dungeon.tscn` | `extra_lock` — seven sconces lit and the bed slept in | Level 7 — THE NIGHTMARE. Minimal scene: root + Environment + AmbientPlayer + Player at (0,0.1,−48) in the Antechamber — everything else built by `dungeon.gd` in `_ready()` from `dungeon_gen.gd`'s output. Sets `current_level = 7`; BackDoor returns to The Breach. ⚠️ The dungeon is DIFFERENT EVERY LOAD; pin it with `-- --dungeon-seed N` |
| `level_3.tscn` | TWIST_READ | The Void (level 8). Player spawn z=−2.0; vignette strength 2.0; BackDoor at z=−3.05; `_spawn_note_tables()` called in `_ready()` (all 8 notes). Sets `current_level = 8` (`level_3.gd:16`) |
| `ending.tscn` | — | Reloads intro_room, credits fade |

## ⚠️ Building a level without coincident-surface bugs (READ THIS FIRST)

Levels 1 and 2 shipped with a family of bugs the player described as *"textures merging into each
other"* / *"lagging textures"*. Every one of them was the same underlying fault — **two visible
surfaces occupying the same plane** — and the fix was never in the art. Session 15 fixed six
variants (Issues 19, 20, 23, 24, 25, 26). KONTUR had the same bug and nobody had noticed.

**Run this before calling any procedurally-built level done** — it sweeps EVERY level in the game
since 2026-08-17, so the bare command is the whole check; the argument only narrows it:
```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path game \
  --script res://tests/check_wall_overlap.gd            # all nine scenes, 12 scene-runs
/Applications/Godot.app/Contents/MacOS/Godot --headless --path game \
  --script res://tests/check_wall_overlap.gd -- Corridor   # …or one, by label or by path
```
It asserts two things and prints `WALL-OVERLAP PASS` / `FAIL` with the offending node names:
1. no two CSG boxes have parallel faces within 2 mm while overlapping in the other two axes;
2. every `QuadMesh` sits at least 2 cm clear of every CSG box.

### The rules it encodes
| Rule | Why |
|---|---|
| Rooms in a `ROOMS` table must **ABUT, never overlap** | Overlapping rooms emit floor/ceiling slabs whose visible faces are both at y=0 / y=h → z-fight (the Lab's `Observation` poked 0.5 m into two neighbours) |
| Never hand-compute a wall-prop position; use `wall_point()` | Its inset is measured from the room's NOMINAL boundary, and the wall face is `T/2` in from that. The morgue poster's hand-rolled `c.z + 2.9` landed exactly on the face and got sliced apart |
| Wall props need `inset ≥ 0.16`; **0.22** if anything hangs behind them | `LivingMirror` puts its figure 0.05 behind the glass. At 0.1 the figure was *inside the wall* — invisible in both levels, for the whole project's life |
| Artwork goes on a **`QuadMesh`**, never on a `BoxMesh` face | A box doesn't map the whole texture per face; it renders a magnified crop. `door.gd:build_visual()` is the pattern — box for edge/depth, quad for art |
| Any deliberately overlapping slab must be **offset**, not coplanar | Floor bridges are sunk `BRIDGE_SINK` (4 mm) for exactly this reason |
| A new builder that emits walls must dedup by **interval**, not by exact span | Abutting rooms of different depths emit same-plane walls with different spans; exact-match dedup builds both |

### Why this was hard to catch
It is **camera-dependent**: a depth fight resolves differently per position and angle, so static
screenshots from `tests/screenshot_level.gd` mostly did *not* reproduce it while walking around in
game did. Three rounds of fixes were driven by the user's own in-game screenshots. **Do not trust a
clean screenshot run as evidence that geometry is sound — run the assertion.**

### ⚠️ Put artwork on a QuadMesh, never on a BoxMesh face
A `BoxMesh` does not map a whole texture onto each face, so a textured box renders a magnified CROP
of its own art (Issue 24 — the exit doors showed one hinge and no window, while the tray and monitor
beside them, on quads with the same material, were fine). `door.gd:build_visual()` is the pattern:
box for edge/depth, `QuadMesh` on each face for the art.

### ⚠️ `ResourceLoader.exists()` returns true for a texture whose IMPORT failed
A `.png` that is really JPEG data imports with `valid=false` and no `.ctex`, so `load()` fails while
`exists()` still says yes — the guard passes and the prop renders blank (Issue 25, a recurrence of
Issue 1). If a texture silently doesn't appear, run `file` on it before debugging the code.

### ⚠️ A baked transparency checkerboard is PAINT, and near-white is the brightest paint there is
A supplied cutout that is not RGBA is carrying its background as opaque pixel data. `lab_breaker_panel.png`
shipped as an 8-bit **RGB** PNG whose background was the light two-tone checkerboard an editor draws to
*represent* transparency — 20 % of its texels above 0.90 sRGB — on the one prop in the game whose whole
design is that it cannot be seen. It read as a pale rectangle with a lighter outline from 9.4 m in a
pitch-black room. `tools/flatten_alpha_checker.py` flood-fills that background dark from the image border
(reachability-limited, so it cannot eat a cream label inside the art) and crops. Issue 63; the shape-side
twin of "a billboard texture must be a real RGBA cutout". **Look at a new texture's histogram, not just at
`file`.**

### ⚠️ Measure DARKNESS as contrast, never as an absolute level
"Peak 1.5 of 255, therefore invisible" was wrong twice on the same prop: against a background of literally
0.0000 that patch is the only thing in the frame. Sample the panel's whole screen bounding box, take the
**max** (a thin bright border averages away to nothing), and compare against a ring of the surface around
it. Issue 62. And ⚠️ `unproject_position()` returns **viewport** coordinates while `get_image()` returns the
**rendered** image — 1152×648 against 3024×1701 on this machine — so any probe that mixes them must scale,
or it measures the wrong part of the frame and reports it confidently.

### ⚠️ Emission is most of a surface's colour (no tonemapping, no glow)
The project has **no glow/bloom, no fog and no SSAO on any level**, and renders with Linear tonemap
at exposure 1.0. Two consequences that bit hard (Issue 21):
- Any `emission_energy_multiplier` **above 1.0 clamps to flat pure white** with no detail. Ceiling
  fittings use `FIXTURE_EMISSION` 0.55 (Lab) / 0.6 (House); `MazeKit`'s 1.6 only survives because
  Backrooms strips are seen down a corridor, never directly overhead.
- Because light energy is ~0.45, a surface's **albedo contributes far less than its emission**. A
  self-lit prop's albedo must be DARK or the point light beside it blows it out — and a dark albedo
  is also what lets a blackout drive the fitting visibly dead.

## Panic System

`player.gd` maintains a `_panic` float (0–50). It rises while the player gazes at any node whose scene tree contains a `ScaryObject` ancestor, at a rate of `scare_intensity × PANIC_BASE_RATE (20/s)`. **Gaze detection uses `GAZE_RANGE=3.0m`**, which since 2026-08-15 is the SAME as `INTERACT_RANGE` — the two raycasts remain separate calls, but the ranges now match deliberately, so nothing is reachable that was not already dangerous to look at. It decays at `PANIC_DECAY_RATE (3.5/s)` — a full bar takes ~14 s to drain idle. Hitting `PANIC_MAX (50)` fires `Screamer.trigger()` and resets panic to 0.

The heartbeat `AudioStreamPlayer` (loaded via `GameState.load_audio("heartbeat")`) adjusts volume and pitch in proportion to max(`_panic / PANIC_MAX`, `_gaze_timer / GAZE_TRIGGER_TIME`).

Visual feedback is provided by `hud_canvas.tscn` (at `game/assets/elements/hud_canvas.tscn`) — a `PanicHUD` node with two shader-driven `ColorRect`s: `BlurRect` and `TintRect`. Driven by `set_panic_ratio(ratio)`.

To make a prop raise panic: the `ScaryObject` must be an **ancestor** of the `StaticBody3D` whose collider the gaze ray hits — `player.gd:_find_scary_object()` walks UP from the hit body. Build it as `ScaryObject (Node) → StaticBody3D → CollisionShape3D (+ mesh)`. Because `ScaryObject extends Node` (no transform) it **breaks the Node3D spatial chain**, so put the world transform on the `StaticBody3D` itself — its non-Node3D parent makes the body's local transform == its global transform. For a *moving* gaze prop (the void creatures), move that inner body, not the outer node. Set `scare_intensity` (default 1.0). ⚠️ Nesting `ScaryObject` *under* the body (the old pattern) silently registers **zero** panic — this was the bug behind the dead corridor/house cursed props and the non-reactive void creatures (fixed 2026-06).

Panic source priority per frame (`_update_panic`): gaze at a ScaryObject **with `scare_intensity > 0`** (2026-09-12, Issue 196 — an intensity-0 object such as a harmless or burnt Weeping Frame no longer blocks decay while looked at) > sprinting (+6/s) > dark-zone creep (+3/s, flashlight off) > decay. Dread-zone pressure (`DREAD_PANIC_RATE` **2.0**/s) is added **on top** regardless of branch, and inside a dread zone decay drops to `DREAD_DECAY_RATE` 2.0/s — the two cancel exactly, which is what makes KONTUR a no-decay level.

### Zone & movement modifiers
- `add_panic(amount)` — instant spike from scripted events/traps; fires the screamer at max like gaze panic
- **Sprint** (Shift): ×1.6 speed, +6 panic/s, suppresses decay while held — "Walk. Do not run." is a real rule
- **Calm zones** (torchlight): while inside ≥1 `CalmZone`, decay runs at ×2.5 (`CALM_DECAY_MULT`)
- **Dark zones**: while inside ≥1 `DarkZone` with the flashlight OFF, panic creeps +3/s (`DARK_PANIC_RATE`); gaze panic takes priority over dark-creep
- **Standstill** (Backrooms only, opt-in): +3/s after `STANDSTILL_GRACE` 4 s of `not _is_moving`. ⚠️ **Never while `_input_frozen` or `_qte_active`** (2026-09-07, Issue 182) — charging for not moving while the game refuses to let you move is Issue 18's shape. It became reachable the moment Issue 179 made a freeze clear `_is_moving`: before that a frozen player latched the flag from their last walking frame and was exempt **by accident**, and the fix turned that accident into +3/s through the Sprawl's 12 s scripted crate watch. `check_sprawl_crate.gd` went red with the player dead at t = 3.6 s. ⚠️ **The general lesson: a latched value is a de-facto guard, and correcting it removes protection nobody knew was load-bearing** — grep every reader of a flag before changing when it is written
- **Dread zones** (corridor Zone C, Void Rooms C+D): decay weakens to 2/s (`DREAD_DECAY_RATE`) and +2/s (`DREAD_PANIC_RATE`) accrues constantly — net idle rate barely negative
- **Flashlight**: infinite since 2026-09-03 (`INFINITE_BATTERY`) and widened to 1.6 energy / 18 m / 30° — ⭐ **except in the Lab and the House, which narrow it to 11 m / 24° via `set_torch_profile()` (2026-09-07)**, because at ambient 0.0 the beam is the only lever "come closer to see things" has. Every other level keeps the default, and must: `level_6_breach.gd:LIGHT_WEAPON_DOT` is `cos(FLASH_ANGLE)`. ON by default at spawn. ⚠️ It can still be taken away — `kill_flashlight()` (the Corridor's noclip, THE NIGHTMARE's candle) and `lock_flashlight()` (the Lab wing, hiding spots, the House cellar blackout) are untouched, and a LOCKED torch still sounds different from a DEAD one
- `apply_slow(duration)` — the beartrap LIMP, speed ×0.45 (`SLOW_MULTIPLIER`); timers don't stack, longest wins. `cancel_slow()` clears it immediately (beartrap escape success). ⚠️ Since 2026-08-15 this is only what happens AFTER you break free — being caught is a hard pin (`begin_qte()` → `_apply_movement()` zeroes `velocity.x/z`), not a slow
- **Read-to-die trap notes**: `NoteUI` feeds `player.add_panic(TRAP_PANIC_RATE × delta)` while a trap note is open (works during tree pause — NoteUI is `PROCESS_MODE_ALWAYS`)

## ⚠️ Skills — MUST use these, do not improvise

| When the user wants to… | Use |
|---|---|
| **build a NEW level** (or implement one of the three specced-unbuilt ones) | `new-level` |
| **fix / change / tune / improve an EXISTING level**, or act on a playtest, J-captures or a log — one level or several | `level-work` |

These two carry the procedure **and** the guards — including three failures that are silent
(`AUDIO_SUBDIRS`, `LEVEL_SCREAMERS`, `start_current_level()`'s `_:` arm) and a renumber whose real
size is **12 items, not the 5 this file used to list**. Improvising these is what produced the
2026-09-19 spec drift. Both mandate **running the game**, not just the assert suite.

## Skills and agents — the parts their own descriptions DON'T say

Skills live in **`.claude/skills/`** and agents in `.claude/agents/`, and both are listed with their
descriptions in every session — so what follows is **only** the rules and history that are not in
that listing.

⚠️ **Corrected 2026-09-19.** This paragraph said skills live in `.agents/skills/`. They did, and
that is exactly the problem: Claude Code loads `.claude/skills/`, so **every skill in this repo had
never once loaded** — for its whole life. `grill-me` appeared to work only because the user asked
for it by name and the file was opened by hand. The four live skills were moved to
`.claude/skills/`; `caveman`, `zoom-out` and `design-an-interface` are still in `.agents/skills/`
and **still do not load**. If you add a skill, it goes in `.claude/skills/`.

- ⚠️ ~~`nano-banana-pro`~~ is **DEAD** (2026-08-15) — the Gemini API path no longer works, and the
  skill is now disabled. Use the image pack instead: see **Image Generation**
- ⚠️ `idea-generator` must **not** recreate `REPORT.md` / `IDEA_HISTORY.md` at the repo root; both
  were consolidated into `GAME_MECHANICS_IDEAS.md` on 2026-07-27 and archived to `drafts/`. It
  writes accepted items into §4 and verdicts into §5, and **never implements anything itself**
- ⚠️ `game-tester`, `maze-tester` and `dungeon-tester` are **forbidden from changing difficulty
  constants** — that is always the user's call
- ⚠️ `level-improver` carries the same forbidden list **plus**: no new fail states, no shared files,
  no level renumbering. It cannot talk to the user — it returns `## OPEN QUESTIONS` and the parent
  session relays them
- ⚠️ `tools/run_tests.sh` deliberately routes `autoplay_dungeon` to the `dungeon-tester` agent
  rather than into the suite (it is a difficulty instrument, not a regression guard), which is what
  makes that agent load-bearing rather than optional
- `game-testing` (the SKILL, distinct from the `game-tester` AGENT) holds the log-signature tables
  (panic % → constants), the known false positives, and the verification rules

## Debugging
Before diagnosing any bug, read `docs/ISSUES_SOLUTIONS.md`. It documents the hardest bugs encountered so far — Godot input event double-fire, UI anchor off-screen rendering, raycast geometry misses on flat objects, the Gemini JPEG-as-PNG import failure, and double-screamer re-entry on rapid keypresses. Re-solving a known issue wastes time.

## API Keys
All keys live in `.env` at the project root. Never commit `.env`.
See `.env.example` for required keys.
