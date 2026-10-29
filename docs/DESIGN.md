# Kestrel's Hope — Game Design

A cozy survival game. A lone pilot crash-lands his ship, the **Kestrel B26**,
on an uncharted forest world. The wreck becomes home. You salvage the ship's
own parts to build hacked-together tech, farm, forage and slowly turn a crash
site into a homestead — or rebuild the Kestrel and leave.

Tone: **mostly relaxing, with gentle survival pressure.** Familiar at a
glance (old-growth pine forest, granite mountains), strange up close.

---

## What exists today

- **Space version** (`main.tscn`): full ship interior — glass canopy cockpit,
  kitchen, lounge with curved viewport, quarters with sleeping pods, bathroom,
  engineering, gunner seat, padded arch, wall exhaust. Coffee machine, personal
  log, ship computer, sleeping. B26 exterior shell.
- **Crash site** (`crash_site.tscn`): damaged interior (breach, debris, sparks,
  emergency lights), pixel-art old-growth forest, meadow, pond, butterflies,
  separate mountain peaks, two daytime moons, crash trail, smoke.
- **Character**: low-poly pilot with robotic right arm (glowing palm),
  procedural walk animation. Placeholder until a proper model (.glb with
  skeleton + walk/idle animations) is made.
- **Day–night cycle** (crash site): 24-minute day, moving sun, dusk/dawn
  colours, stars and moonlight, fireflies at night, sleep to morning, clock
  on the ship computer. Press **T** to skip ahead an hour.
- **Tools**: `tools/build_scenes.gd` regenerates the scenes;
  `tools/playtest.gd` and `tools/crash_playtest.gd` test them.

---

## Core loop

**Explore → salvage & forage → build & grow → improve ship & homestead**,
with the freedom to just sit in the lounge with coffee and a book.

---

## Salvage-based building

The ship is the parts catalogue. Builds use **specific, named components**
pulled from the Kestrel, and every part pulled has a cost.

| Build | Parts | Trade-off |
|---|---|---|
| Moisture harvester | Frion accelerator (climate control) + mesh | Ship climate control goes offline |
| Solar irrigation | Hull solar collectors + coolant pump + fuel line tubing | Less power for ship systems |
| Hydroponics rack | Cockpit display panels (grow lights) + reactor bypass coupling | Fewer cockpit displays |
| Greenhouse | Cockpit / lounge window glass + frame | — |
| Greenhouse heater | Galley heating coil | No hot meals until replaced |
| Plant scanner (arm upgrade) | Nav array scrap | — |
| Medicine still | Reactor shielding | Reactor runs less safely |

**Strip it to survive, or keep it intact to escape?** Players can build a full
homestead, a working ship, or something in between.

**Difficulty range**
- *Easy*: one or two parts, no tools — rain barrel, compost bin, planters.
- *Medium*: several parts + workbench — moisture harvester, solar irrigation.
- *Hard*: rare forest parts, a repair minigame (rerouting wires, balancing
  power), or a prerequisite tool — hydroponics bay, long-range comms, reactor fix.

Visual style: improvised — mismatched panels, exposed wires, tape, crates as
planters.

---

## Relax activities (no goal required)

- Farming: plant, water, harvest; ship-ration seeds and alien crops
- Reading in the lounge: books with lore, the pilot's past, planet guides
- Small repairs: flickering lights, panels, tuning the coffee machine
- Foraging: mushrooms, berries, herbs — vary by area and time of day
- Making medicine at the workbench from foraged plants
- Cooking in the galley
- Scanning plants and creatures with the robot arm → journal
- Sitting (pilot seat, couch, pond edge) with the camera pulling back
- Fishing in the pond, campfire under the two moons, decorating the ship
- Morning routine: wake in the pod, coffee, check the log, look outside
- Coffee goal: find/grow an alien coffee-like bean

---

## Survival (cozy, but present)

- **Hunger**: ~one good meal a day. Soft penalties first (slower, no sprint,
  slower building), dangerous only after days of neglect.
- **Thirst**: tied to moisture harvester, rain catchers, pond filter.
- **Cold at night**: inside is warmer (more so once the breach is patched or a
  heater is built); outside needs a campfire, warm clothes or hacked heat.
- **Health & medicine**: injuries from falls, animals, cold, bad food. Heal with
  medicine you make — no instant health packs.
- **Wild animals**: mostly harmless and skittish; some territorial (warn first);
  a few nocturnal predators. Deal with them by avoiding, scaring off, taming or
  fighting. Lights, fences and a perimeter alarm protect the homestead.
- **Rule**: danger scales with what you're doing. Home in daylight is safe;
  the forest at dusk is risky but pays better.

**Difficulty modes**: *Cozy* (needs barely matter, animals never attack),
*Normal* (default, gentle needs), *Stranded* (harsher needs, nights, animals).

---

## Day–night cycle

- Full day ≈ 24 real minutes (1 game hour = 1 real minute), adjustable.
- Sun moves; sky goes blue → orange/pink → dark with stars; moons rise at night.
- Fog/haze tint follows time of day. Ship emergency lights become a beacon.
- Sleeping skips to morning. Ship computer shows local time.
- Drives crop growth, moisture collection (fog at night), solar power (day only).
- Night: fireflies over the pond, butterflies gone, bioluminescent plants.

---

## Making it feel otherworldly

**Familiar at a glance, strange up close.**

- **Sky**: two moons on different cycles (occasional eclipses), a ringed gas
  giant or planetary ring, slightly teal/lavender sky, long colourful sunsets,
  auroras, a non-Earth day length.
- **Plants**: bioluminescence at night; plants that react (curling ferns,
  flowers that follow you, spore pods); pockets of purple trees, red grass,
  crystal flowers; spiral bark, glowing hanging seed pods.
- **Creatures**: six-legged grazers, floating jellyfish drifters, four-winged
  birds, glowing or swarming butterflies; big things heard at night but rarely
  seen.
- **Landscape**: a few floating boulders, crystal outcrops, perfectly round
  stones, giant half-buried spiral shells; something hidden in the mountains
  (a spire, ruins).
- **Atmosphere**: glowing pollen in light shafts, coloured dawn fog, slightly
  floaty jumps (0.94 g), faintly glowing rain, odd lightning.
- **Sound**: birdsong that's melodic but wrong, the forest humming, sudden
  silence before something big passes.
- **Mystery**: signs of earlier visitors, another wreck, the robot arm reacting
  to certain places, rhythmic signals on the radio, animals that seem to watch.

---

## Story beats

- **Opening**: quiet, lonely space routine → alarms, shaking, crash → wake in
  the quarters with daylight through a hole that wasn't there.
- **Distress beacon** occasionally picks up static, voice fragments, coordinates.
- **Ship's log** becomes a journal of being stranded.
- **The photo in the locker** slowly reveals who he left behind.
- Over time the wreck becomes a home: patched hull, garden outside the breach,
  string lights, campfire.

---

## Opening flow (proposal — decisions pending)

**1. Start menu.** Title **KESTREL'S HOPE** in a chunky pixel font over a
live 3D background. Background options: the Kestrel drifting in space
(camera slowly circling), the crash site at dusk (smoke, fireflies,
mountains), or the view out the cockpit. Menu: New Game, Continue (once
saving exists), Settings (difficulty, volume, fullscreen), Quit.

**2. Space opening.** Wake in the sleeping pod; quiet routine (coffee, log,
window, ship computer) that teaches the controls. Crash trigger options:
- A: after the routine (coffee + log + computer)
- B: when he goes to sleep — alarm jolts him awake
- C: timer after a few minutes
- D: routine triggers it, with a timer backup

**3. Crash (~15–30 s).** Proximity alarm, ship computer warnings, lights
flicker to red, impact jolt, camera shake, sparks, things falling. Player
may keep control (stumble to the cockpit, planet rushing up through the
canopy) or watch a short cutscene. "BRACE FOR IMPACT" → white flash → black.

**4. Wake up at the crash site.** Black screen, muffled ringing, breathing.
Blurry vision clears: quarters floor, red emergency lights, birdsong,
daylight through a new hole. Thought on screen: "...Ugh. Where am I?"
Control returns; first goal: "Check the ship computer."

**5. Then** the computer gives a damage report and first objectives (check
the beacon, find water) and the game opens up.

**Open questions**
1. Start menu background?
2. Crash trigger: A, B, C or D?
3. Keep control during the crash, or a short cutscene?
4. Story: what hits the ship, where was he headed? (Can stay mysterious;
   the beacon and log fill it in later.)

---

## HUD plan

- Always on, minimal: compass strip at top (ship + waypoints, sun/moon time
  icon), small pixel mini-map in a corner (projected-hologram look),
  survival icons that appear only when low, interaction prompts.
- **Wrist computer** in the robot arm (Tab): he raises his arm, camera moves
  in, full-screen hologram in the palm's blue. Tabs: Map (fog of war, pins),
  Inventory, Builds, Journal, Ship status, Vitals. Could start glitchy after
  the crash and unlock features as it's repaired.
- Option: "clean screen" setting hiding compass and mini-map.

---

## Known chores

- Godot adds `uid=` to `ui/terminal_theme.tres` and
  `world/materials/smoke.tres` on first open (shows as changes in GitHub
  Desktop — safe to discard). Fix the builder to save them with a uid.

---

## Story so far

November, 4023. The **Kestrel B26** is a mining vessel owned by **Ushida
Industries**. After a failed mission near **Aphelion**, pirates struck on the
outer rim. The crew was lost (including **Hale**, whose bunk he can't bring
himself to clear) and the reactor badly damaged. Only **Gana**, a pilot from
**Asura**, survived. The Kestrel has drifted for 43 days with navigation dead
and fuel running low, until it reaches an uncharted green world. In orbit,
the ship picks up an **unidentified signal** from the surface; scanning it
overloads the nav array and the Kestrel is pulled down. The signal comes from
the ruins (likely the Great Ring), which becomes the long-term mystery.

Opening as built: intro flyby → drifting-ship shot with green typed
narration → cockpit. Next: cockpit dialogue and the signal → crash.

---

## Vehicle idea (decide next session)

A way to get around the forest faster. Options:
- **Speeder bike**: salvaged from the cargo hold or built from ship parts
  (thruster, repulsor coils, seat). Fast, loud, carries salvage; good for
  long trips. Could be a mid-game build that needs repairing first.
- **Hoverboard**: smaller, nimble, fun for weaving between giant trunks and
  doing jumps; less carrying capacity. Could be an early hacked build.
- Fits the salvage theme either way: pulling the parts costs something on
  the ship. Needs fuel/charge (solar?). Night riding with a headlight.

---

## Sound plan

- Generate in code: ship hum, computer beeps, sparks, alarms, coffee machine.
- Free libraries (Freesound, Kenney, OpenGameArt): birds, wind, creek,
  footsteps on metal and grass.

---

## Suggested build order

1. ~~Day–night cycle~~ (done)
2. Start menu + opening crash sequence (space → crash site) — see "Opening flow"
2b. HUD: compass + mini-map, then wrist computer
3. Inventory, pickups and salvage (pull named parts from the ship)
4. Moisture harvester + first garden plot
5. Hunger / thirst / cold with difficulty modes
6. Night bioluminescence, alien plants, floating rocks, ambient sound
7. Solar power and irrigation; workbench; medicine; cooking
8. Animals; reading in the lounge; sitting; repairs; greenhouse; hydroponics

## Opening: bringing Meki back

Meki is the ship's floating drone and Gana's link to the ship's computer.
The pirate surge 43 days ago blew his core capacitor, so the game opens on
emergency power: dim red lights, a faint hum, and anything marked
`needs_power` (coffee, ship computer, personal log, the lounge holo) shows
"(no power)".

1. Rummage through the parts barrel in engineering (where the old reactor
   stood): capacitors, fuse, coil, tape, wrench and a welding torch.
2. Meki lies dead on the workbench. The repair screen (camera over the
   bench, inventory on the right, Gana thinking out loud below) asks for one
   item per step. Wrong items get a characterful line; after two misses the
   line gets a hint.
   - Replace the blown capacitor: the round capacitor.
   - Seal the shell: the welding torch.
3. Meki boots, rises off the bench and says hello; the rooms power back up
   one by one. From then on he floats off Gana's shoulder and E talks to him
   (ship status, what happened, where we are, what next).

The repair screen is data-driven (see `MEKI_REPAIR` in
`interactables/workbench.gd`), so later repairs and builds reuse it.
Story flags and the inventory live in the `GameState` autoload.

The reactor is now the column beside the cockpit door.

## Act one plan (agreed, October 2026)

This supersedes the older opening proposal above where they disagree.
Nothing after INITIATE LANDING is planned in detail yet.

### Story bible

- **Gana**, pilot from Asura. Married to **Angel**, back home; getting home
  to her is what keeps him going.
- **Hale**, an engineer Gana met when they were both drafted into Asura's
  military. Best friends; both went on to work for Ushida Industries. The
  Kestrel B26 was crewed by just the two of them, plus Meki.
- **Meki**, the ship's drone and link to the ship's computer. Hale built
  half of him.
- **The attack.** "Pirates" hit the Kestrel near Aphelion, 43 days ago.
  Nothing was taken: the hold is still full. Hale disappeared in the attack.
- **The truth (revealed slowly).** Ushida found the ore they mine stores
  absurd amounts of energy and is building weapons with it. Hale saw the
  plans and wanted out; Ushida wouldn't end his contract. The richest
  deposits are in a system nobody has colonised yet, which is why a
  two-person crew in an old ship was sent. The attack was Ushida.
- The planet below stays **unnamed** for now; so does the material (Hale
  just calls it "the ore").
- Tone: cozy survival with a slow-burn mystery underneath. Clues are found
  at the player's pace; no villains on screen early.

### Sequence

1. **Intro**, then Gana wakes in the pilot seat. Seat options: **Panel**,
   **Kestrel drive** (computer UI), **Stand**.
2. **Switches fail.** MAIN DRIVE, NAV and DIAGNOSTICS clack, flicker amber
   and die; the gauge reads REACTOR 12% / REQUIRED 40%. Gana thinks out
   loud and points himself at Meki. The Kestrel drive opens but anything
   live says "Insufficient power".
3. **Meki.** Gana gave up on fixing him weeks ago; out of options, he tries
   once more. Parts barrel + workbench repair (built).
4. **Diagnosis.** Meki explains: main cell damaged; port thrusters getting
   no power; nav and comms damaged. He mentions one corrupted private file
   marked HALE that he can't open.
5. **Power reroute puzzle.** Meki jacks into the engineering computer; the
   player routes power from backup cell B around the damage (puzzle, rules
   TBD — e.g. drawing the line on the reactor schematic).
6. **Back in the cockpit** the switches work and the windshield HUD boots.
   Coffee, lounge, music and books are powered. Nav, comms and thrusters
   have power but "not enough to get us home".
7. **Hale's file recovers in the background.** No extra repairs in space
   (ship repairs belong to the core game on the planet). Meki works on it
   on his own; progress shows on Diagnostics (HALE_PRIVATE.LOG: n%
   RECOVERED). Meanwhile: coffee, reading, music, sleep, the HUD tabs.
8. **Nav** shows a blinking power signal on the planet, terrain notes,
   O2/pressure/temperature (breathable), and — once every HUD tab has been
   seen — **INITIATE LANDING** with damage warnings (port thrusters, nav,
   hull, low success estimate).
9. **Free time.** Landing waits as long as the player likes: cook, read,
   music, sleep. Readouts are mood, not timers; gentle occasional nudges
   only.
10. **The letter interrupts the landing.** Pressing INITIATE LANDING, Meki
    cuts in: the file has just finished, and he needs Gana to see it
    first. Hale's letter opens in Meki's box (the ore, the weapons, the
    refused contract, why they were sent, that it wouldn't be an accident).
11. **Closing it resumes the landing**, now with the weight of the letter.
    Meki: "You're landing now? Chances of survival... 23%." Gana, dry:
    "Great. What a helpful little droid." → crash (not designed yet).

### Gana thinking out loud

Typed-out italic lines in the GANA box (same as the repair bench), with a
soft blip. Used for story beats, first-time interactions and the odd idle
nudge when stuck. Short, never blocking, E skips, no back-to-back repeats.
After Meki wakes some become two-line exchanges with him.

Personal story comes through these, tied to places:
- Pilot seat: 43 days alone in the chair.
- Hale's bunk / side of the quarters: Gana explains Hale disappearing in
  the attack.
- Photos on the desk: Gana and Hale from the draft days; Angel.
- The full hold: "What kind of pirates leave the cargo?"
- Hale's pried-open locker.
- Lounge, galley, window: small memories of Hale and the planet below.

### Windshield HUD

A hologram layer projected on the cockpit glass, retro vector style
(phosphor green lines, amber warnings, red damage, faint scanlines). The
glass tints slightly darker while it's active. Seat → Panel eases into a
first-person view out of the windshield; the switch panel sits below.

Layout: one main view, a row of tabs along the bottom. Each tab is a small
live preview; A/D selects, the main view swaps with a CRT flicker.

- **Altitude**: attitude line, altitude, orbital speed, fuel, orbit
  "stable (degrading)".
- **Diagnostics**: rotating wireframe Kestrel; cycle systems to highlight
  them (damage blinks red); selecting one unfolds a 2D schematic. Status
  tiles per system (green / amber / red). Shows Hale's file recovery.
- **Comms**: ANGEL (HOME) no carrier, USHIDA DISPATCH no response,
  EMERGENCY BEACON transmitting, no reply. First view, Gana: "...Angel.
  I'm so sorry. I promise I'll come back. ...Still nothing from Ushida. Or
  our emergency beacon. What the hell are we supposed to do?"
- **Nav**: drawn over the real planet through the glass: grid, the signal,
  terrain labels, atmosphere; later INITIATE LANDING.

Unread badges (blinking amber dot) mark tabs not yet opened and come back
when something new happens there. Every tab must be seen before landing unlocks
(the letter itself interrupts the landing); until then Nav says "LANDING
CALCULATION PENDING: SYSTEM CHECK INCOMPLETE" and Gana or Meki nudge
toward any unseen tab.

### Still open

- Reroute puzzle rules.
- Days passing on the ship (sleep advances the day, small morning
  changes) and a save system.
- More free-time activities (cooking), and the book text files.
- Where the full hold and Hale's locker live (a small cargo bay?).
- Updating the intro narration and logs to match (later).

### Built so far (act one)

- New Game: after the intro Gana is sat in the pilot seat; seat menu
  [E] Panel / [Q] Kestrel drive / [Space] Stand. Opening thoughts play.
- Switch plate on the dash (MAIN DRIVE, NAV, DIAGNOSTICS) with a reactor
  gauge. Without power the switches clack, flicker and spring back, the
  glass flashes INSUFFICIENT POWER, and Gana's thoughts point to Meki.
- Kestrel drive opens from the seat; on emergency power its live pages say
  INSUFFICIENT POWER (status and crew list still work).
- Meki's repair (bench) → he wakes, talks, runs his diagnosis (main cell,
  port thrusters, nav, comms, the corrupted HALE file) and sends Gana to
  the power panel.
- Engineering power panel: Meki jacks in; the reroute puzzle is a pipe
  puzzle on a green schematic (rotate conduits so cell B feeds lights,
  galley/lounge and cockpit around the cracked cell A). Solving it restores
  power (lights come back room by room).
- Two power stages in GameState: `meki_online`, then `power_restored`
  (what `needs_power` waits for).
- Switches then latch on; with all three the windshield HUD boots: tabs
  ALTITUDE, DIAGNOSTICS (rotating wireframe Kestrel, W/S cycles systems,
  HALE_PRIVATE.LOG %), COMMS (Angel / Ushida / beacon; Gana's lines on
  first view), NAV (wireframe globe, the signal, atmosphere and terrain).
  Unread badges; landing unlocks once every tab is seen.
- INITIATE LANDING → warnings → confirm → Meki interrupts → Hale's letter
  in Meki's box → "Chances of survival... twenty-three percent." / "Great.
  What a helpful little droid." → NAV shows DESCENT PROGRAM ARMED. Nothing
  after that is built yet.
- Gana's thought box (typed, non-blocking, click to skip; Meki lines in
  cyan). Thought spots: Hale's bunk (how he disappeared), Hale's pried
  locker, photos of Gana & Hale and of Angel on the quarters shelf, the
  sealed cargo crates.
- Meki's talk menu adapts ("What should I do now?", "Hale's file").

Simplifications to revisit: the Nav globe is drawn on the HUD rather than
over the real planet (there's no planet in the space scene yet); the
photos are simple painted placeholders; the 2D schematic view for each
diagnostics system isn't done yet.
