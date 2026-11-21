# Trace notes

## Source and conventions

Primary source: Sega's single-sheet logic board schematic dated 9 November
1976 (the main schematic; not included here). The last sheet of the
service manual is a secondary reference. The native scan of the main
schematic is 13560 x 8809 pixels; native-resolution crops were used
to distinguish small open-circle junctions from unjoined crossings.

The HDL names physical reference designators and pins. “107/2” on the drawing
denotes half a package; some half labels differ from the physical pinout.
Physical pins take precedence. Counter vectors use bit 0 for QA, then QB,
QC and QD. A module boundary is not a connector on the original PCB.

TTL models are ideal functional models with no propagation delays. INIT=0
is a convenient initial simulation state, not an added PCB reset. Ripple
clocks and asynchronous feedback are preserved. In particular the 74192
has two independent clock inputs and uses an event model;
`rtl/ttl/fonz_74192_sync.v` is its single-clock equivalent
(docs/74192_SYNC.md). This source is
not yet suitable for ordinary single-clock FPGA synthesis. The original
74107 master-slave sampling window is approximated by falling-edge sampling.

Component references used while implementing cell behavior:

- TI [7448 and related decoders, SDLS111](https://www.ti.com/lit/ds/symlink/sn74ls47.pdf), table T2: RBI is pin 5, BI/RBO pin 4, LT pin 3; original 6/9 glyphs lack tails.
- TI [74390/74393, SDLS107](https://www.ti.com/lit/ds/symlink/sn74ls390.pdf): separate /2 and /5 sections and falling-edge counting.
- TI [74107 family](https://www.ti.com/lit/ds/symlink/sn74ls107a.pdf): JK and asynchronous clear behavior; see sampling approximation above.

## Connected sections

### Raster and picture

`fonz_raster` joins IC67A, IC68/46, IC4, IC89, IC93, IC24/2, IC3 and their
decode gates. IC93 is a 7442 (the type appears as “42” inside the symbol).
The vertical 74161s share the IC67.Q3 clock; the horizontal terminal-count
decode drives IC24's enables. No Pong timing constants are used.

`fonz_upper_shape` joins IC67B/69/91/90, IC48, IC73/51, IC49/50 and IC71.
IC101.6 drives the two /LOAD pins, IC67B's clock and IC9's clears; IC91./CARRY
only feeds IC47.9.
IC51.QC9 resets IC73; IC73.QD8 clocks IC51. Both IC90 /2 sections feed their
own /5 clocks. The two PROM bit orders are reversed explicitly at the mux
inputs to follow Q4,Q3,Q2,Q1 -> C0,C1,C2,C3.

`fonz_lower_shape` joins IC63/85, IC109/88, IC86/87 and IC108. IC109 takes
the IC106.5 clock directly, not the crossing IC62.2 wire. IC88.QC9 resets
IC109; IC109.QD8 clocks IC88. IC84.3 drives both mux enables, with inputs
from IC62.2 and IC62.6; the latter inverts IC83.Q9.

`fonz_picture` joins the above to the road gates and collision counters.
Important video connections:

| Destination | Source |
| --- | --- |
| IC5.9, IC5.10 | IC27.11, IC25.12 |
| IC7.10/2, IC7.11/1 | IC4.Q5, IC3.Q5 |
| IC6.11/13 | IC71.7 |
| IC6.10 | IC108.7 |
| IC6.9 | IC41.3 |
| IC6.2/3 | IC71.9 |
| IC6.1 | IC20.Q5 |
| IC45.1 / IC6.4 | IC108.9 |
| IC26.1 | IC101.6 |
| IC27.2 | IC102.Q13 |
| IC5.5 | IC28.QB4 |
| IC7.9, IC7.13 | IC5.6, IC27.3 |
| IC29 clock | IC47.1 |

All rows above were checked junction by junction on the native scan on 6 November 2026 (docs/NET_CHECKS.md).

IC47.1 crosses the IC27.3 return without joining it. Mixer outputs IC5.11,
IC7.8 and IC7.12 feed R13=1k, R26=470 and VR13=2k + R3=1k respectively.
R27=220 pulls up the junction; C16=4.7uF couples it to connector 7.

#### Mixer levels

`scripts/video_mixer_levels.py` solves the junction voltage. Assumptions:
TTL low is a 0.2 V source; TTL high is a 3.4 V source behind the output
diode, so a high output above 3.4 V carries no current; the junction is
unloaded, because C16 blocks DC and the monitor input is not on the drawing.
After AC coupling only the level relative to blank matters, so grey is
255 x (V - V_blank) / (V_white - V_blank) with blank = 100 and white = 111.
VR13 is taken at mid travel (1 kΩ, branch 2 kΩ).

| IC5.11 | IC7.8 | IC7.12 | Junction | Relative to blank | Grey | Meaning |
| --- | --- | --- | --- | --- | --- | --- |
| 0 | 0 | 0 | 2.870 V | -0.392 V | 0 | Sync tip |
| 0 | 0 | 1 | 3.065 V | -0.196 V | 0 | Not produced |
| 0 | 1 | 0 | 3.809 V | +0.548 V | 0 | Not produced |
| 0 | 1 | 1 | 4.134 V | +0.873 V | 0 | Not produced |
| 1 | 0 | 0 | 3.261 V | 0 | 0 | Blank / black |
| 1 | 0 | 1 | 3.470 V | +0.209 V | 31 | IC7.12 layer only |
| 1 | 1 | 0 | 4.524 V | +1.263 V | 185 | IC7.8 layer only |
| 1 | 1 | 1 | 5.000 V | +1.739 V | 255 | Both layers |

Sync sits 0.392 V below blank, and peak white is 1.739 V above it, so sync
is about 18% of the full 2.13 V swing. IC5.11 is composite sync (the XNOR of
IC27.11 and IC25.12, low in either sync). Those can only fall while IC4.Q5
or IC3.Q5 is high, and that holds IC7.8 and IC7.12 low, so 000 is the only
sync state the board makes. The module shows every IC5.11-low state as black.

VR13 changes only the IC7.12 branch. At 0 Ω, 101 is 51 and 110 is 140 (sync
-0.369 V, white +1.915 V); at 2 kΩ, 101 is 22 and 110 is 205 (sync
-0.400 V, white +1.675 V). `rtl/fonz_video_mixer.v` holds all three
settings, chosen by `VR13_SETTING` (default 1, mid), and passes IC5.11
through as `csync_n`. Its inputs are named for both ends of each wire:
`IC5_pin11_R13`, `IC7_pin8_R26` and `IC7_pin12_VR13`. It is not yet
instantiated in `fonz_board`.

### Player and position counters

The player section joins IC18, IC40, IC64/42 and control gates. IC64 preload
is `{1,0,IC61.6,IC39.8}`; IC42 preload is `0011`. IC19.6 goes through IC41.8
before reaching the two /LOAD pins. IC20A J/K are high; IC39.6 clears it.
IC62.10 inverts IC41.8 and drives IC38.5, IC60.4 and the IC63 clears.
IC40A J1, IC40A /CLR13 and IC40B /CLR10 are one wire from IC103.Q5, the
coin-meter pulse that also drives IC17.11; it crosses the IC62.10 vertical
without a junction. IC60.3 is a NAND (OR outline, bubbled inputs) of
IC59.4 and IC59.6, so it is high while either steering switch is closed; it
drives A8 (pin 14) of both lower shape PROMs IC86/87.

The upper-left IC22/44 and IC21/43 pairs share a clock and three preset
wires: 21.A=22.C, 21.B=22.D, 21.C=44.A. IC21 ENP/ENT are high. The shared
clock traces to IC4./Q6; the preset wires trace to IC18.QA/QB/QC. These
joins are instantiated in `fonz_scene`. IC83.S6 comes from IC25.12;
IC83.Q7 clears IC51. IC41.8 clears the IC106 oscillator, and its inverse
IC62.10 resets IC63. IC88's clears come from IC105.Q5 (the IC100.1 wire);
IC88.9 only clears IC109. IC37.4 feeds the common IC85 XOR inputs.
IC65.12 loads IC22/44; IC65.6 loads IC21/43 and also drives IC83.R5 and
IC92.2. IC84.11 = NAND(IC22.QD, IC44.QA) feeds IC101 pins 2 and 10.

These connections were checked junction by junction on the native scan on
6 and 8 November 2026 (docs/NET_CHECKS.md).

### Game, time and score

`fonz_game_and_score` joins the coin latch, the three game latches in IC83,
IC75/76, IC77/79, IC74, display muxes IC53..58 and the segment decoder.
IC76 is the time-units counter; its /BORROW drives IC75.DOWN. IC82.13
combines both /BORROW outputs and inhibits the timer through IC82.10.

IC83.S11 crosses the coin-reset wire without a junction; its source is
IC60.8. IC83.R1 and IC83.R14 share IC103B /Q12 (corrected 8 November 2026;
they had been on IC101.11). IC83.S2 comes from IC61.8. IC81.6 is IC103.12
AND IC61.8. IC82.3 is IC103A Q13, the same net as the time clear (it had
been on IC103A /Q4). The score clear wire comes from IC101.11; time clear
comes from IC103.Q13. IC59.8 supplies IC83.S15. Every net in this section
was checked on the native scan (docs/NET_CHECKS.md).

The display scan indices are 0=time tens, 1=time units, 2=score units,
3=score tens, 4=score hundreds, 5=score thousands. IC100.12 is an additional
open-collector driver on the BCD A wire, gated by IC81.11 from IC79.QA13
and selector 5. The sixth digit is not hardwired zero. IC78's seven used
inputs decode 1999 and clear IC74. Open-collector mux outputs resolve by
ANDing their pulled-up values.

The MiSTer score overlay (`rtl/mister/fonz_score_overlay.v`) is not part
of this trace; it only reads `digit_enable` and `segments_abcdefg`.

Found while testing it (8 November 2026), fixed by the net audit (docs/NET_CHECKS.md):
the score could not count in any static IC103 state, because IC82.3 had been
wired to IC103A /Q4 and the IC83 R inputs and IC81.5 to IC101.11. With IC82.3
on IC103A Q13 and those resets on IC103B /Q12, the idle board counts the
score from the IC92 clock, and the overlay test checks that real count.

### Board wiring

| Source | Destinations |
| --- | --- |
| IC45.8, the 14.305 MHz oscillator output | IC67 clock pin 12 |
| IC67./Q2 | IC37.9. The inverted output at IC37.8 clocks IC64/42 and IC40 and feeds IC41.2 |
| IC25.12 | IC83.S6, IC92.1, IC105 trigger pin 6 and IC47.12 |
| IC47.13, the NOR of IC24.QB and IC25.12 | IC61 pins 2 and 3, gating both steering directions |
| IC27.11 | IC97 trigger pin 9, IC67B /CLR10 and IC5.9 |
| IC65.6 | IC21/43 /LOAD, IC83.R5 and IC92.2 |
| IC103.Q5 | IC17.11 (coin meter), IC40A J1 and /CLR13, IC40B /CLR10 |
| IC105.Q5 | IC92.5, IC100.1 and both IC88 clears |
| IC84.11 | IC101 pins 2 and 10 |
| IC2.QB, QC, QD | IC58 scan inputs A, B, C respectively. D is grounded |
| IC83.Q9, IC24.QA, IC105.Q5 | IC92 pins 3, 4, 5 respectively in the score clock path |
| IC30./Q12 | IC27.4 and both IC99 reset pins |
| IC99.Q5, IC99.Q9 | IC100.9 and IC84.5 respectively |

IC96 takes its clock from IC95.4, which combines the conditioned AC sense
at IC37.10 with IC96B.QA feedback. IC30./Q4 clears both halves. IC96A.QD
clocks the second half and IC96A.QC drives the solenoid circuit through
IC100.10. IC103A takes the conditioned antenna signal at pin 1. Its /Q4
feeds both B10 and /CLR11 on IC103B, whose A9 comes from the coin pulse at IC38.8.

## Analogue boundaries

The following remain external responses, not implemented oscillators:

| Circuit | Evidence retained |
| --- | --- |
| Crystal oscillator | X1=14.305 MHz, external clock at IC45.8 |
| IC9 / IC106 | Modelled: `rtl/analog/fonz_shape_oscillator.v`, docs/SHAPE_OSCILLATORS.md. Paired 74123 feedback; 10pF timing capacitors, TR1/TR9 emitter followers on the shared Rext node, 470pF output loads |
| IC97B | C27 and C28, each 22nF, in parallel. Rext is R40 1k from TR5's emitter. Modelled (`fonz_road_timing`) |
| IC97A | C23=100pF, R36=10k. Modelled |
| IC102B | C46=100pF; Rext is R72 3.3k (with P4) from TR7's emitter. Modelled |
| IC102A | C42 and C43, each 4700pF, in parallel. Rext is R58 2.2k (with P3) from TR6's emitter. Modelled |
| IC104B / IC104A | 100pF timing capacitors. 104B Rext is R98 3.3k (with P5) from TR8's emitter; 104A R80=10k. Modelled |
| IC30A / IC30B | R28=47k, C17=47uF / R31=47k, C22=220uF |
| IC103A / IC103B | Antenna/start monostables; 47k with 220uF / 100uF |
| Throttle | Photocoupler cell on connector a/c into VR11/R107/C77 (about 4.7 s) and TR10, which sets IC105A's control voltage. See docs/CONTROLS.md |

The 556 timers IC98, IC99 and IC105 are modelled in `rtl/analog/fonz_556.v`
(one 556 half with its RC network, integrated on a clock enable) and wired
from their drawn values in `rtl/analog/fonz_556_timers.v`: IC98A
R39/R43/C29, IC99A R54/R53/C36, IC99B R45/R44/C32 (the sheet's pin 8/13
labels are swapped; the standard astable is used), IC105A R100/C68 as a
monostable with pin 3 from the throttle network, and IC105B
R101+VR10/R96/C61 with VR10 set to 77.8k: 0.707 s a count, the manual's standard 70 s game. The unit test is
`tb/fonz_556_tb.v`:

```sh
iverilog -g2005 -o build/tb_556 tb/fonz_556_tb.v rtl/analog/fonz_556.v rtl/analog/fonz_556_timers.v
vvp build/tb_556
```

The board still takes their Q outputs as inputs; a top level joins them.

### Road monostables

`rtl/analog/fonz_road_timing.v` closes the IC97/102/104 loop: it takes the
six `{A,B,/CLR}` vectors and returns the Q pins, using `fonz_74123_core`
for the pulses and a `real`-valued model of the four transistor networks
for the widths. It is a simulation model; the FPGA board needs a fixed-point
version. One road line is: IC27.11 falls at H=32, 97B delays to the left
kerb, 97A is a short gap, 102B is the left kerb, 102A the road, 104B the
right kerb, 104A a short gap, and its end sets IC20 (off road) until the next
97A. IC84.11 gates the kerbs into dashes.

Rext sources, followed on the native scan on 8 November 2026 (these correct
the earlier table, which put TR6 on 97B and TR8 on 102A):

| Stage | Rext from | Route on the native scan |
| --- | --- | --- |
| 97B | TR5 emitter through R40 1k | 97B pin 7 down x~5312, left along y~4067, up x~2713, left y~3789 to R40 |
| 102A | TR6 emitter through R58 2.2k / P3 | y~3755 right to x~6286, up to y~3416 at 102A |
| 102B | TR7 emitter through R72 3.3k / P4 | x~5665 up, y~3821, x~5900 up to y~3526 at 102B pin 7 |
| 104B | TR8 emitter through R98 3.3k / P5 | x~6600 up to y~3527, right to 104B pin 7 (x~6821) |

TR6, TR7 and TR8 are emitter followers on +5 V with emitter pull-ups R57
100k, R71 68k, R97 68k. Their bases are charged once a frame: TR2 (2SA484,
base from IC94.10 = NOT IC3.5) switches +5 V onto the line that feeds D6/D7,
D8/D9 and D10/D11 during V=0..15, and the base capacitors decay through the
frame, so the road and kerbs get wider down the screen. IC100.6 and IC100.4
ground the bottom of the 22 uF capacitors in the TR7 and TR8 networks during
the active frame and release them in V=0..15.

Simplifications, all stated in the module header: base currents are ignored;
the TR4/C20/C30 kick into TR5's base (IC100.8 from IC99, the road curves) is
not modelled; TR3's base network is unresolved, so TR3 is held off by
default (`TR3_RESET=0`) and the left road edge is fixed. With TR3 fully on
each frame the road vanishes from the top ~90 lines, which the footage does
not show. VR4 midway (1k, the manual's standard setting), VR7/8 at mid travel, P3/P4/P5 not fitted. VR6 is at 1k of its 10k
(11 November 2026): it sets how far TR6's base runs down through the frame,
so how much the road widens down the screen. At mid travel the road went
from 18 % to 32 % of the picture width; the manual's adjustment page draws
it almost edge to edge at the bottom and the footage has about 60 %. With
1k it is 19 % at the top, 45 % halfway and 59 % at the bottom. The
74123 width with a transistor supply V is the 'LS123 data-sheet width
K(C)*R*C (TI SDLS043 Figure 7, as in `fonz_74123`) scaled by
ln(V/(V-1.2))/ln(5/3.8).

`tests/tb_road_frame.v` runs the board for 10 frames with this model and
writes the last frame to `build/frames/`. `docs/reference/sim_road_frame.png`
is its mixer-code image (IC7.8 x4 + IC7.12 x2 + IC5.11, not monitor levels):
off road light, road mid grey, dashed kerbs, the road widening to the right
down the screen. With the 'LS123 timing of `fonz_74123` the road spans
H~160 to ~310 of the 80..453 active area, left of centre at the top and
widening to the right. R40 1k with 44 nF cannot make the 97B delay shorter
than about 17 us (left kerb near H=160); the curve and steering inputs that
move the road are not in yet.

`fonz_analog_connections` exposes 74123 A, B, /CLR vectors and expects Q
responses in return. It does not produce pulse widths. The analogue
transistor, diode, capacitor and variable-resistance networks still require
implementation. Timing cannot be recovered by setting these Q inputs to
constants. Cassette audio is intentionally absent.

Contact and edge conditioning (R76/C51, R77/C52, R67/C44 and the six
cabinet contact networks) is modelled; see docs/CONDITIONING.md.

### 74123 family (settled 9 November 2026)

The 74123s are 'LS123s. Confirmed on 9 November 2026. The schematic marks
them only "123/2", and the board photos are too blurry to read. The
evidence that pointed this way:
- IC30's 47 uF and 220 uF electrolytics connect directly, with no
  protection diode. TI recommends that diode for the standard '123 when
  /CLR is used (SDLS043 Figure 2), and says the 'LS123 needs none.
- The road position. IC97B's Rext is only R40 1k, where the standard
  '123's 0.7/Rt term adds 70%. With `FAMILY_LS=0` the left kerb ends near
  H=212 at the top of the frame, against H=159 for the 'LS123 and about
  H=135 in the gameplay footage (`tests/tb_road_frame.v`).
`fonz_74123` and `fonz_road_timing` default to `FAMILY_LS=1`. The
standard '123 setting is kept only for comparison.

## Unresolved details and next implementation work

- IC41 (settled by function, 6 November 2026). Pins 8 and 11 are
  drawn as ANDs (bubbled OR with bubbled output), pins 3 and 6 as NANDs, on
  both the main schematic and the service manual's sheet. One package cannot mix them.
  Pins 8 and 11 must be AND: as NANDs, the IC64/42 and IC18 /LOADs would be
  held low with their inputs idle high and the counters could never count.
  So IC41 is taken as a 7408 and pins 3 and 6 are modelled as AND. Pin 3
  also argues for it: as a NAND it would hold IC6.9 high with no road and
  hide both shapes over the whole screen. Pin 6 is a gated clock either way.
  Define `FONZ_IC41_DRAWN_NAND` to restore the drawn NANDs. Footage
  agrees: in the gameplay video at 20 s (docs/reference/README.md)
  the bikes and kerb dashes are the brightest marks on a grey field, so the
  IC7.8 layer (470 ohm, strongest) is lit only for objects and lines. With
  the drawn NAND that layer would be lit almost everywhere. The smoke test
  shows the same: IC7.8 stays off with no objects (AND) but follows the
  raster everywhere (NAND). No board photo of IC41's marking was seen.
- IC28's marking reads “392/B”. Its drawn pins (1, 2, 4, 13, 12, 8) match a
  74393 exactly and exclude a 74390, so it is modelled as a 74393. Only the
  label is unexplained. Both clocks, IC84.9 and IC100.5 are on the IC3B /Q6
  net (6 November 2026).
- Undrawn TTL inputs, checked on the native scan on 6 November 2026 and
  genuinely absent from the drawing: IC69 and IC91 DOWN (pin 4), IC76 UP
  (pin 5), IC83A second set input (pin 3; S1 pin 2 is drawn), IC33 LT
  (pin 3) and BI/RBO (pin 4). They are modelled inactive high, as a floating
  TTL input reads. The IC90 clears (pins 2 and 14) and the IC69/IC91 CLR
  pins (14) are drawn grounded, as coded. See docs/NET_CHECKS.md.
- Zero-delay asynchronous feedback may need a timed reference simulation
  before translating it into FPGA clock enables. No propagation timing or
  metastability is modelled, and no simulation result is claimed.
- Add analogue timing models, then retime for FPGA and add MiSTer
  integration. No such integration or bitstream exists yet.

The current validation is Python PROM extraction plus HDL parsing and
elaboration with slang. Passing it establishes HDL consistency only.
