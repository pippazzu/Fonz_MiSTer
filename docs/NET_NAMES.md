# Wire names in the RTL

Every wire in `rtl/fonz_*.v` is named after the board, so the name says
where it goes. The rule: count the IC types on the board, and name wires
like `IC21_pin1_IC23_pin6` so that you can see what goes where.

## The rules

| Wire | Name | Example |
|---|---|---|
| Two ends | driver pin, then load pin | `IC26_pin10_IC25_pin2` |
| More than two ends, including several pins of one IC | driver pin, then a signal name; loads are not chained | `IC105_pin5_THROTTLE`, `IC58_pin4_DIGIT3_n` |
| Output pin that goes nowhere | driver pin, then `NC` | `IC20_pin2_NC` |
| Tap that leaves the board (connector, transistor, pot, resistor) | source pin, then where it goes | `IC17_pin2_CN23`, `IC94_pin12_VR1` |
| Node behind a resistor and capacitor | the parts, then the load pins | `R77_C52_IC60_pin12_IC61_pin11` |
| Contact input from a connector | connector, then load pin | `CN21_IC38_pin1` |
| Wired AND (many open-collector drivers) | the load pins, then a signal name | `IC34_pin9_1_13_11_BCD_n` |
| Counter or decoder bus | the IC, then its pins with bit 0 (QA) first, then a signal name if useful | `IC68_pin14_13_12_11_H`, `IC75_pin3_2_6_7` |
| Shape PROM address | the bundle name; the comments list the counter pins | `UPPER_SHAPE_ADDRESS` |

- Pin numbers are the physical pins on the drawing. Gate letters and
  data-sheet pin names (QA, /CLR) are not used in names; comments may use them.
- A name ending in `_n` is active low.
- A wire keeps one name in every module it passes through. A module port is
  named after the wire it carries, so `IC27_pin11_HSYNC_n` is the same name in
  `fonz_raster`, `fonz_raster_video`, `fonz_picture` and `fonz_scene`.
  When a port takes one bit of a bus, the port gets that pin's own name
  (`.IC28_pin4_IC5_pin5(IC28_pin3_4_5_6[1])`).
- A /Q output of an analogue monostable (`IC30_pin4_CRASH_n`,
  `IC103_pin12_START_n`) is inverted once in `fonz_board` and passed down.

- The MiSTer top (`rtl/mister/`), the analogue models (`rtl/analog/`) and the
  benches use the same names as the board sheets. Where a model port takes a
  single pin it may be named by that pin alone (`IC94_pin2`).

## The check

`python scripts/check_net_names.py` (run by `scripts/run_tests.py` as
`net_names`) reads the chip list and checks every name against the DIP
pinout of its type: each pin is a real signal pin, a name starts at an
output pin, a two-ended name ends at an input pin, a bus lists the pins of
one counter section QA first, an assign commented `pins 12,13 ->11` names one
gate of its package, a sub-sheet port carries a wire of its own name, and a
wire has one name across `rtl/`, `sim/`, `tests/` and `tb/`. It cannot tell
whether a two-ended name really has two ends; `docs/NET_CHECKS.md` and the
scan are the reference for that.

## What keeps its old name

- The ports of `fonz_board`. The MiSTer top, the analogue models
  (`rtl/analog/`), the stand-in benches and `scripts/make_fpga_board.py` all
  connect to them, so changing them is a separate step. The raster taps
  (`IC67_pin3_PIXEL_CLK` and the others) already follow the rule.
- The `icNN_ab_clear_n` vectors to the 74123 models: each is three pins of one
  half, not one wire.
- `fonz_shape_oscillator_connections`, which is used twice (IC9 and IC106),
  keeps generic port names. The instances connect it to named wires.
- Instance names (`ic69`, `ic77_p15`, `ic83d`), which name a package or half.
- In the MiSTer top, `IC99_pin4_pin10_RESET_n` and `IC105_pin6_TRIGGER_n`
  (and the 556 model ports `IC30_pin12_IC99_pin4_pin10`,
  `IC25_pin12_IC105_pin6`). They carry the IC30.12 and IC25.12 nets through
  the extra board outputs `ic99_4` and `ic105_6`, which go when the board's
  ports are renamed.

## The chip list and the IC-type count

`rtl/fonz_board.v` begins with the chip list: one line per IC, sorted by
number, with its type. MSI parts carry the type printed on the drawing; gate
packages are read from the symbol and its pin numbers. The IC-type count below
it is written by `python scripts/ic_count.py`, so it cannot drift from the
list. `scripts/run_tests.py` runs `ic_count.py --check`, which also fails if
a wire name uses an IC that is not on the list, or if the RTL never mentions a
listed IC.
