# BACKLOG_Sep_16 — the user's 2026-09-15 run (8 captures, 2 deaths, 1168 s)

## Evidence
| # | where | the user | log |
|---|---|---|---|
| 1 | Corridor, blind room | "The level looks weird and floating in the air" → "the lever floats and doesn't look cool… just the empty room. Launch it, take screenshots, analyse, make it better. You have image generation tools." | lever plate 0.4 m off the stone wall, nothing else in the room |
| 2 | Corridor, mirrors | "the noise and image appear when you are slightly too far away… make the second mirror hidden — before you are close you have no idea the mirror is there" | wake at `ACTIVE_DIST` 7 m, sting at 2 m |
| — | Backrooms | died 9 s in, torch on → the Smiler | `DIED (level 4)` at the hub 0.7 s after 1/3 |
| 3 | Backrooms seam | "only the first message NO DOOR / WALK INTO IT; second 'it is not a coincidence'; third YOU ARE HERE FOR A REASON" | `VERB_SCRAWL` on the correct arm every round |
| 4 | Flood Basin | "this grey thing on the floor looks too boring… a weird looking swimming pool with dark blue water; it should not make a lot of sense, it is backrooms" | `DryPlatform` is one flat box |
| 5 | Flood altar | "Should there be any kind of animation when you put all the objects?" | `_on_plate_complete`: chime + caption |
| 6 | KONTUR death | "only running animation accompanied by the scream, we do not need the static image following after it" | `trigger_with_lunge` → `trigger()` shows the image |
| 7 | KONTUR archive | "two pieces of text on top of each other… one lower than the other, different colours" | `KeyItem` label + `_notice` toast both `PRESET_CENTER` |
| 8 | KONTUR blackout | "I could walk into the door before I turned off the flashlight" | `DarkSeamPlug` is `use_collision = false`; `GATE PASSED — dark` 23 s before `FLASHLIGHT OFF` |
| — | Flood seam | engine error | `Removing a CollisionObject node during a physics callback` from `glitch_wall._on_body → advance_level` |

## Decisions (the user's, one question at a time)
- **R1** Blind room: seat the lever in a proper wall cabinet and DRESS the room to the hotel's decay (render → analyse → props, generated textures where needed → render again).
- **R2** Mirrors: wake (image + noise) at **4 m** for both; the **410 mirror does not exist** (no frame, no glass) until you are inside 4 m, then it appears with the wake noise.
- **R3** Backrooms: **spawn with the torch OFF** (F turns it on; the light becomes a choice). The Smiler's rule is unchanged.
- **R4** Seam scrawls by round: 1 `NO DOOR. / WALK INTO IT.` · 2 `IT IS NOT A COINCIDENCE.` · 3 `YOU ARE HERE FOR A REASON.`
- **R5** Dry platform → a weird raised **swimming pool with dark blue water** (still the calm island).
- **R6** Altar complete → **the relics wake**: the candle lights, the bell rings by itself, the doll's head turns to you, the lamp gutters, a long door groan from the wing. Zero panic.
- **R7** Lunge deaths (condemn, yellow phone, Perëkozhnik): **no static image after the lunge** — black, then restart.
- **R8** Keycard texts: the pickup label stays centred; the notice goes to the lower caption slot in a different colour.
- **R9** Blackout plug is **solid while the torch is on** (a wall you bump into), open when it is off or the gate is passed.
- **R10** Zone transitions from a glitch wall are deferred out of the physics callback.

## Build list
1. R10, R8, R9, R7, R3, R4 (small code) — `check_backrooms_seam`, `check_kontur_condemn`, `check_kontur_phones`, `walk_kontur`, `walk_backrooms`, `check_scare_loudness`.
2. R2 — `check_mirror_wake`, `check_turn_mirror`, `check_mirror_figure`, `check_corridor_doors`, `check_prop_mounting` (Corridor).
3. R6 — `check_flood_puzzle`.
4. R5 — `check_shell_sealed`/`check_wall_overlap`/`check_reachable` (Backrooms), a render.
5. R1 — renders before/after (`screenshot_branches`), `walk_corridor`, the Corridor sweeps.
6. Docs, full suite one row at a time, OFFER a playtest.

## Status (2026-09-16)
Built: R1 (linen room: seated lever cabinet, boiler + flue, linen rack, laundry cart, mop bucket,
dead bulb — `screenshot_blind_room.gd`, `/tmp/blind_shots/`), R2 (`ACTIVE_DIST` 4, the 410 mirror
absent until then — `_set_mirror_present`), R3 (`flashlight.visible = false` on arrival), R4
(`ROUND_SCRAWLS`), R5 (the raised tiled pool: deck, curbs, ramp, dark water quad, chrome ladder,
cold lamp; `flood_pool_tile.png` from flux, raw in `assets_src/`), R6 (`_relics_wake`: candle flame
+ light, bell ding + rock, doll sits up, lamp gutters, groan from the Sump), R7
(`Screamer.trigger(image_override, with_image)`), R8 (caption slot), R9 (Issue 215), R10 (Issue 216).
Verification: see the suite table in the session recap. Not hand-played.

