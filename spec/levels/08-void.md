# Level 8 — The Void — spec

> **SPEC-FIRST.** Record intended changes here before code; keep the spec synchronized with the level.

## SPEC

**Level 8 — The Void (broken geometry, the last unreal level)** — `level_3.gd` + `void_fragments.gd`,
`void_creature_visual.gd`, `void_face.gd`, `void_alignment.gd`, `void_keystone.gd`, `void_rearrangement.gd`,
`void_loop_note.gd`, `void_shard.gd`, `void_cradle.gd`, `void_sanctum_plate.gd`, `void_door_visual.gd`,
`void_stare_director.gd`, `void_anchor.gd`, `void_drawer.gd`, `void_exit_door.gd`; scene
`level_3.tscn` (⚠️ the name does not match the level number; it sets
`current_level = 8`). Rebuilt on `RoomBuilder` 2026-09-12; reworked three times on 2026-09-20 — on the
2026-09-19 playtest, on the 13:10 one, and on the 15:00 one that completed the level. The textures,
music, violet vignette and the crossing are the user's and stay.

- **Layout:** 15 abutting rooms, 14 doorways: Threshold → Hall1 (PocketA trap) → Ward (Archive dead
  end) → LoopIn → LoopStraight → LoopOut → Hall2 → TileHall → Morgue → Hall3 (PocketB trap) →
  ChildRoom → Sanctum. The Morgue is **12 × 10 (x −21..−9, z 42.5..52.5)** since 2026-09-20 — the
  TileHall's x = −9 wall and Hall3's z = 42.5 wall are shared exactly. The ChildRoom is **8 × 7
  (x −18..−10, z 29.5..36.5)** since pass 3, the Sanctum's x span exactly, so the shared z = 29.5
  plane is one interval and RoomBuilder emits one wall where it used to emit two (measured: 145 →
  143 CSG boxes). Every other footprint and doorway is the 2026-09-12 table.
- **Opening:** the Threshold has candles, `CalmThreshold`, a rule-bearing note, shards hung on threads
  and the BackDoor. There is no entrance creature. The first encounter is B on the Ward's west side,
  leaving the east route clear. The Ward's E-armed frame rearranges once after you look away.
- **Five lethal stalkers B–F** (Ward, loop corridor, Morgue, child room, Sanctum), each the Void's own
  fractured figure: **2.2 m**, arms to the knees, the head detached 12 cm above the neck and rolled
  onto one shoulder, 4–8 cm of black between misaligned fragments, albedo 0.25 stone with pale chips
  only on edges, a leaning mid-stride reach as the rest pose, **five variants keyed on the stalker's
  node name**. In front of the skull hangs an oversized **0.32 × 0.46 m stone mask**, bigger than the
  head it belongs to, carrying `void_face.png` — a gaunt grey HUMAN face with enormous fixed eyes, a
  mouth a little too wide and doll cracks — at albedo ~1.0, the brightest thing on the figure, with
  the jumble of the level's own broken objects confined to the mask's rim and a socket at the temple:
  a face you recognise first and find wrong second. It reads at 5 m; the pass-1 recess did not read at
  2.5 m. The head and mask turn to you only in unobserved ticks — so it is looking at you whenever you
  look back — and you cannot understand what the rim is made of. **A watched stalker never moves, without exception**: physics and mesh freeze, the
  head turns to face you only in unobserved ticks, and the 4 s stare-off's retreat is deferred to
  the first unobserved frame. Advancing has the scrape tell. **Unobserved they move at 3.0 m/s and
  the stare-off retreat is 2 m** (pass 2, the user's numbers, Void-only exports `stalk_speed` /
  `retreat_distance`; the shared defaults 1.25 m/s / 3 m stay for the Nightmare); gaze cost, contact
  distance, the 5 s opening grace and the 4 s stare-off are unchanged. **B (−3.6, 16.2) and D (−11.2, 47.0) stand
  where they stand** — the user's ruling; the 1.1 s and 0.44 s look-away windows are the design.
- **The stare** (`creature_stalker.gd` opt-in `whisper`, `void_stare_director.gd`): every stalker
  carries a positional whisper loop (`stalker_whisper`) whose level rises with continuous gaze from
  ANY distance with line of sight and falls after a look-away. A stare held past the dismissal fires
  ONE diegetic hallucination at 6 s and every 6 s after, cycling: the blink (two curved eyelids close
  over 0.12 s, hold 0.25 s and open over 0.2 s with the `blink` sound; a second figure stands at arm's
  length for exactly one frame as they part), the panic-bar lie
  (`panic_hud.lie()` to 0.98 for 0.8 s; real panic never moves), a scrawl, the nearest lamp dimmed to
  20 % for 1 s. Never while a note is open, the tree is paused or input is frozen; never the blink on
  the tiles. **No panic term anywhere in it.**
- **Movement:** swept capsule clearance, floor support and per-room leashes constrain advance, retreat
  and loop relocation; blocked movement stops or slides; the visible inner body lunges on lethal
  contact. All stalkers suppress movement, contact and gaze pressure while the player is in the tile
  hall; `CreatureD.watch_only` also holds there.
- **The loop:** the 30 m corridor repeats via a seam at z 32 that sends a +z walker back 15 m keeping
  heading and velocity. `LoopNote` (z 23, `void_loop_note.gd`) **does not exist until lap 2** —
  invisible, no collider — and then appears where the torn pages lie with a `paper_drop`; reading it
  breaks the loop. The ladder, all zero panic. Every send-back: both corridor lamps flicker for a
  second and a `loop_slam` sounds from the doorway behind you. Lap 1 kills `Light_Loop_34` and drops
  a torn page. Lap 2 walls up the LoopIn↔LoopStraight doorway behind the player (`LoopWallPlug`,
  0.2 × 3.3 × 1.80 in the wall material, added deferred) with a `stone_grind`, scrawls `AGAIN.`, and
  the whisper rises from BOTH ends of the corridor (a second emitter at the south end rides creature
  C's whisper level). Lap 3+ kills `Light_Loop_19`, lifts the six wall stains to y 1.75, and a
  footstep echo answers your own steps 0.35 s late from 2 m behind while you walk the corridor
  (SCARY.md P2, Void-scoped). Creature C creeps 2 m per lap. Reading the note frees the plug.
  Backtracking is allowed before lap 2 and after the read; between, the corridor holds you.
- **Causeway and the perspective puzzle:** 1.6 m tiles and 1 m beams carry the north and south routes
  over the walled abyss to a 2.0 × 2.2 m island at (−3.6, 45.5). **Three broken memories in three
  corners**, each assembling in projection only from its own tile: a DOOR from the island looking
  west, a BED from the spine's first tile (1.4, 45.5) looking north-east, a WINDOW from the south
  branch's middle tile (−3.6, 42.8) looking south-east (a canvas builder places each shape's pieces
  at distinct depths; dark edge markers sit on the three tiles). Each keystone's prompt exists
  **only within 1.5 m of its own tile's centre** — the prompt says WHERE to stand and never whether
  you are aligned, and only your eyes say whether it is assembled.
- **The puzzle is a quest: three carried anchors (pass 3).** Each viewpoint carries an empty stone
  SOCKET in its view's own tint (`"The socket is empty."`), and the object that fills it is hidden in
  the level's early rooms: a violet **door handle** on PocketA's floor under the trap note, a bone **bed
  slat** at the open mouth of the Ward's E-armed folded frame, a verdigris **window latch** inside
  Hall2's flat doorframe — which is also the step-through, so the 1.2 s clock runs while you bend for
  it. **One anchor at a time**; the shard is a separate slot, so the HUD line composes
  (`"a stone shard · a door handle"`) and `GameState.carried_item` is a LINE, never a key —
  `void_cradle.gd` and `void_alignment.gd` ask the level (`carried_anchor()` / `has_shard()`).
  E on the matching socket seats it and it BECOMES that view's keystone, in its own silhouette and
  its family's colour; the existing look-and-hold runs from there unchanged, wrong press and all. The
  wrong object is refused by name (`"It does not belong to this one."`) at **zero cost** — the level
  already charges 6 panic for a wrong ANGLE, and pricing one mistake twice would make the quest a tax.
  An empty socket can be neither solved nor failed. The inscription names the three objects and still
  says nothing about where they are or whether a shape is held. Tolerances were set from a measured coverage curve, per view (door radius 1.30 / seam
  0.20 rad, bed and window radius 1.00 / seam 0.12): ≥ 88 % of a 0.3 m grid over each tile aligns,
  and no adjacent tile does. A wrong press costs **6 panic** (`WRONG_PRESS_PANIC`) and a stone knock.
  `MorgueSeal` retracts and the abyss reply plays **only on the third** solve. The inscription reads
  `STAND WHERE THE BROKEN THINGS / REMEMBER ONE DOOR, ONE BED, ONE WINDOW. / THE HANDLE, THE SLAT AND
  THE LATCH ARE ELSEWHERE. / THERE ARE THREE PLACES TO STAND.` — it teaches the count, the shapes and
  the three objects, never the state and never where they are. Fall at y −4 over a pit floor
  at −8; camera shake is suspended in this hall; the fixed lamp supports a torch-off solve.
- **Abyss reply:** the third solve moves the small fragments together, then a larger doorway below
  unfolds under reveal lighting with a delayed stone reply. Non-lethal, one-shot, the floor and
  camera never move.
- **The Morgue:** the inverted slab (its collider is three shapes, so the 1.91 m underside is real
  headroom), the dead monitor on the north wall, the note on the west wall, a drawer bank along the
  north wall and one impossibly long pulled drawer on the floor. The hollow on the slab's underside
  holds a **torn page** at (−13.1, 1.84, 45.5) — a fragment of the twist note, laid flat against the
  underside — so the "E under the slab with your back to D" beat survives the shard moving out.
- **SEARCH (pass 3):** the bank's **seventeen fronts open on E**, once each, sliding out 0.35 m over
  0.25 s with a `drawer_pull`. **Sixteen hold nothing**; one — column 4, row 1, never hinted, the
  second-furthest column from the door — holds the page that points at the Archive (*"We kept the
  shard under the table you turned over. The handwriting is yours."*). The page STANDS in its drawer
  and pokes 0.10 m above the front's top edge, because from eye height you cannot see into an open
  0.54 m drawer at all. Zero panic, no fail state; the Morgue's DarkZone charges only with the torch
  off, which searching does not ask for.
- **The shard hides at the beginning (pass 3):** `SlabShard` sits in the legs-up basin of the Archive's
  inverted table at (−3.4, 0.42, 22.0) — **invisible and collider-less until that table rearranges
  itself behind your back**, which is its existing `arm_on_sight` beat, and announced only by a
  `paper_drop` from the prop. The Archive is a dead end off the Ward that none of the day's three
  runs entered. The table's collider was cut back to its 0.22 m top slab for it: a bounding-box
  collider makes a basin a place the eye can enter and the E-ray cannot. Missing it costs the walk
  back; the loop is two-way once its note is read, so it can never softlock.
- **STEP THROUGH (pass 3):** standing inside Hall2's flat doorframe (7.0, 44.7) for **1.2 s
  continuous** drops you out of a second flat frame in LoopIn (8.0, 15.3), thirty metres back, with
  heading and velocity kept and a `frame_drop` at the destination. **One way, backwards only** — the
  LoopIn frame has no area — so it bypasses nothing and is the relief valve for the anchors' return
  trips. It cannot strand anyone behind the corridor's lap-2 plug: reaching Hall2 at all means
  passing the z 32 seam, which sends you back every time until the loop note is read. Zero panic.
- **The far-wing chain:** the shard fits the child room's cradle (E on the cradle body beside creature
  E; without the shard the prompt says something is missing); completing it tweens the slats level and
  retracts `SanctumPlate`, the stone cover over the Sanctum's twist note (layers 1|2, prompt *"The
  stone will not move."*, `move_aside_instantly()` for the reachability guard). It never blocks a doorway.
- **Props, all Void-native and matte:** the folded frames (Ward), a stair into the ceiling (Hall1), a
  doorframe lying flat over black (Hall2) **and its twin in LoopIn, which is where the first one puts
  you**, chairs fused into the wall (LoopIn), a table legs-up (Archive), a heap of doors (Hall3),
  shards on threads (Threshold, PocketA, PocketB), the slab, the seventeen drawers, the
  cradle, the monitor, the drawing, the music box. The table and the heap **rearrange once when
  unobserved after first sight** (`void_rearrangement.gd:arm_on_sight`). **Five matte albedo families
  assigned by room** — bone, rust, verdigris, violet stone, tar (`void_fragments.gd:PALETTE`): Ward
  bone, Archive rust, LoopIn verdigris, Morgue slab bone + drawers rust, child room bone, Hall3 heap
  mixed, Hall1 stair and Hall2 doorframe tar, shards violet; the figures keep their own dark stone,
  and the Ward's lamp is desaturated to (0.85, 0.75, 1.0) so bone can read under it. Textures `void_sheet`,
  `void_child_drawing`, `void_monitor_face`, `void_face`, `void_door` — every one made for this level;
  the echoes of earlier levels survive only in the notes' text.
- **The exit assembles itself (pass 3):** `void_exit_door.gd` (a `door.gd` subclass, on the ExitDoor
  only) overrides `_open_door()` **token-first** — `begin_transition("door")`, then 0.9 s of animation
  and a 0.3 s hold, then `complete_door_transition`. The eight floating sub-rects tween to their true
  places on the grid, to zero tilt AND to the scale that closes the 3.7 cm seams, with a
  `stone_grind`; for 0.3 s the Void contains one whole door. ⚠️ The token comes first because an
  animation is 1.2 s in which a death can land: animate-first would let a death restart the level and
  then let this coroutine advance the restarted scene to the ending (Issue 219's shape).
- **Doors:** ExitDoor and BackDoor skip `door.gd:build_visual()` for `void_door_visual.gd`: the dark
  door box, the blood-red plate every earlier level taught (kept as `DoorMesh` so the unlock flare
  still finds it), and in front of it six or seven separated stone slabs each showing its own sub-rect
  of one `void_door.png` via `uv1_offset`/`uv1_scale`, with frame posts at different depths — the
  puzzle's doorways that never assemble. **Eight slabs** on each door; the exit is the most broken —
  one of its eight hangs askew (pass 2 replaced the *removed* slab with this, because a missing one
  left a half-metre of red). The builder stores each slab's `true_position` / `true_rotation` /
  `true_scale`, which is what the exit's assembly tweens to. Collider, script and unlock rule
  unchanged apart from the exit's own `_open_door()` override.
- **Sound:** `ambient_void` loops (set in code; the import file had it off and the bed died after one
  play). Every stalker whispers; the corridor's return sounds are `loop_slam`, `paper_drop`,
  `stone_grind` and the shared `footstep`; pass 3 adds `drawer_pull` on each drawer, `frame_drop` at
  the step-through's destination, `paper_drop` on the shard's reveal and `stone_grind` on the exit's
  assembly. ⚠️ Every gain is set from the file's measured RMS, never from a plausible number.
- **Notes/zones:** **eleven** notes — nine on walls at 1.3 m (five safe, three read-to-die traps, one
  twist) plus pass 3's two Morgue pages, which are flat rather than hung (the slab's torn fragment and
  the page standing in a drawer). Two `DarkZone`s (the 12 × 10 Morgue, the 8 × 7 ChildRoom),
  `DreadFarWing` over the far wing, `CalmThreshold` at the entrance. Fatal: creature contact, the abyss, a trap note read to the end, full panic.
- **Progress:** `save_progress()` stores notes read, loop state and laps, the solved views, the spent
  reveal, the Ward frame's armed/spent, `shard_taken`, `cradle_done`, the spent rearrangers and — since
  pass 3 — `anchors_taken`, `carried_anchor`, `sockets_filled` and `drawers_opened`. ⚠️ `shard_taken`
  means OUT OF THE WORLD and is never reset; holding it is `has_shard()` = `shard_taken and not
  cradle_done`.
  Navigation restores them without replay (the plug from the laps, the carried shard and anchor
  re-issued, taken anchors gone from the world, seated ones back in their sockets, pulled drawers
  still open); death resets them; a return from the ending spawns at the exit facing in with the plate
  gone.
- **Completion:** the twist note unlocks ExitDoor. Shared transition arbitration accepts the first door
  or fatal action and invalidates callbacks from replaced scenes (`spec/systems/scripts.md`).
- **Instrumentation:** every beat writes to the playtest log — `VOID loop lap N` … `VOID sanctum plate
  retracting`, `STALKER <id> awakened / dismissed / retreated / lunge`, `HALLUCINATION <effect>`, and
  since pass 3 `VOID anchor TAKEN/PLACED/refused`, `VOID socket <view> filled/refused/empty`,
  `VOID shard REVEALED`, `VOID STEP THROUGH #n`, `VOID drawer c_r pulled (THE PAGE)` and
  `VOID exit door ASSEMBLING`.

### Verification

**Pass 3 measured (2026-09-20):** `check_void` 93/0 · `check_void_alignment` 121/0 · `walk_void` 78/0
(0 stalls) · `walk_void_live` 81/0 with the real E exit into `ending.tscn` through the 1.2 s assembly ·
`check_transition_race` 29/0 · `check_stalker_motion` 51/0 · `check_void_stare` 27/0 ·
`check_wall_overlap -- Void` 0 findings (**143** CSG boxes / 35 flat / 343 solid props) ·
`check_reachable` **33 783 cells (527.9 m²), 41 targets, 38 reachable, 2 inert, 1 contained, 0
unreachable** · `check_note_mounting` **11 notes, 3 same-room pairs** · `check_doorways` 14 doorways,
1 gated · `check_shell_sealed` 236 points, 0 escaping · `check_art_aspect` green.

What each file covers — ⚠️ the CHECK COUNTS below are pass 2's and are superseded by the line above;
the descriptions are what still holds, plus pass 3's additions: `walk_void` now fetches and seats all
three anchors and pulls all seventeen drawers through the ray; `check_void` measures the child room, the
drawers, the hidden shard, the step-through's 1.2 s (with a 0.76 s control) and the exit door's
assembly; `check_void_alignment` measures the two socket refusals and the three distinct keystones;
`check_transition_race` races a death against the 1.2 s assembly in both orders.

`walk_void.gd` (geometry only, 44 checks: two laps with the plug present at lap 2 and gone after the
read, the three viewpoint tiles through the real ray, the shard, the cradle, the plate, the exit ray) ·
`walk_void_live.gd` (48: every creature retained at 3.0 m/s, all five encounters, the stare-then-look-away
before the twist note, a real E exit into `ending.tscn`) · `check_void.gd` (68: the note absent before
lap 2 and present after, the flicker restores the lamp, the sounds load, the bed loops) ·
`check_void_alignment.gd` (98: the coverage grid ≥ 70 % per view, adjacent tiles refused with the
shipping ray as control, each shape solves only from its tile, a wrong press costs 6.0 and opens nothing,
the seal stands until the third, the chain, restore/death/return) · `check_void_stare.gd` (27: whisper,
one hallucination per 7 s stare, the eyelids meet and part, no `YOU BLINKED.`, panic untouched,
frozen-input gate, no blink on the tiles) · `check_stalker_motion.gd` (51: zero displacement in any
observed frame on both paths; a 3.0 stalker covers 2.4× the default per tick, the default unchanged) ·
`check_transition_race.gd` (19) · the geometry guards' Void rows (wall-overlap 145 CSG boxes / 34 flat
/ 301 solid props, 0 findings; shell 228 points, 0 escaping; 14 doorways, 1 gated; reachable 516 m²,
19 targets, 17 reachable, 2 inert, `LoopNote` a gate; 9 notes; 25 art samples all 1.000×). Full suite
2026-09-20 evening: **119 passed / 0 failed**. `probe_void_view_region.gd` is the instrument the
tolerances came from and is kept outside the suite.

### 🔨 PLANNED — 2026-09-20 pass 4 (the 18:30 run: completed, 0 deaths, four captures)

Evidence: `backlogs/captures/08-void-2026-09-20d/`. An Opus research menu (games in this level's vein)
fed a grill; the user chose item by item. Rulings and numbers in DECISIONS & GOTCHAS. ⚠️ This pass
knowingly reverses `GAME_MECHANICS_IDEAS.md` §7.3 Q5's *proposed* "cut the Void minigame"; the surviving
half of that reasoning — never the House's genre again — is honoured.

- **The cradle GIVES.** Completing the cradle fires a survivable, zero-panic in-world scare: a sixth
  fractured figure with no rules, no collider and no AI rises through the cradle and lunges to 0.6 m in
  front of the camera over 0.35 s with a loud positional `cradle_sting` (never the fatal screamer
  sound), after a 0.6 s `HoldBreath` dip, then is gone. Creature E is held off (`protected_player_rect`
  = the child room) for the lunge + 1 s so a blinded player cannot be coin-flipped (§8.11). One-shot;
  a restore never replays it. Replaces: a slat tween and a plate retracting two rooms away.
- **A secret door that did not exist.** A sixth-room `FrameHall` (x −27..−21, z 44..50) abuts the
  Morgue's west wall with a doorway at (−21, 47.5) plugged from `_ready()` by `SecretPlug` (the loop
  plug's pattern, 0.2 × 3.3 × 1.80 in the wall material; the doorway's 4 mm floor bridge hidden until
  then) so the shell is sealed from frame 0. The plug frees on the cradle with a distant `stone_grind`;
  the child room's crayon drawing rearranges when you look away into a plan with one door marked; the
  Sanctum plate's prompt becomes *"Something else was opened instead."* Doorways 14 → 15, 2 gated.
- **THE HALL OF FRAMES.** Five upright doorframes in the new room, each framing a small diorama of a
  thing met earlier, in that room's family — hung shards (violet), the folded frame (bone), the legs-up
  table (rust), the fused chairs (verdigris), the ceiling stair (tar). Step through them in the order
  you first met them (Threshold → Ward → Archive → LoopIn → Hall1) with the step-through's 1.2 s dwell.
  **Right:** you drop out of the next frame, the room's lamp gains a step, `frame_tone` rises an
  interval, the whisper hushes a beat. **Wrong:** you drop back out of the frame you entered with a
  slam, the lamp dies for 2 s, the frames re-scramble when you next look away, and the cradle figure
  stands in a diorama one frame nearer each time — on the third wrong step, 1.2 m behind you for one
  frame. **Finish:** the frames slide into one line, a corridor, with the hidden note at its end. Zero
  panic, no fail state, retryable; brute force is a floor (≤ 15 tries), not a wall. It makes the
  step-through load-bearing.
- **The hidden note moves the stone.** A safe, journal-kept note at the corridor's end, readable only
  **empty-handed** (three anchors seated, the shard spent — already mandatory, so no new gate; the
  prompt refuses by name otherwise). Reading it retracts `SanctumPlate`; the cradle no longer does.
  `TWIST_READ` and the exit door are untouched. One note points, one moves the stone, one reveals.
- **The Ward touch answers across the room.** Touching the left folded frame makes the RIGHT one, five
  metres away, change shape the moment you look away — only while you are still in the Ward, with a
  stone grind from it — a larger transform than before. The bed slat never moves.
- **Discoverability, structurally.** One Morgue drawer (not the page's) starts pulled out; Hall2's
  flat frame reacts to a dwell (its slabs tilt toward the black over the 1.2 s and snap back on exit — a
  diegetic affordance, not a §8.2 readout); the secret door's site brings you back past the drawers.
- **P.T.'s swap in the loop:** lap 1 swaps one corridor stain for a hung chair leg at the same spot;
  lap 2 swaps it for a hand-sized page. One discrete object change per lap, against a remembered
  baseline. Zero panic.
- **The wall texture's Gemini sparkle is cloned out** (`wall_void.png`, bottom-right; the floor was
  clean).
- Proves: `check_void` — the room is sealed at frame 0, the plug frees on the cradle, the lunge fires
  once with E protected and `_panic` unchanged (control: unprotected E lunges), the drawing rearranges,
  one drawer open at start, the Hall2 frame reacts and the LoopIn twin does not, the loop swap per lap;
  new `check_void_frames` in the maze-tester shape — N seeded scrambles solvable, a wrong step never
  strands, dwells reachable from a human stance, the finish reachable, the note refuses while carrying
  (control), the figure never has a collider; `walk_void`/`walk_void_live` — the new route through the
  hall to the ending; `check_reachable` (`SecretPlug` gate), `check_doorways` (15, 2 gated),
  `check_shell_sealed`, `check_wall_overlap`, `check_note_mounting`; screenshots read as images.

## NEEDS A PLAYTEST

Three passes on 2026-09-20 were verified by guards, a coverage probe and screenshots; the pass-2 build
was **hand-played to the ending at 15:00** (564 s, two panic deaths, both from close stare-offs in the
dread wing, neither complained about) and pass 3 answers that run. **Pass 3 has not been hand-played.**
What it needs a human for, first:
- **The walking cost of one anchor at a time.** Three objects, one pair of hands, three sockets on the
  causeway: the handle is ≈ 100 m from its socket, the slat ≈ 80 m (and the step-through takes 30 m of
  that off the way back), the latch 8 m. Measured on the walk bot, not on a human. If it reads as
  errands rather than as a quest, the fix is to let the player carry all three — one line in
  `take_anchor()` — and nothing else in the design depends on the restriction.
- **The tar handle as a keystone.** It is the dimmest of the three seated objects (tar's palest slot
  is albedo 0.17, and this level has no emission to spend), so it reads as a dark silhouette inside a
  bright violet socket. The other two (bone slat, verdigris latch) read as objects. **Resolved the
  same hour: the handle moved to the violet family** (the door view's own tint) and re-shot — it reads.
- **Whether anybody searches seventeen drawers.** Sixteen are empty by design. Nothing hints the
  seventeenth, and the page in it is the only pointer to the Archive — the shard is findable without
  it (the Archive is on the way), but a player who misses both walks the far wing twice.
- **The step-through**, which is unsignposted by design: standing still in a doorway on the floor for
  1.2 s is a thing nobody does by accident. The latch lying inside it is the teacher.

Verdicts from the 15:00 run, all now built: the three viewpoints were found in nine seconds and the
identical keystones read as buttons ("*too simple… make it more like a quest*"); the child room was too
small to move in; the shard was seven seconds from its cradle ("*make it somewhere at the beginning…*");
the final door wanted an animation; the level wanted one or two more sub-challenges. Still open from
earlier passes:
- **The three memories.** Whether a human finds the spine tile, the island and the south-branch tile
  as "places", and whether a bed that can read as a bench at first glance is enough of a bed.
- **3.0 m/s.** Whether the stalkers now read as dangerous to pass, and whether B in the Ward — 2.6 m
  from first sight, 0.4 s to contact at this speed — is a lesson or a wall.
- **The mask** at play distance, and the human face on it: judged from screenshots at 2.5 and 5 m.
- **The loop's returns** — the flicker, the slam, the grind, the whisper from both ends, the echo —
  gains set from files, never heard in a room. And whether the corridor now feels closed behind you.
- **The palette** under each room's lamp, and the desaturated Ward lamp.
- **The eyelids** — 0.12 / 0.25 / 0.20 s, and the one-frame figure as they part.
- **The far wing's panic economy** — now measured on a human: 95 % at the Morgue note after 25 s of
  stare-off cycles with D at 2.5–4.5 m, and 85 % carried out of the child room after 50 s with E, then
  a death on the west pad. `DreadFarWing` cancels decay, so every close stare is permanent. The user
  asked for harder, not easier, and did not flag either death; no constant moved.

## DECISIONS & GOTCHAS

### Built 2026-09-20 — pass 3 (one level-improver; the 15:00 run's three captures)

**What the pictures said.** Capture #1, all three shapes held in 9 s: *"The buttons for pressing still
all look the same — shall we figure out how to hide them, make it more like a quest?"* Capture #2, in
the child room: *"This room is too small."* Capture #3, after the ending: an animation on the last
door, the missing block moved *"somewhere at the beginning… so that if you miss it you will have to
walk all the way"*, and *"at least 1-2 subchallenges"*.

**Measured in the build.** E's leash grew with the room from **4.90 × 5.90 m (28.9 m²) to 6.90 × 5.90
(40.7 m²)** — it can follow a metre further west and a metre further east; the cradle, creature E, the
lamp, the drawing and the trap note all kept their world positions because `pos` did not move. The
child room's growth REMOVED two CSG boxes (145 → 143): its x span now equals the Sanctum's, so the
shared z = 29.5 wall is one interval. The step-through fires at **1.2 s** and not at 0.76 s (measured
at 48 physics ticks inside the frame, with the level's own dwell clock read as well as the drop
count); the LoopIn frame moves nobody. The page is in **drawer 4_1** of 17 — the second-furthest
column from the door, deterministic, never hinted. The exit's **eight** slabs (not seven: pass 2
replaced the removed slab with an askew one) tween from a worst offset of 0.149 m onto their stored
sub-rects and tile 100 % of the leaf. Gains from the files: `drawer_pull` −17.4 dBFS RMS → −8.5 dB /
unit 3.0, `frame_drop` −16.2 → −10.5 / unit 4.0 (it plays at zero distance from the arriving player),
`stone_grind` −10.3 → −8.0 / unit 5.0 (the loudest file, the quietest gain).

**Rulings that are now load-bearing.** A wrong OBJECT costs nothing, because the level already charges
6 panic for a wrong ANGLE and two prices for two kinds of mistake turns a quest into a tax. An empty
socket can be neither solved nor failed. `GameState.carried_item` is a COMPOSED LINE in this level and
nothing may test it for equality again. `_shard_taken` means out of the world, never in hand.

**The step-through cannot strand anybody**, and the reasoning is the load-bearing part: to stand in
Hall2 at all you must have crossed the seam at z 32 walking +z, and that sends you back every time
until the loop note is read — so `_loop_broken` is always true by the time the frame can fire, and the
lap-2 wall plug is always already gone. Nothing was added to guard it; if the seam ever becomes
one-shot, this becomes a softlock.

**Deviations from the plan, by measurement.** The shard sits at y 0.42 in the table's basin, not on its
top: the table's collider had to be cut back to its 0.22 m top slab (Issue 230) and 0.38 m still
grazed it. The drawer page STANDS in its drawer rather than lying in it (Issue 232) — from eye height
you cannot see into an open 0.54 m drawer at all. The assembly tweens SCALE as well as position, or the
finished door is a red grid (Issue 233). The anchors are sized against the shapes they gate: at 1.1 m
the slat subtends ±2.6° against a bed that ends at +6.1° with a socket at +19.1°, the latch ±4.2°
against a window that ends at +5.7° with a socket at +20.0°, and the handle hangs inside the door's own
±12.2° opening, which is where a handle belongs. ⚠️ The tar handle is the DIMMEST of the three seated
keystones — tar's palest slot is albedo 0.17 and this level has no emission to spend — so it reads as a
dark silhouette inside a bright violet socket rather than as an object. **Moved to the violet family**
(the door view's own tint, and the hung shards') on the builder's recommendation, re-shot, reads as an object.

⚠️ **`SlabShard` KEPT ITS NAME** although it is no longer near the slab: it is the node name three
guards' configs and two walk routes address it by. The slab's hollow now holds `SlabPage`.


### Built 2026-09-20 evening — pass 2 (one level-improver + the parent; suite 119 / 0)

**The measured cause of the 20 wrong presses:** the pass-1 tolerance (`radius 0.65 / seam 0.10`)
covered **24 % of the island** on a 0.3 m grid, and the north and south keystones were reachable from
two tiles each. Pass-2 tolerances come off a measured coverage curve per view — door `radius 1.30 /
seam 0.20` (0.16 → 73 %, **0.20 → 86 %**, 0.25 → 96 %), bed and window `radius 1.00 / seam 0.12`
(0.10 → 92 / 88 %, **0.12 → 92 / 96 %**) — giving **87.8 % / 100 % / 100 %** of grid cells aligned at
eye ± 0.15 m and facing ± 15°. Every adjacent tile centre aligns for no view; from an adjacent tile the
prompt is absent and the shipping ray finds no keystone (controls). ⚠️ The door's neighbours read seam
errors of 0.106 / 0.140 rad, INSIDE its 0.20 limit — it is the radius and the 1.5 m prompt gate that
refuse them, because perspective alignment is near-invariant along the view axis; a player 2.3 m back
sees a nearly assembled door and no prompt, which is a fair tell. Shrinking the island to 1.6 × 1.6
would let the seam test do that work (~0.14 → 100 %); **not done** — the island's size is the crossing's.
`GATE_RADIUS` 1.5 m covers each tile to its corner (island 1.48, tile 1.13) and excludes every adjacent
centre by a margin as thin as 0.10 m on the bed's tile — a tuning pass should know that.

**Rulings on the builder's open questions.** The bed is the weakest silhouette (a bench at first
glance); left for the playtest — three distinguishable memories is what was asked. The Ward's lamp was
the most saturated violet in the level and rendered the bone palette lavender; **desaturated to
(0.85, 0.75, 1.0)**, energy untouched, re-shot: bone reads. The claim that the door's lintel hangs at
chest height across the walkway was **measured false**: the lintel spans y 2.61–2.78 at x −7.3, the
posts stand clear of every beam, and the door geometry is byte-identical to pass 1. Deviations
accepted: the mask slab is 0.32 × 0.46 (a 0.42-tall art quad overhangs 0.40); `_mat(Color)` stays and
`fmat(family, slot)` sits beside it because three other scripts call the raw form.

**Bugs the build found (docs/ISSUES_SOLUTIONS.md 227–229).** The flicker ended at energy 0 and the
ladder only ever turns lamps off, so it killed a lamp two rungs early (227). `check_void`'s watch-only
control stood 3.7 m from D for 1.5 s and, at 3.0 m/s, staged its own death (228) — a wait next to a
creature is a distance, and a speed change re-prices every one. The face socket had been sunk behind
an opaque quad on every variant for its whole life, and the bed and window keystones sat on the
pieces they gate (229) — occlusion is a camera fact.

**Sounds and gains.** `loop_slam` −17.7 dBFS RMS, `paper_drop` −16.6, `stone_grind` −10.3 (the loudest
file gets the quietest gain), the south whisper rides C's level over the same −38…−8 dB window, the
footstep echo uses `unit_size 2.0 + max_db 0` so at its fixed 2 m the gain is exactly 1.0. None heard
in a room.

### Pass 4 rulings — 2026-09-20 18:30 run, grilled on an Opus games-research menu

Measured: completed in 413 s, 0 deaths, peak panic 39 %; the anchor quest worked end to end; **no drawer
was pulled and the step-through never fired** — pass 3's two verbs were never discovered; the Ward
fragment re-posed 57 s after the touch, two rooms away (no distance gate on the trigger); the cradle's
payoff was a slat tween plus a plate two rooms away; `wall_void.png` carries the Gemini sparkle. The
research menu (Visage/Layers of Fear's giving scare, Void Stranger's behaviour-gated secret, Yume Nikki's
relinquishment ending, P.T.'s single-swap tells, Anatomy, Control's Oceanview bell, Manifold Garden,
Antichamber, Paratopic, Superliminal; NaissanceE, Babbdi, Fear & Hunger, Lorn's Lure, ECHO studied and
not taken) is at the plan file's side. User rulings: **the Hall of Frames** (over a 2D reconstruction
overlay and a which-is-wrong chamber — the latter legal here, §8.10 being Backrooms-specific, but an
anomaly that looks like a glitch is indistinguishable from a defect in a level whose premise is broken
geometry); **the secret door on the Morgue's west wall** (over the Sanctum's east wall and the Archive's
south); **zero panic on the lunge**; **the other Ward frame answers**; **the effect ladder as
described, zero panic** (over adding 6 per wrong step); **the hidden note empty-handed only**.

### Pass 3 rulings — 2026-09-20 15:00 run, grilled on an Opus research menu

Measured: the three shapes solved in 8.7 s and 7.5 s with the gated prompts (the place tell
over-corrected); the keystones are one `Vector3(0.16, 0.30, 0.30)` box in one colour for every view;
the Archive, PocketA and PocketB were entered in none of the day's three runs; the shard's hollow and
the cradle are seven seconds apart; the child room is 42 m² with the cradle, E and a DarkZone in it;
the spawn-to-cradle route is ≈ 97 m, so a missed early shard costs a 194 m round trip. The user chose:
carried anchors with distinct keystones (over solve-in-order, whose refusal would be as ambiguous as
Issue 226, and over loose depth pieces, which would invalidate the coverage probe); the shard in the
Archive under the inverted table (over the Threshold's hung shards and PocketA); STEP THROUGH and
SEARCH as the two new verbs (over the doorway-that-was-not-there and the music box that freezes
figures); the child room enlarged with the cradle beat untouched; the door that assembles itself;
and the far wing's economy kept as it is. Rejected ideas cross-posted to `GAME_MECHANICS_IDEAS.md` §5.1.

### Pass 2 rulings — 2026-09-20 evening grill

Measured from the run: 20 wrong keystone presses in four minutes, the island solved at 222 s, north
and south never; at least one press from (−5.4, 47.6) — the tile NEXT to the north viewpoint, 1.9 m
from its feet against a 0.65 m radius, so a wrong-tile press and a wrong-angle press were
indistinguishable and the far wing was never reached. B was stared at from 1.5 m without a death
(watched = frozen) and passed at a walk: 1.25 m/s unobserved against 4.0. The head at 2.5 m is ~20 px.
`ambient_void.ogg.import` `loop=false`. User rulings: **3.0 m/s and a 2 m retreat, Void only**; three
DIFFERENT memories (door, bed, window) in three corners with the keystone prompt gated to its tile;
the mask; five families by room; the note absent until lap 2 with sound and light on every return;
an eyelid blink and no `YOU BLINKED.` text.

### Built 2026-09-20 — the playtest pass (spec-first, grilled item by item, one level-improver + the parent)

**Rulings, with the numbers they were made on.** Loop note legible from lap 2 (it was read at 150.56 s
and 259.89 s, both before the z 32 seam). B and D stay: 1.1 s and 0.44 s look-away windows, restaging
offered and declined. A wrong keystone press costs 6.0 (measured band 5.4–6.1; a right press adds 0).
No difficulty constant moved. Reused art rejected twice — echoes in the notes' text only. The stare is
paid for in whispers and hallucinations, never a panic term (a third option with a distant drip was
offered and not taken). The face is a generated image PLUS a jumble, the doors are slabs PLUS a
generated leaf — the user's call to use the image tool, with geometry carrying the silhouette.

**Measured in the build.** Head tracking: rest −0.244 rad → +0.346 rad in 2 s unobserved, **0.000000 rad**
drift while watched (the deliberately broken build drifts 0.240665, ~480× the threshold — the first
control was worthless because a still player let the lerp converge; it now teleports the player 1.2 m
while staring). Shard ray from (−12.88, 44.68), **2.86 m** from D (≥ 2.3 required — approach from the
south). Slab underside 1.91 m, shard at y 1.70, top 1.85. Loop: each lap in 20 ticks; plug ray empty at
lap 1, hits at lap 2, empty after the read; lap 3 both lamps at 0.00 and 6 of 6 stains at 1.75. Seal
solid at 1/3 and 2/3, physically gone at 3/3. Plate intercepts the twist ray until the cradle; the note
is what the ray finds 1.4 s after. Reachable 516.2 m² (was 452), 19 targets.

**Deviations from the plan, by measurement.** `LoopWallPlug` is 1.80 m wide, not 1.82 — at 1.82 it
overlaps each jamb by 1 cm with coincident x-faces, which `check_wall_overlap` reports; RoomBuilder's
doorways are full height, so 0.2 × 3.3 × 1.80 fills the opening exactly. `SanctumPlate` is
(0.6, 0.8, 0.06) yawed π/2 (note.gd's convention maps local z to world x; the plan's ordering would
have made it 0.6 m thick). The `arm_on_sight` rearrangers ride the prop's OWN layer-1 body: a marker
node with `interact()` on layer 0 is reported UNREACHABLE by `check_reachable` (measured, two of them),
on the body they read INERT. Wall-overlap floors raised to 140 boxes / 12 quads / 190 solids (measured
145 / 13 / 223) — a floor a whole prop family could vanish under is not a sample size. The inscription's
third line became "THERE ARE THREE PLACES TO STAND." — it teaches the count, never the state, so it is
not the §8.2 readout the ruling removed; without it a correct island solve that opens nothing reads as
a bug. The door heap intrudes 10–14 cm into Hall3's nominal doorway lane (x −13.2 vs −13.1) — accepted:
the corridor is 3 m wide, the route runs x −14, every guard green; flush to the wall it becomes a relief.
At lap 2+ the BackDoor route is closed until the note is read — intended, the spec's own wording, and
the one place the level takes an exit away. The face recess stays 4 cm deep: the jumble now fills it.

**Measured after the stare wiring.** The level ticks at **60.1 physics frames per wall second** headless
in every configuration (baseline, whisper rising, whispers off, director off) — the new per-frame
systems cost nothing measurable. The first draft of `check_void_stare` timed out and its diagnosis is
worth keeping: a stalker re-awakened by the stare that dismissed it ADVANCES the moment you look away
(1.25 m/s, 3.75 m in the 3 s wait), so the next stare was from 2.2 m, inside the gaze range, and the
panic bar killed the test's player — the game was right and the test had staged its own death. The
test now steps beyond the 8 m engage distance before any unwatched wait.

**Verified after the wiring (stare, face, doors), 2026-09-20.** `check_void` 48/0 · `check_void_alignment`
58/0 · `walk_void` 41/0 · `walk_void_live` 45/0 · `check_void_stare` 24/0 · `check_stalker_motion` 49/0 ·
`check_transition_race` 19/0 · `check_wall_overlap -- Void` 0 findings (145 boxes / 33 flat / 297 solids) ·
`check_art_aspect` 408/0 with the Void at 24 measured samples, all 1.000× (the door slabs' sub-rects and
the face quad among them). 31 screenshot poses read as images. ⚠️ The doors' first cut was rejected on
the picture, not by a guard: 7–13 cm gaps and a removed slab left the red plate dominant — a red grid,
not a broken door; the seams are now under 4 cm and one slab hangs askew instead. **Full suite for this state: 118 passed / 0 failed** (`tools/run_tests.sh -q`, 2026-09-20 — the 117 the
build left plus `check_void_stare`; spec claims 149 checked, 0 areas where code is newer than its spec).

**The Nightmare inherits the deferred retreat — verified 2026-09-20.** A per-seed probe (nine seeds,
every Still One, two awaken → stare → dismiss → look-away cycles each, 495 checks) recorded **zero**
movement in any observed frame and the retreat on the first unobserved frame every time; its 66
"failures" were all benign — 36 leashed cell statues already at their leash edge (the old instant retreat
clamped identically) and 30 crypt statues that spawn inside their own sarcophagus by design. The suite's
`walk_dungeon`, `check_dungeon_hunter/rooms/map` are green. `autoplay_dungeon` (seeds 101 + 404): three
invocations, six seed-runs — five reached the bed with 0 deaths, one early run recorded one death whose
attribution line was not captured and which two later runs did not reproduce. ⚠️ A consequence to watch
on the Nightmare's next hand playtest: a stare-off inside 3 m used to END the gaze cost by moving the
statue away at 4 s; now the statue stays until you look away, so keeping your eyes on it after the
dismissal keeps costing 12/s. The correct play (stare, then turn) is what the Void's rule teaches.

**Bugs the build found (docs/ISSUES_SOLUTIONS.md 220–224).** The loop note before the seam (220). A
test that read `current_scene` during the switch (221) — and its second cause: **a freed node compares
equal to null in Godot 4**, so a one-shot block guarded on `if _level == null` re-entered when the exit
swapped the level out (223). The dismissal that moved a watched stalker (222). `check_void.gd` had no
deadline and could hang the suite forever; its lap budget was only polled while another timer ran (224).
`inverted_slab`'s single collider was a brick; a typed `var d: Node` throws on a freed instance; exact
arrival legs cannot converge at time_scale 6 because `ai_move_dir` is normalised; the door heap's panels
were built facing the wall (caught only by reading the screenshot).

### Approved 2026-09-19; implemented 2026-09-20

⭐ **Hand-played 2026-09-20** (six captures, one death, completed on the second run, peak panic 62 %).
Measured: the loop never fired in either run — `LoopNote` (z 23) was read at 150.56 s and 259.89 s,
both before the seam at z 32, so the torn pages, `AGAIN.` and the creep were skipped; the one death was
D, 1.78 m from the Morgue landing pad with a 0.44 s look-away window; the perspective puzzle was solved
in under two seconds because the island is on the direct path and the prompt announced alignment; the
dismissal's 3 m retreat executed in the observed frame (capture #2, "*we want those creatures to move
when we not look*"). User rulings from the grill: **B and D stay where they are** (restaging to a
witness window was offered and declined); **reused art is rejected**, twice now ("*unique objects and
decorations for this level*") — earlier-level echoes survive in the notes' text only; **a wrong
keystone press costs 6 panic** (the user's number); the loop note is **legible from lap 2**; the
stare is paid for in **whispers and hallucinations, never a new panic term**.

The user retained the atmosphere and crossing, rejected an immediate entrance monster and familiar
ordinary furniture, chose a fractured humanoid, kept the look-away rule, and selected perspective
alignment instead of a separate minigame. No difficulty-constant retune was requested. A live route
exposed the Ward's old east-side placement crowding the exit, so its sculpture now stands west.
The same route must create space with a stare before turning to read the twist note.

The old geometry walk removed all monsters; it never proved encounter survivability. The human
log's death beside ExitDoor was a real fatal event overlapping its delayed advance. The subsequent
ending → corrupted intro redirect itself was intentional. Swept movement and transition ownership
address these separate issues; screenshots alone did not prove that the corridor was impassable.

### Historical September 12 rebuild

The previous four-room ring became the current RoomBuilder layout, fixing a sealed pocket, exposed
sky and missing guard coverage. Rooms must abut exactly: the first Morgue draft was one metre short,
sealing the far wing. Its safe note belongs on the west wall because the south centre is a doorway.
The early six-stalker design, ordinary fragment furniture and tile-hall DarkZone were superseded by
the approved changes above.

### Audit record — 2026-09-19 spec audit

⚠️ **"15 abutting rooms … 14 doorways" is EXACT and was VERIFIED, not narrowed.** `level_3.gd`'s
`ROOMS` const holds exactly 15 rows and `DOORS` exactly 14. A claim-checker `COUNT?` that reports 19/16
is counting the `#` comment lines inside those arrays (the Morgue-abutment warning and the LoopOut
bridge-overlap warning). No spec change was needed. The stale code header was corrected during the September 20 implementation.

⚠️ **Two claims above could not be verified from the code and were left standing, not edited.**
(1) *"Standable area 77 → 452 m²"*: the 77 m² figure is corroborated by `level_3.gd`'s header, but 452
appears nowhere in the repo and does not reconcile with the `ROOMS` table (the raw sum of the 15 room
footprints is ~710 m², ~590 with the tile hall's freed floor taken out), so whatever it measures is
narrower than the room table and is not written down. (2) *"a `DreadZone` over Hall3 + Sanctum"*:
`DreadFarWing` is one box spanning x −21.5…−10, z 19.5–42.5, which also covers PocketB and the
ChildRoom — Hall3 and the Sanctum are its ends, not its extent.
