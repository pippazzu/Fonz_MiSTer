# Net checks against the native scan

Each entry is one net, followed on the native scan (13560 x 8809),
with native pixel coordinates so it can be re-checked. "Junction" means an
open-circle join dot was seen in a crop. Wires that cross without a dot are
not joined. Routes were followed with `scripts/trace_net.py` and confirmed in
crops.

Status: **confirmed** (code matched the scan), **corrected** (code changed),
**open** (not settled; reason given).

## IC3B /Q6 net (frame-rate signal) — corrected 6 November 2026

Driver IC3B pin 6. Members: IC3B K11, IC3A /CLR13, IC28 pins 1 and 13,
IC84 pin 9, IC100 pins 5 and 3.

Route from IC28: up x≈11263 (junction to IC84.9 at y≈4109; IC28.1 at
y≈4564), left along y≈2690 (junction at IC3B /Q6, x≈8621), up x≈6502, left
y≈1890, up x≈5655, left y≈1490, down x≈988, right y≈4140, down x≈4494,
right y≈4725 (junction at IC100.5, x≈4697) to IC100.3 (x≈5817).

`python scripts/trace_net.py 11263 4540 U` reproduces it.

An earlier reading had IC28.1 on IC30.5, and IC28.13, IC84.9, IC100.3, IC100.5 on IC30.13.

## IC30 pin 13 (Q of the first 74123 half) — confirmed 6 November 2026

Right to x≈10952, down to y≈4778, left to x≈10178, down to y≈7212, left
along the bottom to x≈692 (faint between x≈800 and 1020), up to IC17 pin 1.
No junctions on the way. Only load: IC17.1 (IC17.2 → connector 23, CRUSH).

## IC30 pin 4 (/Q of the first 74123 half) — confirmed 6 November 2026

Down x≈10210 (junction at y≈5303 → right to IC96 pins 2/12 at x≈11254),
left along y≈7142 to x≈2784, up to y≈5891, left to x≈2263, down to the
junction at IC41 pin 12 (x≈2264, y≈5920). From there left along y≈5920 to
x≈1750, up to y≈5690, left to x≈731, up to y≈5067, right to x≈1645 and up to
IC39 pin 2. IC28 pin 2 joins this wire beside IC30.
Loads: IC96 /CLR (both), IC41.12, IC39.2, IC28.2.

## IC39 pin 1 — confirmed 6 November 2026

Down from IC39 to the junction on the IC17 pin 5 wire (x≈1676, y≈5222):
the same net as IC41.13 and IC17.5 (`IC62_pin6_GAME_LATCH_n` in the code). It crosses the
y≈5098 wire without a dot.

## Raster J-K flip-flops — corrected 6 November 2026

- IC4A K4 = IC45.6 / IC4B J8 (the H=453 decode).
- IC3A K4 = IC26.4 / IC3B J8 (the V=261 decode).

Both had been wired to the other half's /Q6.

## IC69/IC91 /LOAD, IC67B clock, IC9 /CLR — corrected 6 November 2026

Driver IC101 pin 6 (NAND of IC102.5 and the R67/C44 node). Route from the
counters: IC69.11 (junction x≈4112) and IC91.11 sit on the y≈2488 wire,
which runs left to x≈3430 and up to IC67B CK9 (y≈2282). A junction at
x≈3797 takes it down to y≈3229 (junction) where it meets IC9 /CLR3 and
/CLR11 (x≈3383), then right to x≈5130, down to y≈3347, right to x≈5810,
up to y≈3150 and right to x≈6550, down to IC101.6.

An earlier reading had all of these on IC91 pin 12 (carry). IC91.12 only feeds IC47.9.

## IC47 pins 8 and 9 — corrected 6 November 2026

IC47.8 = IC69.12 (junction on the IC69.12 → IC91.5 wire, x≈4232 y≈2283)
and IC47.9 = IC91.12. An earlier reading had IC67.6 and IC69.12. IC47.10 → IC25.4 and
IC92.9 (y≈2162), and IC67.6 → IC92.11 and IC48 /CLR (y≈2194, down x≈4575):
both confirmed as coded. Crop at native (3300,1950)-(5300,3150).

## Undrawn inputs — confirmed 6 November 2026

| Pin | On the drawing | Model |
|---|---|---|
| IC69.4, IC91.4 (DOWN) | absent; CLR14 grounded (IC69 via the A/B ground junction, IC91 directly) | high |
| IC90.2, IC90.14 (CLR) | grounded (crop at native 3592,2104) | 0 |
| IC76.5 (UP) | absent; DOWN4 → IC82, B1 and C10 to ground, A15 and D9 to IC59.12 | high |
| IC75 | UP5 and A15 to +5 V, B1 to IC83.13, C10 ground, D9 IC59.12 | as coded |
| IC83A pin 3 (second set) | absent; R1, S2, Q4 drawn (crop at native 6640,6240) | high |
| IC33.3 (LT), IC33.4 (BI/RBO) | absent; drawn pins 5 RBI, A7 B1 C2 D6, a..g, GND | high |

## Raster and video audit — 6 November 2026

Every row of TRACE.md's video connection table, followed from the gate input
back to its driver with `scripts/trace_net.py` and confirmed in crops:

| Input | Driver | Status | Evidence (native) |
|---|---|---|---|
| IC5.9 | IC27.11 | confirmed | run left from (10040,1880) ends on the IC27.11 vertical (9485,1878) |
| IC5.10 | IC25.12 | confirmed | left y≈1919, down x≈9537, left y≈2128; IC25.12 rises at x≈8837 and joins it with a dot (8837,2119) |
| IC7.10 and IC7.2 | IC4.Q5 | confirmed | shared vertical; run ends at the IC4B Q5 / IC27.13 junction (9304,1795) |
| IC7.11 and IC7.1 | IC3.Q5 | confirmed | left y≈1993, down x≈9578 (junction at y≈2132, branch right), left y≈2150; IC3.Q5 rises at x≈8635 and joins with a dot (8635,2147) |
| IC6.11 and IC6.13 | IC71.7 | confirmed | ends at IC71 1Y (5501,2284); separate from the IC45.1/IC6.4 wire on the same x |
| IC6.10 | IC108.7 | confirmed | ends at IC108 1Y (5034,4951) |
| IC6.9 | IC41.3 | confirmed | ends at IC41.3 (6769,3962) |
| IC6.2 and IC6.3 | IC71.9 | confirmed | vertical x≈10182; ends at IC71 2Y (5762,2286) |
| IC6.1 | IC20.Q5 | confirmed | ends at IC20B Q5 (5876,3936) |
| IC45.1 and IC6.4 | IC108.9 | confirmed | ends at IC108 2Y (5428,4953) |
| IC26.1 | IC101.6 | confirmed | ends at IC101.6 (6498,3231) |
| IC27.2 | IC102.13 | confirmed | ends at IC102B Q13 (6574,3627) |
| IC5.5 | IC28.4 | confirmed | see the IC3B /Q6 entry |
| IC7.9 / IC7.13 | IC5.6 / IC27.3 | confirmed | crop at (9400,1900)-(11000,3600) |
| IC29 clock (1A) | IC47.1 | confirmed | ends at IC29 1A (10453,4548) |

Gate types and the other inputs in the same crop also match the code:
IC7.8 = NOR(10, 11, 9) and IC7.12 = NOR(2, 1, 13); IC6.8, IC6.12 and IC6.6
NOR3; IC47.1 = NOR(IC6.12, IC45.2); IC27.3 = NAND(IC27.2, IC6.6);
IC6.5 ← IC26.2; IC5.6 = XOR(IC6.8, IC28.4). Mixer: IC5.11 via 1 kΩ,
IC7.8 via R26 470 Ω, IC7.12 via VR13 2 kΩ + R3 1 kΩ, joined and coupled by
4.7 µF to connector 7 (H is ground).

Raster decodes:

- IC89 (H=453): 5 ← IC68.QA, 6 ← IC68.QC, 3 ← IC46.QC (dot), 4 ← IC46.QD,
  1 ← IC4.Q3, 2/12/11 to +5 V. IC27.8 = NAND(IC46.QA, IC46.QC). Crop
  (7300,1250)-(8950,1900).
- IC25.8 (V=261): 9 ← IC24.QA (dot), 10 ← IC24.QC (dot), 11 ← IC3.Q3.
  IC26.10 ← IC24.QD, IC26.12 ← IC2.QA. Crop (7000,2050)-(8300,2700).
  The 74161 load is synchronous, so the counter shows 261 for one pixel
  clock and the frame is 261 lines (about 60.4 Hz).

Not followed individually: IC93's inputs and the IC95 decode gates (they are
not on the video path's table).

The audit also found the upper-shape /LOAD and IC47 errors recorded above.

## Player, steering and position counters — 6 and 8 November 2026

Confirmed (crops at native (1800,4600)-(3150,6200) and (2950,4450)-(3750,5150)):

- IC64: PT/PE +5 V, CK shared with IC42 and IC40B CK9, CL1 +5 V, preset
  D=+5 V, C=ground, B ← IC61.6, A ← IC39.8; CA → IC42 PT/PE and IC19.3.
- IC42: CL1 +5 V, preset A=B=+5 V, C=D=ground; CA → IC20A CK12 (C75
  220 pF) and IC19.4. IC64.9 and IC42.9 (/LOAD) share the wire from IC41.8.
- IC20A: J, K +5 V, CLR13 ← IC39.6, Q3 → IC19.5.
- IC19.6 = NAND(IC64 carry, IC42 carry, IC20.Q3); IC41.8 = AND(IC19.6,
  IC39.6) → IC64/42 /LOAD, IC62.11 and IC106 /CLR11.
- IC40B: J8 = K11 ← IC95.1, CK9 shared clock, Q5 → IC40A CK12 and IC39.5.
  IC40A: J1, CLR13 and IC40B CLR10 are one wire; K4 ground; /Q2 → IC39.4.
  The two dots on IC40B's Q5 run (x≈2094 and x≈2125, y≈5098) are on
  separate wires: the paper between them is blank.
- IC18 (74192): UP ← IC19.8, DOWN ← IC19.12, LO ← IC41.11, CLR ground,
  preset A=C=+5 V, B=D=ground (0101).
- IC19.8 = NAND(IC28.8, IC34.4, IC39.11); IC19.12 = NAND(IC28.8, IC37.12,
  IC62.12). IC19.11/13's wire ends at pin 13; pin 1's wire is separate.
- IC39.11 = NAND(IC18.QC, IC18.QA); IC82.4 = NOR(IC18.QC, IC18.QB);
  IC39.8 = NAND(IC61.12, IC61.6) → IC64.A; IC41.11 = AND(IC30 /Q4,
  IC41.13 net).

Completed 8 November 2026:

| Net | Status | Evidence (native) |
|---|---|---|
| IC62.10 → IC38.5, IC60.4 | confirmed | down x≈3373 to y≈6236, left to x≈1967, up; dot at IC60.4 (1968,6189) |
| IC62.10 → IC63 /CLR 2, 12 | confirmed | branch right along y≈5112 (dot at 3372,5112), dot at IC63 (3927,5113), on to pin 12 |
| IC40A J1, /CLR13, IC40B /CLR10 | **corrected**: IC103.Q5, was IC62.10 | the J1/CLR wire (x≈2125) runs down to y≈5286, right, and crosses the IC62.10 vertical at (3372,5286) with no dot (5x crop); down x≈3406, right along y≈5786 to the IC17.11 junction (5641,5791), down x≈5643, right along y≈5999, down to IC103 pin 5 |
| IC88 /CLR 2, 12 | **corrected**: IC105.Q5, was IC62.10 | left along y≈5990 to the dot on x≈3511 (3511,5981); up to y≈4539, left to x≈2963 and up to the IC105.Q5 dot (2966,4465), which continues up to IC100.1 |
| IC38.4 | confirmed IC95.10 | left along y≈6033, up x≈667, along y≈1413, down x≈10079 to IC95.10 |
| IC60.5 | confirmed IC95.13 | left along y≈6063, up x≈637, along y≈1442, down x≈10047 to IC95.13 |
| IC61.13 | confirmed IC38.6 | crop at (1700,5950)-(3500,6600) |
| IC61.1 | confirmed IC37.6 | y≈6375 left to x≈1516, up to the IC37.6 / IC59.3 junction (1518,6270) |
| IC61.2 and IC61.3 | confirmed IC47.13 | shared vertical x≈2274 (dot at 2274,6268); IC47.13 → up x≈6857, left y≈2391, up x≈6597, left y≈1795, up x≈5876, left y≈1550, down x≈612, right y≈6094, down x≈1780; no junctions |
| IC61.5 | confirmed IC60.6 | down x≈2213 |
| IC61.4 | confirmed IC37.4 | up x≈2272 from the dot at (2276,6796); pins 3 and 4 are separate wires (5x crop at 2280,6475) |
| IC59.4, IC59.6 | confirmed ← IC37.6, IC37.4 | crop at (1350,6150)-(2400,6900) |
| IC60.3 gate | **corrected**: NAND, was NOR | OR outline with bubbled inputs and no output bubble, drawn the same as IC39.8 (crop 1680,6400) |
| IC60.3 load | **corrected**: IC86/87 A8, was IC88.9 | right along y≈6407, up x≈4152, right along y≈5756; dots at (4898,5757) to IC87.14 and (5390,5429) to IC86.14. The IC88.9 wire stops at y≈5818 and turns left to the IC109 clears (dot 3741,5810): 5x crop at (4840,5730) |
| IC92.2 | **corrected**: IC65.6, was IC27.11 | the IC65.6 wire (y≈2660) runs right to x≈3460, jogs down to y≈2702 and crosses x≈3600 (the IC27.11 route) with no dot, to IC92.2. IC27.11 goes only to IC5.9, IC67B /CLR10 (dot 3551,1941) and IC97.9 |
| IC22/44/21/43 clock | confirmed IC4B /Q6 | x≈1285 and y≈1685 (dot to IC22.CK at 1498,1686), IC44.CK via x≈1995; y≈2533 to IC21/43 CK; right along y≈2533, up x≈3051, ... to IC4A /CLR13 (8551,1935) and the IC4B K11 / /Q6 wire (9068,1941) |
| IC22 | confirmed | PT/PE/CL +5 V; A=B=ground; C ← x≈1170, D ← x≈1201; QD11 crosses the +5 V wire at (1777,1842) with no dot and goes to IC84.12; LD9 ← IC65.12 |
| IC44 | confirmed | PT/PE ← IC22 CA; CL +5 V; A ← x≈1232; B=C=D=+5 V; QA14 → IC84.13; LD9 ← IC65.12; CA → IC66A CK12 (C18) and IC65.2 |
| IC21 | confirmed | PT/PE, D, CL +5 V; A, B, C at the dots (1172,2562), (1204,2594), (1234,2624): 21.A = 22.C, 21.B = 22.D, 21.C = 44.A |
| IC43 | confirmed | PT/PE ← IC21 CA; A..D and CL +5 V; CA → IC66B CK9 (C81) and IC65.4 |
| preset wires | confirmed IC18.QA, QB, QC | x≈1170/1201/1232 down to y≈5429/5397/5368; dots at IC18.QA (2400,5431), QB (2448,5399), QC (2494,5370) |
| IC65.12 | confirmed | NAND(IC22.CA, IC44.CA, IC66.Q3); down x≈3019, left along y≈2157 to IC22.9 and IC44.9 only |
| IC65.6 | confirmed | NAND(IC21.CA, IC43.CA, IC66.Q5); dot at (2985,2660) on the y≈2660 wire with IC21.9 (1884) and IC43.9 (2359); left to IC83.R5 |
| IC66A, IC66B | confirmed | J, K, /CLR +5 V |
| IC84.11 | confirmed | NAND (OR, bubbled inputs) of IC22.QD and IC44.QA; along y≈1814, ..., to IC101.2 (dot 6249,3873) and IC101.10 |

IC92.13 and the rest of IC92/IC101 were not followed (outside this check).

## Coin, game latches, timer and score — 8 November 2026

Every input in `fonz_game_control.v`, `fonz_score.v`,
`fonz_score_decode.v` and `fonz_scoreboard.v` followed to its driver
with `scripts/trace_net.py` and checked in crops. Two nets corrected, the
rest confirmed.

### Corrected

| Pin | Was | Is | Evidence (native) |
|---|---|---|---|
| IC82.3 | IC103A /Q4 | IC103A Q13 | IC82.3 rises on x≈6087 and joins the y≈6198 wire with a dot (6085,6198). That wire runs left to x≈5316 and down to IC103A pin 13 (y≈6718); right, it reaches x≈6931 and rises to IC75 CLR14 (dot 6933,5872), the time-clear net. /Q4 is the separate y≈6165 wire above it (IC103B B10 dot 6058, CLR11 dot 6182, IC101.13) |
| IC83.R1, IC83.R14, IC81.5 | IC101.11 | IC103B /Q12 | One vertical at x≈6958: R1 corner (6958,6662), R14 dot (6957,6430), IC81.5 dot (6963,6134), top dot (6962,5979) on the y≈5975 wire. That wire comes from the IC103.12 → IC101.12 dot (6352,6105) up x≈6352. IC101.11 leaves on its own wire, up x≈6505 and right along y≈6007, crossing x≈6958 with no dot |

With the old wiring IC82.1 was held low by the idle-high /Q4, so IC83.Q9
stayed set and the score clock (IC92.3) was blocked in every steady state.
IC103A Q13 idles low, so IC82.1 now follows only the tilt input. Likewise
the IC83 latches were held reset whenever both IC103 halves were idle
(IC101.11 idles low); IC103B /Q12 idles high and pulses low on a coin.

### Confirmed

- IC38 coin latch: 1 ← connector 21 via R93 (dot 6145,6770), 13 ← connector
  20 via R91/C59, 2 ← 11, 12 ← 3; 9 is the R76/C51 node from 38.3, 10 ← 38.11.
  IC38.8 → IC83.R10 (dot 6665,6535) and up to IC103B A9.
- IC83C: S12 ← IC82.1; S11 ← IC60.8 (down x≈7900, left y≈7060, up x≈6700),
  crossing the IC38.8 → R10 run at (6698,6535) with no dot; Q9 → dot
  (6861,7090) on the y≈7090 wire → right, up x≈8611 to IC92.3.
- IC83D: S15 ← IC59.8 (down x≈9598 to y≈7042, left, up x≈7018). Q13 →
  IC60.13, IC61.9, IC59.13 and IC75.B1 (y≈6069).
- IC83A: S2 ← IC61.8 (x≈6985, also IC81.4); Q4 → IC59.1 and IC17.9.
- IC82.13 = NOR(IC75.13 on pin 12, IC76.13 on pin 11) → IC82.9, IC60.9,
  IC61.10 (x≈7700). IC82.10 = NOR(IC82.13, IC105.Q9) → up x≈7596 to IC76.DOWN4.
  IC75.DOWN4 ← IC76.13 (dot 7072,5832).
- IC60.11 = NAND(IC83.13, R77/C52 node); IC60.8 = NAND(IC60.11, IC82.13);
  IC61.8 = NAND(IC83.13, R77/C52 node, IC82.13). IC81.6 → LO11 of both
  192s (dots 7115/7149 on y≈5900).
- IC75/76 presets as in the undrawn-input table above; D9 of IC75 and A15,
  D9 of IC76 on IC59.12 (y≈6046). IC76 CL14 is the y≈5869 wire from IC75
  CL14. The "14" label on IC76 sits over the LOAD wire, which ends on the
  box edge; read literally that would tie CLR to LOAD and hold the counter
  cleared, so it is taken as a drafting slip.
- IC92.6 = NOR(83.Q9, 3; 4; 5) → IC27.5; IC27.6 → IC74.1A; IC74 1QD6 → 2A15;
  IC74 2QD8 → IC77.15 (x≈7968); IC74 clears 2/12 ← IC59.10 (x≈9564).
- IC77/79 (74390, drawn half numbers swapped on IC77): 13→12, 9→1, 3→4,
  7 → IC79.1 (dot 8449,5871); IC79 3→4, 7→15, 13→12. All four clears on the
  IC101.11 wire (y≈6007, dots at x≈8080, 8237, 8615, 8833).
- IC78 (1999): 3 ← IC79.13, 4 ← IC79.7, 2 ← IC79.3, 12 ← IC77.3,
  5 ← IC77.13, 1 ← IC77.7, 11 ← IC77.9, 6 +5 V. IC78.8 → IC59.11 → 59.10.
- IC80B NOR4 (strobe 11 +5 V): 9 ← IC79.7, 10 ← IC79.6, 12 ← IC79.5,
  13 ← IC79.3. IC80A (strobe 3 +5 V): 1 ← digit 0, 4 ← digit 5,
  2 ← IC81.3, 5 ← IC81.8; IC80.6 → IC33.5 (RBI).
- IC81.11 = AND(IC79.13, digit 5) → IC100.13; IC100.12 → BCD A wire.
  IC59.8 = NOT IC79.13 → IC81.2 and IC83.S15. IC81.3 = AND(digit 4, IC59.8).
  IC7.6 = NOR(58./Y3 on 3 and 4, IC79.13 on 5) → IC81.10; IC81.9 ← IC80.8.
- IC58 (7442): A15/B14/C13 ← scan, D12 ground; outputs 0..5 → IC36 → digit
  verticals, which drop to the enable wires: digit 0 y≈5255 (IC53, IC80.1),
  1 y≈5282 (IC54), 2 y≈5313 (IC55), 3 y≈5345 (IC56), 4 y≈5377 (IC57,
  IC81.1), 5 y≈5462 (IC80.4, IC81.13).
- IC53..57 (7403): gates on output pins 6/8/3/11 take QA/QB/QC/QD of IC75,
  IC76, IC77 (13,11,10,9), IC77 (3,5,6,7), IC79 (3,5,6,7) respectively. The
  four output wires reach IC34 9, 1, 13, 11 → IC33 A7, B1, C2, D6 (bus
  verticals x≈7046, 7076, 7107, 7136). IC100.12 joins the pin-6 (A) wire.
