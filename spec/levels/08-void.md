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

- **Layout:** **16** abutting rooms, **15** doorways (2 gated): Threshold → Hall1 (PocketA trap) → Ward
  (Archive dead end) → LoopIn → LoopStraight → LoopOut → Hall2 → TileHall → Morgue (→ **FrameHall**, the
  secret room west of it, x −27..−21, z 44..50, its doorway at (−21, 47.5) plugged from frame 0 until
  the cradle) → Hall3 (PocketB trap) → ChildRoom → Sanctum. The Morgue is **12 × 10 (x −21..−9, z 42.5..52.5)** since 2026-09-20 — the
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
  headroom), the dead monitor on the north wall, the note on the west wall **2.5 m south of its centre**
  (the secret doorway sits at the centre — Issue 236), a drawer bank along the north wall — **one drawer
  starts pulled out** (not the page's) so the bank visibly has a moving part — and one impossibly long
  pulled drawer on the floor. The hollow on the slab's underside
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
- **The far-wing chain (pass 4):** the shard fits the child room's cradle (E on the cradle body beside
  creature E; without the shard the prompt says something is missing). Completing it tweens the slats
  level and **the cradle GIVES**: a 0.6 s `HoldBreath` dip, then a sixth fractured figure with no rules,
  no collider and no AI rises through the cradle and lunges to 0.6 m in front of the camera over 0.35 s
  with `cradle_sting` on Master (the loudest thing in the level; Ambience is ducked under it), then is
  gone — zero panic, one-shot, never replayed by a restore, creature E held off (`protected_player_rect`
  = the child room) for the lunge + 1 s. Three things answer it: `SecretPlug` frees with a distant
  `stone_grind` from the Morgue's west doorway; the child room's crayon drawing becomes, when you look
  away, a plan with one door marked in red (`void_child_drawing_plan.png`); and `SanctumPlate`'s prompt
  becomes *"Something else was opened instead."* The plate (layers 1|2, `move_aside_instantly()` for
  the reachability guard) is retracted by the **hidden note** at the end of the Hall of Frames, read
  only **empty-handed** (three anchors seated, the shard spent — already mandatory, so no new gate;
  it refuses by name otherwise). `TWIST_READ` and the exit door are untouched. It never blocks a doorway.
- **THE HALL OF FRAMES** (`void_frame_hall.gd`, in `FrameHall`): five upright violet frames, each
  holding a small diorama of a thing met earlier in its room's family — hung shards (violet), the
  folded frame (bone), the legs-up table (rust), the fused chairs (verdigris), the ceiling stair (tar).
  Step through them in the order you first met them (Threshold → Ward → Archive → LoopIn → Hall1),
  with the step-through's 1.2 s dwell. **Right:** you drop out of the next frame, the lamp gains 0.15,
  `frame_tone` rises an interval, every whisper hushes a second. **Wrong:** you drop back out with a
  slam, the lamp dies for 2 s, the frames re-scramble — in PAIRS, each pair only while neither is in
  view, because no arrangement of five frames in a 6 × 6 room has a free bearing (Issue 241) — and
  the cradle figure stands in a diorama one frame nearer, behind you for one frame every third wrong
  step. **Finish:** `frame_settle`, the five frames slide into one line, a corridor, the dioramas
  shrink away — the pieces finally agree — and the hidden note stands at its end. Zero panic, no fail
  state, retryable; brute force ≤ 15 dwells.
- **The Ward touch answers across the room:** E on the left folded frame arms it; the moment you look
  away — only while you are still in the Ward — the RIGHT frame, five metres off, changes shape (yaw
  0.9, tilt 0.35, lifted 0.3 m) with a stone grind from it. The bed slat never moves. Hall2's flat
  doorframe reacts to a dwell (its bars tilt toward the black over the 1.2 s and snap back on exit);
  the LoopIn twin does not. The loop swaps ONE object per lap against a remembered baseline (P.T.'s
  tell): lap 1 a stain at z 27 becomes a hung chair leg, lap 2 a hand-sized page.
- **Props, all Void-native and matte:** the folded frames (Ward), a stair into the ceiling (Hall1), a
  doorframe lying flat over black (Hall2) **and its twin in LoopIn, which is where the first one puts
  you**, chairs fused into the wall (LoopIn), a table legs-up (Archive), a heap of doors (Hall3),
  shards on threads (Threshold, PocketA, PocketB), the slab, the seventeen drawers, the
  cradle, the monitor, the drawing, the music box. The table and the heap **rearrange once when
  unobserved after first sight** (`void_rearrangement.gd:arm_on_sight`). **Five matte albedo families
  assigned by room** — bone, rust, verdigris, violet stone, tar (`void_fragments.gd:PALETTE`): Ward
  bone, Archive rust, LoopIn verdigris, Morgue slab bone + drawers rust, child room bone, Hall3 heap
  mixed, Hall1 stair and Hall2 doorframe tar, shards violet; the figures keep their own dark stone,
  and the Ward's lamp is desaturated to (0.85, 0.75, 1.0) so bone can read under it. The wall texture's Gemini sparkle is cloned out (Issue 235). Textures `void_sheet`,
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
- **Notes/zones:** **twelve** notes — nine on walls at 1.3 m (five safe, three read-to-die traps, one
  twist), pass 3's two Morgue pages (the slab's torn fragment, the page standing in a drawer) and pass
  4's hidden note at the end of the settled hall. Two `DarkZone`s (the 12 × 10 Morgue, the 8 × 7 ChildRoom),
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

### Pass 5 (built 2026-09-21 from the 23:33 run: 945 s, 7 deaths, not completed, eight captures)

The run's evidence is `backlogs/captures/08-void-2026-09-20e/`; the rulings are in DECISIONS ("Pass 5
rulings"). **Difficulty is ruled fine by the user (capture 6) — no constant changes in this pass.**

- **The twist note refuses while the plate stands** (the bug in capture 8: the note was read 13 s after
  the cradle with no frame step, no settle and no hidden-note read in the log). `TwistNote` gets
  `void_twist_note.gd` (extends `note.gd`, the hidden note's pattern): `prompt_text()` *"The stone covers
  it."* and `interact()` refuses (log `VOID twist note refused — the plate stands`) while the level's
  `_sanctum_plate` is valid; `retract()` / `move_aside_instantly()` clear it; `_restore_progress` keeps it
  consistent with `hidden_note_read` (`level.plate_stands()` is the one truth; `retract()`,
  `move_aside_instantly()` and the ending's instant unseal all clear it). The plate grows to 0.90 × 1.10
  at x −17.74 (0.13 m clear of the wall face, 0.09 m clear of the paper — never coplanar) as **defence in
  depth only**: ⚠️ no plate narrower than the room closes the grazing band — the note hangs 0.34 m off the
  line a player walks along that wall, and from (−17.5, 0, 22.2) the ray crosses the plate's 6 cm depth
  2 cm before its edge; **7 of 13 swept stances still reach the note's collider. The refusal is the
  gate.** **Replaces:** a 0.60 × 0.80 slab 3 cm in front of the note as the only gate. **Proves:**
  `check_void` — from thirteen swept stances along the wall E opens nothing while the stone stands
  (control: the refusal removed → 7 of them open the page), and the guard asserts the grazing band is NOT
  empty, so if geometry ever did block every angle it says so; `walk_void_live` — refused before the
  hidden note, read after.
- **A cause shows a receipt; the change still happens off-screen** (captures 2, 3, 7 — the second run
  in which the off-screen rule read as "nothing" / "a bug"). The Ward's suspended fragment becomes a
  **hospital gurney hung nose-down by one corner** (`void_fragments.gd:gurney`, boxes only, bone family;
  *"E — Touch the hanging gurney."*); E drops it 0.10 m and yaws it 6° over 0.4 s with a `stone_grind` at
  the gurney itself, and THEN the right frame answers off-screen as built. **The shard is visible from
  the start**, wedged in the inverted table's underside (*"It is wedged fast."*, refuses, log `VOID shard
  refused — wedged`); the table's off-screen rearrangement frees it into the basin with a
  `shard_clatter` (log `VOID shard FREED into the basin`), takeable as today. **Replaces:** an abstract
  bone assembly as the touch prop; a shard that does not exist until the look-away. **Proves:**
  `check_void` — the gurney carries the touch collider and moves on E; the shard refuses at start, frees on
  `rearranged`, is takeable after; screenshots of both.
- **The corridor charge** (capture 4): the first **southbound** entry to the loop corridor after the loop
  is broken (an Area3D at x 11..14, z 41..43, **polled** — a `body_entered` signal fires on the crossing
  only, and a player who walks in northbound and turns round inside it must still arm it) makes a
  rule-less figure — a `charge` mode on `void_cradle_figure.gd`, no collider, no `ScaryObject` — stand at (12.5, 0, 16.5) under the dead lamp facing away, turn over 0.25 s,
  rush to 0.6 m in front of the camera over 1.0 s with the shared `jumpscare` on a Master emitter, and
  vanish. **Zero panic**, one-shot, `corridor_charge_done` saved and never replayed; creature C held off
  (`protected_player_rect` = the corridor) for the charge + 1 s. Log `VOID corridor charge FIRED`.
  **Replaces:** nothing — the return trips for the slat were empty. **Proves:** `check_void` — fires once on
  a southbound entry after the loop is broken, never on the northbound first pass, `_panic` unchanged with
  `RandomAmbient` unregistered (Issue 240), C protected; `walk_void_live` on the return leg.
- **The cradle figure rises from the cradle's visual centre with the shared `jumpscare`** (capture 5):
  `arm()` takes the assembly's bounding-box centre, not the node origin; the `CradleSting` emitter loads
  `jumpscare` (−2.83 dBFS RMS) at **−10.3 dB / unit 4.0 on Master** (`_make_sting`, shared with the charge),
  the gain that lands it where `cradle_sting` (−10.09 dBFS at −3.0 dB) was measured. `cradle_sting.wav`
  stays on disk, unplayed. **Proves:** `check_void` — the figure's home is within 0.2 m of the assembly's
  centre (measured 0.055 m; the node origin it used to rise from was y 0.00); a screenshot at the peak.

### Verification

**Pass 5 measured (2026-09-21, the builder; the parent's re-run is in DECISIONS):** `check_void` 206/0 ·
`check_void_alignment` 130/0 · `check_void_frames -- --seeds 1` 29/0 · `walk_void` 100/0 · `walk_void_live`
101/0, 0 deaths · `check_reachable` 42 targets, 38 reachable, 2 inert, 1 contained, 0 unreachable, **1
waived** (`InvertedTable_Archive`, see DECISIONS) · `check_doorways` 15, 2 gated · `check_shell_sealed` 231
points, 0 escaping · `check_wall_overlap -- Void` 0 findings (150 boxes / 41 flat / 426 solid props) ·
`check_note_mounting` 236/0 · `check_transition_race` 29/0 · `check_void_stare` 27/0 · `check_stalker_motion`
51/0.

**Pass 4 measured (2026-09-20, the builder; the parent's re-run is in DECISIONS):** `check_void` 142/0 ·
`check_void_frames` 75/0 over six seeds · `check_void_alignment` 128/0 · `walk_void` 93/0 ·
`walk_void_live` 95/0, twelve consecutive green runs · `check_transition_race` 29/0 · wall-overlap
**150 CSG boxes / 41 flat / 415 solid**, 0 findings · shell 231 points, 0 escaping, sealed at frame 0
with the plug in · **15 doorways, 2 gated** · reachable **555.2 m², 42 targets, 38 reachable, 3 inert,
1 contained, 0 unreachable** · **12 notes** · 26 art samples · full suite **120 / 0**.

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

## NEEDS A PLAYTEST

Four passes on 2026-09-20; the first three were hand-played the same day (the third and fourth runs
completed the level). **Pass 5 (2026-09-21) has not been hand-played, and neither has pass 4's Hall of
Frames** — the fifth run won the level through Issue 242 without entering it. Pass 5 needs a human for:
- **The Ward gurney** — does it read as a gurney from the Hall1 doorway (4 m) and from 2.4 m; does the
  0.10 m drop + grind on E register as "I did that", and do you then turn and find the right frame changed?
- **The wedged shard** — visible from the Archive's doorway? Does *"It is wedged fast."* read as a puzzle,
  and does the clatter behind you land?
- **The corridor charge**, walking back south after the loop note — does 25 m of run-up read as a scare
  or as a cutscene, and does the shared `jumpscare` at −10.3 dB sit right in the mix?
- **The cradle** — the figure rises from the middle of the cradle on the shared `jumpscare`: louder or
  quieter than pass 4's?
- **The Sanctum** — E on the twist note before the frames, from the wall and from in front: *"The stone
  covers it."* and nothing opens. After the hidden note: *"E — Read the page."*
- ⚠️ **Known, not fixed (pass 5 open question 2):** the Archive's inverted table and Hall3's door heap are
  walk-through (collision layer 2, since sight mode shipped); the heap intrudes 10–14 cm into Hall3's lane,
  so making them solid re-measures `walk_void` and `check_doorways`. A later pass's call.
Pass 4 still needs a human for:
- **The cradle's giving scare** — the sting sits on Master under a `HoldBreath` dip, the figure lunges to
  0.6 m; judged from a guard and a screenshot, never felt. And whether the three answers (the distant
  grind, the drawing's plan, the plate's new line) send you to the Morgue's west wall.
- **THE HALL OF FRAMES** — whether the answer (the order you met the things) is discoverable, whether the
  wrong-step ladder keeps tension or reads as punishment, whether the pairwise re-scramble is ever seen
  (it must not be), whether the tar diorama reads as a ladder or a hole, and how many dwells a human
  needs (the bot: five; brute force: fifteen).
- **The hidden note** — whether "put everything back" lands as the ending's meaning or as a refusal.
- **The Ward touch** — five metres across the room, with a grind; nobody has turned round to it.
- **Whether the drawers and the step-through are found now** — one drawer starts open, Hall2's frame
  reacts, and the hall makes the verb load-bearing; the 18:30 run found neither.
- **A hazard the bot found**: standing still just south of the child room's doorway with your back to
  E is inside E's reach through the opening (Issue 239). The 15:00 human survived that spot; watch the
  log for `CreatureE lunge` near z 28–29.
- **Audio** — every gain from a file's RMS; the whisper hush on a right step is unasserted.
- Still open from earlier passes: the far wing's panic economy (the user's ruling: keep), one anchor
  at a time (kept for a playtest), the loop's return sounds.

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

### Built 2026-09-21 — pass 5 (one level-improver; the parent's sound, docs)

**Files.** New `void_twist_note.gd` (extends `note.gd`, asks `level.plate_stands()`); `void_sanctum_plate.gd`
0.90 × 1.10 × 0.06 at x −17.74; `void_fragments.gd:gurney()` (2 rails, 4 legs, 4 caster discs, head board,
mattress, 2 straps — boxes, bone; pose tilt 0.85 / yaw 1.72 / roll 0.22, the first pose at 77° rendered as
a pale rectangle and was re-posed to 49° broadside); `void_rearrangement.gd` touch mode builds the gurney
and plays the receipt (hang node −0.10 m, yaw 6°, 0.4 s, `stone_grind` −9.0 dB / unit 2.0 AT the gurney ≈
−6.5 dB at 1.5 m, a shade louder than the distant answer's −8.3 dB); `void_shard.gd` `wedge()` /
`free_into_basin(announce)` / `is_freed()` — wedged at (−3.19, 0.74, 21.66) on the doorway side, 0.52 m
above the table's collider (Issue 230), basin (−3.4, 0.42, 22.0) unchanged, `shard_clatter` (−22.46 dBFS)
at −3.0 dB / unit 3.0; `void_cradle_figure.gd` `arm(player, source, sting)` with `_bbox_centre()` and a
`charge` mode (`arm_charge`, +66 lines against ~130 for a new file); `level_3.gd` `CHARGE_AREA_POS`
(12.5, 1.65, 42.0) / size (3, 3.3, 2) polled, `CHARGE_FIGURE_AT` (12.5, 0, 16.5), rush 24.4 m in 1.0 s,
creature C's `protected_player_rect` = the corridor for the beat + 1 s then restored to the tile rect,
`_make_sting()` (shared `jumpscare` −10.3 dB / unit 4.0 Master) for `CradleSting` and `ChargeSting`,
`snap_to_strike()` for captures.

**Measured.** Gurney AABB x −3.69..−1.89, y 0.13..2.27, z 12.61..13.68 — 5 cm clear of `FoldedFrame_Ward_L`
(z 13.73), neither a CSG box, so `check_wall_overlap` could never have said a word. Its touch volume (0.80 ×
0.60 × 0.45 at world y 1.25..1.85, z 13.08..13.53) passes 0.33 m ABOVE the bed-slat approach ray — the first
draft swallowed the slat, caught by the control, not by eye. Cradle figure home (−15.728, 0.948, 34.300)
against the assembly's bbox centre (−15.739, 0.948, 34.246): 0.055 m.

**Five positive controls run red then green** (the refusal removed → 7 stances open the page; the wedged
guard removed; the receipt's early return; the southbound guard; `_bbox_centre` → the node origin), each
with the modified file proven changed by sha (the twist note is a new file, so `git diff` is empty by
construction). **The parent's re-run:** the wedged guard removed by hand — `check_void` red on "…and E on it
REFUSES" (the deadline check cascades), green again at 206 / 0 with the file byte-identical; the first
attempt matched nothing and ran green, again — check the diff is non-empty before reading a control.
Full suite 122 passed, 1 failed: **`check_darkness`, the parallel Breach session's uncommitted
`lock_flashlight()` in `level_6_breach.gd:_ready()`** — not this level.

**Rulings on the builder's questions.** (1) The plate cannot close the grazing band and the spec said it
would — the spec is corrected, not the geometry: the refusal is the gate, the plate is defence in depth,
and the guard asserts the band is NOT empty. (2) The Archive table and the door heap are walk-through
(layer 2, overwritten in `_ready()` since sight mode shipped) — **left as shipped**, recorded in NEEDS A
PLAYTEST; making them solid moves Hall3's lane and is a later pass. (3) The reachability sweep's one
waiver on `InvertedTable_Archive` is accepted: the alternative is re-adding the interact volume that
swallowed the shard's ray. (4) `walk_void`'s 2 m corridor detour stays — the shipping route uses the
step-through, so nothing else walks the corridor southbound. (5) `check_void` plants `_loop_broken` to run
the charge before the lap stages; the walks cover it in the genuinely broken state.

**Bugs the build found (docs/ISSUES_SOLUTIONS.md 244–246, plus Issue 228 a fourth and fifth time).** A
sight-mode rearranger ran the touch-mode branch of its own `_ready()` for its whole life, because
`arm_on_sight` is set on the line AFTER `add_child` — each carried a spurious interact volume and a stray
box, and had its layer overwritten. `Object.call()` on a renamed method unwinds the function and fails
nothing: `check_void` printed PASS with eight checks gone, its count floor 80 below the real count. Its
reload guard was an ordering test on stage labels that are not ordered. Two new stages staged their own
deaths on creature C (Issue 228).

### Built 2026-09-20 — pass 4 (one level-improver; the parent's assets, guard, docs)

**Measured.** FrameHall added +7 CSG boxes exactly (its floor, ceiling, three walls, the new bridge, and
the Morgue's x = −21 wall split by the doorway): 150 / 41 / 415. Reachable 555.2 m² (was 527.9), 42
targets. The hall's shells stand on end via Rx(−π/2) + a 1.17 lift (opening y 0.12–2.22, width 0.92);
backdrops 1.40 × 2.20 at y 0.10–2.30 (a 2.50 quad dips into the floor slab). Lamp 0.25 + 0.15 per right
step → 1.00 at five. Gains from the files: `cradle_sting` −10.09 dBFS RMS → **−3.0 dB / unit 4.0 on
MASTER** (at 0.6 m the distance gain clamps at +3, so the effective level is 0 dB and its −1.01 peak
sits on the ceiling without clipping; Ambience is where `HoldBreath` ducks to −30, so a sting there
would land inside its own silence — `screamer.gd` routes the same way); `frame_tone` −7.5 / 4.0 at
pitch 1.0 / 1.125 / 1.25 / 1.5 / 2.0; the hall's `loop_slam` −6.0 / 3.0; `frame_drop` −10.5 / 4.0;
`frame_settle` −5.5 / 6.0; the secret door's `stone_grind` −6.0 / unit 8.0 ≈ −11 dB at the 14.2 m from
the cradle — a distant answer. Panic from everything in the pass: **0**, asserted with `RandomAmbient`
unregistered (Issue 240). Five positive controls run red then green: the plug removed, E's rect not set,
a collider on the figure, the note's refusal removed, the re-scramble's observation check removed.

**The parent's re-run (2026-09-20 night, after the hand-back).** `check_void_frames` **75 / 0 over six
seeds** (registered in `tools/run_tests.sh` after `check_void_alignment`) · `check_void` 142 / 0 ·
`walk_void_live` 95 / 0 · full suite **121 passed, 0 failed** · 65 screenshots regenerated, ten read as
images (the settled corridor, the figure in a frame, the plan drawing, the answered Ward frame, the open
doorway, the hidden note's prompt, the bone and tar dioramas, the open drawer, the clean wall). ⚠️ One
positive control was re-run by the parent rather than trusted: with both `return`s removed from
`void_hidden_note.gd:interact()` the harness reddened on exactly "…and E opens nothing" and "…and the
stone has not started moving" (29 checks, 2 failed), green again with the file restored byte-identical.
The first attempt at that control matched nothing and ran the unmodified file green — a control that
never modified the code proves nothing, so check the diff is non-empty before reading the result. The
claim checker's two `COUNT?` rows were the 2026-09-19 audit paragraph below, corrected to 16 / 15.

**Rulings on the builder's questions.** The tar diorama is the dimmest of the five and reads as a
ladder silhouette — **left**: it is correct (Hall1's stair is tar), and lightening one backdrop would
cost the one-family-per-room rule its meaning; the honest lever is the hall lamp's base. The wrong-step
figure escalates **every third** wrong step, not once — a player who keeps flailing keeps being
answered. The settle **frees the dioramas** (a 0.5 s shrink under the 1.6 s settle) — otherwise the
corridor is five blocked holes; "the pieces finally agree" is the reading. The shells are **violet, not
tar**: tar at 0.17 in a 0.25-lit room is invisible, and legibility was the run's headline complaint; the
cost is that they no longer rhyme with Hall2's tar step-through frame. `walk_void_live`'s twist-note
leg is routed round the Sanctum's east side to keep every stance ≥ 2.3 m from F and out of E's sight
line — a harness change that documents a real hazard, no level change (the far wing's economy is the
user's ruling). The doorway's 4 mm floor bridge is hidden until the door opens although it is invisible
by construction (both floors cover it) — a later edit to either footprint would quietly turn it into a
seam that says *door here*; `check_void` asserts solid floor under it in both states.

**Bugs the build found (docs/ISSUES_SOLUTIONS.md 236–241).** The Records-sign fault from the other end
(a doorway added at a wall's centre landed on the note hanging there — the note moved 2.5 m south).
Godot 4 replaces duplicate node names, so `DoorFloor` addressed one bridge of fourteen — bridges are
found by geometry now. Issue 228 recurred in a brand-new stage the same day. The live walk's three
deaths in nine at the twist note were creature E through the child room's doorway, not F. A zero-panic
claim cannot be measured with `RandomAmbient` running. And a five-point ring has no free bearing, so
the re-scramble is pairwise.

### Pass 5 rulings — 2026-09-20 23:33 run (945 s, 7 deaths, not completed, eight captures)

Evidence `backlogs/captures/08-void-2026-09-20e/`. **Measured:** the twist note was read at 889.9 s with
no frame step, no settle and no hidden-note read — the plate never retracted; the plate is a 0.60 × 0.80
slab 3 cm in front of the note, and from a grazing stance along the Sanctum's west wall (capture 8 at
(−17.5, 0, 20.9)) parallax slides it off the page, which the screenshot shows peeking out beside the
slab. The Hall of Frames was never entered (0 position samples in x < −21, z 44..50) — the bug handed the
player the ending first. The Ward answer fired 33 s after the touch in life 1 (the right frame stayed in
view) and within 10 ms in later lives; the shard appeared 4.4 / 11 / 5.6 s after the table came into
sight, always on a look-away. No drawer pulled, no step-through, second run running. Deaths: E at the
child room's south doorway / inside the Sanctum ×3 (one 5.5 s after the cradle lunge — Issue 239's
hazard), B in the Ward ×3, C in the loop corridor ×1.

- **Difficulty is fine — the user's words (capture 6): "*Even though I am losing frequently — the
  difficulty is fine, the level should not be simple.*"** No constant moved; E's 1 s hold-off after the
  cradle lunge stays (offered a 6 s hold-off, declined by recommendation and ruling).
- **A cause shows a receipt; the change still happens off-screen.** Two runs in a row read the
  off-screen rule as "*nothing happened*" / "*this shard did not appear immediately*". The touched
  object now reacts under your eyes (the gurney drops 0.10 m with a grind) before the right frame
  answers off-screen; the shard is visible from the start, wedged, and the look-away frees it. Rejected:
  making both immediate and on-screen (drops the level's one rule for two props); sound only (the 18:30
  run already had the grind and it was not noticed).
- **The Ward's suspended fragment is a hospital gurney hung nose-down**, geometry only, bone family:
  "*Objects in this level, even though they should be broken and corrupted, they still should represent
  some objects.*" Rejected: a wheelchair fused into the wall (small silhouette), an upside-down crib
  (pre-empts the cradle), a generated image on a quad (reads flat from the side for a thing you walk
  around).
- **The corridor charge costs zero panic** — the loop corridor is walked three times, twice on the
  return for the slat, and the user asked for "*a sudden jumpscare with 3d animation*" there. A +10
  version was offered and declined: the pass already rules that a scare with a number attached can be
  optimised against. Not a pursuer (no collider, no rule, one-shot); creature C is held off for it.
- **The cradle figure rises from the assembly's visual centre and uses the shared `jumpscare`** at
  −10.3 dB (jumpscare −2.83 dBFS RMS against cradle_sting's −10.09 at −3.0 dB). The pass-4 concern that a
  fatal sting reused for a survivable scare teaches the fatal sound is free was stated once and
  overruled: the Corridor's silhouette and KONTUR's blackout figure already use `jumpscare` for
  survivable in-world figures, so this is the game's existing practice, not a new precedent.
- **The twist note refuses while the plate stands.** Not a ruling — a bug (capture 8). A blocker 3 cm
  in front of a target does not block at a grazing angle; the target is gated itself, and the plate is
  widened to cover the page from every stance. The level was winnable without the minigame.

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

⚠️ **The room and doorway counts are EXACT and were VERIFIED, not narrowed.** On 2026-09-19 `level_3.gd`'s
`ROOMS` const held exactly 15 rows and `DOORS` exactly 14; **since pass 4 (2026-09-20) it is 16 rows and 15
doorways** — `FrameHall` and its west Morgue doorway, counted by `{` row literals. A claim-checker `COUNT?`
that reports more (19/16 on 2026-09-19, 35/17 on 2026-09-20) is counting lines other than the row literals:
the `#` comment lines inside those arrays (25 in `ROOMS`, 4 in `DOORS` after pass 4). Older dated
verification records above that say "14 doorways, 1 gated" are history, not drift. The stale code header
was corrected during the September 20 implementation.

⚠️ **Two claims above could not be verified from the code and were left standing, not edited.**
(1) *"Standable area 77 → 452 m²"*: the 77 m² figure is corroborated by `level_3.gd`'s header, but 452
appears nowhere in the repo and does not reconcile with the `ROOMS` table (the raw sum of the 15 room
footprints is ~710 m², ~590 with the tile hall's freed floor taken out), so whatever it measures is
narrower than the room table and is not written down. (2) *"a `DreadZone` over Hall3 + Sanctum"*:
`DreadFarWing` is one box spanning x −21.5…−10, z 19.5–42.5, which also covers PocketB and the
ChildRoom — Hall3 and the Sanctum are its ends, not its extent.
