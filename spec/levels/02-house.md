# Level 2 — The House — spec

> ⚠️ **SPEC-FIRST.** This file is the live representation of this level. Plan a change here (marked `🔨 PLANNED`) *before* writing code, then drop the marker and record the rationale below once it is built. See `CLAUDE.md` → SPEC-FIRST.

## SPEC

**Level 2 — The House (abandoned domestic interior)** — rebuilt procedurally (Session 10)
- ⭐ **2026-09-24 (f): THE GLASS RE-SEALS ON A REOPEN.** Found by reading the code during the (e) pass,
  then fixed and measured here. `_reset_positions()` re-armed the hammer on every reopen, by the
  standing rule that ESC must not become a checkpoint, but it never reset `_glass_broken`. Break the
  glass, press ESC and reopen: the panes were redrawn SEALED while `_check_glass()`, the collision
  and `_is_won()` all still treated them as gone. A sealed-looking room you could walk into, with
  the hammer back on the board. The glass now re-seals with the hammer (`_glass_broken = false` in
  `_reset_positions()`), so a close banks nothing, which is the same rule as the fragments.
  Guarded in `check_maze_traps.gd`: break → ESC → reopen → the panes are solid and `_is_won()` is
  false on the key cell.
- ⭐⭐ **2026-09-24 (e): THE MAP GAME — TWELVE CURATED MAZES, AND IT CANNOT KILL YOU WHILE YOU
  PLAY** (third playtest, 457 s, **1 death, and it was inside the map**. Capture #1: *"There
  are many geometries in this map that are impossible. We need … 10-15 possible ones that are not
  simple but not impossible either — no dead loops, no situations where it is unavoidable to bump
  into the monster … there can be no way you die from the level screamer while you are still playing
  the game. Only after you lost it several times in a row from the monster"*). The grill answers are
  in `backlogs/02-house-porch.md` §2 rows 16–17. ⚠️ **Every paragraph further down that says "a
  fresh maze every attempt", "a brand-new maze" or that the map's panic can kill is history.**
  - **A fixed set of 12 layouts replaces fresh random mazes.** `MazeChaseUI.CURATED_SEEDS` is
    **[1030, 1085, 1101, 1146, 1356, 1472, 1534, 1611, 1767, 1804, 1930, 1134]**. A new attempt (the
    first open, or after a win or a catch) calls `_load_layout(_pick_layout_seed())`:
    - `_pick_layout_seed()` picks one uniformly and **never the one dealt last**
      (`_last_layout_seed`, on the UI, which lives as long as `HouseMap`).
    - `_load_layout()` does `seed(s)` → `_generate_maze()` → **`randomize()`**, so the seed drives
      only the generator and the rest of the game stays random. It logs `MAP layout seed N`.
    - A seed fixes the whole layout: the walls and braid, the hammer, the glass room, the hunter's
      and patroller's starts, and the snares. **The generator's algorithm is unchanged.**
    - **The patroller's runtime choices** (`_pick_patrol_target()`) draw from their own
      `_patrol_rng`, which `_reset_positions()` reseeds from `patrol_seed` on every open. The game
      sets `patrol_seed` to the layout's seed, so a layout plays the same each time it is dealt,
      given the same hand on the mouse. The harnesses vary only this value.
    - ESC still resumes the same instance (`_instance_live`), as before.
  - **How the 12 were chosen:** `tests/probe_maze_curate.gd` (reproducible, headless, ~4.5 min), the
    user's *"filter only, I pick 12"*. It sweeps generator seeds **1000–1999**. The filters live in
    `tests/lib/maze_curation.gd:analyse()`. "Mandatory" cells are, per leg of the tour (start →
    hammer → key), every cut vertex of that leg (removing it disconnects the leg's ends), plus the
    leg's own end. Each carries the player's arrival time along the tour. A seed is rejected on:
    - **(a) an unavoidable race:** min over the mandatory cells (not the key's own cell, which the
      glass shuts to the hunter) of `hunter arrival − player arrival` must be **> 1.2 s**. The hunter
      arrives at `MONSTER_START_DELAY` + its BFS cells × 96 / `MONSTER_SPEED`; the player at
      tour cells × 96 / `PLAYER_SPEED`.
    - **(b) behind the hunter:** the hunter's start cell is itself mandatory, or when it wakes it is
      nearer the first waypoint (the hammer) than the player still is, by ≥ 1 cell.
    - **(c) the patroller's circuit crosses a mandatory cell:** the real `_tick_patroller` runs for
      45 s of game time on the layout's own sub-seed, with the player out of aggro.
    - **(d) a dead loop:** any of the bot runs below stalls (no new low in corridor distance to its
      goal for 10 s) or times out (100 s).
    - **The band:** the survivors are each played **20 times** by the harness bot. The patroller
      sub-seed is `seed×100+k`, and k = 0 is the game's own. A seed is kept at **50–85 %** and ranked
      by distance from 67.5 %; ties go to the smaller seed.
  - **The map can no longer kill.** Every panic write from the map goes through
    `MazeChaseUI.add_map_panic()`: the drip and proximity, a snare, and `HouseMap`'s `CATCH_PANIC`.
    It reads `get_panic_ratio()` and adds only the room left under **`MAP_PANIC_CAP` 0.98** (49 of
    50). The bar and heartbeat still climb to the cap; `player.add_panic()` never reaches
    `PANIC_MAX` from the map. No shared file was touched.
    - **The 3rd catch IN A ROW** (`HouseMap.CATCH_STREAK_FATAL` 3, the user's number) fires
      `Screamer.trigger()`, the House's death and restart. It logs `MAP caught (streak N/3)`.
    - A win resets the streak to 0 (`MAP won (catch streak reset)`). ESC or a close is not an
      attempt. A level restart resets it, because `HouseMap` is rebuilt.
    - The Issue-9 self-clear guard stays, because a screamer from elsewhere can still unpause the
      tree under the overlay.
    - **Every rate is untouched:** `MONSTER_SPEED`, `MONSTER_START_DELAY`, the patroller's four,
      `PATROL_MIN_ROUTE_GAP`, `SNARE_*`, `CATCH_PANIC`, `MAZE_DRIP_RATE`, `PROXIMITY_*`, `SPRING_K`,
      `PLAYER_SPEED`, `BRAID_FRACTION`, `TOUR_BAND`, `fragment_count`, `FRAGMENT_MIN_DETOUR`.
  - **What proves it:**
    - `check_maze_gen.gd` asserts (a)–(c) on all 12. It also asserts the dealer: 600 deals give all
      12, 0 repeats and 0 strays. A seed must rebuild the same layout, the global RNG must be handed
      back, and the patroller's circuit must replay. The 200-seed structural sweep still runs.
    - `check_maze_chase.gd` runs the bot on exactly the 12 × 20 and asserts each seed at **9–18 / 20**
      (45–90 %) with no stalls, and the aggregate at 50–85 %. CATCH / SKIP / PURSUE run on the 12
      plus 40 raw generator seeds.
    - New `check_maze_no_death.gd` (in `run_tests.sh`) uses the real `HouseMap` + UI in the House.
      At 98 %, 4 s of drip + proximity + a snare: no screamer, and panic is held at 0.98. Catch 1 at
      90 % is not a death. The ejected player survives 2 s of 3D. ESC leaves the streak at 1, and
      catch 2 is not a death. A won standalone map resets 2 → 0. Catch 3 at 0 % panic fires the
      screamer.
    - `screenshot_maze_ui.gd` renders all 12 boards plus a 4×3 sheet.
  - Instrumentation (no gameplay change): the forest log lines now print panic, as `PORCH blade
    pulled … panic N%` and `FOREST clock OFF … panic N%, peak N%`. The user asked "at what panic
    level I was when I took the blade", and the log could only reconstruct it.
- ⭐⭐ **2026-09-24 (d): THE SECOND PLAYTEST** (345 s, 0 deaths, peak panic 91 %, three
  J-captures; the grill answers are in `backlogs/02-house-porch.md` §2 rows 13–15).
  - **The blade is in the forest's far corner, behind a tree** (capture #1: *"too simple to find
    it. Let's put it somewhere in the corner of the forest just behind the tree so that you need to
    actually search for it, probably in several runs"*).
    - **Where:** `HouseOutdoors.BLADE_CLEARING` is **(−37.5, 0, 21)**, the far north-west corner,
      d = **25.5 m**. It is 2 m inside the west trunk ring and 2.5 m inside the north one, and it is
      reachable on foot (the real `AutoPlayer` walks there and back). It was at (−32, 15), d 20.
    - **Hidden:** one deliberately thick trunk, `HidingTrunk` (r **0.55**; the seeded trunks are
      0.16–0.34), with the same bark, a solid collider and its own canopy. It stands
      `HIDE_TRUNK_DIST` **1.2 m** from the stump, on the bisector (`HIDE_DIR`) of the two sightlines
      it must cut: from the rail gap (−12, 6) and from the forest's middle (−26, 6). The stump is
      yawed `BLADE_STUMP_YAW_DEG` **6.5°**, which puts the blade edge-on to both sightlines, so its
      width cannot peek round the trunk.
      - The trunk is built after the seeded passes and outside the RNG. The seeded layout is exactly
        what the moved clearing alone produces.
      - `BLADE_CLEAR_R` 3.5 still keeps seeded trunks out of the clearing.
    - **Still fixed, still no hint**, so a player learns it across deaths. The forest clock's
      constants did not move.
  - **The blade is real art** (capture #2: *"the blade does not look very realistic, you have the
    image generation tool, please use it"*). The art is `guillotine_blade.png` (1024×576 RGBA,
    generated). It shows a bolted iron bar on top, a full-width iron band, and the steel below it
    with its edge **low on the left** seen from the front. The triangle under the diagonal is
    transparent. It is built on the `door.gd:build_visual()` pattern
    (`HouseGuillotine.build_blade()`, used by both the stump and the frame):
    - **Two `QuadMesh`es**, front and back, 2 mm proud of the edge boxes. They are cropped by UV
      to the art's opaque bounding box and sized to its aspect (**1.789**) at `BLADE_ART_W`
      **0.50 m** wide, i.e. 0.28 m tall.
      - Alpha **scissor**, not blend.
      - The back quad is turned round **and mirrored in U**, so the slant is the same blade seen
        from behind.
    - **Thin dark edge boxes** (`BladeEdge0..6`, iron, 14 mm) give it thickness. `blade_profile()`
      measures them off the texture's alpha once, at load (11 ms): 12 horizontal strips, each box
      only as wide as the columns opaque in every row of its strip. So no box shows through the
      cut-away triangle or between the top bar's three tabs.
    - **No emission** anywhere; moonlit (render layer 2).
    - If the file is missing, it falls back to the old two boxes.
    - The frame's dropped height is now derived: `blade_down_y()` puts the blade's lowest point on
      the lower lunette board (0.63), which is 0.75 for the art and 0.94 for the old boxes. The
      stump lifts the blade so its lowest point is `BLADE_BURY` **0.12** m in the wood (0.08 before the
      verification render, below).
  - **The witch is SEEN in the house** (capture #3: *"At least one time the baba yaga should be seen
    in the house. I heard it but did not see"*). Measured cause: glimpse 2 stood **12.9 m** behind
    the player, beyond the House's 11 m torch, in a house at ambient 0.0, so she was invisible.
    - **The beat, for both sightings:** the Lab nook's and the cellar child's idiom, **without the
      nook's panic**. `witch_scream` plays at her, into a `HoldBreath` dip (0.4 s). The player is
      pinned (`freeze_input()`, velocity zeroed by hand) and `turn_to_face()`d onto her chest over
      `WITCH_SIGHT_TURN` **0.45 s**. She holds `WITCH_SIGHT_HOLD` **1.5 s** and fades over
      **0.4 s**, and the player is released.
      - She is a `Watcher` (`house_witch.png`, 1.65 m, `require_los` true), persistent so only
        the beat decides when she goes.
      - **Zero panic:** a forced turn cannot be avoided, so it must not cost (SCARY §8.11).
      - Postponed on `WITCH_SIGHT_RETRY` 0.25 s, never fired blind, while a note or any pause is
        up, the player is already pinned or in a beartrap QTE, or the cellar blackout runs.
      - A real-time `WITCH_SIGHT_SAFETY` **5 s** release means a sighting can never strand the
        player frozen.
    - **Sighting A (guaranteed):** it fires when **`SafeNote_First` (the Bedroom) is closed**, via
      a one-shot method connection to `NoteUI.closed`. She stands in or near the Bedroom's east
      doorway (−4, 12.5), the room's only way out. A placement **ladder**, each rung through
      `Watcher.spawn()`:
      1. the doorway's inner side (−5, 12.5);
      2. its outer side on the Landing (−3, 12.5);
      3. mid-room toward the doorway;
      4. 2.5 m behind the player.

      The first pass takes only 1.6–4 m, then any distance. If nothing fits, the scream and the
      turn toward the doorway still happen and it is logged, never skipped silently.
    - **Sighting B (only for a long stay):** it fires once the level has run `WITCH_B_AFTER`
      **480 s** of game time and A has happened. Paused time is excluded: it is counted in
      `_process`, which does not run under a pause. It comes at the next safe moment with the
      player **inside one of `ROOMS`** (not on the deck, not in the forest, not in the cellar).
      She appears **behind** the player: the camera's back vector, a ±30° fan, 2.5–3.5 m, the
      spot itself inside a room. The same beat follows, zero panic, one-shot.
      - `witch_b_after` is a test hook only; the constant is the user's.
    - **Glimpse 2 is deleted** (the Hallway scream after taking the fruit): its constants, its
      placement and its scream call are gone. Its scream is what the sightings use. The yard
      glimpse (1) and the tree-line glimpse (3) stay, silent.
    - Save keys: `witch_seen_a` / `witch_seen_b`. Neither is ever replayed on a back-door return.
      An older snapshot whose `witch_glimpses` still holds 2 loads harmlessly.
  - **What proves it** (measured numbers under DECISIONS & GOTCHAS):
    - `check_house_porch.gd`, **126 checks**:
      - the stump at the corner, d 25.5;
      - 16 physics rays (three points across the rail gap and the forest's middle, to the blade's
        centre, both ends and the stump's top) stop on `HidingTrunk` with every other trunk
        excluded, and a control ray with it excluded reaches the stump;
      - the blade art on quads on both blades, on no box face, with no emission, on layer 2;
      - the real `AutoPlayer` round trip to the corner (the planner now also requires a line of
        sight from its stopping cell to the stump);
      - taking the fruit spawns no witch and no scream.
    - New **`check_house_witch.gd`, 40 checks**:
      - A: nothing while the note is open. After a real E press closes it, the player is pinned,
        the scream plays at her, the camera is turned onto her (dot ≥ 0.9), she is ≤ 4 m away
        with a clear physics ray, panic stays 0.000, and the player is released after the hold.
        A is one-shot. It is checked from three more reading spots, and each lands.
      - B: nothing before the (hooked) timer. Nothing on the deck with the window broken and the
        Living Room in plain sight behind the player. Nothing while a note is open. Then she is
        behind the player (dot −1.00), 3.0 m, inside, turned onto, zero panic, and released.
      - Save/restore.
    - Renders (`screenshot_house_porch.gd`): `20`/`23` the stump by torch, `22a`–`22c` the trunk
      hiding it, `25` WitchA mid-hold, `26` WitchB behind, `27` the art in the frame.
- ⭐⭐ **2026-09-24 (c): THE FIRST PLAYTEST OF THE PORCH PASS — THE FOREST IS REQUIRED NOW**
  (441 s, 0 deaths, four J-captures; the grill answers are in `backlogs/02-house-porch.md` §2
  rows 9–12. Row 9 **reverses** the porch pass's "optional dread", on the user's call).
  - **The scrawl fires on a real LOOK at the guillotine** (capture #1: *"should appear after you
    first look at the gilatin, not … immediately after you enter the back yard"*).
    `_looking_at_guillotine()`, on the deck only:
    - the guillotine's centre (`GUILLOTINE_LOOK_Y` 1 m up) is within `GUILLOTINE_LOOK_RANGE` 5 m;
    - the camera's **3-D** forward has a dot of at least `GUILLOTINE_LOOK_DOT` 0.9 to it;
    - a layer-1 ray from the camera reaches it (the player is excluded, and the guillotine's own
      body counts as seeing it);
    - all three hold for `GUILLOTINE_LOOK_HOLD` 0.3 s.

    The old `PORCH_VISIT_DWELL` 2 s fallback is deleted. The old test was a flat dot ≥ 0.6 with
    no range and no line of sight. Stepping west out of the window gives 0.69 (measured 0.70 in
    3-D), so it fired on the first deck frame, 0.25 s after the burst. Measured now: 3 s on the
    deck facing west fires nothing, and turning to the frame fires it **0.32 s** later, once.
    **Arming the painting is decoupled from the scrawl.** The first frame on the deck
    (`HouseOutdoors.on_deck`) arms it, before any look and whether or not one ever comes, so a
    player who never looks squarely at the frame is never stranded without the fruit.
  - **The guaranteed tree-line ghost is actually seen now.** It still runs `PORCH_GHOST_DELAY`
    4 s after the scrawl, but `_looking_at_yard()` now needs the camera facing west
    (fwd.x < `YARD_LOOK_X` −0.7; it was −0.35, which a camera on the guillotine passes). The run
    is a fixed lane (`TREE_LINE_GHOST_X` −19.5, z 12 ↔ 0, either direction) straight across
    what the porch's open west side shows. The old lane was projected from the camera's
    heading. With the camera on the guillotine it ran about z 15 → 25, off to the north, and
    was almost certainly never seen (Issue 276). Measured by a probe from the deck with the
    camera on the frame: **3 of 21** lane points visible, the rest blocked by the guillotine
    itself, the porch's north screen and the 2.4 m fence. (Looking west, the old code's lane had
    been fine, 16–19 of 21.)
    Measured from the deck: 120 frames of the run sampled, **100 % on screen and 100 % seen** (at
    least one of three rays across the figure's 0.9 m width arrives), **0 frames hidden by the
    porch or the fence**. A centre-only ray gives 85 %; the misses are the thin porch posts and a
    trunk crossing the figure's middle. `PORCH_GHOST_WAIT_MAX`'s fallback (run
    anyway 6 s later, heard) is unchanged.
  - **No basket** (capture #2: *"remove the box, and make the bolt cutters appear just on the
    floor"*). The `Basket` node, its collider and the wicker material are gone.
    - The compact `BoltCutters` (0.55) land on the deck boards at the frame's local
      (0.14, 0.004, 0.64), and one melon half at (−0.16, 0.17, 0.62). Both are clear of the
      runners and the front cross beam, which end at z 0.25.
    - The other half still lands on the bench.
    - The cutters are taken with E through the shipping ray, from where you stand in front.
  - **THE FOREST IS REQUIRED: THE BLADE IS OUT THERE** (capture #3: *"currently it makes no sense
    to walk there … you need to search for something there"*).
    - **The frame starts bladeless.** The blade assembly (the weight and the edge) is hidden,
      and the rope has run out to the boards with its toggle lying on them.
    - **The stump.** The blade is driven into a tree stump, `HouseBladeStump`
      (`house_blade_stump.gd`), at `HouseOutdoors.BLADE_CLEARING`. ~~(−32, 0, 15). That is d = 20 m,
      the depth where the clock peaks, and 9 m north of the straight line west from the rail gap.~~
      ⭐ Since 2026-09-24 (d) it is at **(−37.5, 0, 21)**, d 25.5, the far north-west corner,
      behind one thick trunk (top of SPEC).
      - **The clearing.** `house_outdoors.gd`'s seeded placement rejects any trunk within
        `BLADE_CLEAR_R` 3.5 m of it. This shifted the rest of the layout from the first trunk
        that used to fall there: 85 → **81** walkable trunks, the nearest now 3.72 m from the
        stump.
      - **Built from parts:** a flared bark cylinder (`forest_bark.png`), a paler cut-top disc,
        a dark split, and four tapered roots running into the litter. There is a solid layer-1
        cylinder to walk round.
      - **Its interact volume** is a layer-2 / mask-0 box that encloses the stump and the blade,
        so pointing anywhere at the stump gives the prompt. (`player.gd` does not walk up from
        what its ray hits.)
      - **The blade in it** is `HouseGuillotine.build_blade()`, the very assembly the frame is
        missing. It leans **8°** (was 24°), is yawed 35° across the cut, and its low corner is 0.12 m in
        the wood.
        It is moonlit (render layers 1 + 2) and has **no emission**. ⭐ Since 2026-09-24 (d) it is
        the generated `guillotine_blade.png` on quads over thin edge boxes, not two plain boxes
        (top of SPEC).
    - **Fixed spot, no hint** (the user's call): no path, no sound beacon, no glint. The player
      explores.
    - **Pulling it.** E on the stump (`E — Pull the blade free.`) plays the `blade_pull` stand-in
      AT the stump and pops a toast. The stump empties and its interact volume is disabled.
      `_blade_state` becomes `"held"`, and the carried line gains **"guillotine blade"**.
      Carrying costs nothing; the clock is the only price.
    - **Mounting it and using the frame.** The guillotine takes the fruit and the blade **in
      either order**. With both in hand, E mounts the blade first (one press, one thing).
      - **The prompts:**
        - `E — Mount the blade.` while the blade is carried. The blade appears raised, and the
          rope and toggle are hauled up to the cleat over 0.45 s with `guillotine_rope`.
        - `E — Set the watermelon in the lunette.` while the fruit is carried.
        - `E — There is no blade.` otherwise, while the frame is bladeless: on an empty lunette,
          AND on a loaded one, where **the pull is refused** and nothing drops.
        - `E — The lunette is empty.` once the blade is on. This still thinks the old
          **SHALL I PUT SOMETHING THERE?**
        - `E — Pull the rope.` when both are in.
      - **WHERE IS THE BLADE?** The frame's bladeless E is a red scrawl, throttled on the same
        `PORCH_SCRAWL_REPEAT` 4 s cooldown as the lunette's thought, so two never stack.
    - **Saving:** a new key, `blade_state` (`stump` | `held` | `mounted`), restored silently by
      `_restore_porch()`:
      - the stump is emptied without a sound;
      - a held blade is carried;
      - a mounted blade hangs in the frame (down, if the fruit was cut).

      A cut fruit forces `mounted` whatever the snapshot says.
    - **The clock's constants did not move.** ⭐ The numbers below are for the old (−32, 15)
      clearing; the corner's are under DECISIONS & GOTCHAS (2026-09-24 d). Measured with the real
      `AutoPlayer` walking the real capsule round the seeded trunks on a 20.3 m route (rail gap → a spot 1.2–1.7 m from
      the stump), pausing 0.6 s at the stump and walking back to the deck:
      - from calm, peak **10.6 / 50**;
      - straight after the window scare (25), peak **34.6 / 50**;
      - 11.0 s of walking, deepest d = 18.4 m.

      The plan's 14 / 39 was straight-line arithmetic. **This is a player who knows where it
      is.** The search is the real cost, and it is the playtest question (below).
  - **The cellar gap is 1 s shorter** (capture #4). `CHILD_APPEAR_DELAY` is now **4.5** (it was
    5.5) and `CELLAR_WHERE_HOLD` is now **1.2** (it was 2.0), the user's figures. WHERE AM I? is up at 0.7 s and gone by
    **3.9 s** (0.7 + 0.6 in + 1.2 + 1.4 out), a **0.6 s** margin before the doll. The blackout is
    now **7.5 s** (4.5 + `CHILD_HOLD` 3.0).
  - A stale comment calling the fridge *"optional, off the quest path"* is corrected (`level_2.gd`,
    above the fridge's panic constant): the second digit has been on its head since 2026-09-13.
  - **What proves it:** `check_house_porch.gd`, **121 checks** (was 82):
    - 3 s on the deck not looking at the frame does not fire the scrawl, but does arm the
      painting; a look fires it within 0.6 s;
    - no ghost while the camera is on the guillotine; the ghost's run is projected on screen
      and ray-checked for occlusion;
    - the blade is in the stump and the frame is bladeless (by a physics ray on the stump);
    - E on the bladeless frame gives WHERE IS THE BLADE?, and a loaded bladeless pull is
      refused with no halves and no cutters;
    - **the real walk** to the stump and back, from 25 and from 0, with the pull through the
      shipping ray; the `blade_pull` player is heard at the stump; the stump's volume is gone
      by ray;
    - the blade mounted through the ray;
    - the cutters on the deck (a ray down meets them and the boards 4 mm under them); a ray where
      the basket stood meets the deck;
    - the cutters taken through the ray;
    - `blade_state` round trips for `stump`, `held` and `mounted`, plus a blade-first snapshot
      that goes E on the empty lunette → fruit → pull → CUT (either order).

    Proved able to fail: four mutation runs (DECISIONS & GOTCHAS).

    Renders: `screenshot_house_porch.gd` poses `05a_bladeless_from_window`, `20`–`24` (the
    stump by torch from ~4 m, by moon alone, from the straight line, close, and pulled), and
    `17_cutters_on_deck`.
- ⭐⭐ **2026-09-24 (b): THE FIRST NOTE MOVES TO THE BEDROOM; THE USER'S SOUNDS GO IN.**
  - **The first safe note (digit 4) moves from the Living Room to the Bedroom's north wall**
    (the user: the Living Room now holds the way to the forest, and the Bedroom, with its bed and
    the child's drawing, was left with nothing once the cutters left). It is renamed
    `SafeNote_Living` → `SafeNote_First`. Each room now has a job: the Living Room has the
    window and the forest, the Bedroom has digit 4.
  - **The user's recordings replace the stand-ins, outright.** The code loads only the user's
    file; the stand-ins it replaced, and the unused `witch_hum`, are **untracked and gitignored**
    (the user: *"we do not want to commit files that are not being used"*), and
    `make_sfx_house_porch.py` now writes only the three stand-ins still played
    (`porch_wind_gust`, `guillotine_rope`, `forest_run_leaves`):
    | beat | user file | replaces |
    |---|---|---|
    | the night outside | `dark_forest_soundtrack` (50 s stereo) | `porch_forest_night` |
    | the pane bursts | `window_glass_break` (the user's `glass_break.wav`, renamed because `shared/glass_break` shadows the same base name) | `window_burst` |
    | the blade drops | `guillotine` | `guillotine_drop` |
    | the melon bursts | `watermelon_crack` | `melon_burst` |
    | every ghost run-by | `ghost_sound`, pitched per kind | the three synthetic screams |
    | ~~the witch's second glimpse~~ ⭐ since 2026-09-24 (d) the two house SIGHTINGS (glimpse 2 is deleted) | `witch_scream` | — (**new**) |

    The soundtrack becomes **one non-positional** player instead of two positional beds: two
    unsynchronised copies of a musical track would clash. It keeps the same outside / through
    the broken window / through the glass gain offsets. ~~The witch screams from **behind you in the
    Hallway** the moment glimpse 2 is placed, so the sound is what turns you round to see her.~~
    ⭐ Superseded 2026-09-24 (d): she was heard and never seen there (12.9 m behind, beyond the
    torch). Glimpse 2 is deleted; the scream leads the two sightings, which turn the camera onto
    her (top of SPEC). Still zero panic.
  - The user's `dark_forest_soundtrack.wav` (14.5 MB, 24-bit/48 kHz) ships as a q6 `.ogg`
    (2.4 MB); the original is kept at `assets_src/audio/level_2_house/`. Its gain is
    `FOREST_TRACK_DB` −8. `watermelon_crack` is quiet (mean −31.6 dBFS), so it plays at +8 dB;
    `witch_scream` is hot (mean −5.6), so `WITCH_SCREAM_DB` is 0.
  - **What proves it:** `check_house_porch.gd` §0 (82 checks now): every one of the six base
    names resolves to the user's file; `ForestNight` is one `AudioStreamPlayer` on the user's
    track; `SafeNote_First` is in the Bedroom on its north wall and nothing is named
    `SafeNote_Living`; ~~glimpse 2 leaves a `WitchScream` player within 2 m of her~~ (glimpse 2 is
    deleted since 2026-09-24 d; `check_house_witch.gd` asserts the scream at the sightings). The render
    `07_bedroom` (`screenshot_level.gd`) shows the page on the north wall.
- ⭐⭐ **2026-09-24: THE PORCH, THE FOREST, THE GUILLOTINE AND THE WITCH** (the user's design,
  Granny-referenced, grilled 2026-09-24 — `backlogs/02-house-porch.md`). **Replaced** the bolt
  cutters under the Bedroom bed (`_spawn_cutters`, `_tick_cutters`, `CUTTERS_PITCH_DEG`,
  `CUTTERS_DIST`: all deleted, nothing under the bed any more) and the north-wall painted-forest
  window (`forest.png` quad, glass, frame bars and `EM_FOREST`: deleted). **The chain for digit 2
  is:** the witch's note (Entry Hall) → the window scare → the window **bursts** → the **first
  porch visit** (red scrawl **SHALL I PUT SOMETHING THERE?**, plus one ghost pass along the tree
  line — ⭐ since 2026-09-24 (c) the scrawl waits for a real look at the guillotine, and the first
  step onto the deck is what arms the painting) → **this is what arms the falling painting** (it used to be armed by solving the map,
  `_apply_guest_stage(1)`, whose stage is now kept empty so `guest_stage` keeps its numbering; the
  fall trigger itself is unchanged: 4.5 m, facing, line of sight) → behind the fallen painting is
  **a ragged hole in the plaster with a watermelon in it** → carry it to the guillotine → place
  → pull → **bolt cutters** in the basket → the fridge chain → the head → digit 2. (⭐ Since
  2026-09-24 (c) the guillotine also needs **its blade, from a stump in the forest**, before the
  pull, and there is no basket: the cutters land on the deck — the entry at the top of SPEC.) Geometry lives
  in `house_outdoors.gd` / `house_window.gd`, the props in `house_guillotine.gd` /
  `house_watermelon.gd`, and every BEAT (clock, ghosts, witch, scrawl, save/restore) in
  `level_2.gd`, which logs each one to `DebugLog` (`PORCH …`, `FOREST …`, `WITCH …`).
  - **The tall window** (`HouseWindow`) is on the LivingRoom's **west** wall (x = −8.5, centred
    z = 6), a real outside wall. It is floor-length, **1.4 × 2.3 m**, because the controller
    cannot step over a sill. The opening is a RoomBuilder cut (`WALL_CUTS`, *not* `DOORS` —
    `check_doorways.gd` rays through every doorway and would find the pane) closed above 2.3 m by
    a `WindowLintel` CSG block exactly the gap's width. In the opening: a fixed casing (jambs,
    head) and a breakable sash (stiles, rails, low kick boards, a mullion, two transoms, two glass
    `QuadMesh` leaves facing the room) plus `Pane`, a real layer-1 collider. `_tick_forest` is
    unchanged in its numbers (≤ `FOREST_SCARE_DIST` 1.5 m of the glass's centre →
    `flash_scare(screamer_forest)` + jolt + `FOREST_SCARE_PANIC` 25). **0.6 s after the flash
    CLEARS** (`FOREST_SCARE_HOLD` 0.8 + `WINDOW_BREAK_DELAY` 0.6, a non-pausing-through timer) the
    pane **bursts inward**: the user's `window_glass_break` (fallback the shared
    `glass_break`; 2026-09-24 b), a `porch_wind_gust` loop at
    the opening, the collider is freed, and 18 shards + 7 splinters land on the living-room floor
    (visual only — no collider, so nothing to trip on). Any burst, including the silent restore
    one, sets `_forest_fired`: a spent window can never re-fire the face on the deck.
  - **The porch**: a deck at x −12…−8.6, z 3…9, **level with the house floor at y = 0** (the
    doorway bridge under the opening is 4 mm below it, the RoomBuilder convention). A roof on four
    posts at 2.75 m, **board screens closing the north and south ends** (the porch looks out one
    way only), a rail along the west edge with a **1.8 m gap** (z 5.1…6.9) facing the yard, and
    weatherboards over the house wall behind it. The guillotine stands at the north end
    (`GUILLOTINE_AT` (−10.35, 0, 7.75)), its front turned toward the window. ⚠️ **Zero forest
    panic on the deck**: the guillotine is worked standing there (Issue 18).
  - **The yard and forest** (~~**optional**: the quest never needs it~~ — ⭐ **REQUIRED since
    2026-09-24 (c)**: the guillotine's blade is in a stump in a trunk-free clearing, since
    2026-09-24 (d) at (−37.5, 0, 21) behind one thick trunk, top of SPEC): walkable x −40…−12,
    z −12…24 (28 × 36 m) on a `forest_floor.png` ground flush with the deck; 85 trunks (81 since the
    clearing, 2026-09-24 c; still 81 with it in the corner, d, the nearest seeded one 4.25 m from the
    stump, plus the one thick `HidingTrunk`) with
    colliders (seeded, `TREE_SEED` 2409; never inside `CLEAR_SPOTS` — the witch's and the
    ghosts' lanes — or the arrival apron in front of the rail gap), each with a `forest_pine.png`
    canopy billboard; a dense ring of trunks at the edge, invisible walls just outside it, and a
    2.4 m fence along x = −12 either side of the porch (over eye height, so the void behind it is
    never seen). Pine silhouettes stand on the ground out to x −66 / z −36…48. A radius-100
    unshaded inward **sky dome** (`night_sky.png`, yawed 122° so its painted moon is in the west)
    is seen outdoors and through the window. **Moonlight** is a `DirectionalLight3D`, energy 0.32,
    cold, shadow-casting — and its `light_cull_mask` is **render layer 2 only**: everything
    outdoors is put on layer 2 as well as 1 (`HouseOutdoors.moonlit()`), nothing RoomBuilder builds
    ever is, so **no interior surface can receive moonlight by construction**. Measured below.
  - **The forest clock** (`_tick_forest_clock`, a level-driven `add_panic(rate · delta)`, the
    idiom of KONTUR's phone; ⚠️ **a new panic term, explicitly approved by the user, grill Q4**):
    d = metres past the porch rail (`HouseOutdoors.forest_depth`). **0 on the deck and indoors.**
    Off the deck the rate is `FOREST_RATE_EDGE` **3.5 /s** = `PANIC_DECAY_RATE`, so at the tree
    line the bar **holds**, rising linearly to `FOREST_RATE_DEEP` **5.5 /s** at `FOREST_DEEP`
    **20 m** — **net +2 /s ⇒ 25 s from calm to death** (all three marked `⚠️ DELIBERATE — the
    user's call 2026-09-24`). Sprinting stacks on top, deliberately. It is suspended while the
    tree is paused, a note is open or input is frozen. `player.gd` is untouched.
  - **Ghost run-bys** (`DoorLunger`, the Corridor's run-away billboard): an RGBA cutout with its
    scream attached (and `forest_run_leaves`), appearing 8–14 m ahead within ±25°, running ACROSS
    the view between the trunks, fading over its last 2 m and freeing itself; its sound is
    reparented to finish where it was. **Three kinds**: the barefoot woman (1.75 m, 5.5 m/s), the
    thing on all fours (0.95 m, 7 m/s) and the tall forest creature from the window scare, far off
    (3.1 m, 14–19 m out, 3 m/s, `set_glow` 0.6 because its 38/255 cutout read as nothing among the
    trunks). The cutouts all run right; one crossing to the left is mirrored by a negative U scale.
    **Zero panic, no collider, no rules.** Cadence 6–10 s random while d > 2 m, plus **one
    guaranteed pass** along the tree line (x = −19.5) `PORCH_GHOST_DELAY` 4 s after the
    first-visit scrawl, once the player looks out at the yard (or 6 s later regardless, heard).
    ⭐ Since 2026-09-24 (c): "looking at the yard" is fwd.x < −0.7 and the lane is fixed at
    z 12 ↔ 0 (top of SPEC; the old projected lane ran behind the fence).
  - **The first porch visit** (`_tick_porch`): ~~on the deck and either facing the guillotine or
    `PORCH_VISIT_DWELL` 2 s there. It scrawls once, arms the painting and queues the ghost.~~
    ⭐ **Since 2026-09-24 (c):** the first frame on the deck arms the painting; the scrawl (once)
    and the queued ghost wait for a real look at the guillotine (range 5 m, 3-D dot ≥ 0.9, line
    of sight, held 0.3 s). The dwell fallback is deleted.
  - **The painting → the hole → the watermelon**: the hole is a second `WALL_CUTS` entry in the
    ChildRoom's exterior north wall at `PAINTING_X`, 0.62 × 0.62 m (y 1.19…1.81, inside the
    0.8 × 1.0 panel), filled below and above by wall-material blocks and backed by a small dark
    housing outside the wall **0.28 m deep** (`NICHE_BACK_Z` 19.18). Over it, hidden until the fall,
    a `plaster_hole_ring.png` decal: the art agent's `plaster_hole.png` with its painted-black
    middle flood-filled transparent (it would have hidden the fruit), so the real recess shows
    through a ragged edge that covers the cut's square corners. `HouseWatermelon` sits in it and
    is **completely inert until the painting is down** (`reveal()`). E → carried.
  - **The guillotine** (`house_guillotine.gd`, built from parts: runners, uprights, rear braces, a
    crossbar, a two-board lunette with its neck gap, an iron weight over an oblique steel blade
    riding IN FRONT of the lunette — ⭐ since 2026-09-24 (d) the generated `guillotine_blade.png` on
    quads, top of SPEC — a bascule bench, and a rope over a pulley to a toggle;
    ~~and a wicker basket~~ — ⭐ no basket since 2026-09-24 (c), and **the blade is not on it
    until you bring it from the forest**, top of SPEC). EMPTY → LOADED → CUT → DONE, with a
    `prompt_text()` per state. With the fruit, E sets it in the lunette (where it reads as a head);
    with the blade mounted, a second E pulls the rope (`guillotine_rope`), the
    blade drops (the user's `guillotine`; 0.16 s), the fruit bursts
    (the user's `watermelon_crack`) into two halves, flesh
    up — one on the deck boards in front, one on the bench — and a compact `BoltCutters`
    (`size_scale` 0.55, 0.31 m) lies on the deck for a third E. E on the empty lunette (blade on,
    no fruit) repeats the red thought, throttled to `PORCH_SCRAWL_REPEAT` 4 s. **No fail state: it
    can never hurt you.**
  - **The witch**: a note on a small side table in the Entry Hall, 1.6 m ahead-right of the spawn.
    It is journal-archived and is **neither a safe note nor a trap** (named `WitchNote`, never
    connected to `_on_safe_note_read`; `SAFE_NOTES_TOTAL` stays 3). Text: *"An old woman lives in
    this house. She follows you everywhere, even when you think you are alone. Do not look for her.
    She likes to hide things inside fruit."* ~~**Three**~~ **Two one-shot, zero-panic `Watcher`
    glimpses** outdoors (`house_witch.png`, 1.65 m), silent — and, ⭐ since 2026-09-24 (d), the two
    house **sightings** A and B (top of SPEC):
    1. note read, window not yet broken, in the Living Room facing the glass: she stands in the
       yard on the view line through it (x −17.5…−21). ⚠️ The **one** `require_los = false` call
       in this level, with `watcher.gd`'s required argument: its own LOS ray would stop on the
       pane (which has to be a layer-1 collider to stop the player), so `_clear_through_glass()`
       runs the same ray excluding only the pane — it still catches "inside a wall or trunk". Her
       look-away rule is the level's (`_tick_witch_glass`, 0.5 s unseen after being seen), because
       `Watcher._is_seen()` cannot see through the pane either. The forest scare's face replaces
       her;
    2. ~~fruit taken: at the far end of the Hallway (z 4.2…6.6), **behind** the player (dot < 0.2),
       retried for `WITCH_2_PATIENCE` 20 s and then dropped with a log line (also dropped if the
       fruit reaches the lunette first);~~ **DELETED 2026-09-24 (d)**: heard, never seen;
    3. fruit cut: on the tree line, off-centre in view first.
    A glimpse that cannot be placed yet stays **pending**, never latched. **She follows**: a later
    glimpse that is due removes the previous figure if nobody is looking at it. ⚠️ **She never
    moves toward you, chases or kills.** SCARY §8.4: the Breach stays the only chase level.
  - **The carried HUD** is `_refresh_carried()`, which rewrites the whole line from state and
    joins every held item: `cellar key · watermelon · guillotine blade · bolt cutters` (the blade
    since 2026-09-24 c; the cutters only while the fridge they exist for is still chained). This
    fixed a latent overwrite (below).
  - ~~**`SafeNote_Living` moved to the living room's NORTH wall centre**~~ — superseded the same
    day by 2026-09-24 (b): it is `SafeNote_First` on the **Bedroom's** north wall. (It had left
    the living room's west wall because the window took that spot: read there, your face would
    be inside `FOREST_SCARE_DIST`.)
  - **Save/restore** gains `window_broken`, `porch_visited`, `painting_armed` / `painting_fallen`
    (**no longer derived from `guest_stage`** — `_force_guest_stages` does not touch the painting),
    `melon_state` (wall | held | placed | cut), `blade_state` (stump | held | mounted — 2026-09-24
    c) and `witch_note` / `witch_glimpses`; `cutters_held` now means "taken off the deck" (it said
    "from the basket" until the basket went). Everything is restored by
    `_restore_porch()` on a back-door return and nothing is replayed (a broken window stays broken
    silently, the guillotine is forced to its state, no scrawl, no witch).
  - **What proves it:** `check_house_porch.gd` (72 checks then, ~150 s; **121** since 2026-09-24 c) — the note through the ray and
    not counted as safe; glimpse 1 beyond the glass; a capsule query and a real walk stopped by the
    pane; the scare, the burst 0.6 s after the flash clears, a ray through where the pane was, and
    a real `AutoPlayer` walk out onto the deck; the scrawl once; the guaranteed ghost; E on the
    empty lunette; the clock measured (below); ghost cadence and zero panic; the painting → hole →
    fruit through the ray; ~~glimpse 2 behind you~~ (no witch after the fruit since 2026-09-24 d); EMPTY → LOADED → CUT → cutters through the ray;
    glimpse 3; every new key; three snapshots (held / placed / done) reloaded through
    `_restore_progress()`; the fridge chain cut with the restored cutters. Also updated:
    `check_house_fridge_chain`, `check_house_guest`, `autoplay_house_route`, `check_window`
    (rewritten for the west window), `check_reachable` (two gates), `check_prop_mounting` (House
    floor 9 → 5), the House screenshot poses, and a new `screenshot_house_porch.gd` that
    photographs every state and measures the interior darkness.
- ⭐ **2026-09-16 (H4, `BACKLOG_Sep_16c.md`):** the cellar child fires when the **cellar NOTE is
  closed** (`_arm_child_on_note_close`, a one-shot on `NoteUI.closed`), pinning the player at the
  note; the ramp's foot keeps only the scrawl. Its scream is **`screamer_house`** (baba yaga, the
  user's call) at 0 dB / `max_db` 6. **H5:** a red **WHERE AM I?** scrawl at `CELLAR_WHERE_AT` 0.7 s,
  held ~~2 s, faded by 4.7 s — timed to be GONE before the doll at 5.5 s~~ — ⭐ since 2026-09-24
  (c) held 1.2 s, gone by 3.9 s, before the doll at 4.5 s (top of SPEC).
- ⭐ **2026-09-16 (H2/H3):** the cellar's scripted HOLD apparition is **deleted** (it spent the
  doll 5 s early); the director's random one stays upstairs. The cellar blackout **pins the
  player** (`_begin_cellar_blackout` freezes; `_can_show_child` ignores that pin) until the child
  has appeared. "Collect the key." uses the lower caption slot.
- ⭐ **2026-09-15 (H1, Issue 214):** the cellar apparition **retries on an abort** — latches only
  when `ApparitionDirector.arm()` returns true, else respawns and re-polls every 0.25 s for 20 s
  (`_tick_apparition_retry`, refused while paused / a note is open).
- ⭐⭐ **2026-09-13 (H1b):** the map's glass is a **ROOM**: `_place_glass()` glazes every open edge of
  the key's cell (`_pane_rects`, solid to the icon and the monsters until `_break_glass()`); the mark
  is `house_map_key_icon.png` and the hammer icon was redrawn upright (`tools/make_map_icons.py`).
  `_is_won()` = fragments empty AND `_glass_broken` AND on the key; the hammer meets a pane through
  `_check_fragments()` → `_check_glass()`, so the bot harnesses hit it. 28/40 unchanged (asserted then without a quoted re-run; re-measured 2026-09-24 e: 27/40, and 233/400 on the wider probe).
- ⭐⭐ **2026-09-13 (`BACKLOG_Sep_13.md` H1–H4):** the map game's stages are a **hammer** and a
  **glass case with the key in it** (`tools/make_map_icons.py`; the seal is a glass pane, a
  `glass_shatter` + cracked case for `WIN_HOLD` 0.4 s on the win; no mechanic moved). The
  **second digit is on the forehead of the head in the fridge** (`house_fridge_thing_digit.png`,
  read by gaze → `SafeNote_Head`), the fridge wears a **chain + padlock** (`chained`,
  `chain_tried` → the level cuts it if the **bolt cutters** are held), and ~~the cutters lie
  half under the Bedroom bed, `visible` only with the torch aimed ≤ −30° from within 3.2 m
  (`bolt_cutters.gd`, `_tick_cutters`)~~ — ⚠️ **superseded 2026-09-24**: the cutters come out of
  the watermelon the porch guillotine cuts, onto the deck boards (the basket went 2026-09-24 c; the
  entries at the top of SPEC); `_tick_cutters` is deleted. `SafeNote_Bedroom` is gone; `SAFE_NOTES_TOTAL` stays 3.
  The cellar child's scream is re-mastered to −3 dBFS and lands 0.3 s into the dip. The
  correct code makes the lock FALL (`lock_drop.wav`) and the door asks **ARE YOU SURE YOU WANT
  TO GO IN THERE?** Guards: `check_house_fridge_chain`, `check_house_lock`, `check_maze_traps`.
- ⭐⭐ **AND DARKER STILL SINCE 2026-09-07** — the same change as the Lab, for the same reason:
  `set_torch_profile(11.0, 24.0)` and `DARK_AMBIENT` 0.02 → **0.0**, with every self-lit prop
  halved (the forest window 0.90 → 0.40 — that painted window is deleted since 2026-09-24, the TV static panel 0.70 → 0.30, notes 0.60 → 0.25, the
  cellar key's card 0.50 → 0.30, the two `LivingMirror` figures 0.50 → 0.25, the doors 0.08 →
  0.03). ⚠️ **And the cellar key's own `OmniLight3D` is OFF.** It was created as a child of the key
  and never appended to `_lights`, so `_drive_lights()` — the one function that holds this level's
  ten lamps at zero — had no idea it existed: from the moment the map minigame was won until the
  key was picked up it burned at 0.35 energy over a 2.5 m radius, i.e. it was the only real light
  source in the building. Kept at zero rather than deleted, so the decision has a record.
- ⭐ **PITCH BLACK UNTIL EVERY NOTE IS FOUND, AND THEN ONE LAMP (2026-09-03, the user's call).**
  `DARK_AMBIENT` 0.02, every lamp held at zero by `_drive_lights()`; reading all three SAFE notes
  fades up `Lamp_Lock` — the wall lamp beside the combination lock at the far end of the
  ChildRoom, which has existed at energy 0.4 since long before this — over `LAMP_ON_FADE` 2.2 s,
  with a new positional `lamp_wake` sting AT the lamp. ⚠️ **Only that one.** The Lab already owns
  the everything-at-once relief; this beat is a single warm point at the end of a black house that
  you then have to walk to, and a second lamp spends it.
- ⚠️ **THERE WAS NO NOTE COUNTER BEFORE THIS.** `_spawn_notes()` discarded two of the three safe
  notes' return values and only the cellar one's `read` signal was wired; `GameState.journal` is a
  whole-game de-duplicated array, not a per-level count. ⚠️ It counts by NODE NAME, not `+= 1` —
  `note.gd` emits `read` on every OPEN, so a player re-reading the living-room note three times
  would otherwise light the house without ever going down to the cellar for the third digit.
  ⚠️ `save_progress()` carries `safe_notes` AND `lock_lamp` together; restoring one without the
  other either lights a house whose code the player has not learned or re-darkens a solved one.
- ⚠️ **The cellar's `DarkZone` is GONE and the bedroom event's with it** (D4). The cellar one was
  the urgent case: it overlapped the `DreadZone` exactly, and `player.gd` adds dark tax ON TOP of
  dread pressure while the dark branch also suppresses decay — **+5/s with no way down**, in the
  one room that takes the torch away on purpose (8.5 s then, 7.5 s since 2026-09-24 c) and has a
  beartrap on the entry line.
  **The `DreadZone` stays**; it is the cellar's real pressure signature and does not depend on the
  torch.
- Built at runtime in `level_2.gd` via `RoomBuilder` from an 8-room ground floor (entry hall, hallway, living room, kitchen, landing, bedroom, bathroom, child's room) **plus a gently-lowered CELLAR** (`_build_cellar()`, floor at y=−1.5) reached by a walkable ramp. Same `.tscn`-minimal / `PRESERVE`-whitelist pattern as the Lab
- ⚠️ **THE CELLAR DOOR'S PLANKS AND PADLOCK WERE 1.5 m TOO HIGH** (fixed 2026-09-07, Issue 170,
  from *"Test whether the door in the basement at the house level works fine"*). The mechanism was
  perfect and six tests measured it green; the PICTURE was two thirds absent, because
  `cellar_gate.gd` positioned its children at `HEIGHT * 0.5 + offset` on a `BoxMesh` already centred
  on a body at y = 1.5. Two of three planks and ~75 % of the lock sat above the leaf inside
  `CellarShaftCap`, so the prop that exists *"so it reads as sealed rather than as a wall the
  builder forgot to cut a doorway in"* read as a blank slab, in a house at ambient 0.02.
  ⚠️ **`check_cellar_key.gd` had never re-checked the doorway AFTER a successful key-open** — the
  one direction a player cares about — and called `interact()` directly rather than through the
  raycast. It now walks there, presses E through the shipping ray, waits past the 0.9 s tween,
  asserts the doorway is clear, and walks down and back out.
- **Cellar key sub-quest**: a glowing `KeyItem` (`key_item.gd`) → `picked_up` → the player is now
  *carrying* the key (`GameState.set_carried`, shown on the HUD); the `CellarGate` (`cellar_gate.gd`)
  only opens when they walk down and press **E** on it. ⚠️ `picked_up` used to be wired straight to
  `_open_cellar_gate()`, so winning the Bathroom minigame flung the cellar open from the other end of
  the house and the key was a formality (BACKLOG #16). ⚠️ The ramp/shaft/ceiling use `rotation.x = -angle` (a +angle inverts the slope and drops the ceiling to knee height); the key sits clear of its (collision-less) stand so the interaction ray reaches it. **Session 11 fix (two parts):** (1) the ramp's TOP SURFACE is now continuous with the floors at both ends — it starts at z=1.7 where `RoomBuilder`'s doorway floor-bridge ends (both at y=0) and the bottom is extended 0.6 m under the cellar floor — so there's no end-lip to climb (`move_and_slide` can't step up; a tilted box poking ~0.14 m above the floor was the real "can't enter the cellar" block, *not* headroom). (2) The sloped ceiling is offset a constant 2.6 m along the ramp normal (~2.45 m vertical clearance) and a flat `CellarShaftCap` at y=3 seals the top; the ramp wears `house_wood_stairs.png`. Verified walkable BOTH ways by `tests/walk_cellar.gd`. **BUG_FIX.md 4.3** first moved the key into a 2-drawer search in the Landing; a later session **replaced that entirely** with a bigger quest, so Landing is empty again (a deliberate trade). **Current feature**: a folded paper map (`HouseMap`, `house_map_prop.gd`) on a stand in the **Bathroom** (`_spawn_bathroom_map()` — it moved Landing → Kitchen counter → Bathroom; the objective string has now been wrong THREE times, so re-check it whenever the quest moves — the four lines live together as `OBJ_*` consts at the top of `level_2.gd` now, because the fresh-level path and `_restore_progress()` had drifted apart twice. ⚠️ It is `The cellar is locked. Find the key.`: it used to read *"Find the folded map — it hides the cellar key"*, and the objective HUD was the ONLY thing anywhere in the level that named either the map or the key, so the one puzzle was solved on screen before the player entered a room (playtest 2026-08-16). ⚠️ **Replaced, not deleted** — the map is the only route to the key and nothing else in the game names it, so an empty objective would strand a player who never walks into the Bathroom) opens a full-screen, paused 2D maze-chase minigame (`MazeChaseUI`, `maze_chase_ui.gd`) — a fresh **16×9** **braided** randomized-DFS maze for every genuine **attempt**, i.e. on a win or a catch. ⭐ **Since 2026-09-24 (e): one of TWELVE CURATED layouts of that generator, never the same twice in a row** (top of SPEC).
  - ⚠️⚠️ **THE OBJECTIVE IS TWO-STAGE SINCE 2026-08-16 (a user-requested redesign, approved after a brainstorm): COLLECT the torn fragment(s) of the map, THEN escape to the mark.** Shipped at **`fragment_count = 1`** — see the frontier below, and `backlogs/02-house.md` §9 P6 for all of it. The mark is genuinely **inert** — and visibly sealed, `TargetSeal` — until the last fragment is in hand; `_is_won()` is the single win predicate and it checks both halves. Fragments carry **no panic and no fail state**; a catch ends the attempt exactly as before (`CATCH_PANIC` 18, clamped below the bar since 2026-09-24 e, ejected to 3D, retryable, a different curated layout since (e)) and **fragments already collected are lost with it — there is deliberately no partial-progress carry-over**, and they also **re-arm on a close-and-reopen** exactly as the snares do, so ESC cannot become a checkpoint.
    - **Why, and it is not "a longer maze is a harder maze".** The user asked for a maze "more packed with actions"; the measurement (`backlogs/02-house.md` §7 P4, 200 seeds) said **the median winning run was 9.8 s**, p90 14.4 s. There is no room in ten seconds for a hunter, a patroller and five snares to *matter* — most runs ended before the patroller was ever met. The fragments buy **time on the board**, which is what turns the roster that already exists into decisions.
    - **Measured outcome (history — the raw generator; the player is dealt the curated twelve since 2026-09-24 e): 232/400 = 58 % win rate, median run 21.7 s** (p10/p90 18.2/27.4 s; `check_maze_chase.gd` reports 28/40 and prints the duration every run). For scale: the build before this pass was 59 % at 9.8 s, and the one-stage control on this board is 80 % at 16.9 s.
    - ⚠️⚠️ **THE ONE FINDING TO KEEP IF EVERYTHING ELSE HERE IS REWRITTEN: length bought from the ROUTE is free, length bought from WAYPOINTS is not.** Measured, 200–400 seeds per point — 10×8: N=0 82 % at 10.9 s · N=1 57 % at 14.1 s · N=2 21 % at 17.0 s · N=3 14 % at 17.5 s, the hunter's kill rate going **3.5 % → 70 %** for a run only 60 % longer. Against that, simply making the board bigger left the one-stage control at **80 % and 16.9 s**. **The head start is a one-off budget and every waypoint spends it**: `MONSTER_START_DELAY` buys ~600 px of lead once, after which the player nets 240 − 172 = 68 px/s *and only while running directly away*; a heading change hands it back to a pursuer that never tires or resets. A longer route is still monotone flight; a waypoint is not. This is why the shipped design takes its duration from **`GRID_COLS`/`GRID_ROWS` and its structure from ONE fragment.**
    - ⚠️ **The original 30–45 s target is NOT met and was retired by the user (2026-08-16), who accepted that the target was probably wrong.** 16×9 with N=2 reaches 28 s but at 20 %. Going further needs `MONSTER_SPEED`/`MONSTER_START_DELAY` or a counter-play that gives the lead back — both the user's call, neither taken.
    - **`fragment_count`** is the shipped N; **`TOUR_BAND`** is the validate-and-reject band the whole tour (start → every fragment → mark) is generated into, ≤ `FRAGMENT_PLACE_ATTEMPTS` tries and then the best candidate — never a `while`, because this runs inside a **paused** overlay where a hang is indistinguishable from a crash (Cogmind's map-validation loop; Spelunky guarantees its solution path after generation rather than hoping for one). ⚠️ **The band is the second lottery fix and a bigger one than the patroller's**: unbanded on the shipped 16×9 board the win rate ran **91 % at a 41-cell tour down to 27 % at 72+**. Banding to **50…64** cuts the tour's p10–p90 spread from 42–77 to 48–69 while moving the mean barely at all (56.3 % unbanded → 58.0 % banded) — **it is a variance instrument, not a difficulty one, and that is the point.** ⚠️ **The window is about four points wide in both directions** — 54…70 measured 51.8 % and 52…66 measured 54.0 % (both under `check_maze_chase.gd`'s asserted 0.55 floor), while 46…60 measured 63 % (over the user's 59 % ceiling). ⚠️ **The band is board-specific**: it read `34…45` on the old 10×8 grid and must be **re-measured, never rescaled**, if the grid moves again.
    - ⚠️⚠️ **THE TOUR IS MONOTONE OUTWARD, and that is the difference between the feature working and not.** Fragment k is drawn from a band around `k/(N+1)` of the way along the route, so every waypoint is further from the spawn than the last. The first build placed them anywhere off the line and ordered them nearest-neighbour: **10/200 escapes, median catch at 5.6 s** — nearest-neighbour makes the first waypoint the one *closest to the hunter*, so the head start is spent walking out and back. **Detours yes, backtracking no.** ⚠️ And a fragment may never sit in a **dead end** (`_braid()` opens only 55 % of them): worth a measured 4 points, and asserted by `check_maze_gen.gd`.
    - ⚠️ **`_route_cells` means the whole TOUR now, not the direct line.** While it still meant the direct line, **39 % of all deaths were the patroller** — fragments are chosen for being off the direct line and the patroller was banded for being off the direct line, so the two were pushed into the same space by construction. Pointing `_compute_route()` at the tour put it back to 20 %.
    - ⚠️ **"Off the route" is measured as DETOUR COST**, `d(start,c) + d(c,mark) − d(start,mark)`, not as raw distance from the route cells. The obvious alternative is unusable here and the reason is worth keeping: the direct route already has a **median length of 28 cells in an 80-cell grid**, so "3+ cells clear of the route" is routinely an EMPTY set — a constraint that is usually unsatisfiable degrades silently to "place them anywhere", which is the shape of Issue 34's stub.
    - ⚠️ **`_place_monster()` now guards the first step toward `_tour[0]`, not toward the mark** — the player's opening move is toward the nearest fragment, and the mark is inert for the first half-minute. Same rule, corrected destination; `check_maze_gen.gd` moved with it.
  - ⚠️ **The patroller no longer starts on your artery (2026-08-16)** — the single largest source of the reported randomness, and a one-line omission: `_place_patroller()` required only `PATROL_MIN_START` cells from the player's *start cell* and never consulted `_route_cells`, which `_generate_maze()` has already computed by the time it runs (`_pick_patrol_target()` has avoided route cells since the day it shipped; only the START did not). Measured over 200 seeds: **40 % of instances began it ON the route, and those seeds won 28 % against 83–100 % once it was 3+ steps off** — a 3× swing in survival decided by a placement nobody chose. It is now banded to `PATROL_MIN_ROUTE_GAP` by bounded sampling with an accept-the-best fallback, then a deterministic sweep (there may genuinely be no such cell); `check_maze_gen.gd` asserts the band against an independent BFS, failing only when a *better* candidate existed and was not taken — **200/200 seeds on the shipped board**. ⚠️ **The constant is 5 here and was 3 on the 10×8 board: the cliff moves with the grid.** Measured at 400 seeds, gap ≥ 3 with band 46…62 gives 58 % at 20.7 s with a **33-point** spread across patroller-distance buckets; gap ≥ 5 with band 50…64 gives **the same 58 %, one second longer, with a 12-point spread**. Raising the bar alone overshoots to 63 %, so the headroom it frees is spent on a longer tour band — **the two constants were chosen together and must be re-measured together.** ⚠️ `PATROL_SPEED` / `PATROL_AGGRO` / `PATROL_CALM` / `PATROL_MIN_START` were **not** touched.
  - ⚠️⚠️ **THE BOARD IS 16×9 SINCE 2026-08-16 (was 10×8), and this is where the run's LENGTH comes from.** The user's call, taken on the frontier above: a longer route is still monotone flight from the spawn, so it buys duration at no cost in win rate (one-stage control: 82 % at 10.9 s on 10×8, **80 % at 16.9 s on 16×9**), whereas buying the same duration from waypoints cost 82 % → 14 %. ⚠️ **The size is bounded by the SCREEN, not by taste**: at `CELL_SIZE` 96 the playfield is 1536×864, and `_root` is anchored at the viewport centre, so the overlay needs 478 px above it for the caption and 508 px below for the counter and pips against 540 either way at 1080p — **nine rows is the last row that fits.** Verified in the real overlay by `screenshot_maze_ui.gd`, never on paper; this file has already put a caption across the middle of the parchment once by trusting arithmetic. ⚠️ **`TOUR_BAND` and `PATROL_MIN_ROUTE_GAP` are board-specific and were re-measured, not rescaled** (34…45 → 50…64 and 3 → 5); `FRAGMENT_MIN_DETOUR` was re-swept and stays 6. ⚠️ **`SNARE_COUNT` 5 is a much thinner scatter in 144 cells than in 80, so it was isolated rather than assumed: 232/400 with five snares, 232/400 with none — identical to the seed.** Reported, not retuned. (Caveat: the harness bot walks the route and `_place_snares()` excludes route cells, so that number bounds the snares' effect on route-walking, not on greedy corner-cutting.)
  - ⚠️ **The 2026-08-16 redesign moved ZERO difficulty constants.** `MONSTER_SPEED` 172, the patroller's three, all four `SNARE_*`, `CATCH_PANIC`, `MAZE_DRIP_RATE`, `PROXIMITY_*`, the spring/speed panic degradation and the 55 % braid floor are all untouched — the list is repeated at `MONSTER_SPEED` in the script. The difficulty came from **structure**.
  - ⭐ **HISTORY since 2026-09-24 (e) — the current figures are the twelve curated layouts' (top of SPEC and DECISIONS: 160/240 = 66.7 %, median 20.4 s; the raw generator re-measured at 233/400 = 58.3 %, 21.6 s).** What this line said then: **CURRENT MEASURED DIFFICULTY — quote these and nothing else:** `check_maze_chase.gd` **28/40**; the wider probe **232/400 = 58 %**; median run **21.7 s**; asserted floor **0.55 (22/40)**. ⚠️ **The old 37/40 and 26/40 figures are DEAD.** They predate both the two-stage objective and the patroller band, and the harness that produced them could not see either. Read the isolation table in `backlogs/02-house.md` §9 P6 before quoting any of it — the patroller band is a difficulty *reduction* of 23 points and the fragment spends all of it, so the net is 59 % → 57 % with a 45 % longer run and two lotteries closed.
  - ⚠️ **The panic drip is charged per second, so a longer run costs LIFE as well as time** — checked rather than assumed. Over 400 winning runs on the shipped board: median **7.9** of `PANIC_MAX` 50, p90 10.6, worst 15.8, against the one-stage control's 3.5 / 5.7 / 9.8. Per second that is 0.36 vs 0.32 — **proportional to time, not compounding**, across a board that doubled in area. A *caught* run is still the more expensive outcome (≈3.9 of drip plus `CATCH_PANIC` 18), so the longer board did not change which failure hurts most. `MAZE_DRIP_RATE` did not need to move and did not.
  - ⚠️ **Closing the map no longer re-rolls it** (2026-08-16, the user's call). `ui_cancel` closes for free and `HouseMap.interact()` reopens; `open()` used to regenerate unconditionally, so ESC was a free re-roll and the optimal play was shopping for an easy layout — measured, 134 s with ONE catch versus 13 s for the same puzzle. A maze now lives until it is won or you are caught (`_instance_live`); reopening resumes it from the start cell with every snare re-armed. **Strictly harder, chosen knowing that.** Nothing is memorizable across attempts, only within one. (⭐ Since 2026-09-24 (e) the twelve curated layouts ARE learnable across attempts, on the user's call; ESC still resumes the same instance.)
  - ⚠️ **BRAIDED since 2026-08-15** — `_braid()` opens 55 % of dead ends into loops, because the user asked to "make more space so that you can actually bypass the monster" and in a PERFECT maze that is topologically impossible, not merely hard. `dungeon_gen.gd` already carried the same lesson.
  - **The roster:** a **patroller** (a second monster walking a circuit *off* the player's likely route, giving chase only within `PATROL_AGGRO`, slower than the hunter — measured, one wandering to random cells cost 9 seeds in 40 by standing in a corridor, which is a roadblock rather than a threat); **snares** (`SNARE_COUNT` 5, off-route, pinning the icon 1.2 s for 3 panic — never a second fail state; ⚠️ drawn at their TRUE `SNARE_RADIUS` in ice blue with a frost glyph since 2026-08-16, the disc having been `SNARE_RADIUS * 1.6` in diameter — radius 20.8 against a 26 px trigger, understating the hazard by 36 % of its area, in near-black brown on sepia parchment. Issue 74; the numbers themselves untouched); and a looping **chase track** (`chase.wav`, trimmed and crossfaded by `tools/make_loop.py`, on an `AudioStreamPlayer` child of the CanvasLayer so it survives the tree pause; Master bus, matching `combination_lock.gd`; stopped in `_close()` **and** `_hide_after_external_unpause()`).
  - ⚠️ **`MONSTER_SPEED` 172, raised 88 → 132 → 172** across two playtests on the user's call. The escape rate never moved at any of the three speeds; what changed is how fast a mistake is punished — hunted down 9.4 s after stopping at 132, **5.2 s at 172**. ⚠️ **Do not raise it again without re-running `check_maze_chase.gd`.**
  - ⚠️ **The hunter follows CORRIDORS, not a beeline.** It steers by a BFS distance field from the player's cell, recomputed when they change cell. It used to use a raw Euclidean beeline, which in a randomized-DFS *perfect* maze points into a wall most of the time — the corridor route is routinely 5–15× the straight line — so it jammed and could never close once the player left the start (BACKLOG #14: *"it can basically kill the player only at the beginning"*).
  - ⚠️ **`_place_monster()` avoids the FIRST STEP of the only route to its target.** In a spanning tree that cell is a roadblock the player cannot walk around — harmless while the monster drifted into walls, a measured 12-in-40 instant death once it followed corridors. Since the two-stage objective it guards the first step toward `_tour[0]` (a fragment), not toward the mark, which is inert for the first half-minute.
  - ⚠️⚠️ **ONE SPEED, WHATEVER THE PANIC (2026-09-10, capture #6: *"the ideal speed is constant"*).**
    The spring and the speed cap used to degrade with the 3D player's panic (`9→3`, `240→100`),
    and panic CARRIES ACROSS attempts — so a retry after a catch ran ~35 % slower than the first
    try, which the player read as the map "slowing down". Both House deaths that session were
    panic deaths INSIDE the map, not catches. Now `SPRING_K := 7.5` and `PLAYER_SPEED := 210.0`,
    between the old first- and second-run values; `_drag_step()` takes `panic_ratio` and ignores
    it. ⚠️ DELIBERATE at the constant. Catch panic, drip, proximity and every monster number
    untouched. `check_maze_speed.gd` feeds the same cursor at panic 0 and 0.9 and asserts identical
    travel, with a control on the retired lerp.
  - **Panic climbs the whole time it is open:** a flat `MAZE_DRIP_RATE=0.4`/s plus a squared proximity term up to `PROXIMITY_MAX_RATE=2.5`/s, via the same "a paused UI's own `_process` still calls `player.add_panic()`" idiom `note_ui.gd` uses for trap notes — which means the UI **must** self-clear if a screamer fires and unpauses the tree out from under it (Issue 9 guard, copied verbatim from `combination_lock.gd`/`note_ui.gd`). ⭐ Since 2026-09-24 (e) all of it goes through `add_map_panic()`, clamped at 0.98 of the bar, so the map's own panic cannot fire that screamer; the guard stays for screamers from elsewhere, and the map's one death is the third catch in a row. Winning calls the unchanged `_build_cellar_key()` at the counter's other end for a real 3D pickup; getting caught (`CATCH_RADIUS=20px`) ejects back to 3D with a jolt + `CATCH_PANIC=18` (bracketed between `beartrap.gd`'s own 15/40 spring-vs-fail values) and the map is retryable. `house_drawer.gd` (the superseded Landing search) was deleted as dead code.
  - ⚠️ **Legibility (playtest 2026-07-25, capture #3)**: the caption was added as a second child of the `CenterContainer`, which overwrites every child's anchors/offsets — so it landed stacked dead-centre ON the parchment in a cream that matched it. It now hangs off `_root` with a black outline (`ScreenText._outline()` convention). The three icons are 1024×1024 PNGs whose ink fills only ~30–40 % of the canvas, in the same sepia as both the parchment and the wall rects, so each rendered as ~28 px of near-invisible scribble; `modulate` cannot fix that (it multiplies — no multiplier turns brown into saturated blue), so `_make_icon()` stacks a dark halo disc + a bright identity disc sized to `ICON_HALF_EXTENT` + the ink on top. See ISSUES_SOLUTIONS Issue 32.
  - **Test coverage:** `tests/screenshot_maze_ui.gd` drives the real `interact()` path — `screenshot_scene.gd` structurally cannot reach a UI behind a prop. Maze generation is stress-tested independently of any scene by `tests/check_maze_gen.gd` (200 seeds: connectivity, non-trivial target distance, valid monster and patroller placement; since 2026-09-24 (e) also the fairness filters on the twelve curated seeds), because the minigame is only ever opened by player interaction and a normal scene smoke test never exercises `_generate_maze()` at all.
- **THE GUEST (2026-07-28/29) — the house rearranges itself, one step per quest milestone.** The
  House is the only level with genuine backtracking pressure (Bathroom map → key → Kitchen → cellar
  → ChildRoom lock crosses the ground floor repeatedly), and this is what that traffic is for:
  | milestone | what changes |
  |---|---|
  | map solved | ~~**arms** the child's-room painting~~ — ⚠️ **since 2026-09-24 nothing; the FIRST PORCH VISIT arms it** (top of SPEC; since 2026-09-24 c, precisely the first step onto the deck). It comes off the wall **beside the exit lock** when you are within 4.5 m, facing it, **and can actually see it**, with `painting_fall` at +8 dB and a camera jolt |
  | key taken | (nothing) |
  | cellar gate opened | arms **the cellar sequence** (below) |
  | third note read | the **music box** has moved to the Hallway, still playing, between you and the exit |
  - ⚠️ **The music box move is the ONE beat still on `MovedProp`'s off-screen rule.** The painting,
    the cellar child and the Intro wheelchair were all moved to happens-in-front-of-you on playtest
    feedback across two sessions. In rooms this dark an anomaly nobody witnesses is one nobody gets;
    the music box survives because it is meant to be *discovered* on the way out, not watched
  - The music box is a **real object** (`music_box.gd`) with the loop as its CHILD — that is the only
    reason the sound travels with it. It used to be a bare `_loop_audio` with no body at all. **E
    winds it**: the crank turns and the tune comes up out of the room tone for ~22 s, re-windable
  - ⚠️ **The falling painting moved BEDROOM → CHILD'S ROOM (2026-08-16, the user's proposal).** Stage 1
    (history: since 2026-09-24 the porch arms it, not the map) fired when the map was solved, and after that the Bedroom is off every remaining route — map → key
    → Kitchen → cellar → the exit lock never re-enters it — so the level's most expensive scripted
    beat was staged in a room the player had already finished with. The ChildRoom holds the exit lock
    and cannot be skipped. `painting_house.png` and the child's crayon drawing simply **swapped
    walls**; the drawing took the Bedroom's south wall. ⚠️ `_drop_painting()`'s landing offset now
    runs along the panel's **own forward** (`basis.z`) instead of the hard-coded `p.z + 0.55`, which
    was correct only for a panel facing +z and would have slid this one a metre sideways into the
    plaster
  - ⚠️ **…and then, one replay later, EAST WALL → NORTH WALL, BESIDE THE EXIT DOOR** (2026-08-16:
    *"let it be next to the door so once you approach the lock it falls"*). The right ROOM was not
    enough — on the east wall the beat merely happened somewhere in the same room. It now hangs at
    `PAINTING_X = 0.85` on the north wall; the exit door occupies x −1.33…−0.08, so there is ~0.5 m
    of wall between them and the panel is in the frame you are looking at while you work the lock.
    ⚠️ Not on a doorway — ChildRoom's only `RoomBuilder` doorway is SOUTH at (0, 14); the exit door
    in the north wall is a prop. (⭐ Since 2026-09-24 there IS a RoomBuilder cut behind the panel —
    `WALL_CUTS`' 0.62 m hole, filled back to a 0.62 × 0.62 m opening — but it is a hole the panel
    is MEANT to cover, not a way through, and it is not in `DOORS`.) The 0.55 m landing slide puts it at (0.85, 0.06, 18.29), clear of
    the small bed and clear of the walking line to the lock at x = −0.7
  - ⚠️ **The drop needs LINE OF SIGHT, not just range and a facing dot** (Issue 77). Distance +
    facing alone is a test for *pointing at*, and in a house it is satisfied through walls: the
    2026-08-16 log has the painting falling **1.5 s after the key was taken and ~130 s before the
    player entered the room**, through the Landing's south wall, to nobody. `_painting_in_sight()`
    is one ray from the eye, excluding the panel's own body and the player
  - ⚠️ **The fallen panel goes to `collision_layer = 2`** (`note.gd`'s raycast-hittable /
    movement-invisible convention). Pitched flat it is a 0.8 × 1.0 footprint standing 11 cm proud of
    the boards and `move_and_slide` cannot step up; measured, it split the north end of the room —
    the end the lock is on — from one free lane into two. Gaze panic is unaffected, because the gaze
    ray uses the default all-layers mask
  - ⚠️ The music-box wind is two streams that must both come back: the recording plays at `LOUD_DB`
    while the room-tone bed **ducks to `BED_DUCK_DB` rather than stopping**, and both return after
    `PLAY_TIME`. A duck with no restore is Issue 50's shape; `tests/check_music_box.gd` waits past
    the wind-down in real time and asserts the bed is back
- ⭐⭐ **THE CELLAR CHILD IS IN YOUR FACE AND THE CAMERA IS FORCED TO IT (2026-09-10, capture #7).**
  `_cellar_child_appear()` now tries a player-relative ladder — `CHILD_NEAR [1.7, 2.0, 2.4]` ahead,
  ±`CHILD_FAN_DEG` 25° at 2.0, 3.2 ahead, then 2.0/2.6 BEHIND, then the room centre — through
  `Watcher.spawn(require_los = true)`; on success it zeroes the velocity, `freeze_input()`s,
  `turn_to_face(child + 1.35 m, CHILD_TURN_TIME 0.45)` and dips the bed (`CHILD_DIP` 0.4), the Lab
  nook's idiom. `_end_cellar_blackout()` unfreezes. `check_house_guest.gd` asserts ≤ 2.6
  m, dot ≥ 0.9 after the turn, pinned then released, and case (iii) (nose to the wall) now
  REQUIRES a figure behind and the turn. Zero panic as before.
- **THE CELLAR SEQUENCE** — three scripted beats, timed to the
  user's spec: every lamp AND the torch die instantly → **4.5 s of nothing** (5.5 until
  2026-09-24 c, capture #4) → the child, screaming → **3.0 s later** the lights return and it is
  gone
  - ⚠️ **The dark-zone and standstill taxes are SUSPENDED for the whole sequence**
    (`player.set_smiler_active(true)`). ⚠️ **The cellar's `DarkZone` was REMOVED in the darkness pass
    (D4) — the whole House is unlit until the three safe notes are read, and the cellar's `DreadZone`
    is kept.** The suspension stays: forcing the torch off would
    otherwise charge +3/s for a scripted event with no counter-play — Issue 18, and the player died
    there at 99 % panic on the run that prompted this
  - The figure is a `Watcher` (zero panic, no collider, no rules) at **1.95 m** — deliberately taller
    than a child, because at child height it read as small and far away rather than on top of you.
  - ⚠️ Two earlier placements FAILED SILENTLY and both are worth remembering: spawning it on the
    milestone put it two rooms from the player, `Watcher.spawn()`'s line-of-sight check failed
    through the walls, it returned null and the one-shot flag was already set — no figure, no
    scream, no darkness, ever. Spawn a scripted beat where the player IS
  - ⚠️ **Only ONE figure down here.** The atmosphere pass also put a `Watcher` in the far corner;
    it was cut, because the mood piece arrived first and spent the surprise the event needed
  - ⚠️ **IT IS POSTPONED, NEVER FIRED BLIND (2026-08-16).** `_cellar_child_appear()` re-arms itself on
    a 0.25 s timer while `NoteUI.is_open`, `get_tree().paused` **or** `player.is_input_frozen()` — the
    same three conditions `apparition_director.gd` refuses on, and the level's own set-piece checked
    none of them. It measurably needed to: the 2026-08-16 log has the child spawning at t=206.98
    *inside* a beartrap QTE that started at 205.48, with a countdown UI over the screen. And
    `SceneTreeTimer` defaults to `process_always = true`, so the old bare `create_timer()` fired
    straight through a tree pause as well. ⚠️ `CHILD_POSTPONE_MAX` (45 s) is the safety valve: the
    blackout's END is armed by the appearance, so a beat that postponed for ever would strand the
    player with no lamps and no torch. Past it, the figure is given up and the lights come back
  - ⚠️ **`require_los = true` on every `Watcher.spawn` here.** It was `false`, which `watcher.gd`
    restricts to `congregation.gd`, and the LOS ray is the ONLY probe that catches "inside a wall"
    (Issues 40/59) — so the `[3.2, 2.4, 1.8]` ladder below it was dead code. Measured with the flag
    off, a player facing the cellar's south wall from 0.7 m got the figure at z = −11.9, **2.5 m
    beyond the wall.** With it on, the ladder is refused and the room-centre fallback runs
  - ⚠️ **DELIBERATE (2026-08-16): the cellar beartrap STAYS on the forced-blind entry line.** It sits
    1.6 m past the blackout trigger on the only heading in, inside an 8.5 s window (7.5 s since
    2026-09-24 c) with no lamp and no torch, and it fired in both playtest sessions. The user was shown that measurement and chose
    to leave it. That is what makes the postponement guard above load-bearing rather than tidy —
    the collision will keep happening
- **The Kitchen** (42 m², previously ONE prop): sink, table and chairs built from real parts, plus
  a **fridge** (`house_fridge.gd`) — it hums, and on E the scream fires FIRST, the door swings 0.28 s
  later, and a head is revealed on the shelf as it clears. **10 panic, the only new panic term in the
  whole atmosphere pass**; ~~voluntary, optional, off the quest path,~~ one-shot, and inert afterwards
  (⚠️ **on the quest path since 2026-09-13**: digit 2 is on the head's forehead, behind the chain
  the bolt cutters cut — the "optional" wording outlived that change here and in `level_2.gd` until
  2026-09-24 c)
  - ⚠️ The carcass is an **open-fronted shell of five slabs**, not a solid box — see Issue 46
  - ⚠️ **The door is hinged on the +X edge and swings +105° OUT (fixed 2026-08-16, Issue 69).** The
    hinge used to sit on −X, and rotating that free edge by +105° carried it toward local −Z, i.e.
    *backwards through the shell* — the playtest capture of an "open" fridge contains no door and no
    handle at all, because both were inside the box. The hinge moved rather than the angle flipping,
    on the user's call: it is also the edge furthest along the approach from the Hallway doorway, so
    the panel uncovers the cavity toward the player instead of sweeping across the kitchen table
  - ⚠️ `REVEAL_DELAY = 0.62` was **NOT** retimed. The second half of that same report ("the head
    appears not immediately") is a symptom of the door: the head is meant to be revealed *as the door
    clears it*, and with nothing clearing, 0.62 s reads as a pause in front of an open box
  - ⚠️ The lower wire shelf is `SIZE.y * 0.34`, not 0.40 — at 0.40 it drew straight across the bottom
    7 cm of the face, which is the same capture. The head now RESTS on that shelf, clear of both
- ⭐ **THE KITCHEN DRAWER IS TWO PRESSES NOW (2026-09-10, capture #5: *"The note should be
  physically seen in this cabinet before it will be taken"*).** E slides it open and a real page
  (`DrawerPage`, a nested layer-2 body on `DrawerSlide`, art `kontur_note_page.png` cropped to the
  quad's aspect, collider `disabled` until the slide finishes) lies in it; a second, separate E
  takes and reads it, and only then does `record_note()` run. `lab_cabinet_drawer.gd`'s beat, and
  the Flood's. `can_interact()` on the drawer is `not _opened`; the page's is "open and present".
  `check_open_then_read.gd`'s House section asserts no note and no journal entry after E1, that the
  shipping ray finds the PAGE, and that E2 archives exactly once. `check_wall_overlap.gd` waives
  `DrawerPageSheet` by name (it lies inside the counter while shut).
- **The kitchen drawer** (`kitchen_drawer.gd`) carries a second, independent hint for **KONTUR Gate 1**
  ("the black door is the way out, the red one is not a door" — the rule, never a position, since the
  colours swap per run). Gate 1's only other hint is in the Lab morgue behind a beartrap and two
  instant-fail objects, and getting it wrong BANISHES rather than costs a strike
  - ⚠️ **It opens BEFORE the note, and it opens OUTWARD (both fixed 2026-08-16, Issue 73).** It was
    Issue 58 verbatim — the slide Tween started and `NoteUI.show_note()` was called two statements
    later, and `show_note()` pauses the tree, so the drawer only moved once the page was dismissed.
    The note is now fired from the tween's `finished`. And `SLIDE` is **−0.34**: it was +0.34, which
    drove the panel 34 cm into the counter it is set into, so the corrected ordering would still have
    revealed nothing. `tests/check_open_then_read.gd` measures the slide at the moment the note
    appears **and** asserts the opened drawer is inside no CSG box
  - ⚠️ **ONLY THE VISUALS SLIDE — the collider never leaves the counter face (2026-08-16, Issue 76).**
    The tween moved `self`, a `StaticBody3D` whose child is the `CollisionShape3D`, so an open drawer
    put a 0.62 × 0.26 × 0.14 solid 34 cm out into the room. Measured with the player's own capsule:
    the free lane across the Kitchen at z = 7.40 went from **ONE 5.10 m span to two of 1.30 m and
    2.50 m**, and that lane was the only way past the counter — the playtester was carrying the cellar
    key. Everything visible now hangs off a `DrawerSlide` child; the body is fixed. **An interactable
    in this game may never move a collider into a walkway.** Guarded by `tests/autoplay_house_route.gd`
  - ⚠️ **And it is a DRAWER, not a panel.** It was a single 2 cm board with nothing behind it, so a
    34 cm slide out of a featureless counter rendered as a pale plank hanging in mid-air, which is what
    the user photographed and read as fallen debris. Two sides, a bottom and a back run back into the
    counter (invisible while shut); the handle moved to the **−z** face, having been on the one buried
    in the worktop
- ⚠️ **Furniture is built from PARTS, never one flat box.** Two rounds of playtest photographed the
  beds, chairs, table and music box and called them "boxes that do not make any sense". What makes a
  bed legible is the headboard and a mattress proud of the frame; what makes a chair legible is the
  back. Issue 35 in furniture form. The cellar's shelving/boiler/crates and the kitchen sink slab
  were **deleted** rather than rebuilt — they sat in near-total darkness and read as nothing
- 3 safe notes (one digit each — **the third is in the cellar**, forcing the descent), 2 trap notes (`is_trap`, read-to-die)
- Win: read the 3 safe notes, enter code **472** on the combination lock by the child's-room exit (`CODE_ENTERED`)
- Fail: read a trap note **fully**; the apparition rush; or panic bar fills — which since 2026-09-24 includes **staying out in the forest** (the forest clock, ~25 s from calm at the deepest point). Read-to-die: trap notes feed +12 panic/s while open (`TRAP_PANIC_RATE` in `note.gd`, ticked by `note_ui.gd`); text bleeds red; close early to survive
- **The window + Forest scare** (`_spawn_window()` → `HouseWindow`): since 2026-09-24 a real floor-length window in the living room's WEST wall with the porch and the moonlit forest behind it (the north-wall painted `forest.png` quad is deleted). Press up (≤1.5 m) → SURVIVABLE `flash_scare(screamer_forest.png)` + jolt + 25 panic, and 0.6 s after the flash clears the pane bursts and the porch is open (top of SPEC)
- **Scares**: cursed props (bedroom painting 0.8, living-room mirror 1.2) + a TV-static gaze panel (`tv_static_face.jpg`); a one-way mirror (`living_mirror.gd`) in the bathroom; a music box (`music_box.wav`) in the child's room; the cellar is a `DreadZone` with water drips, a beartrap; pipe groans + random blackouts on timers; 3 `CorridorEvent` triggers (door slam +8, footsteps overhead +6, bedroom light dies +6)
- **Lock penalty**: each wrong combination = harsh buzz (`lock_buzz.wav`) + 10 panic — brute-forcing the lock is itself a fail path

## DECISIONS & GOTCHAS

⚠️ **Dated ⭐ entries live at the TOP of SPEC, not here.** They carry the level's *current* state and
override the older prose beneath them — that is how `CLAUDE.md` was written, and why entries say
things like *"every paragraph below that says 320 m is history"*.

⚠️ **The top-to-bottom order is NOT strictly newest-first.** Measured 2026-09-19: `01-lab.md`'s
2026-09-13 entry sits *above* the 2026-09-14 entry that reverts it, and `04-backrooms.md:302` sits
*below* the same-day entry that supersedes it. **Read the dates; where they tie, read the code.**

Use this section only for rationale that leaves **no trace** in the level — something tried and
abandoned. Anything describing what the level *is* belongs in SPEC.

### The Porch pass (2026-09-24) — measured, and what was decided on the way

- **The house stays black with the moon in the scene — MEASURED, not assumed.**
  `screenshot_house_porch.gd` renders four interior poses torch-off with the moon + dome ON and OFF
  and takes the per-pixel luminance difference: Living Room floor 0.00, Living Room north wall
  0.00, Bedroom 0.00, Hallway 0.00 **outside the window opening** (inside it you are looking at the
  moonlit porch: 38.9 and 7.0 there, which is the point of a window). Frame maxima are unchanged by
  the moon (55.7 / 85.1 / 0.0 / 72.8 — the self-lit notes and TV that were already there). ⚠️ The
  first run read 178 everywhere: that was the HUD objective line and then the crosshair dot, both
  now masked. **Why it holds:** the moon's `light_cull_mask` is render layer 2, and only outdoor
  geometry is on layer 2 — no shadow map is being trusted to keep it out.
- **The forest clock, measured in `check_house_porch.gd`** (real time, RandomAmbient and the
  blackout clock disarmed): deck −3.50 /s (decay alone); tree line d = 0.6, net **+0.06 /s**;
  d = 20, net **+2.00 /s**; deepest reachable (x −39.3, d = 27.3) **+2.00 /s** (capped); 0 → 45 in
  22.5 s ⇒ **25.0 s from calm to death**; input frozen, −3.49 /s (suspended). ⚠️ A first version
  measured the death time on `Engine.time_scale` 4 and got 20.8 s against a 1x slope of exactly
  +2.00 — the harness measuring its own clock; it runs in real time now. ⚠️ And the global
  `RandomAmbient` (+5/+8/+12 at random) once landed a +12 inside a 2 s window and read as
  "+8.00 /s" — any slope measured in this level must disarm it.
- **Ghost cadence, measured:** 5 in 40 s of forest, gaps 7.6–10.0 s.
- **The window bursts 0.6 s after the flash CLEARS, not 0.6 s after it starts.** At 0.6 s from
  the start the burst lands under the 0.8 s fullscreen face and the one moment the player could see
  the glass go is spent. Recorded here because the grill's wording ("about 0.6 s after the flash")
  was read as the flash ending.
- **Glimpse 1 is the level's only `require_los = false`.** The pane has to be a layer-1 collider
  (it stops the player), and `Watcher`'s LOS ray is layer-1 too, so it refused every spot beyond
  the glass. `_clear_through_glass()` is the same ray with only the pane excluded.
- **The roof is a body, not CSG — because of `check_shell_sealed.gd`.** Its sampling grid is
  derived from every `CSGBox3D`'s extent at a 1.5 m step; a CSG roof reaching x −12.35 shifted the
  grid's phase so no sample landed on the cellar ramp's 1.2 m standable band, and the sweep's
  "y = −0.8" floor level measured 0 points on a level nobody had touched there. (The same sweep
  found a 1 cm slot between the fence's and the north screen's colliders; the fence collider now
  overlaps the screen by 0.3 m.) ⚠️ That guard's per-level zones are a grid lottery on the ramp —
  cross-level, filed in the backlog's Deferred.
- **The recess is 0.28 m, not 0.34.** The painting hangs 6 cm proud of the wall directly over the
  hole, and `check_note_mounting.gd` requires a wall within 0.35 m behind every wall panel: the
  recess's back plate is that wall (0.34 m from the panel's centre). At 0.34 m deep it measured 0.40.
- **The painted hole was opaque.** `plaster_hole.png` is a ragged hole with its middle painted black
  (alpha 255 at the centre), so it would have covered the fruit. `plaster_hole_ring.png` is it with
  the dark middle flood-filled transparent inside a 168 px disc (0.328 of the quad), so the ring
  covers the square cut's corners (0.438 m at `HOLE_DECAL_SIZE` 0.96) and the real recess shows.
- **The watermelon flesh texture is a whole round slice**, so the cut face uses object-space
  triplanar scaled to exactly one tile per disc. The first try tiled it (four rind corners round a
  black star — photographed in `17_basket`, a render retired with the basket on 2026-09-24 c).
- **The carried HUD overwrite (Issue 274).** Taking the bolt cutters while carrying the cellar key
  replaced "cellar key" with "BOLT CUTTERS", and using either cleared the line with the other still
  in hand, because every site wrote its own item into the single-string `set_carried()`.
  `_refresh_carried()` rebuilds the line from state; `GameState` is untouched.
- **Rejected in the grill, not built:** the guillotine as a trap (the user chose no fail state), and
  the door-blows-open / front-door porch access (the user chose the breaking window).

### The porch playtest pass (2026-09-24 c) — measured, and what was decided on the way

- **The forest is required, and that reverses the porch pass's own grill (Q1, "optional dread").**
  It was the user's call on the playtest: *"it makes no sense to walk there … you need to search for
  something there"*. Recorded as `backlogs/02-house-porch.md` §2 row 9. Do not re-open "optional":
  the grill's row 9 is final.
- **No hint, by decision.** The user ruled out a path, a sound beacon and any glint. That includes
  emission on the steel: the blade uses the frame's own steel material (no emission), lit by the moon
  on render layer 2 and by the torch, like everything else outside. ⭐ Duller since 2026-09-24 (c),
  the user's call: steel metallic 0.85 / roughness 0.3 → **0.5 / 0.5** and the iron weight albedo
  0.10 → 0.17 (metallic 0.4, roughness 0.7), because at 0.85 the blade in the stump rendered as a
  near-black wedge even under the torch. Re-rendered: it now reads as grey steel by torch
  (`23_stump_close`, `20_stump_torch_4m`), and is still only a silhouette by moonlight
  (`21_stump_moon_only`), so it is legible at arm's length and is not a hint from afar.
  Whether that is findable before the clock bites is the open playtest question below. It is not a
  defect to fix unasked. ⭐ Since 2026-09-24 (d) the blade is the generated art on quads (the
  user's call), with the same no-emission rule; the steel/iron materials survive as the fallback
  and as the edge boxes' iron.
- **The round trip, measured — and why it is lower than the plan's arithmetic.** The real
  `AutoPlayer` walked a 20.3 m A* route round the seeded trunks, from the rail gap to 1.2–1.7 m from
  the stump, paused 0.6 s, and walked back to the deck:
  - from calm: peak **10.6** of 50;
  - from 25 (straight after the window scare's +25): peak **34.6**;
  - 11.0 s of walking, deepest d = 18.4 m.

  The plan's 14 / 39 assumed the 21.9 m straight line to the stump itself. The player stops short,
  and the clock charges by depth, not distance walked. ⚠️ **This is the cost for a player who knows
  where the blade is.** A search from the rail gap with no hint is some multiple of it, and the
  multiple is not measurable without a player.
- **The trunk count dropped 85 → 81.** The clearing rejects trunks inside 3.5 m. Rejection sampling
  with a fixed seed diverges from the first trunk that used to land there, so the whole layout
  after that point moved; the 1200-try budget then fits fewer. `check_wall_overlap -- House`,
  `check_reachable` and the witch/ghost placements were re-run on the new layout.
- **The interact volume encloses the whole stump.** `player.gd:_update_interact_prompt()` takes the
  body its ray hits and does not walk up to a parent. A volume around only the blade would leave the
  bark, the most likely thing to be looked at, with no prompt. The solid stump is a separate
  layer-1 child body. The layer-2 box is 1.0 m wide against a 0.46 m collider plus a 0.4 m capsule,
  so the camera can never stand inside it (where `hit_from_inside` would matter).
- **With both in hand, E mounts the blade first.** "Either order" means either order across visits,
  not a menu: one press does one thing, and the blade is the thing the frame visibly lacks.
- **The mount animation holds `_busy` for 0.45 s.** A second E in the same instant is refused rather
  than queued. `screenshot_house_porch.gd` therefore sets its loaded shot through `restore("placed",
  false, true)`, the level's own restore path.
- **The cellar margin is 0.6 s, not the plan's 0.8 s.** The user's figures (doll 4.5, hold 1.2) were
  built as given. The plan's "gone by 3.7 s" dropped 0.2 s: `ScreenText.scrawl` fades in 0.6 s and
  out 1.4 s, so the scrawl is gone at 0.7 + 0.6 + 1.2 + 1.4 = **3.9 s**. A 0.8 s margin would need a
  hold of 1.0. This is not changed: the constant is the user's.
- **Proved able to fail** (`check_house_porch.gd`, four mutation runs, each restored byte-identical):
  - the old flat-dot + dwell rule, a bladeless pull allowed, and the cutters in the air: 15 red;
  - the old −0.35 yard-look threshold: 1 red;
  - the old z 25 → 15 lane: 2 red, 0 % of the run seen, 21 frames hidden by the porch or fence;
  - the cutters 0.3 m in the air alone: the floor check red.

### The second playtest pass (2026-09-24 d) — measured, and what was decided on the way

- **The corner round trip, measured.** The real `AutoPlayer` walked a **28.7 m** A* route each way
  (rail gap → a spot 1.2–1.7 m from the stump **with a line of sight to it** → back to the deck),
  round the seeded trunks, the ring and the thick trunk. It paused 0.6 s at the stump. It walked
  **15.0 s** in all, and the deepest point was d **23.4 m**:
  - from calm: peak **17.2** of 50 (it was 10.6 at the old clearing), asserted survivable;
  - straight after the window scare (25): peak **41.2** of 50 (cost +16.2; it was 34.6), reported
    only.

  ⚠️ This is still **a player who knows where it is**. The search is the real cost, and with a
  41.2 peak from 25 there is very little room for one on the first sortie. That is what "probably
  in several runs" asks for. The constants are the user's and did not move.
- **The trunk hides it, by rays.** 16 of 16 physics rays stop on `HidingTrunk`: from three points
  across the rail gap and from (−26, 6), to the blade's centre, both its ends and the stump's
  top, with every other trunk excluded. The control rays, with `HidingTrunk` excluded too, reach
  the stump on 16 of 16.
  - **Without the thick trunk, 4 of those 16 sightlines were open through the seeded forest**
    (measured by mutation: the trunk's collider moved 3 m, the whole scene blocked only 12 of 16).
    The trunk is what closes them, not luck in the seed.
  - Proved able to fail: that mutation took the "hides" check to 0 of 16. Putting the art on the
    edge boxes turned the "no box face" check red on both blades. Each was restored byte-identical.
- **The trunk is on the BISECTOR, 1.2 m out, not in front of either sightline alone.** The two
  sightlines meet the stump 22° apart. At 1.2 m each passes 0.23 m from the trunk's axis, inside
  its 0.55 m radius with room for the blade. The blade itself is turned edge-on to both
  (`BLADE_STUMP_YAW_DEG` 6.5), because at r 0.55 a broadside 0.5 m blade would have peeked out on
  one side. The stump's outermost rim can still show a sliver on one side. That is not asserted:
  it is the flared foot, 29 m away, in the dark.
- **The art: strips, not a band.** The first rule, "the rows opaque from the top in every column",
  measured a band of 0 on this art, because the top bolt bar is narrower than the blade. The edge
  boxes are per-strip instead, each as wide as the columns opaque in every row of its strip.
  - The strip's last row is always sampled. Without that, the lowest box poked ~9 mm past the
    diagonal into the transparent triangle.
  - The coordinator asked for the back face mirrored in U, and it is. A back quad that is only
    turned round shows the art correctly *printed* but with the slant on the wrong side for a
    solid blade.
- **The art made the blade SHORTER** (0.28 m, not 0.47), so two numbers are derived from it now
  rather than hand-set. `blade_down_y()` makes the dropped blade still reach the lower board: the
  old 0.94 would have left the art's low corner 12 cm above the neck gap. `BLADE_BURY` puts the
  low corner in the stump: the old lift of 0.13 would have stood it on the wood.
- **Sighting timings, measured** (`check_house_witch.gd`, real input path):
  - A: the player is pinned **0.01 s** after the note closes, and the camera dot reaches ≥ 0.9
    at **0.23–0.25 s** (`turn_to_face` eases out over 0.45). Mid-hold the dot is **1.000**.
    Released at **2.33 s** (the beat is 0.45 + 1.5 + 0.4 = 2.35). Panic max **0.000**.
  - B: pinned 0.03–0.06 s after the close, dot ≥ 0.9 at 0.33 s (a 180° turn), released at
    2.38 s. Behind the player: pre-turn facing · her = −1.00, 3.00 m. Panic max 0.000.
- **Where A lands, by reading spot:**

  | player at | rung taken | distance |
  |---|---|---|
  | (−7.0, 13.8), in front of the note | doorway, inner side (−5.0, 12.5) | 2.37 m |
  | (−9.0, 13.3), the bed end | the inner side is 4.08 m, too far: mid-room (−6.07, 12.95) | 3.00 m |
  | (−5.2, 13.7), by the doorway | the inner side is 1.2 m, too near: the Landing (−3.0, 12.5) | 2.51 m |
  | (−7.6, 14.6), close to the wall | doorway, inner side | 3.34 m |

- **The deck test had to be sharpened, by mutation.** With the pane intact, nothing behind a
  player on the deck can be placed (the pane blocks the LOS), so removing the "player inside the
  house" gate went **unnoticed**. The check now breaks the window and stands just outside it,
  so 3 m behind the player is the Living Room, in plain sight. The same mutation then goes red
  (she fired at 7.8 m). Three mutations, all red, restored:
  - no freeze;
  - +5 panic in the sighting;
  - no room gate.
- **A render artefact, not a cost.** `screenshot_house_porch.gd` turns the player's physics off,
  so an `add_panic()` pushes the HUD's red blur and nothing pulls it back. At z 9.0 the capsule
  entered the Hallway's footsteps-overhead box (+6), and the level's random blackout clock (+4)
  fires about 30 s into the run. Measured headless, B itself adds **0.000**. The driver now
  disarms the blackout clock and stands at z 9.8. A faint softness remains in `26`/`27`, which
  is the same HUD state.
- **Rejected on the way:** a `DoorLunger` (the Lab nook's glowing figure) for the witch. Her
  `Watcher` is unshaded, so her texture is her colour, and she reads fully at ambient 0.0 in the
  torch beam (`25`). Glow would be a beacon, and the House's self-lit props were halved on purpose.

### The curated map (2026-09-24 e) — measured, and what was decided on the way

- **The curation run** (`probe_maze_curate.gd -- 1000 1000 20`, 256 s, reproduced byte-for-byte on
  a second run). Of 1000 seeds:

  | rejected on | count |
  |---|---|
  | (a) race | 451 |
  | (b) behind | 23 |
  | (c) patroller | 335 |
  | (d) loop | 0 |
  | band-low | 34 |
  | band-high | 125 |
  | **kept** | **32** |

  The twelve that ship (bot wins / 20, median win; "ship" = the bot's result on the patroller
  circuit the game itself plays, k = 0):

  | seed | tour | cut vertices | race margin | wins/20 | median win | ship |
  |---|---|---|---|---|---|---|
  | 1030 | 51 | 24 | 3.24 s | 14 | 19.9 s | L |
  | 1085 | 54 | 6 | 3.34 s | 14 | 20.4 s | L |
  | 1101 | 73 | 38 | 3.66 s | 13 | 29.0 s | L |
  | 1146 | 53 | 0 | 5.38 s | 14 | 20.4 s | L |
  | 1356 | 50 | 19 | 3.66 s | 13 | 19.2 s | W |
  | 1472 | 46 | 0 | 5.78 s | 13 | 18.5 s | W |
  | 1534 | 53 | 0 | 4.87 s | 14 | 20.2 s | W |
  | 1611 | 61 | 20 | 4.37 s | 13 | 23.9 s | L |
  | 1767 | 54 | 0 | 6.59 s | 14 | 21.1 s | W |
  | 1804 | 45 | 5 | 3.66 s | 13 | 17.6 s | L |
  | 1930 | 62 | 12 | 1.81 s | 13 | 23.8 s | W |
  | 1134 | 51 | 18 | 3.76 s | 12 | 19.4 s | W |

  **Aggregate 160/240 = 66.7 %, median win 20.4 s** (`check_maze_chase.gd`). The 20 spares are
  in the probe's output, ranked.
- ⚠️ **Every bot loss on the twelve is the PATROLLER: 80 of 80.** The hunter catches the bot zero
  times, because filter (a) removes exactly the layouts where it can. On the raw generator (400
  seeds) the hunter took 101 of 167. So the 50–85 % band here measures how often the patroller's
  circuit meets the obvious line. **The hunter still kills a player who stops:** PURSUE is 52/52,
  median 3.0 s after the stop. Humans drag with lag and the bot does not, so a human's hunter
  deaths are a playtest number, not a harness one.
- ⚠️ **On the circuit the game actually plays (k = 0), the bot loses 6 of the 12.** Filter (c)
  guarantees that circuit never enters a cell the tour cannot avoid, so each of those meetings has
  a way round, which the bot (downhill-only) does not take. Reported, not acted on. Choosing a
  per-layout patroller seed the bot survives would be a difficulty decision.
- **The race margin is 1.2 s and it is `SNARE_HOLD`:** one snare's pin must not turn a won race
  into a lost one. The hunter's arrival is a LOWER bound (it chases the player, it does not head
  for the cell), so the filter errs against the layout. Seed 1930 is the tightest shipped
  (1.81 s).
- ⚠️ **Two of the filters are structurally quiet, and that was measured, not hoped.**
  - **Leg 1 of (a) cannot fire on this board.** The hunter spawns one cell from the player, so its
    distance to any cell is the player's ± 1. With 3 s of grace, 3 + 0.558·(d − 1) > 0.457·d for
    every d. Every real race rejection is on leg 2: the walk back out of the hammer's pocket.
  - **(b)'s "nearer the hammer at wake-up" half cannot fire either,** for the same reason. The
    player has 6.6 cells of lead and the hunter is at most 1 cell nearer. What rejected the 23 is
    the topological half: the hunter's start is a cell the tour cannot avoid.
- ⚠️ **(b) is applied to the HAMMER at wake-up, not to the key — a deliberate reading.** "The
  hunter is nearer the key than the player at t = grace" rejects **639 of 1000** seeds, and 5 of
  the 12. It is nearly always true, because the player's first move is a detour away from the key.
  And it is not a threat: the hunter hunts the player, not the key, and the glass room is solid to
  it. The time-correct version of that question is (a)'s leg 2, the key's approach cells at the
  moment the player walks them. **Open question to the user** (backlog §5).
- **Tour length is not a curation filter.** 1101 ships at a 73-cell tour (29.0 s median) and 1804
  at 45 (17.6 s), both outside `TOUR_BAND` 50…64, which is the generator's own validate target.
  The band that decides is the bot's win rate. This gives the twelve a spread of run lengths.
- **The raw generator was re-measured, which closes the "28/40 predates the glass room" item.**
  `probe_maze_variance.gd -- 400`: **233/400 = 58.3 %, median win 21.6 s** (p10/p90 18.2/27.1),
  panic over a winning run median 7.8. The pre-glass figure was 232/400 = 58 % at 21.7 s, so the
  glass room did not move it. `check_maze_chase.gd` prints the raw 9000–9039 rate as a reference,
  not asserted: **27/40**, against the old 28/40.
- ⚠️ **The patroller's sub-seed moved it off the global RNG, which shifts every layout's snares**
  against the pre-(e) generator for the same seed. `_place_patroller()`'s `_pick_patrol_target()`
  call used to consume one global `randi()` before `_place_snares()` shuffled. The historical
  figures in this file were all measured before that change. The 12 were chosen after it.
  ⚠️ **Any change to the generator, either monster, or `_pick_patrol_target()` silently changes
  what the twelve seeds MEAN.** Re-run the probe and re-pick; never hand-edit the list.
- **The bot is now one copy**, `tests/lib/maze_curation.gd`. It was pasted verbatim into
  `check_maze_chase.gd` and `probe_maze_variance.gd`, and both now delegate to it, as does
  `probe_maze_curate.gd`. Its behaviour is unchanged (200 px/s, downhill with monster avoidance).
  It now caches its BFS field per goal cell, which is what makes the 20 000-run sweep affordable.
- **A test defect caught by its own mutation run:** with the clamp removed,
  `check_maze_no_death.gd` did not fail, it HUNG. The death reloaded the House after
  `RESTART_DELAY` and freed every node the test held. The next stage's `_ui.set()` threw, the
  frame aborted before the timeout check at the bottom of `_process`, and so on every frame until
  a 900 s external timeout. Both checks (scene replaced / UI freed, and the timeout) now run
  FIRST, before any stage touches a node. ⚠️ **In a scene test that can reload, check liveness at
  the top of `_process`, never at the bottom.**
- **Proved able to fail, nine mutations, each restored byte-identical (md5):**
  - no clamp → `check_maze_no_death` red at stage 1, the House reloaded;
  - no streak death → red on catch 3;
  - the win keeps the streak → red, 2;
  - a close counts as a catch → red, 4 checks;
  - curated 1001 (a race seed) → `check_maze_gen` red on (a) 0.39 s and (c);
  - the patroller back on the global RNG → red on (c) for 4 seeds;
  - repeats allowed → red;
  - `randomize()` removed → red;
  - curated 1023 (band-low) → `check_maze_chase` red, 0/20.
- **Renders** (`screenshot_maze_ui.gd`, with a display, `/tmp/shots/house_maze_sheet.png`): twelve
  visibly different boards, all with the caption, the counter, the hammer, the glazed key cell,
  the hunter and the patroller legible. In 1101 the key's glass room is two cells from the start,
  and the route to it is 73 cells: the "so close" layout, and a good one. Each board shows its five snares
  off the route.

### Superseded, moved out of SPEC on the 2026-09-19 audit

Each of these was a passage SPEC's own newer ⭐ entries already declared dead while leaving it in
place. Verified against the code before moving; the winning statement is named on each line.

- **The maze's panic-degraded drag physics** — *"the icon eases toward the cursor on an exponential
  spring rather than snapping, and both the ease rate and the speed cap degrade as panic rises
  (`SPRING_K_BASE=9.0→SPRING_K_PANIC=3.0`, `PLAYER_MAX_SPEED=240→PLAYER_MIN_SPEED=100`). Releasing
  the mouse freezes the icon instantly, no glide, so letting go never costs an unwanted catch."*
  Superseded by the 2026-09-10 ONE SPEED entry — `maze_chase_ui.gd` declares `SPRING_K := 7.5` and
  `PLAYER_SPEED := 210.0` and none of those four constants exists any more (`_drag_step()` takes
  `panic_ratio` and assigns it to `_unused`). ⚠️ The release-freeze half is still true of the code;
  it is kept here only because it shared a sentence with the dead constants.
- **The cellar child's old placement** — *"~3.2 m in front of wherever the player is facing"*, plus
  the pointer sentence that already flagged it. Superseded by the 2026-09-10 ladder entry:
  `CHILD_NEAR := [1.7, 2.0, 2.4]` ahead, then a ±25° fan, then `CHILD_DIST` 3.2 as a late rung, then
  BEHIND, then the room centre. 3.2 m survives in the code as the *far* fallback, which is why the
  number looked live.
- **The cellar sequence's old trigger** — *"on reaching the bottom of the ramp"*. Superseded by the
  2026-09-16 H4 entry: `_begin_cellar_blackout()` has exactly one caller,
  `_arm_child_on_note_close()`, armed off the cellar note's `read` and fired on `NoteUI.closed`. The
  ramp foot keeps only the `CELLAR_HINT` scrawl.
- **The cellar child's old scream gain** — *"`childe_scream` at +18 dB with `max_db` raised to 24,
  or the gain is clamped away"*. Superseded by the 2026-09-16 H4 entry (`screamer_house` at 0 dB /
  `max_db` 6). ⚠️ It is **not dead code**: `level_2.gd:2072-2073` is `0.0 if baba else
  CHILD_VOLUME_DB` / `6.0 if baba else 24.0`, so these are the numbers the FALLBACK path still uses
  when `screamer_house` fails to load — and the "or the gain is clamped away" warning is the reason
  `max_db` is written at all.
- **The cellar's `DarkZone`, the bedroom event's `DarkZone`, and the cellar's HOLD apparition** —
  struck from the `**Scares**` line, which still listed all three. Superseded by the D4 darkness-pass
  entry and the 2026-09-16 H2 entry, both already in SPEC: `_spawn_cellar_contents()` builds a
  `DreadZone` and nothing else, `_ev_bedroom_dark()` kills `Lamp_Bedroom` and drops no zone, and the
  `# ---- apparition` section of `level_2.gd` is now a comment block explaining that the scripted
  HOLD apparition is gone (the director's random one stays upstairs).

### The user's sounds and the first note (2026-09-24 b)

- **`glass_break` could not keep its name.** `GameState.load_audio()` walks `AUDIO_SUBDIRS` in
  order and `shared` comes first, so a `level_2_house/glass_break.wav` would never load:
  `shared/glass_break.wav` answers first. It was renamed `window_glass_break`, and
  `check_house_porch.gd` §0 asserts each user base name resolves to the user's own path. That is
  the only check that can see a shadowed name; the sound still plays either way, just the wrong
  one.
- **The soundtrack is one 2D player, not the stand-in's two 3D beds.** The stand-in was noise, and
  two unsynchronised positional copies of noise read as one space. Two copies of a track with a
  melody in it read as two radios. The outside / broken-window / glass gain offsets
  (`_tick_outdoor_audio`) carry over unchanged. The price is that the track no longer pans with
  the player's head; accepted, because it is a bed.
- ~~**The witch screams on glimpse 2, not 1 or 3**~~ ⭐ **Superseded 2026-09-24 (d):** glimpse 2
  is deleted and the scream leads the two house sightings (top of SPEC). The original reasoning,
  kept for the record: (the user supplied `witch_scream` without placing
  it). Glimpse 2 is the one spawned *behind* you, so a scream is the only way it is ever seen: it
  is what turns you round. Glimpse 1 is framed by the window and glimpse 3 by the tree line, and
  both are already in view. `witch_hum` stays unwired.
- **The first note went to the Bedroom, not back to the Living Room.** It was the user's call: the
  Living Room holds the forest now, and the Bedroom had lost its only purpose when the cutters
  left the bed. The node was renamed `SafeNote_First`. `safe_notes` snapshots store node names, so
  a snapshot taken before the rename would not recognise the note, but snapshots are per session,
  so nothing persisted can hold the old name.
- **The repo ships only what the game loads (2026-09-24 b, the user's rule).** Untracked with
  `git rm --cached` after `9bd0f19` had committed and pushed them, and gitignored:
  - the 49 raw porch generations;
  - the user's 14.5 MB forest master (the game plays the `.ogg`);
  - the eight replaced or unwired stand-ins;
  - `plaster_hole.png` (the level loads `plaster_hole_ring.png`);
  - the painted `forest.png`.

  Their bytes stay in `9bd0f19`'s history; only a rewrite of a pushed branch would reclaim them.
  ⚠️ Consequence: `tools/make_house_porch_art.py` cannot be re-run from a fresh clone. The
  finals it made are committed, and `prompts.txt` records how they were made.

## NEEDS A PLAYTEST

Claims the code cannot settle. Nothing here is a defect — it is what a hand-play or a harness re-run
has to answer before SPEC can state it flatly.

- **Does the doll beat land in its 2026-09-24 (c) form?** It was hand-played on 2026-09-24 in its
  2026-09-16 form (the trigger on the cellar note's close, the player pinned for the whole blackout,
  WHERE AM I? at 0.7 s, `screamer_house` at 0 dB), and the user's one note was that the gap from
  WHERE AM I? to the doll was about a second too long. It is now 1 s shorter (doll at 4.5 s,
  blackout 7.5 s, the scrawl gone 0.6 s before the doll). Does 4.5 s still read as "dark first",
  and does the scrawl still read as the player's own thought?
- ~~**The measured maze figures need the harness re-run.**~~ Settled 2026-09-24 (e): the raw
  generator is 233/400 = 58.3 % at 21.6 s, unchanged by the glass room. The player now meets the
  curated twelve instead (DECISIONS).
- **Do the twelve curated maps feel fair, and "not simple but not impossible" (2026-09-24 e)?**
  The harness says each is 12–14 / 20 for the bot, and every bot loss is the patroller. The things
  to watch:
  - does a human die to the HUNTER on any of them? The filters say it can always be outrun at
    every chokepoint by ≥ 1.2 s, at the icon's full speed.
  - is any layout a stand-out wall? The log names it: `MAP layout seed N` on every new attempt.
  - does learning the twelve across retries make the map too easy by the second visit?
- **Is 3-in-a-row the right death (2026-09-24 e)?** Two catches cost a jolt and 18 of panic, both
  clamped at 49 of 50. The third catch is the screamer and a level restart. Two cases to watch:
  - does a player who is caught twice notice the stakes before the third? Nothing on screen
    counts the streak.
  - does the clamp itself read? A player can sit at a full-looking bar in the map and not die,
    then die to the third catch at an empty bar.
- **How the furniture reads.** "Built from PARTS, never one flat box" is a legibility claim about
  beds, chairs, the table and the music box at ambient 0.0, and two playtests photographed the
  previous version. Only a screenshot from inside the level answers it.
- **`Lamp_Lock` as the level's one relief.** Whether a single warm point at the far end of a black
  house reads as a payoff or as an unexplained light needs a play, not a render.
- **The porch chain, end to end (2026-09-24, not hand-played).** Is the witch's note enough of a
  hint that the fruit behind the painting goes in the guillotine, or does the red thought on the
  porch carry it alone? Does a player who never walks up to the window ever get the porch — the
  window scare is the only way out, and nothing but the view through the glass points at it?
- **The forest clock's feel.** Measured +0.06 /s at the tree line and +2.00 /s deep, 25.0 s from
  calm to death — but whether "the bar holds at the edge" reads as a warning or as nothing happening
  (the HUD does not move) needs a hand-play. The numbers are the user's; only their legibility is open.
- **Are the ghosts seen?** The woman and the crawler read in the renders; the tall creature, far off
  among the trunks, measured faint even with `set_glow` 0.6. And the trunks are plain 14 m
  cylinders under billboard canopies — a forest of poles, or a forest?
- **The witch's two glimpses and two sightings (2026-09-24 d).** Glimpse placement is verified by
  the harness; whether a silent figure at 14 m through the glass is ever NOTICED is a playtest
  question. (Glimpse 2's "does the scream turn you round in time" is answered: it did not, and it is
  deleted.) For the sightings:
  - does sighting A, the scream and the forced turn onto her in the Bedroom doorway ~2.4 m away,
    read as *seen*? Does 1.5 s hold long enough, or too long, to be a pinned player's picture?
  - does a forced turn with **no panic** still land as a scare, or does the user want the nook's
    cost after all? That is a new panic term, so it is the user's call; none was built.
  - B (8 minutes): does a long stay get it, and does a 180° whip in 0.45 s read, or disorient?
- **The user's sounds in the mix (2026-09-24 b).** Gains were set from measured loudness, not by
  ear: the forest track at −8 on AMBIENCE, the glass at +4, the melon at +8, the witch at 0, and
  `ghost_sound` pitched 1.1 / 1.35 / 0.62 for the woman / crawler / tall one. Does one recording
  pitched three ways still read as three different things?
- **Is the corner findable across a few deaths (2026-09-24 d; it was "before the clock bites" at c)?**
  There is no hint, by the user's decision. The blade is at d = 25.5 m in the far north-west corner,
  behind one thick trunk, invisible from the rail gap and the forest's middle (16/16 rays). A player
  who knows where it is pays 17.2 of 50 from calm, or peaks at 41.2 straight after the window scare
  (it was 10.6 / 34.6 at the old clearing). The user asked for "probably in several runs". Two
  things to watch:
  - does the player find it within one or two sorties, retreating to the deck to let the bar drain
    between them?
  - or does the first sortie, taken right after the scare at 25, end in a forest death with the
    blade never seen?

  The constants are the user's. Only the answer is open.
- **Is the blade legible in the stump?** ⭐ Since 2026-09-24 (d) it is the generated art (the
  bolted bar and the rusted steel read under the torch in `20`/`23`, and in the frame in `27`). In
  the stump it is 0.50 × 0.28 m. At a 24° lean and a 0.08 m bury, it read as a plate lying on the
  cut in the verification render. It now stands near-upright (`BLADE_LEAN_DEG` 8°, `BLADE_BURY`
  0.12), and `23_stump_close` reads as an axe driven into a chopping block. It is still small
  against a 0.8 m stump; whether it is recognisable when first seen is the playtest's question. The (c) observations below were of the old box blade:
  - `20_stump_torch_4m`, `23_stump_close`: the stump reads clearly by torch (the pale cut top), and
    since the duller steel (above) the blade in it reads **grey**. It was a dark wedge at metallic
    0.85, because this project has no environment for the steel to reflect.
  - `21_stump_moon_only`: the stump sits in a trunk's shadow band, a silhouette at best.
  - `22_stump_from_the_straight_line`: hidden behind trunks, as designed.

  (The duller steel was done on the user's call the same day, and the art has since replaced it.)
- **Does WHERE IS THE BLADE? teach the second need?** A player who presses E on the bare frame gets
  it before ever holding the fruit. Does it read as "go and find the blade", or as a riddle?
- **The cellar beartrap on the forced-blind entry line.** The user's decision, and it fired in both
  playtest sessions. Now that the blackout also *pins* the player, the collision's shape has changed
  and wants re-observing.
