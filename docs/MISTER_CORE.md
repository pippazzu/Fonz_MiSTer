# The MiSTer core: the whole machine on one clock

The core is built on MiSTer-devel's
[Template_MiSTer](https://github.com/MiSTer-devel/Template_MiSTer). The
traced board and everything around it sits in
`rtl/mister/fonz_machine_fpga.v`; `rtl/mister/fonz_core.v` joins it to the
template's `emu` module in `mister/Fonz.sv`.

| Part | Module | Notes |
|---|---|---|
| Logic board | `fonz_board_fpga` (`rtl/fpga/`, generated from `rtl/`) | docs/FPGA_BOARD.md |
| IC9, IC106 shape oscillators | `fonz_shape_oscillator` | fixed point, docs/SHAPE_OSCILLATORS.md |
| IC97, IC102, IC104 road monostables | `fonz_road_timing` | fixed point and a width table, see below |
| IC30 (crash), IC103 (antenna, coin start) | `fonz_74123` | widths from R and C at elaboration, 'LS123 |
| IC98, IC99, IC105 556s | `fonz_556_timers` | fixed point on a 100 kHz enable, integer parameters |
| Contacts, IC37 Schmitt, coin switch | `fonz_contact_conditioning_fpga`, `fonz_cabinet_inputs` | counters for the RC delays of docs/CONDITIONING.md |
| Throttle grip | `fonz_accel_input`, `fonz_throttle` | into IC105 pin 3 |
| Mains sense, IC37 pin 10 | in the machine module | 60 Hz square wave |
| Video | `fonz_video_mixer_fpga`, `fonz_video_timing_fpga`, `fonz_score_overlay` | grey level, board sync and blanking |

No `real` arithmetic and no timed waits reach the build. The real-valued
models stay as references: `fonz_road_timing_ref.v`,
`fonz_shape_oscillator_ref.v`, `fonz_input_conditioning.v`.

## Layout

| Path | What it is |
|---|---|
| `mister/sys/` | Template_MiSTer's `sys/` folder at the commit in `TEMPLATE_REVISION` (e901a9f, 3 November 2026), byte for byte. Never edit it. |
| `mister/TEMPLATE_SYS.txt` | `git ls-tree -r` of that commit's `sys/`, which the check compares against |
| `mister/Fonz.sv` | The `emu` module: hps_io (OSD, controls, ROM download, rumble), the PLL, arcade_video |
| `rtl/mister/fonz_core.v` | Everything between the framework and the machine: reset, PROM download, inputs, options, CRT line buffer. Simulated by `tests/tb_fonz_core.v` |
| `mister/rtl/pll*` | The template's PLL with its output set to 57.222222 MHz (the only change) |
| `mister/files.qip` | The source list, written by `scripts/template_project.py`; paths point into `rtl/`, nothing is copied |
| `mister/Fonz.qsf`, `Fonz.qpf`, `Fonz.srf` | The template's project files, renamed |
| `mister/Fonz.sdc` | The template's clock lines |
| `mister/analog_multicycle.sdc` | The analogue models' multicycle paths (see "Fitting and timing") |

`.gitattributes` marks `mister/sys/**` as `-text`, because upstream stores
some of those files with CRLF and git would otherwise rewrite them.

## Clock

`clk_sys` is 57.22 MHz, four times the board's 14.305 MHz crystal (X1, read
again on both schematics on 19 November 2026). The crystal is `clk_sys`
divided by four (the phase accumulator in `fonz_board_fpga` wraps every
second clock when `CLK_SYS_HZ` is 57,220,000), so a pixel is exactly 8
clocks, a line 3,632 and a frame 947,952: 454 pixels a line at 7.1525 MHz
(15.754 kHz) and 261 lines a frame (60.36 Hz).

57.22 MHz cannot be made exactly from 50 MHz with integer counters (2861 is
prime). The template's PLL is set with
`output_clock_frequency0("57.222222 MHz")`, and Quartus builds
50 × 103 / 90 = 57.2222 MHz, 39 ppm high (60.363 Hz).

### Repeatable frames

The bikes are drawn by the IC9 / IC106 oscillators, and the same
oscillator counts a bike's rows (IC73/IC51, IC109/IC88), so one oscillator
cycle more or less in a frame moves a row by a line. Any counter that
drifts against the frame therefore makes a still bike flicker. Besides the
whole-number frame above:

- the 1 µs step of the shape oscillators restarts when TR2 turns on, and
  that of the road networks at VBLANK rising;
- the 100 kHz step of the 556 cells restarts at VBLANK rising, so IC105's
  throttle pulse, which places the player's bike, ends on the same clock
  each frame;
- an oscillator half drops its carried width fraction while /CLR holds it.

Whole-machine Verilator runs, game on, grip at rest, frames 380 to 519,
pixels of the player's bike (a 60 × 68 box) that differ from the previous
frame: 163 on average before (at 57.22 MHz without the restarts), 39 on
average after, with a median of 21 and one frame in 16 near 285. No frame
repeats the one before exactly. What is left repeats every 16 frames: the bike
moves down a line and back once in each 16, which is the period of IC28
(a 74393 clocked once a frame); whether IC28 is the cause is not traced.
The 60 Hz mains sense, the throttle's 1 ms step and the contact timers
still run freely.

`FONZ_CLK_SYS_HZ` (set in `mister/files.qip`) sets the edge-node delays
(`fonz_rc_edge_ce`) for that clock: 4 and 11 clocks, 70 and 192 ns,
against 77 and 189 ns on the board.

## Reset

The board has no reset line, but in the core `rst` holds every flip-flop
of the trace, IC67 (the pixel divider) included. `fonz_core` holds `rst`
while the MiSTer reset, the OSD reset or the ROM download is active, then
for 65,536 more clocks (1.15 ms). The crystal runs through reset, and while
`rst` is high `ce_pix` is the crystal divided by two, at IC67's rate, so
the video timing keeps running.

## Video

- The board gates its video with IC67 Q, so some areas change every half
  pixel: the off-road grey alternates. The machine samples the mixer once a
  crystal cycle and sends the mean of the two halves of each pixel, as the
  monitor's video bandwidth would show it.
- Sync and blanking are the board's own (IC27.11, IC25.12, IC4 Q5, IC3 Q5),
  registered with the pixel. Active area 374 × 245 (H 80..453, V 16..260).
- `fonz_crt_out` (sync placed for a 15 kHz CRT, optional 3:4 squeeze) feeds
  the template's `arcade_video` with `{grey, grey, grey}` and its output
  pixel enable (7.15 MHz native, 12.7 MHz squeezed, both on the 57.22 MHz
  clock). arcade_video does the scandoubler, HQ2x, scanlines and gamma.
- Aspect ratio 3:4 (Original), Full Screen or the two custom ratios from
  the MiSTer ini, on the OSD's Video page. No rotation: the tube stands
  portrait with horizontal lines (docs/VIDEO_TIMING.md).
- No audio: the cassette is not part of the trace.

## Controls and options

| MiSTer | Cabinet |
|---|---|
| Left / right | handlebar turn contacts |
| Button 1 | full throttle (the grip contact closes with it) |
| R2 (right analogue trigger) | variable throttle |
| Left stick up | variable throttle, by default |
| Coin, 1P start | coin (the cabinet has no start button) |

Controls come from hps_io's `joystick_0`: bit 0 right, 1 left, 4 Accelerate,
6 Start, 7 Coin (bit 5 unused). R2 is `joystick_rt_analog_0` (Main_MiSTer's
UIO_ATRIG command 0x46). The throttle follows whichever of R2, the chosen
stick and button 1 is pressed furthest; a Main_MiSTer that does not send
0x46 leaves R2 at 0, and the stick and button still work. Rumble goes out
on `joystick_0_rumble`, which Main_MiSTer reads with command 0x003F to
drive player 1's controller motors (on by default, not original; see
[CONTROLS.md](CONTROLS.md#rumble-on-crash-mister-option-not-original-circuitry)).

The options are OSD entries, not MRA DIP switches, because the board has
none; the MRA has no `<switches>`. Its `<buttons>` names the inputs
Accelerate, Start and Coin.

| Page | Entry | Status bits |
|---|---|---|
| Video | Aspect ratio | 122:121 |
| Video | Scandoubler Fx: None, HQ2x, CRT 25 / 50 / 75 % | 5:3 |
| Video | Score overlay | 23 |
| Video | CRT picture: Native 4:3, 3:4 squeeze | 24 |
| Board adjustments | the pots (docs/POT_SETTINGS.md) | 64-97 |
| main | Throttle stick | 26:25 |
| main | Rumble on crash | 27 |
| main | Reset and close OSD | 0 |

The "Board adjustments" page in `mister/Fonz.sv`'s CONF_STR is written by
`scripts/pot_settings.py` between its markers; `--check` fails when it is
stale.

## Pot settings

From the manual's "Details of logic board adjustments" page (9 November
2026). These are the factory settings; all but VR-12
can be changed from the OSD's "Board adjustments" page while the
game runs (docs/POT_SETTINGS.md, scripts/pot_settings.py), each starting
at the setting below, marked "(default)".

| Pot | Setting | Where |
|---|---|---|
| VR-4, swing width | midway, 1k of 2k | `fonz_road_swing`, OSD code `vr4_code` |
| VR-10, game time | 77.8k: 0.707 s a count, about 70 s a game | `fonz_556_timers`, `vr10_code` |
| VR-12, VR-11, throttle limits | wheels 3/4 in above the bottom of the picture at rest, 61 % of the way up it at full grip (the drawing; see CONTROLS.md) | `fonz_throttle` `WIPER_DARK_MV` (not in the OSD); VR-11 is the OSD's "Grip height" (port `VR11_full_mv`, 3061 mV at the factory 61%) |
| VR-1, VR-9, VR-2, bike sizes | bikes 3 1/4 in (42 lines) at the start: VR-1, VR-9 1.8k; VR-2 midway, 50 ohm | `fonz_shape_oscillator`, tables from `scripts/shape_osc_table.py` |
| VR-5, swing speed | midway, 250k of 500k (no setting on the page) | `fonz_road_swing`, `vr5_code` |
| VR-3, road shape in a crash | midway (no setting on the page) | `fonz_road_swing`, `vr3_code` |
| VR-6, road widening down the screen | 1k of 10k | `fonz_road_timing`, `vr6_code`; not on the page, set from its drawing (road nearly edge to edge at the bottom) and the footage |
| VR-7, VR-8, VR-13 | midway | not on the page; `vr7_code`, `vr8_code`, VR-13 picks the mixer |

The page sets the bike sizes by picture ("standard size", a bike 3 1/4 in
tall on a picture about 18 3/4 in tall, so about 42 lines). It names VR-2
for all the bikes and VR-1/VR-9 for each one. In the model VR-2 moves the
size only from 28 lines (0 ohm) to 31 (100 ohm), so the size is set with
VR-1/VR-9 instead (docs/SHAPE_OSCILLATORS.md, "Bike size"). At the earlier
5k the bikes were 29 lines tall, and an opponent passing straight through
the player clocked the collision counter (IC29) to only 17 of the 32 that
fire the crash, so there was no crash. The collision chain and the
debug model are in docs/COLLISION.md.

## Road model, synthesisable

`rtl/analog/fonz_road_timing.v` has the same equations as the reference
`fonz_road_timing_ref.v`: the base networks of TR5..TR8 stepped every
1 µs by forward Euler, here in microvolts with Q32 coefficients worked out
from the integer pot parameters. Each transistor-fed width is read from a
table against the base voltage (`fonz_road_timing_table.vh`, written by
`scripts/road_timing_table.py`), 16.4 mV a step with linear interpolation,
one stage a clock.

`tests/tb_road_timing.v` runs both side by side for nine frames and
compares the four widths on every line of the last one: within 1 % or one
clock. That bench found a jump in the reference's formula: it switched
from "the follower carries the pin to the threshold" to "the emitter
pull-up finishes the charge" at 20 mV above the threshold, which left a
step of about 40 % in the kerb widths. The switch is now where the pull-up
really takes over, so the width is continuous.

## Build

```sh
bash scripts/build_mister_template.sh      # Git Bash; SEED=n for another fitter seed
```

It checks the file list and `mister/sys/` (`scripts/template_project.py
--check`), compiles `mister/Fonz.qpf` with Quartus 17.0
(`C:/intelFPGA_lite/17.0` by default, `QUARTUS_BIN` to change), fails on a
failed compile or any negative slack, and writes
`build/release/YYYYMMDD/Fonz_YYYYMMDD.rbf`. The log is
`build/mister_template.log`. Opening `mister/Fonz.qpf` in the Quartus GUI
and pressing Compile gives the same RBF, without the slack check.

Copy the RBF to `_Arcade/cores/` and the MRA to `_Arcade/`.

## Fitting and timing

Quartus 17.0.2 Lite, seed 1, 21 November 2026: 18,153 of 41,910 ALMs
(43 %), 112 of 112 DSP blocks, 492,801 block memory bits (9 %). Quartus
reports the core clock as 57.22 MHz (period 17.475 ns,
50 MHz × 103 / 6 / 15). On that clock the worst slacks are setup
+2.818 ns, hold +0.245 ns, recovery +12.884 ns and removal +2.251 ns; in
the whole design setup +0.249 ns, hold +0.202 ns, recovery +3.946 ns and
removal +0.928 ns. No slack is negative.

- **DSP blocks.** The fixed-point networks first took 149 DSP blocks, more
  than the chip has. Each product in the shape oscillators and the road
  networks is now cut to 27 × 27 bits (coefficients under 2^26 in Q32, or
  Q31/Q26 for the few larger ones; voltages within ±67 V), one DSP block
  each. The shape oscillator bench still agrees with its reference to
  3.2 mV and 0.8 % in period.
- **Slow paths.** The networks step once a microsecond (road, shape
  oscillators) or every 10 µs (556s), but a step is a chain of multiplies
  and adds that does not fit in one 17.5 ns clock. They read only their own
  state and inputs held at the tick, so `mister/analog_multicycle.sdc`
  gives those paths four clocks. Holding the inputs puts the road and shape
  networks one microsecond behind their references; it shows only in the
  blanked lines 0..15, while TR2 tops the capacitors up. The 556 capacitor
  follows its output one tick (10 µs) late, 0.1 % of the shortest pulse.
  The throttle is pipelined instead (it steps once a millisecond).

## Moving to a newer template

Check Template_MiSTer out at the new commit, write that commit to
`TEMPLATE_REVISION`, and run

```sh
python scripts/template_project.py --sync PATH/TO/Template_MiSTer
```

which replaces `mister/sys/` with the committed bytes of that commit and
rewrites `mister/TEMPLATE_SYS.txt`. Then compare `Template.sv` with
`mister/Fonz.sv` for port changes, build, and check timing.

## Checks

```sh
python3 scripts/run_tests.py                 # unit benches, road, raster, board
iverilog -g2012 -I rtl/analog -DFONZ_CLK_SYS_HZ=57220000 -o build/tb_machine \
    sim/tb_machine.v rtl/mister/*.v rtl/fpga/*.v rtl/analog/fonz_*.v \
    rtl/ttl/*.v rtl/fonz_cabinet_inputs.v rtl/fonz_accel_input.v rtl/fonz_throttle.v
vvp -n build/tb_machine +frames=4            # about 2 minutes a frame
```

`sim/tb_machine.v` runs the machine as the core does and writes
`build/frames/machine_NNN.pgm`.

- `python scripts/run_tests.py template`: files.qip is current, and every
  file in `mister/sys/` has the git blob hash of the pinned commit, with
  nothing missing or added.
- `python scripts/run_tests.py fonz_core`: `tests/tb_fonz_core.v` downloads
  the four PROMs through `fonz_core` and compares all 1,536 locations, checks
  that `rst` holds during the download and falls RST_HOLD clocks after it,
  that the pixel enable runs in reset, hsync at 15.75 kHz and the output
  pixel enable at 7.15 MHz, recovery after an OSD reset, and that every
  joystick bit, analogue input and status bit reaches the machine input
  that `fonz_core.v` documents.
- `python scripts/run_tests.py pots`: the CONF_STR pot page is current.

`mister/Fonz.sv` itself (hps_io, PLL, arcade_video) is only checked by the
Quartus compile; there is no simulation of the template's `sys/`.

The PROM hex files the simulations read (`rom/*.hex`) are not in the
repository: put the `fonz.zip` the MRA names in the repository root and
`scripts/extract_proms.py` writes them (`run_tests.py` does so when they
are missing).
