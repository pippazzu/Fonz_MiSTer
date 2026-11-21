# IC9 / IC106 shape oscillators

Two identical circuits. IC9 clocks the upper shape path (enters at 9.5),
IC106 the lower one (106.5). Each is a 74123 pair in a loop whose speed is
set by a transistor on the shared Rext node. Read from the native scan
the native scan, 8 November 2026: IC9 crop (1100,2400)-(4300,3500),
IC106 crop (2700,4100)-(4300,4900).

## Circuit

| Part | IC9 | IC106 |
|---|---|---|
| Gate (7416, open collector) | IC94.12 = NOT IC83.7 | IC100.2 = NOT IC105.5 |
| Rheostat from the gate | VR1 10k | VR9 10k |
| Series resistor | R7 2.2k | R99 2.2k |
| Coupling capacitor (- on the gate side) | C11 22 µF | C66 22 µF |
| Coupling resistor | R8 3.3k | R102 3.3k |
| Control capacitor to ground | C10 2.2 µF | C81 2.2 µF |
| Diode into the coupling capacitor (+) | D1 MA150 | D12 MA150 |
| Diode into the control capacitor | D2 MA150 | D13 MA150 |
| Base resistor | R6 33k | R103 33k |
| Emitter follower | TR1 | TR9 |
| Emitter resistor to the Rext node | R4 2.2k, P1 in parallel | R105 2.2k, P6 in parallel |
| Rext node pull-up | R5 68k | R104 68k |
| Timing capacitors | C4, C7 10 pF | C69, C71 10 pF |
| Pin 5 load | C6 470 pF | C70 470 pF |

The gate end of the rheostat and the (-) side of the coupling capacitor
are one node. Rheostat + series resistor and coupling capacitor + coupling
resistor are two parallel paths from that node to the control node.

**Diode feed.** All four diodes take their anodes from one wire: the
collector of TR2 (2SA684 PNP, emitter at +5 V, C13 220 µF) through VR2
(100 Ω rheostat). D12/D13 do not come from IC105.5; their wire runs from
native (2996,4426) up x≈2996 and along y≈3262 to the D1/D2 anodes
(`scripts/trace_net.py 2110 3262 R`). TR2's base is driven by IC94.10
(NOT IC3.5) through R15 510 Ω, with R14 3.3k base to emitter. The TR2 wire
and the IC83.7 wire both continue to other control networks; those were not
followed here.

**Pairs.** First half: A1 grounded, B2 from second /Q12, Q13 to second A9.
Second half: B10 high, Q5 out. Both /CLR from the clear net (IC101.6 for
IC9, IC41.8 for IC106). Both Rext/Cext pins (15 and 7) are on the shared
node; C4 sits between 14 and 15, C7 between 6 and 7.

**P1 / P6** are drawn as a resistor inside a box (P1) or an oval (P6)
across the emitter resistor. The part is not identified (a thermistor for
Vbe drift is likely). The model takes it as absent; `R_P` sets it.

## How it works

1. **Once a frame, TR2 tops up.** IC3.5 is high for about 778 µs at the
   start of the frame (measured on the board model: one pulse per
   16.566 ms). TR2 saturates and charges both control capacitors (via D2/D13)
   and both coupling capacitors (via D1/D12) to about 4.1 V.
2. **During the frame the gate decides.** With the gate pulling (IC94.12
   or IC100.2 low), the control capacitor drains through the rheostat and
   series resistor toward ground, held up through the coupling resistor by
   the coupling capacitor (22 µF, time constant 0.1 to 0.3 s). The
   coupling capacitor sags over the frame and is only partly topped up in
   the 778 µs of TR2, so from frame to frame it settles well below 4.1 V,
   and the control voltage falls further than the 4.1 V × (VR + 2.2k) /
   (VR + 5.5k) a full capacitor would give (see Range). With the gate released the gate end
   floats, the coupling capacitor's discharge loop carries no net charge off
   the control node, and the control voltage holds, losing only TR1's base
   current (about 0.1 V a frame).
3. **The control voltage sets the speed.** TR1 follows the control voltage
   (less Vbe and the base-resistor drop) and feeds the Rext node through
   2.2k, in parallel with R5 68k from +5 V. More control voltage, more
   charging current, shorter 74123 pulses, a faster oscillator.
4. **The pair alternates.** Each half's end triggers the other, so the
   period is 2 × (trigger delay + pulse width) and pin 5 is a square wave.

For IC106, IC105.5 is the throttle-controlled 556 pulse triggered once a
frame (docs/CONTROLS.md): the longer the pulse, the longer the gate pulls,
the lower the control voltage and the slower the lower shapes. Open
throttle gives a short pulse and a fast oscillator. For IC9 the gate is
the IC83.7 latch from the position counters.

## Pulse width

Rext network as a Thévenin source: R5 to 5 V in parallel with the emitter
path (2.2k + 33k/(β+1)) to Vcontrol − Vbe. The width follows the '123 rule
of `fonz_74123.v` (TI SDLS043): below 100 pF it is a straight line from
the Cext→0 width of Figure 4 (15 ns + 6 ns/kΩ × Rt) to the page-7 formula
0.28 Rt Cext (1 + 0.7/Rt[kΩ]) at 100 pF. At Cext = 10 pF that line is
15.46 ns + 8.2 ns/kΩ × Rt, written here as 9.72 ns + 0.28 (Rt + 700 Ω) ×
29.29 pF. The 0.28 is taken as the cap charging from 0 V toward the
network's Thévenin voltage to an equivalent threshold of 1.22 V
(ln(5/3.78) = 0.28 at Veq = 5 V), so a source below 5 V charges more
slowly. Below a control voltage of Vbe + 1.22 V the emitter cuts off
part-way and R5 finishes the charge. The trigger delay is 22 ns.

## Range

Frequency of pin 5 against the control voltage, default parameters
(`python scripts/shape_osc_table.py --table`):

| Control voltage | Pulse width | Period | Frequency |
|---|---|---|---|
| 0 to 0.50 V | 573 ns | 1189 ns | 0.84 MHz |
| 0.75 V | 573 ns | 1191 ns | 0.84 MHz |
| 1.00 V | 530 ns | 1105 ns | 0.90 MHz |
| 1.25 V | 460 ns | 963 ns | 1.04 MHz |
| 1.50 V | 373 ns | 789 ns | 1.27 MHz |
| 1.75 V | 273 ns | 590 ns | 1.69 MHz |
| 2.00 V | 169 ns | 383 ns | 2.61 MHz |
| 2.25 V | 123 ns | 290 ns | 3.45 MHz |
| 2.50 V | 99 ns | 242 ns | 4.13 MHz |
| 2.75 V | 84 ns | 212 ns | 4.73 MHz |
| 3.00 V | 73 ns | 190 ns | 5.25 MHz |
| 3.25 V | 65 ns | 175 ns | 5.72 MHz |
| 3.50 V | 59 ns | 163 ns | 6.15 MHz |
| 3.75 V | 54 ns | 153 ns | 6.55 MHz |
| 4.00 V | 50 ns | 145 ns | 6.91 MHz |
| 4.25 V | 47 ns | 138 ns | 7.24 MHz |

The physical span is 0.84 MHz (transistor off, R5 alone) to about
7 MHz (control at the top-up level). With an 'LS123 (Figures 6 and 7) the
same network would give about 0.56 to 6.0 MHz. In operation the control voltage
stays between the top-up level and the rheostat's floor:

Steady state (12th frame) from the reference model, gate pulling from the
top-up on; "half" releases it at mid-frame (line ~143). Control voltage and
pin-5 frequency:

| VR1 / VR9 | line 14 | line 53 | line 133 | line 253, gate half | line 253, gate all frame |
|---|---|---|---|---|---|
| 0 | 3.87 V, 6.72 MHz | 2.17 V, 3.21 MHz | 1.14 V, 0.97 MHz | 1.09 V, 0.94 MHz | 0.90 V, 0.87 MHz |
| 5k | 4.00 V, 6.91 MHz | 2.99 V, 5.23 MHz | 2.01 V, 2.66 MHz | 1.93 V, 2.34 MHz | 1.58 V, 1.37 MHz |
| 10k | 4.03 V, 6.94 MHz | 3.17 V, 5.58 MHz | 2.28 V, 3.54 MHz | 2.20 V, 3.29 MHz | 1.83 V, 1.92 MHz |

With the gate released all frame the control holds near 4.1 V (about
7 MHz). So within a frame the oscillator slows from about 6.9 MHz toward
0.9 to 1.9 MHz for as long as the gate pulls, and stays where it is once the
gate lets go. The rheostat sets how far it can fall.

The fast end leans on the trigger delay and the Cext→0 width (about 40 %
of the period at 4 V), both typical data-sheet figures; the slow end on R5
and the small-C line. Both ends move with the 74123 family, which is not
marked on the scan.

## Bike size

The manual's adjustment page ("Details of logic board adjustments") draws
the player's and the opponents' bikes 3 1/4 in tall at the start, on a
picture 18 3/4 in tall: 42 of the 245 visible lines. It sets the size of
all the bikes with VR-2 (to the left, larger) and of each bike with VR-1
(IC9, the opponents) and VR-9 (IC106, the player). In the machine model it
is the other way round (12 November 2026, docs/POT_SETTINGS.md): VR-1 at
10k shrinks the player's bike and VR-9 the opponent's, as IC9 clocks the
upper shape PROMs (IC86/IC87, the player's layer in docs/COLLISION.md).
Which of the two the manual means is still to be checked.

Measured in the whole-machine Verilator model, player's bike at the start,
its top held at the same line by IC105 pin 3:

| VR1 / VR9 | VR2 | Height |
|---|---|---|
| 5k | 0 | 28 lines |
| 5k | 50 Ω | 29 lines |
| 5k | 100 Ω | 31 lines |
| 2k | 50 Ω | 40 lines |
| 1.8k | 50 Ω | 42 lines |
| 1.6k | 50 Ω | 44 to 45 lines |

VR2 goes the way the manual says but cannot reach the standard size here,
so VR1/VR9 are set to 1.8k and VR2 stays midway. That VR2 moves the size so
little may point at the TR2 top-up in the model (it charges the capacitors
through VR2 for only 778 µs a frame).

Size matters to the crash: IC29 counts the overlap pulses of the two
shapes each frame and fires IC30 at 32. At 5k an opponent passing straight
through the resting player reached 17, so there was no crash; at 1.8k it
reaches 69 and crashes. The opponents' bikes are 42 lines too.

The bike's height sets where its wheels are, so the throttle limits
(`fonz_throttle` `WIPER_DARK_MV`, `WIPER_FULL_MV`) were set again with
it (docs/CONTROLS.md).

## Models

- `rtl/analog/fonz_shape_oscillator_ref.v`: real-valued, event-timed
  reference (simulation only). Control network by forward Euler at 1 µs,
  the floating gate end solved algebraically; retriggerable halves with
  exact delays.
- `rtl/analog/fonz_shape_oscillator.v`: synthesisable. The same network
  in fixed point (µV, Q32 coefficients) on a 1 µs tick; the half period
  from a 320-entry table against the control voltage; two
  `fonz_74123_core` halves given that half period in clock
  cycles less one cycle of trigger latency, with the fraction carried so
  the mean frequency is exact. Constants come from
  `rtl/analog/fonz_shape_osc_table.vh`, written by
  `scripts/shape_osc_table.py`. The coefficients VR1 [VR9] and VR2 set
  are tables over the OSD settings (docs/POT_SETTINGS.md), picked by
  `vr_code` / `vr2_code` at the 1 us tick. 1 - G2 is Q29 and G1 Q30 since
  12 November 2026: before, 1 - G2 was Q31 and cut to 26 bits, which
  dropped its top bit (0.032 became 0.0009) at 1.8k. With it whole the
  bench's worst difference at 1.8k fell from 8.0 mV to 5.4 mV.
- `sim/shape_oscillator_tb.v` drives both with the same frames and checks
  them against each other: worst difference 3.2 mV and 0.8 % in period at
  114.44 MHz with VR1 at 5k, 8.0 mV and 1.7 % at 1.8k.

Both models answer the `{A,B,/CLR}` vectors of
`fonz_shape_oscillator_connections`, plus `gate_oc` (IC94.12 or IC100.2)
and `tr2_base_oc` (IC94.10), all with 1 meaning released.

**Clock.** The oscillator reaches about 7 MHz, so the synthesisable model
needs a clock well above that: at 114.44 MHz (8 × 14.305 MHz) a fast half
period is 8 cycles. At 14.305 MHz it would be one or two cycles and the
fast end would be lost.

**Symmetry.** A perfectly matched pair started together by /CLR (which
triggers both halves, A low and B high) locks in phase at twice the
frequency. Real parts never match; the models run the second half about 1 %
long, so the pair settles to alternating within one cycle, as the real one
does.

## Assumptions

| Item | Value | Why |
|---|---|---|
| VR1, VR9 | 1.8k | Sets the bikes to the manual's standard size ("Bike size") |
| VR2 | 50 Ω (mid) | Same |
| P1, P6 | absent | Part not identified |
| TR1, TR9 β | 100 | Type not drawn |
| 74123 family | '123 rule of `fonz_74123.v` | Not marked. The model defaults to 'LS123 for the fixed parts; the 'LS123 equivalents are in the reference model's header |
| Diodes | 0.65 V + 10 Ω | MA150 small-signal |
| Not modelled | C6/C70 470 pF on pin 5 | Slows the pin-5 edges seen downstream (tens of ns), not the loop, which runs on pins 13 and 12; the board feeds pin 5 back as /Q, which the models follow |
