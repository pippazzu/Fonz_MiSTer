# Reference stills from the gameplay video

Source: a gameplay video of The Fonz (56.2 s, 1920x1080, 29.97 fps, 1684
frames). Neither the video nor the stills are included in this
repository; the notes below record what they show. The main schematic
is an earlier issue of the board: the road, bike and video circuits
match closely, but shapes, timings and the cabinet can differ.

Each still was one exact video frame, scaled to 960x540. The name gives
the time; the frame number is `round(t x 29.97)`.

## What the clip does and does not contain

- One continuous take of a game in progress. ffmpeg scene detection
  (`select=gt(scene,0.4)`) finds no cuts.
- **No attract mode, coin-up, game start or game over.** The game is already
  running at 0 s and still running at 56 s. Those states need other footage
  or the hardware.
- **No score or time on screen.** They are on the cabinet's seven-segment
  display (see `docs/CONTROLS.md`), which is out of frame.
- The monitor is filmed at an angle, so the picture is keystoned and curved.
  The white trapezoid at upper right is a ceiling light reflected in the
  glass, not game graphics. Pink and blue horizontal bands are the camera
  beating against the CRT refresh (rolling shutter), not game colour.

## Picture elements

| Element | Appearance in normal play |
|---|---|
| Grass / field | mid grey, the largest area |
| Road surface | dark grey, darker than the grass |
| Kerbs | both edges, alternating light and dark dashes; the light dashes are among the brightest marks |
| White bike | bright white sprite with two shapes: upright (a "lantern" shape with a ≡ mark) and a sideways, leaning shape seen on bends and at crashes. It is the bike that runs onto the kerb and crashes each time, so it is **probably the player's bike** (inferred, not confirmed) |
| Dark bikes | dark body with white details. They enter from the bottom edge and leave at the top |

## Stills

| File | Frame | What it shows | Compare in simulation |
|---|---|---|---|
| `fonz_video_t00.50s.png` | 15 | Dark bike alone mid-road, S-bend | Dark-bike shape and its brightness against the road |
| `fonz_video_t01.00s.png` | 30 | Almost empty road (one bike leaving at the top), S-bend | Background only: grass, road and kerb levels with no objects. The cleanest frame for the three resistor-layer levels |
| `fonz_video_t03.00s.png` | 90 | White bike entering at the bottom edge, upright shape | Vertical entry/clipping of the white bike at the bottom of the raster |
| `fonz_video_t04.00s.png` | 120 | Wide bend sweeping up and to the right; white bike with a dark bike just ahead | Road curve shape and kerb dash spacing on a strong bend |
| `fonz_video_t06.01s.png` | 180 | White bike (leaning shape) beside a dark bike | Both sprite types side by side, relative brightness |
| `fonz_video_t09.01s.png` | 270 | White bike (leaning) near the right kerb, half a second before the first crash | Steering position just before a crash |
| `fonz_video_t10.01s.png` | 300 | **Crash flash**: road bright white, grass dark, sprites drawn dark | Picture polarity during a crash (see below) |
| `fonz_video_t19.02s.png` | 570 | Second crash, flash frame caught mostly normal; crashed white bike on the right kerb looks faded | |
| `fonz_video_t19.05s.png` | 571 | Next frame: inverted (bright road) | The alternation between the two crash phases |
| `fonz_video_t20s.png` | 600 | Normal play after the second crash: bikes and light kerb dashes are the brightest marks on grey | IC41 polarity (`TRACE.md`): IC7.8 (470 ohm) lit only for objects and lines |
| `fonz_video_t25.99s.png` | 779 | Bend sweeping across from left to upper right, white bike and a dark bike | Road curve |
| `fonz_video_t35.00s.png` | 1049 | Long right-hand bend at the top of screen, white bike upright | Road curve, other direction |
| `fonz_video_t44.01s.png` | 1319 | Fourth crash: white bike off the road on the grass to the right; field inverted (road bright, grass dark) | Crash triggered off-road, not only on the kerb |
| `fonz_video_t50.02s.png` | 1499 | Sharp S-bend sweeping right at the top, white bike upright | Road curve |

## Crash flashes

Four crashes are in the clip. Measured on a grass patch (crop 140x160 at
1420,700 in the full frame), whose level is about 140 normally and about
80 when inverted:

| Crash | Flash, first to last inverted camera frame | Duration |
|---|---|---|
| 1 | 9.61 to 10.28 s | about 0.67 s |
| 2 | 18.85 to 19.49 s | about 0.64 s |
| 3 | 28.76 to 29.43 s | about 0.67 s |
| 4 | 43.71 to 44.38 s | about 0.67 s |

- During a crash the **whole field inverts**: road bright, grass dark,
  sprites dark, kerbs still dashed. It is not only the crashing bike.
- It alternates between inverted and normal on consecutive camera frames.
  The camera runs at 29.97 fps against a roughly 60 Hz CRT, so the flash is
  at least about 15 Hz but its true rate cannot be read from this clip
  (many frames mix both phases). The steady length, about 20 camera frames
  or about 40 fields, is the more useful number.
- After the flash the brightness recovers over about half a second. That
  looks like the camera's auto-exposure, not the game.
- Lead for the simulation, not a conclusion: `rtl/fonz_video_gates.v`
  has IC5.6 = IC6.8 XOR IC5.5, and IC5.5 comes from IC28A QB (the crash
  counter area, `rtl/fonz_picture.v`). That would invert the IC7.8
  layer during a crash. The footage shows the road and grass levels swapping
  as well, so check that the simulated crash inverts the whole field and
  holds for about 0.65 s.

## What to check against these stills

1. Normal play polarity (`t01.00`, `t20`): grass mid grey, road darker,
   bikes and light kerb dashes brightest. Already used to settle IC41.
2. Crash polarity and timing (`t10.01`, `t19.02`/`t19.05`, `t44.01`, and
   the table above).
3. Sprite shapes: upright and leaning white bike, dark bike.
4. Road curves and kerb dash spacing on bends (`t04.00`, `t25.99`,
   `t35.00`, `t50.02`). The traced board's road PROM may differ.
5. Entry of bikes at the bottom edge (`t03.00`) and exit at the top.
