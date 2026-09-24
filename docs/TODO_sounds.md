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

## 2026-09-24 — Intro: THE INTAKE WING (stand-ins, all wanted)

Procedural stand-ins from `tools/make_sfx_intro.py` (stdlib only; `python3 tools/make_sfx_intro.py`
writes ONLY these — the four older intro sounds are rewritten only with `--all`). Replace any of them
by dropping a real recording into `game/assets/audio/intro/` under the **same base name**, then
`--import`; no code changes. Levels measured with ffmpeg `volumedetect` (mean / max).

| File (in `game/assets/audio/intro/`) | What it is | Real-sound prompt (for a sound designer / AI generator) | Stand-in (measured) | Suggested bus / volume |
|---|---|---|---|---|
| `intro_strap_buckle.wav` | A leather restraint strap pulled free of its buckle — three times, one per strap, while you lie on the cell bed | "Close, dry: a thick leather hospital restraint strap drawn back through a steel buckle, leather creaking under tension, a slap of slack leather, the buckle tongue clinking free, 1 second, no room tone" | stick-slip creak, a leather slap at 0.47 s, three inharmonic clinks. −21.0 / −1.0 dB | 3D at the strap, 0 dB, unit 2 |
| `intro_cell_buzz.wav` | The cell door's electric release after the third strap | "Institutional electric door release: a harsh 1-second buzzer with a rattling armature, then a heavy steel bolt shooting back, concrete room, 1.7 seconds" | clipped 120/240 Hz buzz with 31 Hz armature AM, then a bolt clack. −12.9 / −1.0 dB | 3D above the door, +2 dB |
| `intro_door_creak.wav` | An old wooden ward door swinging open (every door in the wing) | "Old heavy wooden hospital door opening slowly on dry rusty hinges: a latch click, a long wavering hinge squeal, a soft knock at the stop, 1.6 seconds, empty corridor" | latch tick, stick-slip hinge squeal slowing, soft stop knock. −20.3 dB mean | 3D at the door, 0 dB |
| `intro_door_rattle.wav` | A locked door tried: the handle rattling against its latch | "Someone trying a locked old door: the brass handle turned and rattled hard against a latch that will not give, 0.7 seconds, dry" | five knock+tone rattles. −22.5 / −1.0 dB | 3D at the door, −4 dB |
| `intro_tap_rust.wav` | The cell tap's first turn: the pipe coughs rust before it runs | "An old tap turned on after years: pipes knock, air coughs and sputters, brown water spits and gurgles into a steel basin, then starts to run, 3 seconds" | low pipe knocks, band-noise sputter bursts thickening, bubble clicks. −17.1 / −1.0 dB | 3D at the sink, −6 dB |
| `intro_tap_water.wav` | ⚠️ **LOOP** — a thin steady stream into a steel basin | "Seamless 3-second loop: a thin steady stream of tap water falling into a small steel hospital basin, close, no room reverb" | band noise + splash shimmer, tail cross-faded into the head. −15.6 / −6.0 dB | 3D at the sink, −6 dB, restarted on `finished` |
| `intro_bulb_hum.wav` | ⚠️ **LOOP** — a bare filament bulb's mains buzz, under every caged bulb | "Seamless 4-second loop: the faint electrical buzz of a bare incandescent bulb on old wiring, 100 Hz hum with harmonics, very slight unsteady flutter" | 100/200/300 Hz + a 50 Hz edge, slow wobble. −14.1 / −8.0 dB | 3D per bulb, −24 dB, unit 1.2 (Ambience) — it dies in the blackout |
| `intro_power_cut.wav` | The wing losing power as the ward door opens | "A building's power cutting out: a heavy relay slam, every electrical hum dropping away at once in a falling whine, a tick of cooling metal, 2.4 seconds" | relay thump, 120 → 18 Hz falling whine, a late tick. −19.7 / −1.0 dB | 3D at the ward door, +2 dB, unit 8 |
| `intro_session46_tape.wav` | The reel-to-reel's "SESSION 46" reel (~40 s). ⚠️ **WORDLESS** — the voice is rationed to five lines | "40 seconds of an old reel-to-reel interview tape played back: capstan motor and heavy hiss, two voices murmuring indistinctly behind a wall (no intelligible words), one voice faltering, close breathing getting faster, a chair scraping, silence, one sharp gasp, then the tape running out and its tail flapping on the reel" | motor + hiss bed; formant-buzz murmur in turns; breathing that quickens; chair scrape at 20.4 s; gasp at 35.3 s; tail flap from 38.2 s. −23.5 / −3.1 dB | 3D at the deck, +2 dB, unit 3 |

**The five observer lines** are TTS, not stand-ins in the same sense — `python3 tools/make_pa_voice.py
intro` writes `pa_intro_{morning,fault,screen,better,proceed}.wav` (macOS `say` "Daniel" through the
Lab PA's tannoy chain; the same person as `pa_trial4`). A human read of the same five lines, run
through the same chain or a real tannoy, would be the upgrade. Only `pa_intro_morning` plays in this
build (VO2–5 land with the ward retrofit and calibration).

---

## 2026-09-24 — House porch pass (stand-ins)

✅ **2026-09-24 (b): six of these are the user's recordings now**, under the user's own names. The
code loads only the user's file. The stand-ins they replaced, and `witch_hum`, are **untracked and
gitignored** (the user's rule: the repo ships only what the game loads), and the tool now writes
only the three stand-ins still played:
- the night outside: **`dark_forest_soundtrack.ogg`**, replacing `porch_forest_night`. The user's
  14.5 MB `.wav` became a q6 `.ogg`; the original is in `assets_src/audio/level_2_house/`.
- the pane bursting: **`window_glass_break.wav`**, replacing `window_burst`. It is the user's
  `glass_break.wav`, renamed because `shared/glass_break` would have shadowed it.
- the blade: **`guillotine.mp3`**, replacing `guillotine_drop`.
- the melon: **`watermelon_crack.wav`**, replacing `melon_burst`.
- all three ghosts: **`ghost_sound.wav`** at pitch 1.1 / 1.35 / 0.62, replacing the three
  synthetic screams.
- **`witch_scream.mp3`** is new: the witch's second glimpse, behind you in the Hallway.

Still stand-ins, still wanted: `porch_wind_gust`, `guillotine_rope`, `forest_run_leaves`, and (new
2026-09-24 c) **`blade_pull`**. The rows below for the other eight are history.

⭐ **2026-09-24 (c): `blade_pull.wav` — NEW, a stand-in, wanted.** The guillotine's blade is driven
into a stump in a clearing out in the forest now (the forest became the required search); E pulls it
free and this plays AT the stump (`house_blade_stump.gd`, 3D, 0 dB, unit size 5).

| File (in `game/assets/audio/level_2_house/`) | What it is | Real-sound prompt (for a sound designer / AI generator) | Stand-in (measured) | Suggested bus / volume |
|---|---|---|---|---|
| `blade_pull.wav` | A heavy guillotine blade wrenched out of a wet tree stump | "A heavy steel blade levered and wrenched out of a wet rotten tree stump outdoors at night: wood creaking and groaning under strain, a short metal scrape, a wet sucking release, then the freed blade ringing briefly, 1.5 seconds, close, dry, no music" | stick-slip wood groan through two resonances rising for 0.78 s, a rising 2.2–4.8 kHz scrape from 0.44 s, a wet lowpassed suck and knock at 0.80 s, then four inharmonic plate partials (612 / 1487 / 2716 / 4130 Hz) ringing out; tanh. Peak −3.0, RMS −18.4, loudest-300 ms −12.3 | 3D at the stump, 0 dB (the caller's `PULL_DB`) |

⚠️ PLACEHOLDERS at the final path, **synthesised** by `tools/make_sfx_house_porch.py` (stdlib, seeded
per sound, 44.1 kHz 16-bit mono). The user is supplying the real ones: drop the real file over the
`.wav` with the same base name (or as `.ogg`/`.mp3` and delete the `.wav`), `--import`, then **remove
that name from `SOUNDS` in the tool**, or the next run of it silently overwrites the real recording.
Levels are the tool's own measurements (peak / loudest-300 ms, dBFS) — set a caller's `volume_db`
from those, not from a guess. The bus/volume column is a suggestion for the code, not a measurement.

| File (in `game/assets/audio/level_2_house/`) | What it is | Real-sound prompt (for a sound designer / AI generator) | Stand-in (measured) | Suggested bus / volume |
|---|---|---|---|---|
| `porch_forest_night.wav` | The porch bed: the pine forest at night — ⚠️ a **seamless 20 s loop** | "Seamless 20-second loop, night pine forest ambience: low wind breathing through tall pines, needles hissing in slow swells, one distant trunk creak, no birds, no insects, no music, dark and lonely" | brown-noise wind + a breathing needle-hiss band, two low creaks at 6.3 s and 14.1 s; filtered circularly, every modulation a whole number of cycles, so the seam is clean. Peak −12, loudest −23.6 | Master, 2D bed, about −6 dB, restarted on `finished` |
| `window_burst.wav` | The window blowing in | "Violent close glass window shattering inward, heavy impact then a long rain of glass shards falling on wooden floorboards, 2 seconds, dry, no reverb tail" | the shared `glass_break.wav` layered under a thump, a broadband crack and a dense rain of short inharmonic shard tinkles thinning over 1.8 s. Peak −3, loudest −7.5 | Master, 0 dB (a sting); 3D at the window if positional |
| `porch_wind_gust.wav` | A cold gust through the broken window | "Single cold winter wind gust swelling through a broken window then dying away, whistling edge, 4 seconds, no rain" | a band-passed noise rush rising 350 → 1250 Hz and a narrow whistle band + tone, 1.4 s up, 2.6 s away. Peak −6, loudest −17.9 | Master, about −4 dB |
| `guillotine_rope.wav` | The guillotine's rope being pulled up through its pulley | "Old hemp rope hauled through a rusty wooden pulley, creaking and squeaking, ending in a sharp iron catch clicking into place, 1 second" | a stick-slip pulse train through two pulley resonances + rope rustle, then a three-partial metal clack at 0.84 s. Peak −3 (the clack), loudest −22.4 | 3D, 0 dB |
| `guillotine_drop.wav` | The blade dropping and hitting the block | "Heavy guillotine blade released: a fast rising metal scrape down wooden grooves, then a massive deep wooden thunk and a short ringing of the blade, 1.5 seconds" | a noise band and a screech both rising in pitch for 0.58 s, then a pitch-dropping 48 Hz thunk, a wood knock and a blade ring; tanh. Peak −3, loudest −8.3 | 3D, +2 dB (or Master, 0 dB if it must dominate) |
| `melon_burst.wav` | The watermelon splitting under the blade | "Watermelon smashed and split open: a hard rind crack, then a wet juicy burst and splatter of pulp and juice onto wood, 1.5 seconds, gross, close" | a click and a hollow knock, a swell of low wet noise, then a rain of short resonant squelch drops thinning over 1.2 s; tanh. Peak −3, loudest −12.7 | 3D, 0 dB |
| `ghost_woman_scream.wav` | The running ghost woman's scream | "Shrill piercing scream of a terrified woman, raw and cracking, strong vibrato, slightly inhuman, heard outdoors in a forest at night, 2.5 seconds" | an additive formant voice, f0 620 → 1000 Hz with 6.3 Hz vibrato and jitter, "aah" opening to "eeh", breath edge, tanh, a little reverb. Peak −3, loudest −8.7 | 3D on the ghost, 0 dB, unit size large so it carries |
| `ghost_crawler_screech.wav` | The all-fours crawler's cry | "Guttural animal-like screech from an emaciated crawling creature: wet throat clicks, a low rattling growl rising into a harsh high shriek, 2 seconds" | a rough 88 Hz growl + sub-octave, a harsh 1.25–1.55 kHz formant screech from 0.55 s to 1.6 s, and an irregular train of hard resonant clicks throughout; tanh. Peak −3, loudest −10.7 | 3D on the crawler, 0 dB |
| `ghost_tall_howl.wav` | The tall ghost's howl | "Very low, slow, inhuman howl of an enormous creature far off in a pine forest, a deep moan rising and falling, long echoing decay, 4 seconds" | two detuned additive "oo" voices at 52–78 Hz + a sub-octave + low breath, a long Schroeder tail. Peak −4, loudest −13.3. ⚠️ Mostly below 300 Hz — inaudible on laptop speakers | 3D, +3 dB, large attenuation distance |
| `forest_run_leaves.wav` | Fast footfalls running through dry leaves (a ghost passing) | "Fast running footsteps through dry leaves and pine needles on a forest floor, 2 seconds, about seven steps, close then passing" | nine steps ~0.23 s apart, each a low thud + a cloud of 22–40 tiny dry crackles. Peak −5, loudest −24.6 | 3D on the runner, about +4 dB |
| `witch_hum.wav` | The witch humming to herself | "Very quiet frail old woman humming a slow wavering minor lullaby through closed lips, breathy, unsteady pitch, close and intimate, 5 seconds, no words" | two slightly detuned nasal "mmm" voices sliding through A3 C4 B3 A3 G♯3 A3 with a wobbling 4.6 Hz vibrato, breath noise, a small room. Peak −10, loudest −15.4 | 3D on the witch, about −6 dB, small unit size so it is heard only close |

---

## Requested 2026-09-23 (Level 6 — the approach, pass 4): placeholders at the user's fixed paths

⚠️ PLACEHOLDERS at the final path, from `tools/make_sfx_breach_pass4.py` (ffmpeg copies). Replace the file at
the same path, same base name, then `--import`. `breach_approach.gd` names each in a `SND_*` constant.

| File (in `game/assets/audio/level_6_breach/`) | What it is | Stand-in | Bus |
|---|---|---|---|
| ~~`approach_drop_crash.wav`~~ ✅ | The ceiling hatch bursting and the body's weight hitting the chain (Containment) | **the user's `drop_crash` (2026-09-24)**. It is byte-identical to their `metal_crash`, the door tell's crash, so a distinct impact is still welcome | Master, +2 dB |
| ~~`approach_drop_chain.wav`~~ ✅ | The chain rattling as the body swings | **the user's `drop_chain` (2026-09-24)** | Master |
| `approach_shutter_breath.wav` | *Optional.* A very low breath from bay B's niche as the face is revealed | KONTUR's `breathing_behind`, slowed ×0.82, low-passed 1.8 kHz | Master, −14 dB |
| *(no file)* the seal race's grind | The blast door grinding shut while E is held | `approach_wheel_grind` in code, pitch 0.55 (`purge_chamber.gd:_race_begin`); since 2026-09-24 that is the user's `wheel_grind` recording, pitched down | 3D, Master |

A dedicated grind (`seal_grind.wav`, a **loop**) would need one line in `purge_chamber.gd:_race_begin()`.

✅ **2026-09-24: the purge door's final slam is the user's `metal_door_close`**, as `purge_door_slam.wav`, the user's call. It is peak-matched to the old slam and loaded by both slam paths in `purge_chamber.gd`, falling back to `blast_door_slam`. The approach bulkhead keeps `blast_door_slam`.

All five user recordings are prepared by `tools/prepare_breach_user_sfx.py`: loudness-matched to the placeholders they replace, originals unchanged in `assets_src/audio/level_6_breach/approach/user/`.

## Requested 2026-09-23 (Level 6 — the approach, pass 3): the user is supplying all of these

⚠️ **These are PLACEHOLDERS already at the final path**, not missing files. They were generated or copied by
`tools/make_sfx_breach_pass3.py`. The user's recording REPLACES the file at the same path, as a `.wav`
with the same base name, then `--import`. `breach_approach.gd` names each one in a `SND_*` constant, with
the stand-in's measured RMS beside it. If a supplied file is much louder or quieter, re-read that
constant's gain.

| File (in `game/assets/audio/level_6_breach/`) | What it is | Stand-in | Bus |
|---|---|---|---|
| `approach_whisper_dont_go_in.wav` | The dead technician's close, hoarse whisper: *"don't… go in there…"* (~2.5 s) | macOS `say -v Whisper`, roughened | Master |
| ~~`approach_wheel_grind.wav`~~ ✅ | **Loop.** The porthole wheel turning under load | **the user's `wheel_grind` (2026-09-24)**, seam crossfaded 0.4 s | Ambience |
| `approach_wheel_creak.wav` | One creak per 30° of wheel | generated | Ambience |
| `approach_porthole_bolts.wav` | The door's bolts drawing back | copy of KONTUR's `door_seal` | Master |
| ~~`approach_porthole_swing.wav`~~ ✅ | The heavy hatch heaving open (~3 s) | **the user's `metal_door_open` (2026-09-24)** | Master |
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
