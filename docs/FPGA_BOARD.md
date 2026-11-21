# Single-clock board and its equivalence check

`fonz_board_fpga` (`rtl/fpga/fonz_board_fpga.v`) is the whole traced
board running on one 48 MHz clock, `clk_sys`. It has the pins of
`fonz_board` with the same names and meanings, except that the crystal
(IC45 pin 8) is made inside from `clk_sys` and comes out as an output. It
also gives `ce_pix`, one `clk_sys` wide at each rise of IC67 Q (pin 3), the
7.1525 MHz pixel clock.

## How it is built

The trace stays the single source. `scripts/make_fpga_board.py` copies every
`rtl/fonz_*.v` sheet into `rtl/fpga/` with `_fpga` added to the module
names and `clk_sys, rst` added to the ports, then:

| Event model | FPGA copy |
|---|---|
| `fonz_74161`, `74107`, `74393_half`, `74390_half`, `74153`, `74279` | the `_ce` cells (`rtl/ttl/fonz_ttl_ce.v`) |
| `fonz_prom` | `fonz_prom_comb` (`rtl/fpga/`, hand-written): combinational read, see below |
| `fonz_rc_edge` (R67/C44, R76/C51, R77/C52) | `fonz_rc_edge_ce` (`rtl/fpga/`, hand-written): 4 `clk_sys` (83 ns) for a rising edge, 9 (188 ns) for a falling one, against ~77 ns and ~189 ns for the RC; a shorter pulse is dropped |
| `fonz_74192` | `fonz_74192_sync` (`rtl/ttl/fonz_74192_sync.v`) |
| `fonz_7442`, `fonz_7448` | unchanged (combinational) |
| `fonz_board` | `fonz_board_core_fpga`, wrapped by `fonz_board_fpga` |

`rtl/fonz_input_conditioning.v` (real-valued RC models) is not copied; the
board uses only its `fonz_rc_edge`, which the table maps. The top
`fonz_board_fpga` is generated too, from `fonz_board`'s port list, so it
follows port changes on the board.

**Why the shape PROMs read combinationally.** The IC71 and IC108 74153
selects come from the same counters that address the PROMs. With the
registered read of `fonz_prom_ce` the select moves one `clk_sys` before the
data, and for that clock the mux shows a bit of the previous word. The check
below caught this as single half-pixel glitches on IC71.9 and IC108.7/9. On
the board the PROM is slower still, and the 470 pF on the 74153 outputs hide
it. The PROMs are 256 × 4 and 512 × 4, small enough for LUTs.

Wires, pins, gates and comments are copied as they are, so a wiring fix in
`rtl/` reaches the FPGA board by running the script again. `run.sh` calls
`make_fpga_board.py --check` and stops if `rtl/fpga/` is out of date. Do not
edit the generated files.

The crystal net is a phase accumulator that changes level 2 × 14.305 million
times a second, so each level lasts one or two `clk_sys` and IC67A divides
it to the pixel rate exactly on average. Each clocked cell sees its clock net
one `clk_sys` late and answers one `clk_sys` later, so a ripple chain settles
one `clk_sys` per stage, well inside the 6.7 `clk_sys` of a pixel.

## Loop cuts

Four places close a loop through combinational logic once the 74192 is the
synchronous cell or the latch is plain gates. Each is cut by one flop on
`clk_sys`, applied by `PATCHES` in the script (it stops if the text it
patches has changed). Verilator `--lint-only -Wall` on `fonz_board_fpga`
reports no `UNOPTFLAT` after the cuts.

| Loop | Cut | Effect |
|---|---|---|
| Timer IC75/76 /BORROW → IC82.13 → IC61.8 → IC81.6 → /LOAD (`docs/74192_SYNC.md`) | IC82.13 registered as `IC82_pin13_TIME_UP_reg` for all its loads | each reload one `clk_sys` later |
| IC69 /CARRY, IC91 /CARRY → IC47.10 → IC92.9 → IC92.8 → IC69 UP (holds the count at 99) | IC47.10 registered as `IC47_pin10_HOLD_reg` for IC92.9 only; IC25.4 keeps the direct net | the hold starts one `clk_sys` after the carry |
| IC18 Q → IC39.11 / IC82.4 → IC62.12 → IC19 → IC18 UP/DOWN (steering limits) | the two decodes registered as `IC39_pin11_IC19_pin10_reg`, `IC62_pin12_IC19_pin1_reg` for the IC19 gates | a limit closes the gate one `clk_sys` later |
| IC38 cross-coupled NAND coin latch | IC38.11 registered as `IC38_pin11_COIN_LATCH_n_reg` | the latch flips one `clk_sys` later |

None of these lags is long enough to reach the next pixel in the test frames.

## Equivalence check

```sh
python3 scripts/extract_proms.py   # once, if rom/*.hex is missing
sh sim/board_equiv/run.sh 8        # frames; needs iverilog, about 20 s a frame
```

`sim/board_equiv/tb_board_equiv.v` runs `fonz_board` from a 14.305 MHz
crystal and `fonz_board_fpga` from 48 MHz side by side. Each board has its
own copy of the analogue stand-ins (`sim/board_equiv/standins.v`): every
74123 half is a retriggerable pulse of a fixed number of pixels, wired to the
board's own A, B and /CLR pins, the 556 outputs are squares or fixed pulses,
the RC nodes are one-pixel delays, and the contacts follow a script (coin,
accelerator, left, right, tilt, antenna). The stand-ins are stepped by each
board's own pixel clock and read the board at the pixel edge, so both boards
get the same responses at the same pixel. In the event model the responses
arrive 17 ns after the edge, so they do not race the board's own clocks in a
zero-delay simulation.

Both boards are sampled twice a pixel (the video is gated by IC67 Q, so it
changes at half pixels): the event model at each falling crystal edge, the
FPGA board at the `clk_sys` where IC67A sees that edge. Sample *k* of one is
compared with sample *k* of the other, over the three video-mixer bits
(IC5.11, IC7.8, IC7.12), the six digit enables, the seven segments and the
six BCD digits. The bench stops if the raster counters ever disagree.

Two kinds of sample are listed but not counted as differences, because they
come from the zero-delay model settling a ripple chain in no time:

- **One sample late**: the FPGA sample equals the event model's previous
  sample. A long ripple chain (IC74 → IC79 for the score is up to ten
  stages) can take more than half a pixel on `clk_sys`.
- **Transient**: the FPGA sample differs, but one `clk_sys` later it shows the
  event model's value. Two counters on one PROM address (IC63 and IC88/IC109
  for the lower shape) still settling; on the board the 470 pF on the 74153
  outputs hide the same moment.

Anything else is a difference and fails the run.

Result as of 9 November 2026 (after the coin/latch/timer audit, the edge
nodes and the PROM download), 8 frames, 1 895 904 samples: **0
differences**, 0 one-late, 1 transient (IC7.12, frame 3). A coin in frame 3
starts a game, the time counts 99 → 88, the crash timer fires in frame 4,
and the antenna pulse in frame 6 ends the game. The score does not count in
these frames with the current trace.

Build with `IVFLAGS=-DDEBUG_NETS` to print the internal counters and video
nets where the boards part.

### What the test frames do not cover

- The stand-ins change at most once a pixel. The real IC9/IC106 oscillators
  run freely; on the FPGA their edges are seen on the next `clk_sys`, so an
  edge within about 20 ns of a pixel edge can land one pixel away from where
  the zero-delay model puts it. That is a sampling difference of the input,
  not of the board.

## Event-model fix found by the check

At time 0 every net goes from x to 0 or 1, and the event cells counted those
as clock edges (IC64 counted once, IC66A toggled), so the event board started
in a state the FPGA board, which loads INIT on `rst`, never reaches. The
player-position chain then ran one line apart from the FPGA board. The cells
in `rtl/ttl/fonz_ttl.v` now act only on a clean 0→1 or 1→0 clock edge, and
the event 74192 starts with UP and DOWN taken as high, as
`fonz_74192_sync` does. This changes simulation start-up only, not the
trace.

The carry nets loaded by C18, C81 and C75 (IC44, IC43 and IC42 pin 15) can
glitch in a zero-delay simulation when two counters on one clock update one
after the other. It did not happen in these frames, but if a future run
shows IC66A, IC66B or IC20A toggling in the event model only, that is the
cause, and the capacitor filters the real glitch.
