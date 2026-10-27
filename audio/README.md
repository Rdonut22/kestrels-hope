# Audio

Drop sound files here.

- `menu_theme.ogg` (or `.mp3` / `.wav`): start-menu music. Plays automatically
  on loop with a fade-in when the file exists.
- `wind_ambience.ogg`: wind ambience outside the crashed ship. Starts the first
  time the player steps out, loops while outside, fades down inside
  (world/outdoor_music.gd).
- `steps/grass_1-6.ogg`: single footsteps cut from "running footstep on grass"
  (evanaeva, Pixabay). Played at random with pitch variation on each foot
  touchdown on grass (player.gd + character_model.gd footstep signal).
- `intro_music.ogg`: intro cinematic music; starts as the ship flies past.
- `space_hum.ogg`: space hum, used in the intro and looped aboard the ship
  in space (ship/ship_hum.gd).
- `thruster_flyby.ogg`: jet ship pass-by for the intro flyby (peak at 4.2 s,
  synced to the pass via THRUST_PEAK in intro.gd).
- `type_blip.ogg`: soft blip per typed character in the intro narration (generated).

- `door_slide.ogg` — pneumatic hiss and soft thunk for the sliding doors
  (synthesised with ffmpeg).

## Lounge holo-player music (user-supplied)

- `music/misty.mp3` — "Misty" (Beegie Adair), the Sad Jazz selection.
- `music/sun.mp3` — "Sun", the Vaporwave selection.
