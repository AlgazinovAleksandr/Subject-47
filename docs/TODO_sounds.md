# TODO_sounds.md — sounds to source or generate

Audio the game is **already wired for** but that does not exist yet. Every entry below has a
working fallback in code, so nothing is broken while the file is missing — dropping the real
file in is all that is needed, no code change.

## How to add one

1. Put the file at the stated path. `.wav`, `.ogg` and `.mp3` all work —
   `GameState.load_audio()` tries each extension in that order.
2. Re-import so Godot sees it:
   `/Applications/Godot.app/Contents/MacOS/Godot --headless --path game --import`
3. Delete the row here.

⚠️ **Base names must be GLOBALLY UNIQUE.** `GameState.load_audio("x")` searches *every* audio
subdirectory and returns the first hit, so a duplicate name in another folder silently wins —
`door_slam` already collides in two folders, with the `level_3_corridor` copy shadowing the
Level 6 one. The names below were chosen to be unique; keep them.

⚠️ **Anything that needs to LOOP is restarted in code** via `finished -> play`, because every
`.wav.import` in this project is `loop_mode=0`. So a loop must start and end near silence or
it will tick once per cycle.

---

## Requested 2026-09-23 (Level 6 — the approach, pass 3): the user is supplying all of these

⚠️ **These are PLACEHOLDERS already at the final path**, not missing files. They were generated or copied by
`tools/make_sfx_breach_pass3.py`. The user's recording REPLACES the file at the same path, as a `.wav`
with the same base name, then `--import`. `breach_approach.gd` names each one in a `SND_*` constant, with
the stand-in's measured RMS beside it. If a supplied file is much louder or quieter, re-read that
constant's gain.

| File (in `game/assets/audio/level_6_breach/`) | What it is | Stand-in | Bus |
|---|---|---|---|
| `approach_whisper_dont_go_in.wav` | The dead technician's close, hoarse whisper: *"don't… go in there…"* (~2.5 s) | macOS `say -v Whisper`, roughened | Master |
| `approach_wheel_grind.wav` | **Loop.** The porthole wheel turning under load | generated | Ambience |
| `approach_wheel_creak.wav` | One creak per 30° of wheel | generated | Ambience |
| `approach_porthole_bolts.wav` | The door's bolts drawing back | copy of KONTUR's `door_seal` | Master |
| `approach_porthole_swing.wav` | The heavy hatch heaving open (~3 s) | the Lab's `metal_creak`, slowed | Master |
| `approach_handle_clack.wav` | The handle seating on the wheel | generated | Master |
| `approach_spark_burst.wav` | One burst from the junction box | copy of the Lab's `breaker_spark` | Ambience |
| `approach_spark_buzz.wav` | **Loop.** The junction box's constant buzz | copy of the Lab's `breaker_buzz` | Ambience |
| `approach_darkroom_bed.wav` | **Loop.** The dark room's own ambience, fading in only inside | generated | Ambience |
| `approach_glass_crunch_1/2/3.wav` | Glass underfoot in the cell chamber, three variants | generated | Master |
| `approach_crt_hum.wav` | **Loop.** The CCTV monitor's hum | generated | Ambience |

And one video: `game/assets/video/breach_cctv_breakout.ogv`, the CCTV breakout loop. The stand-in is from
`tools/make_breach_cctv_placeholder.py`. Convert the user's clip with the Theora recipe in
`assets_src/README.md`. Grain, scanlines and the timestamp are laid over it in the game, so don't bake
them in.

---

## Requested 2026-07-28 (playtest, Intro room)

| File | Length | What it is | Where it fires |
|---|---|---|---|
| `game/assets/audio/intro/switch_stuck.wav` | ~0.5–0.8 s | **A light switch that does NOT throw.** A heavy mechanical clack that stops short — the sound of a switch hitting something and refusing, not a switch working. It must be clearly *different* from `switch_clunk` (the successful throw on the second press), because the whole beat is "that did not work, try again". A dry electrical fizz/pop layered under it is welcome. | `intro_room.gd:_on_switch_stuck()` — the FIRST press of the light switch |
| `game/assets/audio/intro/wheelchair_turn.wav` | ~1.1 s | **A wheelchair turning on a concrete floor, by itself.** Caster squeak plus the low grind of loaded rubber pivoting; slow, deliberate, unhurried. Should feel like weight moving, not like a door hinge. Length wants to match `WHEELCHAIR_TURN_TIME` (1.1 s) so the sound ends as the turn ends. | `intro_room.gd:_tick_wheelchair()` — when the player gets within 3.2 m of the wheelchair and looks at it, after reading the note |

**Current fallbacks** (what you hear until the files land):
- `switch_stuck` → `switch_clunk` at +4 dB with `breaker_spark` under it.
- `wheelchair_turn` → `gurney_creak` at +2 dB.

---

## Standing gap (not from a playtest)

| File | What it is | Why it matters |
|---|---|---|
| `game/assets/textures/shared/watcher_figure.png` | **Not audio** — listed here so it is not lost. A full-body human silhouette, ~1024×2048, **real RGBA alpha** (a `.jpg` or a painted-on checkerboard renders as a solid rectangle — the `apparition_figure.jpg` bug). Almost entirely dark grey-black, **no facial features, no glow, no rim light**, deliberately low contrast. Slightly wrong proportions: arms ~10 % too long. | Used in three places — the Corridor's open doorway, the House cellar corner, and all 6–12 figures of the Backrooms Sprawl's Congregation. ⚠️ **RESOLVED — this row was stale.** The file exists at that path and the registry row further down already marks it ✅ DONE; the 'falls back to a silhouette' claim was left behind. Kept rather than deleted (the file's own rule 3) because the art spec above is worth having on record. ⚠️ Convert with `sips -s format png` after generating: the Gemini pipeline returns JPEG data inside a `.png` and Godot imports it as invalid while `ResourceLoader.exists()` still returns true (Issue 1/25). |

---

## Requested 2026-07-28 (playtest, The House)

| File | Length | What it is | Where it fires |
|---|---|---|---|
**✅ BOTH SUPPLIED BY THE USER 2026-07-29** — `fridge_scream.wav` and `childe_scream.wav`, and the
code now loads those names directly. Kept here only for the gotcha:

⚠️ **`AudioStreamPlayer3D.max_db` defaults to 3.** Setting `volume_db` above that does nothing —
the gain is clamped straight back off. Both of these are asked to be "very loud" (+10 and +18 dB),
so both raise `max_db` as well. If a sound is set loud and is not loud, check that first.

---

## Textures — DONE 2026-07-28

All five generated and in the game. Kept here only for the two lessons.

⚠️ **The key was never the problem.** `nano-banana-pro/generate_image.py` reads the
`GEMINI_API_KEY` *environment variable*, and `load_dotenv()` does not override a variable that
is already set — the shell profile exports a stale 39-character key which was winning over the
current 53-character one in `.env`. Symptom: `400 API_KEY_INVALID` with a perfectly good key on
disk. Fix, per command:
```bash
export GEMINI_API_KEY=$(grep -E '^GEMINI_API_KEY=' .env | head -1 | cut -d= -f2- | tr -d '"'"'"'"'"'"' \r')
```
(A `503 UNAVAILABLE` is different — that is real server load; retry with a short backoff.)

⚠️ **Every one of the five came back as opaque RGB with NO alpha channel**, however the prompt
was worded, and one of them painted a checkerboard as the "transparent" background — the exact
`apparition_figure.jpg` trap in `SCARY.md` §7.1(2). Never trust the prompt; run
`tools/cutout_alpha.py` afterwards, which keys the pale background to real alpha and crops to
the figure (it also fixes the generator always returning 16:9 when asked for portrait).

Generate with:
```bash
nano-banana-pro/.venv/bin/python3 nano-banana-pro/generate_image.py "<prompt>" -o <path>
sips -s format png <path> --out <path>     # MANDATORY — see Issue 1/25
```

| File | What it is | Used by |
|---|---|---|
| `level_2_house/house_child.png` | ✅ DONE — regenerated twice. Now a life-size **antique porcelain doll**: cracked glaze, black glass eyes, mouth open too wide, filthy grey lace, lit dim and low-key so it sits in an unlit cellar naturally. ⚠️ The first attempt ("emaciated screaming child") was REFUSED by the safety filter — reframe, do not retry the same words. | THE GUEST, the cellar sequence |
| `level_2_house/house_fridge_thing.png` | ✅ DONE — a frozen head, milky open eyes, bruised hollows, slack jaw. ⚠️ Ask for a plain background: the first pass baked in a wire shelf that doubled up on the geometry ones. | `house_fridge.gd` interior |
| `level_2_house/house_fridge.png` | ✅ DONE | Kitchen |
| `level_2_house/house_drawer.png` | ✅ DONE | `kitchen_drawer.gd` |
| `level_2_house/house_music_box.png` | ⬜ STILL MISSING — music box body: painted timber, brass fittings, worn. Flat orthographic, no environment. The prop reads on silhouette (lid ajar, crank, feet) so this is polish, not a blocker. | `level_2.gd:_spawn_music_box()` |
| `shared/watcher_figure.png` | ✅ DONE — the generic distant figure. Still used by the Corridor doorway and the Sprawl's Congregation; the House cellar's copy was cut (one figure per room). | Corridor / Sprawl |
