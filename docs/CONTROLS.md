# Cabinet connector and controls

From the main schematic (native scan), checked against the service
manual's schematic (page 16) and its block diagram (page 7), 6 November
2026. Coordinates are native pixels.
"Idle" is the cabinet at rest: no coin, handlebar centred, grip released.

IC37 is a 7414 (inverting Schmitt), so a contact that closes to ground makes
its IC37 output go **high**.

## Inputs

| Control | Connector | Network | Board net (code) | Idle | Active |
|---|---|---|---|---|---|
| Accelerator switch (on the grip) | 16, return T | R83 510 Ω pull-up, R84 100 Ω, C47 22 µF, IC37 13→12, IC34 3→4 | `ic37_12` | 0 | 1 |
| Turn left | 17, return G | R85 510 Ω, R86 100 Ω, C48 22 µF, IC37 5→6, IC59 3→4 | `ic37_6` | 0 | 1 |
| Turn right | 18, return V | R87 510 Ω, R88 100 Ω, C49 22 µF, IC37 3→4, IC59 5→6 | `ic37_4` | 0 | 1 |
| Tilt switch | 1 (drawn beside W), return W | R89 510 Ω, R90 100 Ω, C50 22 µF, IC37 1→2 → IC82.2 | `ic37_2` | 0 | 1 |
| Coin switch, normally open contact | 21 | R94 510 Ω, R93 100 Ω, C60 0.01 µF → IC38.1 | `ic38_1` | 1 | 0 |
| Coin switch, normally closed contact | 20 | R92 510 Ω, R91 100 Ω, C59 0.01 µF → IC38.13 | `ic38_13` | 0 | 1 |
| Antenna | X | C54 0.1 µF, C53 0.1 µF, D17, R75 33 kΩ, R78 220 kΩ → IC103A A1 | `antenna_logic` | 0 | pulses |
| Throttle (photocoupler cell) | a, c | see below | analogue | dark | lit |

The coin switch is a changeover with its common grounded; IC38's
cross-coupled NANDs debounce it. Steering is two switches, not a pot: the
handlebar closes TURN SW LEFT or RIGHT, and IC18 counts while it is held.
The antenna input picks up pulses (the Fonz block diagram groups it with the
tilt switch, so it is an anti-cheat sensor); its idle level comes from R75
and R78 to ground.

## Throttle

The hand throttle is a **photocoupler**, not a pot or switch steps. Parts
list (manual page 12) lists a "Photocoupler Unit"; the block diagram calls
the input "PHOTO COUPLER & ACC. SWITCH".

- The board lights the lamp/LED: connector z ← R110 220 Ω ← IC39.3, where
  IC39.3 = NAND(IC41.13, IC30 /Q4). It is lit only during a game and not
  during a crash, so the speed falls away in attract mode and after a crash.
- The photocell is between c (+5 V) and a. Pin a is the node between
  R105 3.3 kΩ (from +5 V through VR12 10 kΩ) and VR11 10 kΩ to ground.
  More light (grip turned further) raises that node.
- VR11's wiper feeds R107 100 kΩ into C77 47 µF (time constant about
  4.7 s), then R108 3.3 kΩ to TR10's base. TR10 (emitter to ground through
  D14) pulls on the control-voltage pin 3 of IC105A (556), with R109 1 kΩ to
  +5 V and C67 0.01 µF. The throttle therefore sets IC105A's pulse width.
- IC105A: R100 56 kΩ, C68 0.15 µF, D18 on pins 1/2, triggered on pin 6 by
  IC25.12 once a frame; reset pin 4 high. Its output IC105.5 goes to
  IC100.1→2 (the IC106 oscillator control gate: scroll speed; D12/D13 there are
  fed from TR2, not from IC105.5, see docs/SHAPE_OSCILLATORS.md) and to
  IC92.5 (the score clock; the manual: 10 points a second at low speed,
  10 points a half second at full speed).

The ACCEL switch on connector 16 is separate: a contact on the grip that
drives IC34 and the ACCEL output (connector 24, sound) and the steering
gates. The circuit's electrical range (cell resistance at closed and
fully open grip) is not on the drawing. For MiSTer, the R2 trigger should
set the photocell's equivalent conductance, and the 4.7 s filter and
IC105A do the rest.

Crops: native (800,3700)-(3300,4900) for the IC105 network and
(0,4300)-(3000,7600) for the left-edge connector.

### MiSTer accelerator

`rtl/fonz_accel_input.v` turns the controller into a grip demand 0..255:
the furthest of R2, a stick axis picked on the OSD (`stick_sel`: none, left
stick up, right stick up, right stick down) and a full-throttle button. It
also gives the ACCEL grip contact (`grip`, demand above 12).

`rtl/fonz_throttle.v` models the network above from that demand to IC105
pin 3: the wiper voltage, C77 (R107/C77 with TR10's base clamping it at
Vbe + D14), the base current, and TR10 pulling pin 3 down from its 4.615 V
Thevenin level. The cell values are not on the drawing, so the wiper
moves linearly between two voltages (`WIPER_DARK_MV`, `WIPER_FULL_MV`, with
`BETA` 200) set from the manual's adjustment page, "Details of logic board
adjustments". Its two position lines run under the wheels of the player's
bike, measured from the bottom edge of the picture (18 3/4 in tall, 245
lines, 13.07 lines an inch):

| Grip | Manual: wheels above the bottom | Bike in the simulation | Wheels in the simulation | IC105A pulse | Pin 3 |
|---|---|---|---|---|---|
| at rest (start) | 3/4 in | lines 206 to 247 | 0.77 in up | 12.7 ms | 3.90 V |
| fully open | 12 3/4 in written, 61 % of the height drawn | lines 79 to 107 | 61 % of the height (11.5 in) | 4.8 ms | 2.16 V |

The page is not to one scale at the full-grip line: 12 3/4 in is 68 % of
an 18 3/4 in picture, but the line is drawn 61 % of the way up. Set to
the written figure (pin 3 1.85 V, bike on lines 65 to 91) the bike still
went too far up the road on the real board (12 November 2026), so
the full-grip wiper (3061 mV) follows the drawing. The start is unchanged.
Since 21 November 2026 VR-11 is on the OSD page "Board adjustments" as
"Grip height": 55 % to 80 % of the picture, 61 % (the drawing) by
default; the percentages are worked out from the throttle model
(docs/POT_SETTINGS.md), not measured.

The 2 in at the top of that drawing belongs to the road. An earlier
setting (10 November 2026) read it as the bike's top at full grip, which
took the wheels 14.9 in up. The bike's top is set by the IC105A pulse and
its height by the shape oscillator (42 lines at the start, the manual's
3 1/4 in, and 27 up the road, with VR-1/VR-9 at 1.8k;
docs/SHAPE_OSCILLATORS.md), so these two voltages need setting again if
the bike sizes change.

The R2 value reaches the core from the template's `hps_io`
(`joystick_rt_analog_0`, from Main_MiSTer's UIO_ATRIG command 0x46);
`fonz_core.v` feeds it to the machine as `joytrig`. A Main_MiSTer that does
not send 0x46 leaves the trigger at 0; the stick and button still work.

Test: `python scripts/test_throttle.py` (Icarus).

## Outputs

| Output | Connector | Driver | Code |
|---|---|---|---|
| GAME | Y | IC17 5→6 (7406 open collector) | `ic17_6` |
| ACCEL (to the sound unit) | 24 | IC17 3→4 | `ic17_4` |
| CRUSH (crash, to the sound unit) | 23 | IC17 1→2 | `ic17_2` |
| Coin meter | 25 | IC103.Q5 → IC17 11→10, R111 510 Ω, TR27 | not in the code yet (`ic103_5` is the drive) |
| Crash solenoid (in the handlebar assembly) | K, J (100 V AC) | IC100.10 → TR12 (MCD-725 photocoupler), TR11 (AC02D9M triac) | `ic100_10` |
| Video | 7 | IC5.11, IC7.8, IC7.12 mixer, R27, C16 | `ic5_11`, `ic7_8`, `ic7_12`; grey via `fonz_video_mixer` |
| Score and time digits | segments M, L, 10, 9, 8, P, N; digit commons 11, 12, 14, 15, R, 13 | IC33 7448, TR13..19; IC58/36/35 scan | `segments_abcdefg`, `digit_enable` |

## Crash solenoid

The solenoid shakes the **handlebars**, not the cabinet. The manual's
introduction (page 1) says that if you collide with another bike or skid
off the road, "the handle bars vibrate", and the handlebar assembly parts
list (parts catalogue page 3) has item 15, 94803, "Solenoid, AC 100V, 5Kg".

Drive, checked against the schematic on 11 November 2026:

- IC95 (NOR) pin 6 takes the conditioned AC sense from IC37.10, pin 5 takes
  IC96 pin 11 (2QA), and pin 4 clocks IC96 pin 1 (1A).
- IC96 pin 6 (1QD) goes only to pin 13 (2A), the small loop drawn over the
  package. Pin 5 (1QC) goes to IC100.11. Both clears (pins 2 and 12) share
  IC30 pin 4 (/Q, `CRASH_n`), so the count is held at zero except during a
  crash.
- IC100 11→10 sinks the LED of TR12, an MCD-725 photocoupler, whose anode
  is fed from + through R30 220 Ω (C21 22 µF on the supply). The coupler's
  output side fires TR11 (AC02D9M triac, R29 220 Ω), which switches the
  solenoid on connector K. IC100.10 **low** is solenoid on.

So the solenoid is on during counts 4–7 and 12–15 of the AC sense: two
kicks of four mains cycles. At count 16, 1QD falls, 2QA goes high and holds
IC95.4 low, stopping the count until `CRASH_n` clears it. The RTL
(`fonz_crash_divider` in `rtl/fonz_game_control.v`, generated
`_fpga` copy) matches this; `tests/tb_rumble.v` checks the two kicks.

## Rumble on crash (MiSTer option, not original circuitry)

The handlebar solenoid is the cabinet's only feedback; nothing on the board
drives a controller. `rtl/mister/fonz_rumble.v` is a MiSTer-only addition
that turns the two crash outputs into a rumble request:

| Board signal | Meaning | Rumble |
|---|---|---|
| `IC100_pin10_SOLENOID` low (`ic100_10` on the board) | solenoid energised (IC96A.QC: two kicks of four AC cycles) | large motor, full |
| `IC17_pin2_CN23` low (`ic17_2` on the board) | CRUSH active for the whole crash | small motor, about 38 % |

It takes the OSD enable and produces the MiSTer `hps_io` joystick rumble
word (`[15:8]` large motor, `[7:0]` small motor). Both inputs are
synchronised to the core clock. The output is zero when the option is off.

Hook-up in the core:

- The option is the OSD entry "Rumble on crash" (`status` bit 27, 0 = on,
  so it is on by default). `rtl/mister/fonz_core.v` passes it to
  `rumble_enable`.
- The rumble word goes to `hps_io`'s `joystick_0_rumble` in `mister/Fonz.sv`,
  which Main_MiSTer reads with command 0x003F.

`tests/tb_rumble.v` drives the traced IC96 divider with a time-scaled 60 Hz
AC sense and checks two four-cycle kicks, the CRUSH level for the whole
crash, and no output when disabled. Run it with
`python scripts/run_tests.py tb_rumble`.

## Power

| Supply | Pins |
|---|---|
| +12 V | G, F |
| Vcc (+5 V) | 26, 27, 28, d, e, f |
| GND | A, 1, B, 2, C, 3, D, 4, E |
| 12 V return | 5 |

## Unresolved

- Connector S beside J (bottom right) probably carries the AC sense that
  IC96 counts (`ic37_10`); not followed.
- IC17.11 (coin meter drive) is IC103.Q5: up from IC103 pin 5, left along
  y≈5999, up x≈5643 to the junction at IC17.11 (5641,5791). The same wire
  continues left along y≈5786 to the IC40 clears.
- The Fonz block diagram has an "Extended play time" input; no matching
  connector pin was found on the main schematic.

## MiSTer mapping

`rtl/fonz_cabinet_inputs.v` turns pad inputs into the levels on the wires
from the connector to the board (`CN16_IC37_pin13` and so on: 1 at rest,
0 while the switch is closed). The contact-conditioning models
sit on those wires; `fonz_contacts_direct` in the same file is a zero-delay
stand-in for the IC37 Schmitt stage until then, with outputs named
`IC37_pin12_ACCEL`, `IC37_pin6_LEFT`, `IC37_pin4_RIGHT` and
`IC37_pin2_IC82_pin2`.

| MiSTer | Contact | Notes |
|---|---|---|
| Left | Turn left, `CN17_IC37_pin5` | Left and right together close neither: the handlebar can't do both. IC18 counts while held. |
| Right | Turn right, `CN18_IC37_pin3` | |
| Button 1 | Accelerator switch, `CN16_IC37_pin13` | R2 and the chosen stick are the variable throttle. |
| Coin | Coin changeover, `CN21_IC38_pin1` (NO) and `CN20_IC38_pin13` (NC) | One coin per press, however long it is held: NC opens, 0.5 ms gap, NO closed 50 ms, 0.5 ms gap, NC closes. IC38 debounces it and IC38 pin 8 pulses once, on the return throw. |
| Start | Coin | The cabinet has no start button; the coin pulse on `IC38_pin8_COIN` triggers IC103B and starts the game. `START_IS_COIN=0` turns this off. |
| (unmapped) | Tilt, `CN1_IC37_pin1` | Port `pad_tilt`; tie low unless a key is assigned. |
| none | Antenna, `CN_X_IC103_pin1` | Held at its idle level. |

The pad ports are active high, as are hps_io's joystick bits. The test bench
`sim/fonz_cabinet_inputs_tb.v` checks the idle levels, the steering mask,
break-before-make on the coin switch and one IC38 pin 8 pulse per coin or start:

```
iverilog -g2012 -o build/inputs_tb sim/fonz_cabinet_inputs_tb.v rtl/fonz_cabinet_inputs.v rtl/fonz_game_control.v rtl/ttl/fonz_ttl.v
vvp build/inputs_tb
```

MiSTer names the inputs from the MRA's `<buttons>` element
(`scripts/make_mra.py`): Accelerate (button 1), Start and Coin, with
button 2 unnamed because nothing reads it, in the bit order of the J1
line in `mister/Fonz.sv`. There is no Pause: the board cannot stop. An MRA without that element makes
MiSTer list the inputs as A, B, X, Y (seen on a MiSTer, 12 November
2026). The default pad buttons are A for Accelerate, Start and Select for
Coin.

What the MiSTer itself needs for R2 and rumble:

- R2 comes from Main_MiSTer's analogue-trigger command (UIO_ATRIG 0x46),
  which only a recent Main_MiSTer sends, and only for a controller whose
  L2/R2 axes were captured when it was defined in the MiSTer menu. With an
  older Main_MiSTer, or a pad defined before trigger support, R2 stays at 0;
  the Accelerate button and the OSD stick still work.
- Rumble needs `rumble=1` in MiSTer.ini (the default) and a pad with force
  feedback. "Rumble on crash" is an OSD option, on by default.
