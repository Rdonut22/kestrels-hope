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
