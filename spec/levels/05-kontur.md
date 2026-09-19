# Level 5 — KONTUR — spec

> ⚠️ **SPEC-FIRST.** This file is the live representation of this level. Plan a change here (marked `🔨 PLANNED`) *before* writing code, then drop the marker and record the rationale below once it is built. See `CLAUDE.md` → SPEC-FIRST.

## SPEC

**Level 5 — KONTUR ("Object 12")** — `kontur.gd` + `kontur.tscn`
- ⭐ **2026-09-16 (K3):** `Screamer.trigger()` drops the picture for ANY death that lands while a
  lunge is in progress (the condemn bar's own death raced the lunge and showed it).
- ⭐ **2026-09-16 (R7–R9):** every `trigger_with_lunge` death ends in **black, no static image**
  (`Screamer.trigger(_, with_image=false)`); the archive keycard's notice uses the lower caption
  slot; the Blackout plug is **solid while lit** (Issue 215).
- ⭐⭐ **2026-09-13 (K1–K4):** the hammer is **parts lying on the bench** (`kontur_hammer.png`
  retired); the cell's front is an **open barred face** (eight Ø30 mm bars off the centre line,
  rails, a gate section with a lock; no leaf, no port — the sightline sweep still sees all 23
  headings); the **condemn sentence is staged** (`_tick_condemn_beats`: whisper + roll → edge
  `Watcher`s that vanish when looked at + `kontur_condemn_bed` → black/red cuts quickening → a figure
  at arm's length → the bar kills; `condemn_beats()` is the test surface); the Blackout figure is
  **placed where the camera points** (`_place_blackout_figure`, frustum-first fan, `turn_to_face`
  fallback; `check_kontur_figure_frame`).
- ⭐⭐ **IN-WORLD DEATHS SINCE 2026-09-14 (`BACKLOG_Sep_14.md` K1–K2, the user's design).**
  `Screamer.trigger_with_lunge(tex, ahead, reach, time)`: the player is pinned and turned, a glowing
  `DoorLunger` (`kontur_figure.png`, keyed by `tools/cutout_black.py`) stands `ahead` metres away
  (rays at eye AND waist height, short of any wall), lunges to `reach` with the level's own sting AT
  it, then `trigger()` runs unchanged with the 2D sting suppressed — the funnel and every test on
  `_is_triggering` are untouched. The **yellow phone** (`ahead` 1.0 — the desk has no collider,
  Issue 209) and the **Perëkozhnik** (`death_figure` export, KONTUR only) use it; the **condemn
  finale** at `CONDEMN_FINAL_AT` 18 s kills every lamp and the torch, holds `CONDEMN_DARK_HOLD` 2 s,
  brings them back with the figure `CONDEMN_FINAL_AHEAD` 1.5 m ahead and lunges to black, the bar
  held at `CONDEMN_HOLD_RATIO` so the lunge is the death (Issue 210). The cell wears **bars on the
  WEST face too** (K1: seven Ø30 mm bars at −0.58…0.62, none on the occupant's line, a 0.1 m shift
  off the south-west sightline diagonal); `_port_panels`/`PORT_*` dead code is gone. Guards:
  `check_kontur_condemn`, `check_kontur_phones` (yellow → lunge → funnel), `check_kontur_entities`,
  `screenshot_kontur_lunge.gd`.
- ⭐⭐ **A WRONG ACTION IS FATAL SINCE 2026-09-13 (`BACKLOG_Sep_13.md` K2, the user's design).**
  `_strike()` → `_condemn()`: the red sentence **YOU'VE DONE SOMETHING WRONG. YOU WILL PAY FOR
  IT.**, decay pinned, panic on an ease-in curve to `PANIC_MAX` at `CONDEMN_TIME` 20 s (the bar's
  own screamer kills), lamps red, a rising drone (`kontur_condemn.wav`). The 2D flash,
  `STRIKE_PANIC`, `_strikes` and the Archive's "N OF 3 LOGGED" are GONE — every "three strikes"
  sentence below is history. ⚠️ Gate 8's MISTIMED catch is one of the callers and is therefore
  fatal too (reported to the user). Also: the containment cell has a **barred gate** on its
  front (K1; no grid behind the glass — each attempt blinded a sightline heading), the Blackout
  figure stands 2.6 m past the doorway at a pale tint (K3), the phones' prompt names both keys
  (K4, `prompt_text()`), and the real seam is plugged with wall under the torch (K5, Issue 198).
  `check_kontur_condemn.gd`.
- ⭐⭐ **FIRST HAND PLAYTEST + REWORK (2026-09-09), the user's verdict "not scary, not packed."** Full
  evidence and decisions in `backlogs/05-kontur.md` §3a/§3b. The scary half: opening the black door
  **blows every light but the torch** (`_begin_cell_blackout`, restored at the Kitchen) and **Object 12
  charges the glass** as you pass in the dark (`ContainmentCell.charge`, zero panic, cannot kill). The
  packed half: **Gate 6 is now three phones** (see below), **the vinegar is hidden behind a tear-away
  notice** (Gate 2 below), a **PA tannoy** runs on a timetable (`_tick_pa`, zero panic, no answers), a
  **figure stands in the gate-7 dark** visible only torch-off (`_make_dark_figure`). Guards:
  `check_kontur_blackout.gd`, `check_kontur_phones.gd`. Everything added charges **zero panic** except
  the phone gate's unchanged pressure and the blue-phone hallucination.
- **The level whose answers are not inside it.** **Eight** gates, each a *different verb*, each
  answered by a hint planted in an earlier level. A player who explored reads straight through; one
  who rushed must guess, and guesses cost panic they cannot get back. Built procedurally by
  `kontur.gd` via `RoomBuilder` from a 13-room spine (Landing → Vestibule → **AnteWest/AnteEast** →
  Passage → Kitchen → **Records** → Archive → **Switchboard** → **Blackout** → Airlock → Escort →
  Terminus, z −4…98), same `.tscn`-minimal / `PRESERVE`-whitelist pattern as the Lab and House
  - ⭐ **…AND SINCE 2026-08-18 THE LEVEL SAYS SO, ONCE, IN THE SPAWN ROOM** (`_spawn_briefing_notice()`,
    the user's call on backlog H5). That premise used to be stated **nowhere in the game**: the only
    place the principle appeared was the banishment scrawl, which fires *after* a wrong door — i.e.
    only to the players who have already lost a level to it. `NoticeBriefing` hangs on the Landing's
    north wall, east of the doorway, facing back at the player as they materialise, and reads
    **YOU WERE BRIEFED ELSEWHERE.** over *NO COPY IS HELD ON THESE PREMISES.*
    - ⚠️ **A PRINCIPLE, NEVER A PLACE, and it is asserted rather than intended.** It names no gate,
      no answer, no earlier level and no room — `check_kontur_signs.gd` scans its text against every
      gate's operative word plus the room names read out of the scene's own `ROOMS` table, with
      three positive controls (a colour, a number, and a room name taken from the scene). This is
      `kitchen_drawer.gd`'s rule-not-a-position discipline applied to the whole level
    - ⚠️ **Nothing gets easier.** Zero panic, no rule, no gate, no trigger volume. What changes is a
      stuck player's *reading*: "I am missing something in this room" becomes "I should have read
      more", which are opposite behaviours in a level with no decay
    - ⚠️ **It is BOTH a wall notice and a `note.gd` page, and both halves are load-bearing.** The
      target reader is the one who rushed, and a statement they must walk up to and press E on is a
      statement they will skip — so the ART carries the principle, measured legible at **17.1 px of
      cap height from the player's own spawn 7.10 m away** (floor 15). The note body carries the
      full memo and archives it via `GameState.record_note()`, because the principle is worth
      re-reading two gates later. `corridor.gd:_spawn_nightmare_plate()` is the same pairing
    - ⚠️ **It is NOT a ninth gate sign.** It carries **no censor bar** (asserted, the mirror of the
      eight signs' own assertion), a different form series (1-А) and a different shape
      (1500×1300 against the signs' 1500×1000), so it cannot read as a rule the player failed to
      decode. `tools/make_kontur_notice.py` generates it; `check_kontur_signs.gd` still asserts
      there are exactly **eight** redacted signs, so it cannot quietly join them
    - ⚠️ **The hero line is three words because of arithmetic, not taste.** For a plate of fixed
      width the achievable cap height is ≈ `1.06 × width_m / longest_line_chars` — the aspect is
      irrelevant, only the width and the character count bind. At 1.70 m wide, "ELSEWHERE." (10)
      gives 17.1 px at the spawn; "YOU WERE BRIEFED" (16) would have given 12.6 and been unreadable
      from exactly where it is meant to be read
- ⭐ **THE SOVIET HALF IS DARK (2026-09-03, the user's call, D2).** `DARK_AMBIENT` 0.02 and the
  nine lamps from Landing to Switchboard at `SOVIET_DARK` 0.0. ⚠️ **THE SOVIET HALF ONLY** — the
  clinical Airlock/Escort/Terminus wing keeps every lamp, and that limit was taken deliberately
  with the user rather than as a half-measure: Gate 7's entire puzzle is that the Blackout room is
  the room with no lamp, which stops being a place in a level where nothing is lit, and
  `_ev_escort_begins()` needs lamps to kill as you commit to the escort corridor. The darkness
  therefore runs exactly to the Blackout, which is where the visual arc already changes register.
  ⚠️ Every `Label3D` in the level is now `shaded = true` and the Gate 6 hammer is
  `SHADING_MODE_PER_PIXEL`: `Label3D` is UNSHADED by default, so with the torch off the stencils,
  the mailbox slot numbers and the Archive lot cards were the only things on screen, floating in a
  black room. ⚠️ **ONE exception**: Gate 3's offering pedestal keeps its 1.1-energy glow, because a
  bait keycard on an unlit pedestal is not bait — asserted by parent name in `check_darkness.gd`.
- ⚠️ **The PassageA/B `DarkZone` is GONE** (D4) — it sat under the level-wide `DreadZone`, i.e.
  **+5/s with no way down**, in a corridor the player now has no way to cross unlit. Issue 18, and
  the same argument this file already makes for why Gate 7 has never had one.
- **Visual arc = the story**: peeling Soviet wallpaper (`kontur_wallpaper_soviet`) → raw infected
  concrete (`kontur_concrete_infected`, the `CONCRETE_ROOMS`) → clinical KONTUR tile
  (`kontur_facility_wall`, the `FACILITY_ROOMS`, which reuse `lab_floor`/`lab_ceiling`). Done entirely
  with `RoomBuilder`'s per-room `wall_mat`/`floor_mat`/`ceil_mat` overrides in `_rooms_with_skins()`
- **Gate 1 — THE TWO DOORS** (`choice_door.gd`, *choose*): a black and a red door in the vestibule.
  Which side is black is **randomised per run**, so the answer is the colour, never a position. The two
  doors open into **two separate antechambers**, and `_open_the_void()` deletes the floor behind the red
  one — the wrong door is a **hole**, not a decoration. Hint: hidden note in the **Lab morgue**
  - ⚠️ **BOTH LEAVES WERE 1.571× SQUASHED AND BOTH TEXTURES WERE A PICTURE OF THE CONCRETE WALL AROUND
    THEM** (K-T1, fixed 2026-08-18) — Issue 35 / X24's sixth recurrence, on the one prop in the game
    whose entire task is telling two things apart, and where a wrong answer does not cost a strike but
    drops the player through the floor and demotes them a level. `tools/crop_kontur_art.py` crops both
    to the leaf (`door_{black,red}_leaf.png`); the originals stay as the crop's only input.
    ⚠️ `ChoiceDoor.HEIGHT` is now **DERIVED**: `WIDTH` 1.4 is fixed by the doorway, `LEAF_ASPECT`
    0.7485 is the mean of the two crops, and `HEIGHT` = 1.87. ⚠️ **Both doors must stay the same size**
    or the SHAPE becomes a second tell alongside the colour, so a single constant serves both and
    `_build()` warns if a texture drifts more than 8 % from it
- **BANISHMENT** (`_check_void_fall` → `_banish`, threshold `y < −4`): falling out of the world does not
  kill you, it **demotes** you. `GameState.kontur_banished` is set (it survives the transition because
  `reset_level_state()` deliberately doesn't clear it, the same trick `is_ending` uses), `current_level`
  drops to 4, and `backrooms.gd:_check_banishment()` greets you with a blood-red scrawl — *"YOU DIDN'T
  READ. THE COLOUR WAS WRITTEN DOWN SOMEWHERE YOU DIDN'T LOOK."* — then clears the flag so it shows once
- **Gate 2 — THE SHELF** (`bottle_item.gd` + `fungal_barrier.gd` + `wall_sheet.gd`, *use*) — ⭐ **THE
  VINEGAR IS HIDDEN NOW (2026-09-09, captures #5/#6).** The shelf shows only WRONG agents (**bleach /
  poison / water**; poison a new `vial` silhouette + `label_poison_paper.png`); the vinegar is behind a
  **tear-away KONTUR notice** (`WallSheet`) near the barrier — E tears it off and the vinegar is on the
  ledge behind, no hint. A player who never tries the notice must guess and pay a strike. Save/restore
  carries `vinegar_revealed`. The barrier is a fungal mass sealing the way on. Vinegar dissolves it
  (canon: acetic acid retards O-41); a wrong bottle is **consumed**, so a bad guess costs a walk back
  as well as a strike. Hint: the **House TV** static resolves into a KONTUR test card every ~16–26 s
  - ⚠️ **THE THREE BOTTLES WERE THE SAME CYLINDER WITH A 1.733× SQUASHED WORD ON AN OPAQUE BACKDROP**
    (K-T2, fixed 2026-08-18). All three labels shipped as 8-bit **RGB** on a `TRANSPARENCY_ALPHA`
    material, i.e. each bottle wore an opaque rectangle of the generator's studio background — the
    vinegar bottle was carrying a bright yellow flag. `tools/crop_kontur_art.py` keys those backdrops
    into real alpha (`label_*_paper.png`) and the label quad is sized from the artwork, with a floor on
    its width because scaling purely off the body radius gave the slim flask — the RIGHT bottle — the
    smallest word on the shelf. ⚠️ The bottles also gained distinct silhouettes via
    `BottleItem.PROFILES`: **flask** (tall, slim, corked, dark green) / **jug** (squat, shouldered,
    handled, opaque) / **carboy** (short, wide, wide-mouthed). Issue 35 applies to a shelf as much as
    to a bed — three identical cylinders read as three identical cylinders at any distance where the
    words are not yet legible. ⚠️ **This changes nothing about the answer**: shape says nothing about
    which agent retards O-41, and a player who never found the House hint still guesses and still pays
    a strike. ⚠️ `BottleItem.build_visual()` is `static` and excludes the collider, because the
    Perëkozhnik wears one of these as a disguise and a mimic must be built from the SAME geometry as
    the thing it imitates
- **Gate 5 — THE ROSTER** (`combination_lock.gd`, *recall*): a personnel gate in Records welded shut
  until you enter **`ROSTER_CODE`, currently 63**. ⚠️ Was **47** ("You are Subject 47", the intro
  note) until BACKLOG #24 — which made the one gate designed to be answered from memory into the one
  gate nobody had to look for, since the answer had been on screen in the first minute and sat in the
  level's own objective text. The code now has **no other source anywhere in the game**: both digits
  are on two notes in the **Backrooms Flood**'s side runs (WestRun / EastRun,
  `backrooms_zone3.gd:_build_digit_notes`), deliberately off the route from the Descent to the Sump,
  so clearing KONTUR requires having actually searched the flooded wing a level earlier. That is a
  hard dependency; the notes journal and the level-progress snapshots are what keep it fair. Nothing
  in KONTUR states the number; the plate just leaves the field blank. The lock now **sizes itself from its answer**
  (`_digit_count()` in `combination_lock.gd`) — it used to be hard-coded to 3 dials, and "47" on a
  3-dial lock is ambiguous (047? 470?); a playtester who knew the answer still failed it twice. The
  lock gained `code` / `title_text` / `unlocked` / `wrong_code` so it can serve two levels without
  touching `GameState.level2_code`. **Rebuilt 2026-07-25** (capture #5, "the 2d texture on top of a 3d random cube"): the casing carried
  green emission at 0.4, which — emission being most of a surface's colour here — rendered it as a glowing
  mint box with a picture stuck to one face, and the art quad squashed a 1.5:1 landscape source onto a
  0.75:1 portrait mesh. It is now a **landscape** body with a four-bar bezel RIM (a solid bezel slab buried
  the plate — its face landed ~2 mm from the artwork), corner screws, a recessed `kontur_lock_roster.png`
  plate sized from the source aspect, and a real dial `CylinderMesh` laid on its side beside it. Body
  emission is gone; the **art quad** carries 0.35 instead, since this is still a gate that must be found on
  a dark wall (Issue 27's documented split, Issue 33). `combination_lock.gd`'s 2D dial UI is untouched
- **Gate 3 — THE OFFERING** (`offering_pedestal.gd`, *abstain*): a keycard glowing on a lit pedestal,
  deliberately identical in read to the Lab keycard the player has spent five levels being trained to
  grab. The exit is **already open**. Taking it **forfeits the run**; walking past is scored silently on
  entering the Switchboard. Hint: the **Corridor** door plate at d=172 m ("RECOVERED ITEMS ARE BAIT")
- **Gate 6 — THREE PHONES** (`rotary_phone.gd` + `kontur.gd`'s `_tick_phones` cycle, 2026-09-09, the
  user's design) — ⭐ **REPLACED the single "destroy the phone" gate.** Yellow / blue / green phones
  spread around the Switchboard, one ringing at a time; **only the ringing one charges panic, at
  `PHONE_PRESSURE_RATE` 2.0/s** (was 4.5) within 7 m. **E answers, Space smashes** with the hammer (a
  general `secondary_interact()` added to `player.gd`). **Smash yellow and blue, answer or smash
  green.** Answering YELLOW = a loud jumpscare and the run is lost (`Screamer.trigger`); answering
  BLUE = a despairing voice + panic to ~90% + a hallucination (camera roll, edge `Watcher`s, whisper),
  survivable and one-shot, and it STILL must be smashed; answering GREEN = a colleague's voice giving
  the Breach quest obliquely, and it resolves. **Smashing green loses the hint, no strike.** The mimic
  stays a 4th, COLOURLESS, never-ringing phone. The colour rule is **one memo per colour, spread one
  per room** (`PHONE_NOTE_GREEN` in the Passage / `PHONE_NOTE_YELLOW` in the Kitchen /
  `PHONE_NOTE_BLUE` in Records, real `note.gd` pages, archived). Voices by `tools/make_kontur_voice.py`
  (`phone_green_voice` / `phone_blue_voice`). Guard: `check_kontur_phones.gd`. ⚠️ `rotary_phone.gd`'s
  `interact()` SPLITS on `open_note`: the Backrooms keeps its read-to-die lock; KONTUR's phones emit
  and the level decides.
- **Gate 7 — THE BLACKOUT** (*unlight*): an unlit room with three door seams on the far wall. The real
  one is visible **only with the flashlight OFF**; the two that glow under the beam are painted on and
  cost a strike. ⚠️ **No `DarkZone` here** — a room solved by turning the light off must not also tax
  the light being off (+3/s *and* decay suppressed, +5/s with the level DreadZone). Issue 18. The Airlock/Escort/Terminus spine is **built at whichever of three x offsets was
  drawn**, so the answer moves every run. Hint: the **Backrooms Flood**, and (**BUG_FIX.md 3.2**) a
  second one inside KONTUR itself — the Landing mailbox, upgraded from a flat wall decal to a real
  interactable (`KonturMailbox`, `kontur_mailbox.gd`), opens on a note: *"I stopped switching them on.
  I am too afraid of what the light finds..."*
- **Gate 8 — THE AIRLOCK** (*catch* — was a 9 s stillness *wait* until **BUG_FIX.md 4.6**): playtest
  read the old hold-still cycle as "boring, you just stand and wait." Replaced with a catch minigame
  on the same wall meter: a marker oscillates across a fixed track (`AIRLOCK_MARKER_PERIOD=2 s` per
  full sweep) and pressing **E** while it's inside the lit target band (`AIRLOCK_TARGET_WIDTH=35%` of
  the track, centred) counts as a catch; `AIRLOCK_CATCHES_NEEDED=3` in a row passes the gate. A miss
  calls the level's normal `_strike()`. This still **inverts** the Backrooms rule
  that standing still raises panic, and no earlier level hints at any of it — so unlike every other
  gate it still has to **teach itself**, now via the visible track + marker instead of a fill bar
- **Gate 4 — THE ESCORT** (`escort_gate.gd`, *camera discipline*): 26 m with the lights dead behind you.
  Heading may not stray more than `LOOK_LIMIT_DEG=100°` from the corridor axis; `COOLDOWN=3 s`. The
  **first look is free** (`ARM_AT=0.16`) and emits `warned` instead — the lights dying behind you is
  itself an invitation to turn, and a playtester forfeited 1.5 m in, before the temptation or the sign.
  The rule's sign hangs in the **Airlock**, read while standing still for gate 8, not inside the
  corridor it governs. **The
  rule now has teeth**: a `tempt(stage)` signal paced on *distance* (`TEMPT_AT = [0.18, 0.45, 0.72]`,
  measured on progress so a cautious and a brisk player both get all three) fires footsteps behind you,
  then a whisper, then a blood-red **"LOOK BEHIND YOU"** on the screen. It is a lie, and obeying it
  forfeits the run. Diegetic first, text last — a UI that lies about something you can already *hear*
  reads as the level's voice rather than as a cheap trick. Hint: **Backrooms** east-arm dead-end scrawl
- **The exit actually locks** (Issue 16): `_make_door` used to leave `unlock_condition = NONE`, so the
  level was completable having failed or skipped every gate — it cleared in **32 seconds**. `door.gd`
  gained `extra_lock` + `locked_message`; `kontur.gd` holds a `_gates` ledger and `_refresh_exit()`
  keeps the door sealed until all eight pass, naming the shortfall on the door itself
- **FORFEIT**: the three *abstain* gates (offering / phone / escort) cannot be un-failed, so failing one
  voids the run — `_forfeit()` fires a scrawl, rewrites the objective **and** the exit door's locked
  message within a second. That loudness is load-bearing, not polish: a sealed door with no explanation
  reads as a bug rather than as a verdict
- **Fail economy (unique to this level)**: the whole floor is one `DreadZone` (sized to span z −4…98 —
  a short zone silently stops applying partway down the spine). `DREAD_DECAY_RATE` and
  `DREAD_PANIC_RATE` are both 2.0/s in `player.gd`, so they **cancel exactly** — panic never drains
  here. **There is no bespoke
  death path in `kontur.gd`**, and no `player.gd` changes were needed for any of it
- **Redacted signs** (`_make_sign`): each gate's rule is stated on a wall plate with the operative word
  replaced by a censor bar, so a player who missed the hints gets the shape of the question but not the
  answer. ⚠️ **There are exactly EIGHT of them, and the Landing's briefing notice is deliberately not
  one** — it carries no censor bar and its own artwork name, and `check_kontur_signs.gd` asserts both
  the count and the difference. ⚠️ **They are REAL PRINTED DOCUMENTS since 2026-08-18** — eight generated notices
  (`tools/make_kontur_signs.py`, Pillow, deterministic) with an oxblood `К.О.Н.Т.У.Р.` head band, a
  form number, the rule set in type, a censor bar **struck into the image** and a Russian
  counter-signature. The old `Label3D`-over-`kontur_sign_blank.png` and the separate black bar quad are
  gone. **The redaction being baked is the strongest form of it**: the operative word is never rendered,
  so there is no layer to peel and nothing that can drift out of alignment with the bar.
  ⚠️ **THEY WERE UNREADABLE AND NOBODY HAD MEASURED IT.** These are the level's only in-level help, and
  from the line a player actually walks the rule's cap height was **5.1 px on the gate-1 sign and under
  9 px on five more** at 1080p. Three things fixed it, all driven by the measurement: the gate TITLE
  dropped to a kicker and the RULE became the hero; the line break is chosen by trying 1, 2 and 3
  balanced splits and keeping whichever yields the largest type that still fits its leading (a
  word-count rule left "APPROVED AGENT: DOMESTIC" on one 24-character line at 13.3 px); and the plate is
  **1.4 × 2.1 m**, sized from the artwork's own 1.5 aspect. Worst sign now **15.7 px**, best 63.2, floor
  15. `check_kontur_signs.gd` finds the ink by thresholding rows of the imported texture — never a
  constant shared with the generator, which would agree by construction — and converts through the quad
  size, the camera's own FOV and the reading distance; its control stamps the rule back at a quarter
  height and requires the same measurement to call it unreadable. ISSUES_SOLUTIONS **145**,
  cross-level **X55**. ⚠️ Emission is **0.40 with `EMISSION_OP_MULTIPLY`**, not 0.55 with Godot's
  default ADD — an emission colour beside an emission texture lays a flat wash over the artwork
  (Issue 81 / X30), and the card is a mid-tone printed sheet now rather than a near-blank plate.
  ⚠️ `wall_point()`'s inset is measured from the room's NOMINAL boundary, but the wall's inner face
  is `T/2` (0.1 m) in from that — so clearance = `inset − 0.1`. An inset of **0.10 is exactly
  coplanar** and z-fights (it sliced the morgue poster apart); below that the plate is buried
  (Issue 11). `wall_point()` now clamps to a 3 cm minimum clearance itself (Issue 26), so 0.16 is
  still the house style but no call site can get it wrong. Props needing depth behind them —
  `LivingMirror` hangs its figure 0.05 behind the glass — need **0.22**
- ⭐ **The Perëkozhnik** (`creature_shapechanger.gd` + `mimic_shell.gd`): a billboard mimic that
  **wears an ordinary prop until you touch it** (2026-08-18). It never moves or chases and is **not** a
  gate — it feeds gaze panic and kills only within `KILL_DIST=2 m`. Its 16 panic/s stare
  exists to punish the one instinct this level otherwise rewards: walking up to
  something for a better look
  - ⚠️ **THE DISGUISE ADDED NO RULES AND CHANGED NONE.** `GAZE_INTENSITY` 0.8, `KILL_DIST` 2.0, "never
    moves", "not a gate" — all untouched. Its name means *shapechanger* and for its whole life it was a
    static billboard in the Passage's west corner that a player who never swept a torch there simply
    never met. It now stands at one of `MIMIC_SITES` — **a fourth bottle on the kitchen shelf** or **a
    fourth phone on the switchboard desk** — drawn per run and **restored, never re-rolled**, on a
    back-door return (K-T6's rule applied to the level's third randomisation)
  - ⚠️ **THE TELL IS A COUNT, and it stays wrong for as long as you care to look.** The kitchen has
    three shelf slots and four bottles, two of them wearing the same label, and the fourth stands off
    the three-slot rhythm at z=21.9. The switchboard has four phones and **only one of them is
    ringing** — and the ringing one is the gate. A mimic with no tell is a coin flip
  - ⚠️ **LOOKING AT THE DISGUISE COSTS NOTHING.** `MimicShell` is a **sibling** of the `ScaryObject`,
    never a child (`player.gd:_find_scary_object()` walks UP from the collider it hit), and the
    figure's gaze collider is `disabled` while disguised. In the one level with no decay at all,
    charging 16/s for reading four labels would be indefensible
  - ⚠️ **IT CANNOT COST A GATE AND CANNOT KILL YOU WITH THE TOUCH THAT REVEALED IT.** The shell is not
    a `BottleItem` and not a `RotaryPhone`: E consumes no bottle, spends no strike, answers nothing and
    smashes nothing. You interact from ~1 m and `KILL_DIST` is 2 m, so the figure is revealed at a MARK
    ≥ `REVEAL_MIN_DIST` 3 m away with line of sight — it does not walk there, the disguise simply stops
    being true, and from that moment it stands still forever exactly as before. The mark is validated
    by **rays only** (floor, headroom, a 16-ray fan at the figure's own half-width, and the LOS ray,
    which is the member of the set that catches "inside a wall" — Issues 40/59), and if nothing fits
    the figure is **skipped** and the disguise just vanishes. ⚠️ That validation runs 0.6 s after
    `_ready()`, not inside it: CSG colliders are not registered during `_ready()` (Issue 52), so rays
    fired there hit nothing and approve everything
  - ⚠️ **ZERO panic on the reveal** — a sound (`perekozhnik_shed`, gain +10.2 dB derived from its
    measured −21.88 dBFS RMS against `door_seal`'s −11.67) and a 0.08 camera jolt. No `add_panic`, no
    `flash_scare`, no strike
  - ⚠️ Its billboard is **sized from the cutout** now (K-T4). The canvas was 1024×1536 on a 0.9×1.9
    quad — a 1.407× squash — and measured on the alpha channel the FIGURE inside it was a man 1.64 m
    tall and **0.38 m wide**. The quad is sized so the figure lands at `FIGURE_H` 1.78 m and dropped by
    the transparent margin under its boots; the gaze collider wraps the figure, not two thirds of empty
    canvas
- ⭐ **OBJECT 12, CONTAINED** (`containment_cell.gd`, 2026-08-18): the level is named after it and the
  player never saw it, while the very next level is *Object 12, loose*. A steel-and-glass isolation
  booth stands in the **Passage** at `CELL_POS (2.75, 0, 16.9)` with the Breach's own
  `hollow_crown.glb` inside it, wearing `creature_object12.gd`'s palette — that is the feature, not a
  shortcut: meeting it here and being hunted by it one level later have to be recognisably the same
  thing
  - ⚠️⚠️ **HUE SHARED, LEVEL SCALED (revised 2026-08-18) — it used to be "retinted EXACTLY", and the
    picture that produced was a pale beige smiling man in a suit.** `SPECIMEN_ALBEDO` and
    `SPECIMEN_EMISSION_COLOR` are still that script's colours verbatim and are marked not to be
    re-picked; `SPECIMEN_DIM` (0.45), `SPECIMEN_EMISSION` (0.16) and `SPECIMEN_SPECULAR` (0) are
    this level's. ⚠️ **`material_override` was reaching every mesh** — one `MeshInstance3D`, override
    set, no `AnimationPlayer` — so CLAUDE.md's own standing Mixamo warning was the wrong hypothesis
    and is disproved in writing. **The same material is not the same picture**: the Breach meets this
    creature across a lit facility, KONTUR meets it at 1.5 m with a 1.2-energy torch on it in a room
    lit at 0.45. Measured, the shipped material rendered **1.8–2.8× brighter than what was behind it
    and 4.1–4.5× brighter than the booth's own steel**, with a hotspot clipping to 0.98. Setting the
    three constants back to `1.0 / 0.35 / 0.5` makes it byte-equivalent to the Breach's again.
    ISSUES_SOLUTIONS **Issue 147**
  - ⚠️ **DARKENING ALONE CANNOT WORK, AND THAT IS THE GENERAL LESSON.** Sweeping the albedo down, the
    occupant reaches parity with its background at ~0.30 and passes under it at ~0.22 — but the
    measured contrast there is **0.006–0.09**: it goes invisible before it goes dark. `watcher.gd`'s
    premise is *a dark shape OCCLUDING A LIT SURFACE* and this booth had no lit surface in it. The
    three interior faces the player can never reach are now **backlit liners** — `LinerEast` (an
    opaque panel replacing the east pane, which stands 0.15 m from the Passage wall and is
    unreachable) plus one-sided `QuadMesh` panels `LinerNorth` and `LinerSouth`. ⚠️ Emission
    illuminates nothing in this project (no GI, no glow), so a liner raises the BACKGROUND without
    touching the figure, which is the whole reason it works
    - ⚠️ **The north/south panels are ONE-SIDED (`CULL_BACK`) and both obvious builds failed.** A
      *frosted backlit pane* lays its emission over everything behind it, so from the north the same
      veil landed on the figure and on the wall alike — contrast 1–3 %, i.e. it made the occupant
      invisible from four headings it had been fine at, and lifted the whole frame 0.05 → 0.25. A
      *four-slab inner door liner carrying the same port opening* backed the figure everywhere except
      behind the figure, because the occupant stands at exactly the height the hole is. One full
      panel facing +z, drawn from the north and culled at the port, solves both
  - ⚠️ **The glass is `roughness` 0.22, not 0.08.** At 0.08 the pane is a mirror and the torch put a
    near-pinpoint glare on it which, because the player faces the booth head-on, landed **on the
    occupant's chest** at 0.90 luminance. It was diagnosed as a highlight on the creature twice; it
    survives `metallic_specular = 0`, an albedo of pure black, emission off, and the flashlight
    switched off entirely
  - **Measured after the pass, 23 reachable headings, occupant against what is directly behind it over
    one identical eroded pixel mask:** every heading shows it (7 097–67 169 px, was 0 at six of them);
    occ/bg **0.52–0.77** (was 0.36–2.79, brighter at seven); contrast **0.231–0.483**; whole-frame mean
    0.048–0.104 against 0.043–0.058 before, so the backlighting did not turn the booth into a lantern
  - ⚠️ **`tests/check_kontur_entities.gd` now asserts that it can be SEEN**, which is the gap that let
    all of the above ship: 143 assertions about what the prop does *not* do and not one about the
    picture. Headless half — every renderable carries the published `occupant_material()`, albedo,
    emission and specular under documented ceilings, no `AnimationPlayer` playing, and line of sight
    from **every** reachable heading (12 body points, ≥3 clear, segment/AABB against the booth's
    opaque solids), with a live control that plugs the port and requires ≥4 headings to go blind.
    Photometric half — **`tests/screenshot_cell_visibility.gd`**, which needs a display and is
    therefore outside `run_tests.sh` like every `screenshot_*`. ⚠️ Its mask is built with the glass
    HIDDEN and the levels read with it back: an alpha-blended pane perturbs on every pixel when the
    occupant is hidden, so a naive diff mask picks up the whole pane including the ceiling fixtures
    seen through it
  - ⚠️ **NO RULES AT ALL** — the `watcher.gd` contract verbatim: no `ScaryObject`, no gaze panic, no
    kill radius, no `Screamer`, no trigger volume, no `interact()`, **zero panic**. The occupant has no
    collider; the booth has one. It turns its head to follow you at `TRACK_RATE` 0.9 rad/s and that is
    the whole thing
  - ⚠️ **IT MUST NEVER BECOME A PURSUER.** `SCARY.md` §8.4 is one chase level in twelve and that level
    is 6. If a future session wants this to open, it is a new level, not an edit
  - ⚠️ **IN THE PASSAGE BECAUSE THAT IS THE THINNEST ROOM ON THE SPINE**, and deliberately not in a
    gate room: gate 1 is at z=10 and gate 2 at z=27, so the seven metres between them were the longest
    stretch of the level with nothing in it. It is something you come upon, never something a puzzle
    points at. The Perëkozhnik used to stand in this room's west corner and now wears a disguise
    elsewhere, so the Passage is exchanging a billboard nobody reliably saw for something on the
    walking line
  - A positional field hum (`object12_cell`, `HUM_DB` −18 derived from the file's measured −10.87 dBFS
    RMS, `unit_size` 7) gives it a bearing before it is seen. The glass is dark and **not emissive** —
    a lit pane hides what is behind it, which is the prop
- ⭐ **THE ARCHIVE IS TEXTURED (2026-09-10, capture #13, the user's scope: *"Archive lots and racks
  only"*).** `_mb_mat()` gained an optional triplanar `tex` (negative V, the albedo as tint;
  every old caller byte-identical). Racks on `archive_rack_steel.png` (tinted ~0.5 so they are not
  the brightest thing in the room again), linen / tin / bakelite / music-box walnut on the lots,
  the **217 plate is Pillow-engraved art** (`tools/make_archive_plate.py` over a flux brass blank,
  on a quad sized from its aspect; the `Label3D` is gone), and the hidden keycard is a **facility
  pass** (`tools/make_archive_keycard.py`: Cyrillic header, mugshot silhouette, № 47, barcode;
  front and back as two art quads sampling the top/bottom halves, MULTIPLY emission 0.30 on the
  art only — the green box is gone). Textures graded dark for the Soviet half
  (`tools/grade_ritual_textures.py`, shared with the Flood).
  `check_kontur.gd` (every lot textured, the plate art, no "217"
  label) + `check_kontur_archive.gd` (two art faces, no green emissive) + `screenshot_kontur_archive.gd`.
- ⭐ **THE RECOVERY ARCHIVE** (`_spawn_recovery_archive`, 2026-08-18). The Archive's own objective line
  is *"RECOVERY ARCHIVE — DO NOT DISTURB THE INVENTORY"* and its wall sign says *"ITEMS RECOVERED FROM
  AN OBJECT ARE: ▮"*, and it was a 9 × 9 m room containing one black box. Two aisle racks and **six
  numbered lots**, five holding something from a level the player has already crossed — ward bedding,
  a defeated isolator handle, a wound music box, room plate **217**, a handset with the cord cut — and
  **the sixth EMPTY, with the player's own subject number on the card** (`LOT 23-Z · SUBJECT 47 —
  PENDING`). Plus an inventory ledger, a real `note.gd` page on the west wall
  - ⚠️ **ZERO RULES**: no `interact()` on any lot, no `ScaryObject`, no panic, no sound, nothing to
    take. Nothing about it may become a gate — gate 3's whole test is walking past a recovered item
  - ⚠️ **FREE-STANDING AISLE RACKS, not wall racks.** The Archive's two long walls already carry the
    poster and the redacted sign at their centres; a wall rack would simply hide both. The measured
    narrowest lane in the room is **4.00 m** against a 0.80 m capsule (`check_kontur.gd` measures it
    with rays and a point query, never `intersect_shape` — a capsule centred on a CSG box comes back
    clear, Issue 40 — and drops a full-width slab in to prove the probe can report a blocked room)
  - ⚠️ It is what closes **K-T5**: `check_note_mounting.gd` collected **0 props, 0 notes** on the level
    with the most wall text in the game, and the fix was a page the room wanted rather than widening
    the collector (which would have made all eight redacted signs "notes" for the same-room separation
    pass). ⚠️ **This item was built before the user's design direction for this pass arrived** and is
    flagged for their call in `backlogs/05-kontur.md` §3 A1; removing it is one call site, and it
    re-opens K-T5
  - ⚠️ Every lot card is `LotCard_<kind>`, not `LotCard` — six siblings with one literal name and Godot
    renames five of them (Issue 17, third time in this file). And the cards use the LOT's rotation, not
    its negation: `Label3D` is double-sided, so a card facing into its own rack still renders, mirrored
    and unreadable
- **Cyrillic signage and hazard stencils** (`_spawn_stencils`, `_spawn_floor_markings`, 2026-08-18):
  every room on the spine carries a stencilled Russian designation high on a wall (`Л-1 ЛЕСТНИЦА`,
  `У-5 УЧЁТ`, `Ш-9 ШЛЮЗ` …) and the three thresholds where the protocol changes its mind about you
  carry painted hazard bands on the floor. ⚠️ **Paint, not signs** — dark-tinted `Label3D`s and unlit
  ochre quads, so they cannot be confused with the eight NOTICES, which are the level's only actual
  help. ⚠️ `FLOOR_MARK_Y` is **0.03**, the Corridor's own `FLOOR_DECAL_Y`: 0.02 sits exactly on
  `check_wall_overlap.gd`'s 2 cm minimum and `AABB.has_point()` includes its boundary, which is how
  every flat decal in the Corridor got reported the first time that guard was pointed at it.
  ⚠️ **Not one of them says anything about a gate** — a stencil that hinted would put an answer inside
  a level whose whole premise is that the answers are somewhere else
- **Objectives never state an answer** — `GameState.set_objective()` runs in protocol register
  ("PROTOCOL 4-B — PROCEED TO THE MARKED EXIT", "DECONTAMINATION REQUIRED", …)
- ⚠️ **THE LEVEL'S RANDOMISATIONS ARE RESTORED, NEVER RE-ROLLED — AND SO IS THE WORLD THE LEDGER
  DESCRIBES** (K-T6 + K-B1, fixed 2026-08-18, ISSUES_SOLUTIONS **141**/**142**). `save_progress()` had
  written `"dark_x"` since the day the snapshot was added and **nothing ever read it back**, while the
  gate-1 colour was not saved at all — so a back-door return restored the eight-gate ledger and
  re-rolled the answers underneath it, which is the exact failure this file already warned about.
  `_preload_snapshot()` now runs as the FIRST line of `_ready()`, before `_build_geometry()` and
  `_spawn_gate1_doors()` consume the dice; it restores `dark_x`, `gate1_black_east` and `mimic_site`,
  and warns rather than silently re-rolling if it meets an older snapshot
  - ⚠️ **AND `_reopen_passed_gates()` IS THE HALF THAT MATTERED MORE.** `_ready()` rebuilds every
    physical seal on every load and `_restore_progress()` restored only the ledger. Three of those
    seals stand across the spine, and `AirlockSeal` is **unrecoverable by construction**:
    `_tick_airlock()` opens with `if _gates["airlock"] … return`, so the one path that can free it is
    switched off by the flag the restore just set. A player who cleared gate 8, walked back for a note
    and returned was **walled in at z=66 with the exit 32 m beyond it** — a soft-lock reachable by
    using a door the game provides. The restore now opens the black door
    (`ChoiceDoor.open_instantly()`), dissolves the barrier, frees the roster seal, frees the airlock
    seal and its whole marker widget, and silences the phone (`RotaryPhone.mark_smashed()` — both
    methods additive and default-preserving; the Backrooms' two phones never call it)
  - ⚠️ The general rule this encodes: **a ledger and the world it describes must be restored together**,
    and the test is not "does the flag come back" but "having come back, can the player still finish".
    `check_kontur_resume.gd` drives a real advance→go_back cycle with a DIFFERENT seed pinned before
    the return, passes gates 1 and 2 through the shipping `ai_interact()` ray, and carries two
    permanent controls. With the fix disabled it goes red ten ways
- Win: **all eight** gates → exit door → The Breach. Fail: **any one wrong action** (`_strike()` →
  `_condemn()`, fatal since 2026-09-13), the Perëkozhnik, a forfeited run (`_forfeit()` condemns too),
  or the wrong door (which banishes rather than kills)

## DECISIONS & GOTCHAS

⚠️ **Dated ⭐ entries live at the TOP of SPEC, not here.** They carry the level's *current* state and
override the older prose beneath them — that is how `CLAUDE.md` was written, and why entries say
things like *"every paragraph below that says 320 m is history"*.

⚠️ **The top-to-bottom order is NOT strictly newest-first.** Measured 2026-09-19: `01-lab.md`'s
2026-09-13 entry sits *above* the 2026-09-14 entry that reverts it, and `04-backrooms.md:302` sits
*below* the same-day entry that supersedes it. **Read the dates; where they tie, read the code.**

Use this section only for rationale that leaves **no trace** in the level — something tried and
abandoned. Anything describing what the level *is* belongs in SPEC.

---

### Superseded passages, moved out of SPEC (audit 2026-09-19)

Every block below was live SPEC prose until this audit. It is kept **verbatim** for its rationale,
measurements and rejected attempts; none of it describes the level as it is now.

**1 · The three-strike economy** — superseded by the condemn sentence (K2, 2026-09-13), which the
top of SPEC already announced while these sentences stayed live. `_strike()` now calls `_condemn()`;
`STRIKE_PANIC`, the `_strikes` ledger and the Archive's "N OF 3 LOGGED" are not in `kontur.gd`
(`_sync_archive_strikes()` survives and writes `LOT 23-Z   SUBJECT 47 — PENDING`, unconditionally).
Moved from the 2026-09-09 rework bullet, from Gate 8, from the fail economy and from the Perëkozhnik:

> and the **Archive files your strikes** into lot 23-Z ("N OF 3 LOGGED", H3 diegetically)

> A miss calls the level's normal `_strike()` — a full `STRIKE_PANIC=18` that counts toward the 3-strike
> limit — `⚠️ DELIBERATE`, confirmed with the user, who understood 3 mistimed catches alone could end
> the run before choosing this over a softer custom penalty.

> Each wrong answer is `flash_scare(kontur_flash.png)` + jolt + `STRIKE_PANIC=18`. Three strikes
> = 54 > `PANIC_MAX` (50), so `add_panic()` fires the fatal screamer on its own.

> Its 16 panic/s stare is **deliberately** faster than the three-strike budget (see the `⚠️ DELIBERATE` note on
> `GAZE_INTENSITY`)

⚠️ **The user-confirmed part of the Gate 8 note must not be lost:** a mistimed catch was deliberately
given the level's full wrong-answer weight, chosen over a softer custom penalty with the user
understanding that three misses alone could end a run. Under the condemn sentence **one** miss ends
it — harsher than what was agreed, and flagged as reported-to-the-user at the top of SPEC.

**2 · Gate 6 — THE PHONE (one phone)** — superseded 2026-09-09 by the three-phone gate. Its
`PHONE_PRESSURE_RATE` of 4.5/s is the number the live text records as "2.0 (was 4.5)", and
`kontur_hammer.png` is retired to `assets_src/textures/superseded/` (the hammer is parts on a bench):

- **(superseded) Gate 6 — THE PHONE** (`rotary_phone.gd`, *destroy* — was *ignore* until **BUG_FIX.md 4.5**): a
  phone rings for a whole room's length in the Switchboard. Answering still **forfeits the run**
  instantly, unchanged. What changed: simply not answering is no longer enough — while the phone
  rings unresolved, `_tick_phone_pressure()` drains `PHONE_PRESSURE_RATE=4.5`/s panic on anyone within
  `PHONE_PRESSURE_RANGE=7 m` of it, and KONTUR's floor-wide DreadZone cancels decay exactly everywhere,
  so that pressure only ever accumulates. The fix is a **Hammer** (`KeyItem`-pattern pickup, billboard
  QuadMesh from `kontur_hammer.png`) planted in Landing near the level entrance; carrying it flips
  `RotaryPhone.smashable = true`, and `interact()` then calls `_smash()` instead of answering — stops
  the ring for good and fires `smashed` → `_pass_gate("phone")`. A diegetic note by the desk
  ("THESE PHONES... IF YOU CAN'T ANSWER IT, BREAK IT") explains why a hammer is the answer. Hint: the
  **Backrooms** phone is a read-to-die trap. `RotaryPhone` gained `smashable`/`smashed`/`_smash()`,
  defaulting off so Backrooms' own phone (the only other caller) is unaffected

⚠️ Still true and still load-bearing from that block: `PHONE_PRESSURE_RANGE` 7 m, the hammer arming
`RotaryPhone.smashable`, `smashed` → `_pass_gate("phone")`, and the Backrooms phone as the hint.

**3 · The open shelf** — superseded 2026-09-09 (captures #5/#6): `_spawn_gate2_shelf()` puts only
**bleach / poison / water** on the three slots and `_spawn_vinegar_niche()` hides the vinegar behind
a tear-away `WallSheet`. This orphan clause had been left inlined in the middle of the live bullet:

> The old shelf text follows: three bottles (vinegar / bleach / water) on the kitchen shelf,

**4 · The containment cell's observation port** — superseded 2026-09-13 (K2, capture #011; the
user's choice: *"OPEN BARRED FRONT, NO STEEL DOOR"*). There is no leaf and no port: the −z face is
bars over an open void with a gate section, and `PORT_W`/`PORT_Y0`/`PORT_Y1`/`_port_panels` are gone
from `containment_cell.gd`. ⚠️ **Its measurement is why the CURRENT bars sit off the centre line** —
the same 23-heading sweep that condemned the blank leaf is what `check_kontur_entities.gd` re-runs
against the bars, and "no bar at x 0.0" exists because the 180° heading went blind there:

  - ⚠️ **THE DOOR HAS AN OBSERVATION PORT, AND UNTIL 2026-08-18 IT DID NOT.** Three faces are glazed
    and the fourth (−z) is a steel leaf which `_spawn_containment_cell()` deliberately turns to face
    the spine — so the level's one look at its own title creature was staged to face the direction it
    could not be seen from. Measured over 23 reachable poses, **six rendered ZERO pixels of the
    occupant** (the whole 165°–210° arc, at 2.0 m and 3.2 m). The leaf is now four slabs around a
    1.32 × 0.95 m glazed opening (`PORT_W`/`PORT_Y0`/`PORT_Y1`) with a bead frame and two glazing
    bars; the wheel, mid-rail, chevron band and placard all moved, having every one of them been
    sitting inside what is now the opening. ⚠️ It also fixes the *"flat luminous white panel"* the
    same capture shows — that was the torch on the only large untextured flat plane in a corridor
    whose walls carry texture, and the port is what breaks the plane. ISSUES_SOLUTIONS **Issue 148**

⚠️ The one-sided `CULL_BACK` liners the port pass introduced are **still in the code and still in
SPEC** (`LinerNorth` / `LinerSouth` / `LinerEast`), as is the rejected frosted-pane build — only the
leaf and its opening went.

**5 · A dangling pointer, deleted.** The Archive-texturing entry ended *"The 'flat-tinted and
untextured' sentence below is history."* That sentence does not occur below it, or anywhere in this
file — it lives in `01-lab.md:158` and `06-breach.md:118`, about other props. Nothing was superseded
by it, so the pointer was removed rather than moved.

## NEEDS A PLAYTEST

⚠️ Claims in SPEC that are **measurements from a build that has since changed**, or that no headless
guard can settle. None of them is known wrong; none of them has been re-measured against the level as
it stands. Do not delete them, and do not cite them as current until someone plays this.

- **The containment cell's photometry.** SPEC's *"23 reachable headings · 7 097–67 169 px · occ/bg
  0.52–0.77 · contrast 0.231–0.483 · whole-frame mean 0.048–0.104"* was measured against the **glazed
  leaf with the observation port**, which K2 replaced with an open barred front, and K1b then barred
  the west face too. `tests/screenshot_cell_visibility.gd` needs a display and is outside
  `run_tests.sh`; re-run it and restate the numbers. The headless sightline half
  (`check_kontur_entities.gd`) *has* been re-pointed at the bars.
- **Sign legibility.** *"Worst sign now 15.7 px, best 63.2, floor 15"* and the briefing notice's
  *"17.1 px of cap height from the player's own spawn 7.10 m away"* were measured before
  `DARK_AMBIENT` 0.02 / `SOVIET_DARK` 0.0 put the Soviet half in the dark and before Gate 2's sign
  became the tear-away `WallSheet` over the vinegar. `check_kontur_signs.gd` measures ink, not
  brightness — a plate can pass it and still be unreadable in an unlit room.
- **The Perëkozhnik's read.** Both tells are counts — a fourth bottle wearing a duplicate BLEACH
  label off the three-slot rhythm at z=21.9, and a fourth, colourless, never-ringing handset among the
  switchboard's phones. Nothing measures whether either count is *noticeable* at the distance a player
  actually stands, in the dark, with a 16 panic/s stare as the price of stepping closer to check.
