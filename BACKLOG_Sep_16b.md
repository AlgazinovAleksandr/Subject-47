# BACKLOG_Sep_16b — the user's second 2026-09-16 run (6 captures, 1 death, 1081 s)

## Evidence
| # | where | the user | log |
|---|---|---|---|
| 1, 2 | Lab, dark wing | "I did not see the jumpscare after I turn on the [third] light switcher. I just heard it… make sure it comes close, I can see it clearly, the sound louder. Test it. Also make it even more sudden and terrifying." | the watch fired at (−51.6, 8.1), 10 m out of the nook; the room-relative ladder found nothing there, the sting played, the picture was skipped, nothing logged |
| 3 | House, map won | "The text is intersecting with each other. Let's make one text below the other" | `KeyItem` label + "Collect the key." toast both centred |
| 4 | House cellar | "block the creature [shared apparition] from appearing at the doll level… avoid the player escaping the cellar before he sees the doll — block the player's movement for several seconds, complete darkness, then the doll" | `HOUSE scripted apparition APPEARED` at 313.45, the child at 318.72 |
| 5 | Corridor 124 | "This should be bigger. It should look exactly like a place you can enter… a trap" | a single 0.97 m leaf ajar 14° on a solid wall |
| 6 | KONTUR death | "first a creature moving towards me, then a 2D static image… we need only the moving creature" | the condemn bar's `add_panic` death raced the lunge's own `trigger(_, false)` |

## Decisions (the user's)
- **W1** The dark-wing payoff: the breathing cuts dead, 1 s of silence, then the figure at arm's length, glowing, camera pinned, scream over a silenced room; it lunges to your face, holds 0.4 s, flees as the wing lights. Placement by rays along the player's own corridor, NEVER skipped, logged with distance and room. Same +20, still survivable.
- **H2** Only the cellar's scripted apparition is removed; the director's random one stays upstairs. The cellar blackout pins the player until the child has appeared.
- **H3** "Collect the key." moves to the lower caption slot.
- **C6** The 124 door is a 1.94 m double door standing open onto a real 3 × 3 m bedroom (bed, wardrobe, black window); both leaves slam at 4 m. You never get in.
- **K3** Any death that lands while a lunge is in progress shows no picture.

## Status (2026-09-16)
Built: W1 (`_nook_breath_cut` → `_nook_reveal` → `DoorLunger` "NookFigure", `_place_nook_figure` always finite, `_on_nook_lunged`), H2 (`_spawn_apparition` and the retry poll deleted; `_begin_cellar_blackout` pins, `_can_show_child` ignores our own pin), H3, C6 (`_build_break_room`, mouths carry a half-width, `AjarDoor.swing_sign` + swing limit, `AjarDoor_break2`), K3. Renders `screenshot_sep16.gd`. Verification: see the suite table in the recap. Not hand-played.
