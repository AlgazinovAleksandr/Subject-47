# Assets, audio and the folder layout

## Folder Layout
```
horror_game/
├── assets_src/            ← ⚠️ UNPROCESSED originals of supplied assets, OUTSIDE game/ so
│                            Godot never imports them. The tools that consume these are
│                            destructive (restencil_door.py: "run it once, on a copy"), so
│                            the shipped file cannot regenerate itself — these are the only
│                            inputs the pipelines can be re-run from. See assets_src/README.md
│                          ⚠️ PARTLY GITIGNORED since 2026-08-19, and the rule is "does an
│                            automated step read it": the 7 files a tools/ script or a test
│                            takes as INPUT are committed (three make_*.py hard-code their
│                            SRC into this folder, so ignoring them breaks a fresh clone).
│                            Local-only: ALL FIVE video originals (two of them untracked on
│                            2026-08-19 — an ignore rule does nothing to an already-tracked
│                            file, it takes `git rm --cached`), the Veo seeds, reference/,
│                            and every orphan `*_raw.*`. Still tracked: the retired assets in
│                            textures/superseded/ that are not `_raw`.
│                          ⚠️ With VIDEO_PROMPTS.md gitignored too, the five cutscenes are
│                            UNRECOVERABLE from a fresh clone — no source, no prompts, only
│                            the finished .ogv. Deliberate; do not re-derive a clip from one.
│                            Nothing here is loaded by the game at runtime —
│                            every assets_src mention inside game/ is a comment. The table
│                            lives in .gitignore AND assets_src/README.md; keep them in sync
├── backlogs/              ← ⚠️ GITIGNORED ON PURPOSE — local development material, not for
│                            viewers of the public repo (the user's call, 2026-08-19). It is
│                            documented here anyway because a session needs to know it
│                            exists. The level-by-level improvement run (2026-08-16): one
│                            NN-<level>.md per level holding playtest evidence, diagnosis
│                            and costed items, plus 00-cross-level.md (the parking lot for
│                            whole-game issues, written to but never acted on). Indexed
│                            from GAME_MECHANICS_IDEAS.md; rejections cross-post to its §5
├── drafts/                ← superseded docs, annotated rather than deleted (REPORT.md,
│                            IDEA_HISTORY.md, and the KONTUR set archived 2026-08-15)
├── game/                  ← Godot project root (scenes/ scripts/ assets/{audio,elements,
│                            models,textures,materials} — `ls` for the rest)
├── tools/                 ← 29 dev scripts, stdlib-only unless noted:
│                         ⚠️ NEW 2026-09-03: sfx_loudness.py (the shared compress+tanh pipeline —
│                         a peak-normalised sting cannot be made louder with a gain, only denser),
│                         remaster_scares.py (SOURCED stings, in place, originals backed up),
│                         make_sfx_house_lamp.py, merge_creature_glb.py (six 15 MB Meshy GLBs ->
│                         one 9.8 MB model, with the material surgery the source needs),
│                         make_breach_door.py.
│                         ⚠️ A GENERATED sting is fixed in its GENERATOR, never here — the four
│                         make_sfx*.py files take `write_wav(..., loud=)`. Post-processing one in
│                         place is silently reverted the next time anyone re-runs a generator to
│                         add one sound. Check `grep -rl '"<name>' tools/*.py` first. procedural SFX synths
│                         (make_sfx*.py), audio post (make_loop.py), image post
│                         (cutout_alpha.py, restencil_door.py, flatten_alpha_checker.py,
│                         make_arrow_decal.py, crop_kontur_art.py, make_kontur_signs.py —
│                         these need Pillow, so run them with the image pack's venv, see
│                         Image Generation), run_tests.sh
│                         ⚠️ make_arrow_decal.py DRAWS rather than generates: an arrow is a
│                         geometric primitive whose one job is being unambiguous at 15 m, and
│                         no diffusion model can be asked for an exact chevron
├── nano-banana-pro/       ← ⚠️ DEAD (2026-08-15) — the Gemini skill no longer works. Kept only
│                            so old `.md` references resolve. Do not call it. See Image Generation
├── .agents/skills/        ← Claude skills
└── .env                   ← API keys (never commit)
```

### ⚠️ `*.import` and `*.uid` ARE committed — do not re-ignore them

`.gitignore` deliberately ignores **only `.godot/`** of Godot's generated data (2026-08-15),
matching Godot 4's own recommended ignore file.

Those two file types carry the stable `uid://` identifiers that `.tscn` and `.tres` files
reference — 51 resource refs and 36 script refs across this project. While they were ignored,
every fresh import regenerated them with NEW uids and the scenes kept pointing at the old ones:
measured, **26 stale references across 13 files**, producing 5 `invalid UID` warnings on every
single scene load. Godot falls back to the text path, so the game still ran — which is exactly
why it went unnoticed for so long.

The 26 references were repaired in place (uid values only; `path=` untouched) and the warnings
are now 0. They are portable — every path inside an `.import` is `res://`-relative and the cache
filename is derived from the source path, so the files are byte-identical on any machine.

⚠️ If you ever delete a script or asset, delete its `.uid`/`.import` sibling too. Four orphans
had accumulated and were removed in the same pass.

### Audio import

⚠️ **`tools/make_loop.py` turns a one-shot into a seamless loop** — it trims the fade-out and
crossfades the tail over the head with equal-power windows. Needed because every `.wav.import`
here is `loop_mode=0`, so loops are restarted in code by `finished -> play` and any level
mismatch at the seam ticks once per cycle. Built for the House's `chase.wav`, which arrived as
a 29 s composed piece fading to −25.5 dBFS: measured, the seam gap went 10.2 dB → 0.7 dB.

⚠️ **`tools/restencil_door.py`** is the image counterpart: it crops a generated door to its
leaf and repaints a stencilled sign. Its header records two dead ends worth not repeating (a
median-filter inpaint leaves readable ghosts; there is no clean donor patch on that door
because the sign plate is the brightest surface on it). Run it with the Pillow venv, and AFTER
`cutout_alpha.py`.

New `.wav`/`.ogg` files need a Godot import pass before `ResourceLoader` sees them: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path game --import` (or open the editor and let the scan run). Corridor SFX (`clock_chime`, `glass_shatter`, `beartrap_snap`, `door_slam`, `whispers`) are generated by `tools/make_sfx.py` (seeded, reproducible); `ghost_house.wav` is the corridor ambience. House SFX (`lock_buzz`, `footsteps_above`) are generated by `tools/make_sfx_house.py` (same stdlib-only conventions). Backrooms SFX (`fluorescent_hum` looping ambience, `light_pop`, `rotary_ring`, `phone_whisper`) are generated by `tools/make_sfx_backrooms.py` into `game/assets/audio/level_backrooms/`. ⚠️ **The seam tell (`seam_draw` far cue + `seam_rip` near confirm) has its OWN generator, `tools/make_sfx_seam.py`** — `make_sfx_backrooms.py` calls `random.uniform` without seeding, so re-running it to add one sound silently rewrites `light_pop`/`rotary_ring`/`phone_whisper` with different noise. `make_sfx_seam.py` is seeded, prints each file's measured RMS dBFS (which is where `backrooms.gd`'s `SEAM_FAR_DB`/`SEAM_NEAR_DB` come from — set a gain from the file, never from a plausible number), and builds both loops seamless by construction: every modulation frequency completes a whole number of cycles in the loop length and the noise beds are generated as circular buffers. ⚠️ **The two Backrooms PUZZLE tells have their own generator too, `tools/make_sfx_backrooms_puzzle.py`** (2026-08-17, seeded, stdlib): `plate_hum`/`plate_ring`/`plate_set`/`plate_done`/`piece_lift` for the Flood's plate table, and `sprawl_call_far`/`sprawl_call_near`/`crate_shriek` for the Sprawl's box in the dark. It prints each file's measured RMS, which is where `flood_plate.gd`'s and `sprawl_crate.gd`'s gains come from. ⚠️ `crate_shriek` is its own file rather than a borrowed scream on purpose: every candidate already in the project belongs to another beat, and reusing a FATAL screamer for a survivable scare teaches the player the fatal sound is free. ⚠️ It was made **+14.6 dB louder on 2026-08-18** (−20.0 → **−5.4 dBFS RMS**, peak unchanged at −1.01 and zero samples at full scale) on the user's call: the file was already peak-normalised and `flash_scare()` takes no gain, so the only lever is the AVERAGE level — sustained envelopes plus a `tanh` soft-clip, which is bounded by construction rather than by a tuned number. Duration deliberately unchanged, because the sting must not outlive the 0.9 s image. **KONTUR SFX** are generated by `tools/make_sfx_kontur.py` into `game/assets/audio/level_5_kontur/` (`ambient_kontur` looping bed, `breathing_behind`, `door_seal`, `acid_hiss`, `pedestal_alarm`, `kontur_flash`, `screamer_kontur`). ⚠️ **KONTUR's 2026-08-18 additions have their OWN generator, `tools/make_sfx_kontur_extra.py`** (`perekozhnik_shed`, the disguise coming off; `object12_cell`, the containment field's seamless loop) — for the reason `make_sfx_seam.py`'s header gives: `make_sfx_kontur.py` seeds once at module scope and writes seven files in order, so appending an eighth changes the RNG stream every later call sees. It prints each file's measured peak and RMS dBFS, which is where `MIMIC_SHED_DB` (+10.2) and `ContainmentCell.HUM_DB` (−18.0) come from. **Corridor mirror SFX** are generated by `tools/make_sfx_mirror.py` — `mirror_wake` (the glass coming alive) **and, since 2026-08-17, `mirror_stare`** (the seamless loop that rises while you stare into it). ⚠️ That file also owns the project's `compress` + `saturate` pipeline: a peak-normalised transient cannot be made louder with a gain, only denser (Issue 101). **The Corridor's false-door scream** is `tools/make_sfx_false_door.py`. **Session 10 SFX** are generated by `tools/make_sfx_extra.py` (uv-venv-friendly, still stdlib-only): `pipe_groan` + `apparition_drone` → `shared/`, `breaker_throw` → `level_1_lab/`, and `tv_static` + `music_box` + `water_drip` → `level_2_house/`. **Level 6 (THE BREACH) SFX** are generated by `tools/make_sfx_level6.py` into `game/assets/audio/level_6_breach/` (`ambient_breach` looping bed, `door_slam`/`door_batter`/`door_break`/`blast_door_slam`, `shield_stagger`/`shield_drain_loop`, `screamer_breach`, `creature_growl_near`); the level's `acid_hiss` reuses KONTUR's file directly via `GameState.load_audio()`'s subdir scan. The user-provided `mystical_sound.mp3` lives here too, as `ambient_breach_layer.mp3` — a secondary ambience layer, never the primary bed (see the Level 6 write-up).

**The Breach approach (2026-09-23) has four tools of its own, and none rewrites an older file.**
- **`tools/prepare_breach_approach_audio.py`** (stdlib + ffmpeg) prepares the user's thirteen
  approach recordings.
  - It reads the UNCHANGED originals in `assets_src/audio/level_6_breach/approach/`, copied
    byte-for-byte from the user's `new_sounds/`.
  - It decodes to FLOAT and normalises to −1.5 dBFS there, so four sources that decode above full
    scale do not clip.
  - It writes `approach_*` WAVs into `level_6_breach/`: mono, except the stereo ventilation bed,
    whose loop seam is crossfaded.
  - It prints each file's RMS and loudest-300 ms.
- **`tools/make_sfx_breach_approach.py`** (seeded, stdlib) generates the drag, the grating clang,
  the receiver ring, the duct rattle and twelve `approach_mach_*` one-shots. It prints the loudest-300 ms
  that `breach_approach.gd:MACHINERY` sets its gains from.
- **`tools/make_breach_pa.py`** builds `approach_pa_1..3` on KONTUR's `say` + ffmpeg tannoy chain.
  It copies the chain; it does not modify `make_kontur_voice.py` or `make_pa_voice.py`.
- **`tools/make_breach_approach_art.py`** (Pillow; run it with the image pack's venv) keys the flux
  decal raws into RGBA and draws every surface that carries words. It asserts that each cutout has a
  clear border.

All four are deterministic: two consecutive runs of the audio tools produced byte-identical output.
⚠️ Base names are prefixed `approach_`, because `load_audio()` resolves by base name across every
subdir, and names like `dust` or `motor` are one careless file away from a silent collision.

**Level 1 locker + nook SFX (2026-07-26, sourced not generated)** live in `game/assets/audio/level_1_lab/`: `locker_shove` (one per TAB press, pitch-randomised), `locker_settle` (the final slide), `nook_breath` (⚠️ **seamless loop** — every `.wav.import` here is `loop_mode=0`, so `level_1.gd` restarts it via `finished → play` and any discontinuity ticks once per loop) and `nook_scream` (the `flash_scare` payload). `GameState.load_audio()` resolves by base name across every subdir, so new names must be **globally unique** — `door_slam` already exists in two folders and the `level_3_corridor` copy silently wins.

⚠️ **A SECOND conversion pass ran 2026-08-15**, by the same rule, freeing **31.9 MB**:
`ambient_asylum` (27.3 → 2.9 MB, 9.5×), `phone_ringing` (40.7×), `nightmare_scream`,
`fridge_scream` and `apparition_snarl`. All five were SOURCED, all five are loaded by base name
through `load_audio()`, and no `.tscn` references audio at all — so the extension change was
invisible to the code. ⚠️ **`chase.wav` was deliberately NOT converted**: it is the output of
`tools/make_loop.py`, whose whole job is a seam that matches to 0.7 dB, and Ogg Vorbis encoder
delay can reintroduce a gap in exactly the loop that tool exists to create. It is also the one
audio file referenced by a hardcoded path (`maze_chase_ui.gd:CHASE_PATH`) rather than by base
name. Both reasons put it on the "leave as `.wav`" side of the rule below.

**Large sourced audio was converted `.wav` → `.ogg` to keep the repo lightweight** (2026-07-21): the big ambient beds and long screamer/scream clips (`ambient_lab`, `ambient_house`, `ambient_void`, `ambient_kontur`, `ghost_house`, `pa_trial4`, `screamer_forest`, `footstep`, `heartbeat` — several were tens of MB as `.wav`) were re-encoded to `.ogg` and the `.wav` originals deleted; the `.ogg` versions are 10–40× smaller. `GameState.load_audio(base_name)` already tries `.wav`/`.ogg`/`.mp3` by extension, so no script changes were needed. The small procedurally-generated SFX from the `tools/make_sfx*.py` scripts (jump-scare stingers, door slams, drips, etc.) were **left as `.wav`** — they're already small (KBs, not MBs) and regenerating them re-emits `.wav`, so converting them would just be undone by the next `tools/make_sfx*.py` run.

## Asset Pipeline
- **3D models:** Blender → File > Export > glTF 2.0 (.glb) → `game/assets/models/`
- **Textures:** PolyHaven / AmbientCG (CC0 PBR) or Stable Diffusion → `game/assets/textures/<subfolder>/` (see TEXTURES.md for the per-level subfolder layout)
- **Audio:** Freesound.org (CC0) or MusicGen (HuggingFace) → export as .ogg → `game/assets/audio/<subfolder>/` (`shared/`, `intro/`, `level_1_lab/`, `level_2_house/`, `level_3_corridor/`, `level_backrooms/`, `level_5_kontur/`, `level_6_breach/`, `level_9_dungeon/`, `level_4_void/`) — the full list, and the only list that matters, is `GameState.AUDIO_SUBDIRS`

⚠️ `GameState.AUDIO_SUBDIRS` is a HARDCODED list, not a filesystem scan — a new audio folder is invisible and `load_audio()` returns null for everything in it until the folder is added there.
- **Characters/animations:** Mixamo (free) → download as .fbx → open in Blender → export as .glb

### Texture audit rule (run at the start of every level content session)
1. Read `TEXTURES.md`
2. For each row with `status: done`, check the relevant level script (`level_1.gd`, `level_2.gd`, etc.) to confirm the texture is loaded inside `_apply_textures()` (or equivalent)
3. If a `done` texture is **not** referenced in its level script, add the load + apply code before doing any other work
4. For decal-type textures (painting, cobweb, poster, blood — applied via MeshInstance3D quads), check the corresponding `.tscn` for the MeshInstance3D node; add it to the scene if missing

## Free AI Asset Tools
- **3D gen:** TripoSR, Shap-E (HuggingFace Spaces, free)
- **Audio gen:** MusicGen by Meta, Bark (HuggingFace Spaces, free)
- **Image gen:** the image pack — see **Image Generation** below. Prefer PolyHaven/AmbientCG for standard PBR textures; reserve generation for unique horror imagery (wall art, notes, posters, UI backgrounds) that can't be sourced free elsewhere.
- **Narrative/story:** OpenRouter — `nvidia/nemotron-3-super-120b-a12b:free` via `https://openrouter.ai/api/v1`

## Image Generation

⚠️ **`nano-banana-pro/` is DEAD** (2026-08-15) and its Gemini calls no longer work. The replacement
is Hasan Aboul Hasan's MIT-licensed skill pack at
`~/Downloads/claude-image-generation-main` — kept **outside** the repo (and
named in `.gitignore`) so Godot never imports it and it can't be committed. Security-audited
2026-08-15; the only network calls are Cloudflare and fal.

Provision once (~20 s, Python only — do **not** pass `--with-3d`, the Three.js renderer is
irrelevant here and costs ~500 MB):

```bash
bash ~/Downloads/claude-image-generation-main/setup.sh
```

Two engines, and picking the wrong one is the usual mistake:

| Need | Skill | Why |
|---|---|---|
| Horror imagery — textures, creatures, wall art, screamers, posters **with no words on them** | `level-3-image-generator` — Cloudflare `flux-1-schnell` | One call, free tier, on-theme output. **Unreliable at rendering text** — never ask it to letter a sign |
| Anything with **legible text** — notes, signs, plates, redacted documents, UI | `level-1-image-generator` — Pillow, code-based | The only one that renders readable words. Free and deterministic. Cannot draw a creature; it constructs one from shapes |

```bash
PACK="$HOME/Downloads/claude-image-generation-main"
$PACK/.venv/bin/python3 $PACK/.claude/skills/level-3-image-generator/generate.py \
  "<vivid prompt: subject, medium, composition, lighting, palette>" -o out.jpg
```

Keys come from **this repo's `.env`** (`CF_ACCOUNT_ID`, `CF_API_TOKEN`) — the script walks up from
the working directory and loads the project's `.env` before the pack's own.

### ⚠️ Always convert generated output to a real PNG before importing into Godot
```bash
sips -s format png <file> --out game/assets/textures/<subfolder>/<name>.png
/Applications/Godot.app/Contents/MacOS/Godot --headless --path game --import
```
A JPEG named `.png` imports with `valid=false` and no `.ctex`, while `ResourceLoader.exists()` still
returns **true** — so the guard passes and the prop renders blank. If a texture silently doesn't
appear, run `file` on it before debugging any code. See `ISSUES_SOLUTIONS.md` Issues 1 and 25.

