# Collision with the opponent (IC47.1, IC29, IC30)

On 11 November 2026 the MiSTer core (Fonz_20261110.rbf)
draws the opponent bike, which comes back after it leaves the screen, but
the player rides through it without a crash.

## The chain as drawn

| Step | Parts | What it does |
|---|---|---|
| Overlap | IC6.12 = NOR(IC71.9, IC71.7, IC20.5); IC45.2 = NOT IC108.9; IC47.1 = NOR(IC6.12, IC45.2) | IC47.1 is high while the player's IC86 layer (IC108.9) lies on an opponent pixel (IC49/IC50 through IC71) or on the off-road signal IC20.5 |
| Count | IC29, 74393, 1A from IC47.1, 1QD (pin 6) into 2A (pin 13), both clears from IC84.8 = NAND(IC3.6, IC103.12) | Counts the **falling edges** of IC47.1, so one count per run of overlapping pixels on a scan line, not one per pixel. Cleared for the 16 lines of vertical blanking every frame (IC3.6 is low then) and at the coin start |
| Trigger | IC29 2QB (pin 10) into IC30A B2, with A1 = IC30B Q5 | The 32nd run in one frame fires the crash monostable (R28 47k, C17 47 µF, about 0.7 s) unless the crash hold IC30B (R31 47k, C22 220 µF, about 3.4 s) is already running |
| Effect | IC30A /Q4 releases IC28A, loads IC18 with 5 (speed), lights the photocoupler at IC39.3; IC30A Q13 drives the CRUSH output; IC30B /Q12 resets both IC99 halves | IC28.4 then toggles every two frames and inverts the bright layer through IC5.6, so the picture flashes while the crash pulse lasts |

All of this was checked on the native scan (IC29/IC30 crop at 9700,3900
to 11700,5400; docs/NET_CHECKS.md has the IC30 nets) and matches the code.

## What the simulation showed

`sim/verilator/build_dbg.sh` builds `fonz_dbg_top`, the machine with
taps on IC47.1, IC29, IC30, the two shape outputs, the position counters
and the shape oscillators. `sim_dbg.cpp` prints one line a frame: edges on
IC47.1, the highest IC29 count, both IC30 halves, the bounding boxes of the
opponent and the player, their overlap in pixels. `chase=F` steers the
player under the opponent from frame F, which is how a collision happens in
play.

With the bike-size pots at their old guess (VR1 = VR9 = 5k):

- Going off the road crashes: the counter reaches 32 within a frame or two
  and the picture flashes (`left=398-470` or `right=398-470` from a coin at
  frame 300).
- Steering sideways into the opponent at the same height crashes after
  about six frames of growing overlap, with the banked bike.
- The opponent coming straight down through the player, as it does when
  the throttle is open, overlaps for 17 frames (up to 38 pixels a frame)
  and the counter peaks at **28**: no crash. That is the report.

The count depends on the bike size. The PROMs hold a 16 × 34 bike; each
scan line through the overlap adds one count per run of overlapping
pixels, so the count scales with the number of scan lines the overlap
covers. Counting the runs of the two PROM images at the scale the core
drew them (about 1.25 pixels a tick, a bike 20 pixels wide and 24 to 29
lines tall), a vertical pass through the player reaches 32 only for 4 of
the 41 lateral offsets that overlap at all, and never with the banked
bike. At the manual's standard size (3 1/4 in of a 15 1/2 in picture, a
bike 42 pixels wide and 51 lines tall) it reaches 32 for 37 of 85 offsets:
half of all touches crash, which is the game in the footage. The 32 is a
proportion-of-overlap threshold that only works at the intended size.

## The fix: bike size

The bikes were half the manual's size because the shape oscillators (IC9,
IC106, docs/SHAPE_OSCILLATORS.md) ran at 4.8 MHz where the player starts:
their control voltage only fell to 2.8 V with VR1/VR9 at 5k. The pots are
10k rheostats whose setting was a guess ("midway"). Lower settings drain
the control capacitor faster, so the oscillators run slower and the bikes
grow:

| VR1 = VR9 | control at the player's start line | player bike at rest (lines) | share of the picture |
|---|---|---|---|
| 5k (old) | 2.81 V | 29 | 12 % |
| 2k | 2.27 V | 40 | 16 % |
| 1.5k (new) | 2.13 V | 45 | 18 % |
| 1.2k | 2.04 V | 48, touching the bottom | 20 % |
| 1k | 1.97 V | runs off the bottom | |
| 0 | 1.57 V | far off the bottom | |

The manual's text gives 21 % (3 1/4 in of 15 1/2 in); its drawing shows
the player at 17.5 % of the picture. `scripts/shape_osc_table.py` now
defaults to 1.5k, which is the largest bike that stays on the picture with
the present starting line (the player at rest begins at line 211 of 261
and ends at 256; the blanking takes 16 lines). The manual places the
bottom of the resting bike 3/4 in (5 %) above the picture's bottom edge,
with the bike's top at 74 % of the height; the core starts it at 81 %.
When the throttle's rest position (IC105, docs/CONTROLS.md) is moved up to
the manual's line, VR1/VR9 can go to about 1k to reach the full 3 1/4 in.

Both pots are kept equal, as the manual says they interact.

## Update, 11 November 2026: VR1/VR9 at 1.8k

The throttle limits were set to the manual's lines the same day
(docs/CONTROLS.md): the resting bike's wheels 3/4 in above the bottom of
the picture, which lifts the start line. The adjustment page's picture
measures 18 3/4 in (245 visible lines), so the standard 3 1/4 in bike is
42 lines. With the new start line VR1/VR9 are set to 1.8k, which gives
42 lines (docs/SHAPE_OSCILLATORS.md, "Bike size"); the 1.5k above was the
largest that fitted the old start line. A straight pass of the opponent
through the resting player now reaches 69 counts on IC29 and crashes.
