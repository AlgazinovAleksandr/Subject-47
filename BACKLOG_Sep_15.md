# BACKLOG_Sep_15 — the 2026-09-14 evening run (Lab → House → Corridor, quit in the cupboard)

Run: 750 s, 0 deaths, peak panic 49 % (the 275 mirror). Six captures + notes; the log is the
rotated `playtest_log.txt`. Every decision below is the user's (one question at a time, 2026-09-14).

## Evidence
| # | t (s) | Where | Capture / note | What the log says |
|---|---|---|---|---|
| 1 | 145 | Lab, breaker 1 | "the shared monster appears 3 s after the first breaker, the only time in the Lab, other levels as usual; ask about the sound; it must appear where the camera looks or the camera is forced" | HOLD apparition armed at the keycard (336 s), due 13 s; fired? not logged before House. Director suppressed until keycard. |
| 2 | 158 | Lab, exam room | "around this moment the creature will appear" | 13 s after breaker 1 |
| 3 | 526 | Corridor 124 m | "it should be in the middle of the way, not half stuck in the wall" | C5 break-door figure stands 0.3 m off the wall, the frame cuts it |
| 4 | 618 | Corridor 292 m | "Manager mechanics good; the Manager himself should look creepier, match the level; regenerate" | telegraph beat |
| 5/6 | 683–746 | Corridor cupboard (330) | "I got stuck, how do I get away?" · "the reception ring did not work, the door did not close" | CUPBOARD sealed 658; NO release in 88 s (fallback 45 s never fired); torch ON in the capture (the rule needs it off) and nothing said so |
| — | 399 | House cellar | (not noted) | `APPARITION aborted: no legible spot` — the House has no retry; the cellar HOLD never appeared |
| — | 342 | House entry | (not noted) | `SCRIPT ERROR random_ambient.gd:115 add_child on null` at the level transition |
| — | ~560–580 | Corridor 245 bell | "I think I heard the ring, the door didn't close, what is this room for?" | no bell log line; the leg was crossed in ~25 s |

## Decisions
| # | Area | Decision |
|---|---|---|
| L1 | Lab | The taught HOLD apparition appears **3 s after the FIRST breaker** you flip (whichever), wherever you are, the camera forced onto it if it cannot spawn in view (the existing frustum pass + `turn_to_face`). It is the ONLY apparition in the Lab: the keycard arming goes, the director is off for the Lab. Other levels unchanged. Retry-on-abort stays. |
| L2 | All | **`apparition_snarl.ogg` is the ARRIVAL sting of every HOLD apparition** (`ARRIVAL_STING_DEFAULT`). The rush keeps its own sound: since arrival and rush cannot both be the snarl, the rush sting swaps to `all_levels_screamer` (decided by me, flagged). |
| H1 | House | The cellar HOLD apparition retries on abort (the Lab's L1 idiom from Sep 14) instead of dying silently. |
| X0 | All | `random_ambient.gd:_play_near_player` guards a null parent at a level transition (the logged script error). |
| C1 | Corridor | The 124 m figure stands **in the middle of the corridor**, 2 m past the ajar door, fully visible; at ≤ 4 m it is gone the frame you get there and the ajar door **slams**. Zero panic, no death. |
| C2 | Corridor | **The Manager is regenerated**: a decayed 1920s hotel concierge — tall, gaunt, rotted uniform, grey skin, sunken eyes, mouth too wide, long arms, lit from below — on a green screen, keyed by `tools/cutout_green.py`, graded dark. Mechanics untouched. |
| C3 | Corridor | **The cupboard teaches its rule**: the seal FORCES the torch off (`force_flashlight_off`/`restore_flashlight`) and scrawls `DON'T MOVE. DON'T BREATHE.`; F while sealed still pauses the Manager (the rule holds); the 45 s fallback is FIXED and tested with the torch on. |
| C4 | Corridor | **The bell makes the key; the key opens 217.** The reception nook moves to **208 m** (side −1; the 210 ajar door is +1), its spur never closes behind you (no shut-in at all). Ring → `bell_ding` → **every light near you dies for ~4 s** (desk lamp, hall torches 196/214, your torch forced off) → they return and a **brass key tag "217"** lies beside the bell (KeyItem, `set_carried("room key — 217")`). **Door 217 moves to the 230 m corner** (head-on down the 185→230 leg) and is LOCKED without the key: E answers with a toast ("It needs a key.") and nothing else; with the key it takes it and the existing lunge + IT WAS AN ILLUSION plays. Manager telegraphs move to **285 / 300** (≥ 50 m from 230 and from the creature at 340); the 245 whisper room's voice is dropped with the spur. The card page, footsteps and turn rule are gone. |

## Build list (in order; verification named)
1. **X0** null-guard in `random_ambient.gd`. `check_bus_leak` / any level-transition test stays green.
2. **L2** `apparition.gd`: `ARRIVAL_STING_DEFAULT = "apparition_snarl"`, rush sting `all_levels_screamer`; `check_apparition_framing` (sting playing) + `check_scare_loudness` rows.
3. **L1** `level_1.gd`: arm on `_on_breaker_flipped` (first), `APPARITION_AT` 3 s, no keycard arming, `RANDOM_APPARITIONS` false (director never added); `check_lab_apparition_timing` (fires ~3 s after breaker 1, in frustum or turned, retry on abort), `count_apparitions` (exactly one appearance in the Lab).
4. **H1** `level_2.gd` cellar apparition: retry ladder on abort (0.25 s re-poll, deadline); `check_house_guest`.
5. **C3** `spur_cupboard.gd` seal/release torch pair + scrawl; fallback fix; `check_corridor_events` C3 adds "sealed with the torch ON → released at FALLBACK_S" and "torch forced off on seal, back on release"; `walk_corridor`.
6. **C1** `corridor.gd:_tick_break_door` figure at hall centre 2 m past the door, vanish + slam at 4 m; `check_corridor_events` C5; `screenshot_branches`-style render.
7. **C2** flux generation → `assets_src/textures/level_3_corridor/manager_figure_raw.png` (green screen) → `cutout_green.py` → `manager_figure.png`; the cutout-stats assertion; render at the telegraph.
8. **C4** `SIDE_PASSAGES` bell 245 → 208, `FALSE_DOOR_DIST` 230, `TELEGRAPH_AT` [285, 300]; `spur_bell.gd` rewritten (ring → blackout → key), `bell_prop.gd`; `key_item.gd` tag with art (`tools/make_key_tag.py`, Pillow); `false_exit_door.gd` `requires_key` + toast; walker legs (ring, wait for the lights, take the key, open 217); `check_corridor_events` C2 (blackout, key appears, door refuses without it, accepts with it, spacing ≥ 50 m), `check_painting_fall`, `check_prop_mounting`, `check_shell_sealed`, `check_wall_overlap`, `check_reachable` for the Corridor.
9. Docs (ISSUES 213 cupboard fallback, 214 House abort, CLAUDE.md bullets, memory), full suite alone, then OFFER a playtest.

## Status (2026-09-15)
All nine items built. Verification: batch 1 (`check_lab_apparition_timing`, `count_apparitions`,
`check_apparition_framing`, `test_apparition`, `check_scare_loudness`, `check_house_guest`,
`check_darkness`) PASS; `check_cupboard_fallback` (new, in `run_tests.sh`) PASS — the real-run
non-release is explained by the J-capture pause, Issue 213; Corridor sweeps (`check_painting_fall`,
`check_prop_mounting`, `check_shell_sealed`, `check_wall_overlap`, `check_reachable`,
`check_art_aspect`) PASS after the spur/door move; `check_corridor_events` (C1 figure mid-hall,
C2 Manager cutout stats, C3 seal takes the torch + scrawl, C4 blackout → key → 217 refuses/accepts)
and `walk_corridor` (ring, wait, take the key) — see the suite table below; renders in
`tests/screenshot_sep15.gd` → `/tmp/sep15_shots/`. `TELEGRAPH_AT` landed at [283, 298] (not
[285, 300]): 283 keeps ≥ 50 m from door 217 at 230 AND from the running creature at 340.
My call, flagged: the blackout carries footsteps up the spur (zero panic) so the dark is not empty.
Deviation from the build list: the C3 test's torch breach is made on the raw `flashlight` node —
the seal locks F, so a player's only breach is moving, which the slats stop headless.
Not hand-played. The user commits. Offer a playtest.

