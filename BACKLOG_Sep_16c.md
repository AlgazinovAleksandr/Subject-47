# BACKLOG_Sep_16c — the user's third 2026-09-16 run (2 captures, 0 deaths, 589 s)

The user: "we are almost done in terms of making level two (House) and level three (Corridor)
finished… run Godot yourself to test your hypothesis and test your changes."

## Evidence
| # | where | the user | log |
|---|---|---|---|
| 1 | House cellar note | "you need to be stuck in this level after you read the note. The doll sound: the same as baba yaga, the default jumpscare sound for the House" | the child fired at the ramp's foot (237 s), the note was read at 242 s |
| 2 | Corridor 330 spur | "it looks like a small window, and through that window you see the other room. I want it to look like an actual door so that you think you can go there, but instead you get trapped" | probed: capture at path 309.5, 2.6 m from `Spur2Cupboard` — the "window" was the cupboard's MIRROR reflecting the corridor |

## Decisions (the user's)
- **H4** The doll beat fires when the cellar NOTE is closed: lights and torch die, the player is pinned at the note, 5.5 s dark, the doll with `screamer_house` (baba yaga), lights back. The ramp's foot keeps only the scrawl.
- **H5** While pinned in the dark, a red **WHERE AM I?** (0.7 s in, 2 s hold, faded by 4.7 s) — gone before the doll at 5.5 s, never on screen with it.
- **C7** The cupboard and its mirror are gone. The spur ends in a partition with a real hotel door standing open onto a service closet (shelves of linen, a chair, a bucket). Step in → the door slams and locks; the strip of light under it is the only light; the Manager's shadow crosses it as he passes. Rules unchanged (still + torch off 8 s releases; move/torch → he stops and growls; 45 s fallback). Zero panic.

## Status (2026-09-16)
Built: H4 (`_arm_child_on_note_close` → `NoteUI.closed` one-shot → `_begin_cellar_blackout`; `_spawn_guest_child` loads `screamer_house` at 0 dB / `max_db` 6), C7 (`_dress_cupboard_spur` rewritten: partition boxes, `Spur2ClosetDoor` an `AjarDoor` at 150° into the closet, `Spur2ClosetStrip`, rack/chair/pail; `spur_cupboard.gd` slams/reopens a real leaf and draws `ClosetShadow` when the figure is within `SHADOW_AT_M` of the threshold). Renders `screenshot_sep16c.gd`. Verification: see the recap. Not hand-played.

### H5b — the two cellar scrawls no longer overlap (2026-09-16, the user's *"make one clearly at the bottom"*)
Capture #1 of the fourth run: the ramp-foot hint (`CELLAR_HINT`, 4 s, centre) was still up when the
note was closed, and **WHERE AM I?** landed on top of it. `ScreenText.scrawl()` gained a `bottom`
flag (a band 170–300 px above the bottom edge, above the caption slot); `_begin_cellar_blackout()`
passes it, so WHERE AM I? is always at the bottom and the hint keeps the centre. Rendered both at
once (`/tmp/scrawl_pair.png`): a clear gap. `screenshot_sep16c.gd` still reports the text on at
2.0 s and gone at 5.2 s; `check_house_guest` / `check_cellar_key` green.
