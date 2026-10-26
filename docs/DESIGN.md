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

## Sound plan

- Generate in code: ship hum, computer beeps, sparks, alarms, coffee machine.
- Free libraries (Freesound, Kenney, OpenGameArt): birds, wind, creek,
  footsteps on metal and grass.

---

## Suggested build order

1. Day–night cycle (farming and moisture depend on time)
2. Opening crash sequence (space → crash site)
3. Inventory, pickups and salvage (pull named parts from the ship)
4. Moisture harvester + first garden plot
5. Hunger / thirst / cold with difficulty modes
6. Night bioluminescence, alien plants, floating rocks, ambient sound
7. Solar power and irrigation; workbench; medicine; cooking
8. Animals; reading in the lounge; sitting; repairs; greenhouse; hydroponics
