# Contact and edge conditioning

Models in `rtl/fonz_input_conditioning.v`, checked by
`tests/tb_conditioning.v` (`python scripts/run_tests.py conditioning`). The
frame bench `tests/tb_board.v` also drives its contacts and coin through them.

Each node is a first-order RC followed by the receiving gate's threshold
(1.4 V for plain TTL, 1.7 V rising / 0.9 V falling for the 7414 Schmitt).
When the drive changes, the model takes the capacitor voltage at that moment
and computes exactly when it will cross the threshold. A bounce or a short
tap therefore behaves like the real RC: it is absorbed if the capacitor
doesn't reach the threshold, and a partly charged capacitor crosses sooner.
No response is shorter than 10 ns (about one gate delay), which keeps a node
turned round exactly at its threshold from toggling in zero time.

These are simulation models (`real` arithmetic and timed waits). The FPGA
version needs counters that reproduce the delays below.

## Edge nodes, 220 Ω in series, 680 pF to ground at the input

All three sit between a TTL output and a TTL input, and live in
`fonz_board`. The driver's output resistance (estimated at 100 Ω high and
10 Ω low) adds to the 220 Ω, and the receiver's 1.6 mA low-level input
current through 220 Ω lifts the low target to about 0.55 V.

| Node | From → to | Rising edge seen | Falling edge seen | What it does |
|---|---|---|---|---|
| R76/C51 | IC38.3 → IC38.9 | ~77 ns late | ~189 ns late | IC38.8 = NAND(delayed IC38.3, IC38.11): a ~190 ns low coin pulse when the coin switch is released. Without the delay there is no pulse at all |
| R77/C52 | IC59.2 → IC60.12, IC61.11 | ~77 ns late | ~189 ns late | Ends IC61.8's low pulse: IC61.8 sets IC83A, IC59.2 falls, and the delayed node raises IC61.8 again. Without it IC61.8 has zero width |
| R67/C44 | IC102.5 → IC101.5 | ~77 ns late | ~189 ns late | IC101.6 = NAND(IC102.5, delayed IC102.5): the upper-shape /LOAD starts ~77 ns after IC102.5 rises and ends when it falls. Glitches under ~77 ns are absorbed |

## Cabinet contacts

Each input: connector pin pulled up by 510 Ω to +5 V, 100 Ω in series to the
gate input, capacitor from the gate input to ground. Closing the contact
grounds the connector pin. These live in `fonz_contact_conditioning`,
which takes the connector wire levels (1 at rest, 0 closed, as
`fonz_cabinet_inputs` produces them) and drives the board's IC37 outputs and
IC38 inputs.

| Input | Parts | Receiver | Close → gate sees it | Open → gate sees it |
|---|---|---|---|---|
| Accel (16) | R83, R84, C47 22 µF | IC37 13→12 | ~4.0 ms | ~5.3 ms (fully discharged) |
| Left (17) | R85, R86, C48 22 µF | IC37 5→6 | ~4.0 ms | ~5.3 ms |
| Right (18) | R87, R88, C49 22 µF | IC37 3→4 | ~4.0 ms | ~5.3 ms |
| Tilt (1) | R89, R90, C50 22 µF | IC37 1→2 | ~4.0 ms | ~5.3 ms |
| Coin NO (21) | R94, R93, C60 0.01 µF | IC38.1 | ~1.4 µs | ~1.8 µs |
| Coin NC (20) | R92, R91, C59 0.01 µF | IC38.13 | ~1.4 µs | ~1.8 µs |

Closing: τ = 100 Ω × C toward ~0.12 V (0.16 V on IC38). Opening:
τ = 610 Ω × C toward 5 V. A tap shorter than about 4 ms on a steering,
accel or tilt contact never reaches IC37. The receiver's input current while
low, which helps the capacitor charge, is ignored; it shortens the opening
delay a little.

## Start

The board has no start button: the coin starts the game. The coin pulse at
IC38.8 triggers IC103B (pin 9), the start monostable (47 kΩ, 100 µF, about
a second). Its /Q (pin 12) holds IC83A and IC83D reset while the pulse
runs and releases them when it ends. `tests/tb_conditioning.v` uses a 20 µs
stand-in for IC103B; `tests/tb_board.v` has its own 74123 stand-in.

## What the test bench checks

- Idle levels at IC37 and IC38.
- Coin press and release with bounce on both contacts and a 50 µs changeover
  gap: no pulse on press, exactly one ~190 ns IC38.8 pulse on release, and
  it fires the IC103B stand-in.
- Left contact with a bounce: IC37.6 rises ~4.0 ms after the contact
  closes, and falls ~4.4 ms after it opens (2 ms later; the capacitor has
  not fully discharged).
- A 1 ms tap on right never reaches IC37.4.
- Accel and tilt reach IC37.12 and IC37.2 and release.
- IC101.6's leading edge is delayed ~77 ns, and a 50 ns IC102.5 glitch is
  absorbed.
- After an IC103B pulse has cleared IC83A, and with IC83.13 and IC82.13
  forced high (the idle stand-ins never set them), IC61.8 gives one
  ~190 ns pulse and sets IC83A. Held in reset instead, the same loop
  oscillates, which is how the bench caught the IC83 reset net change.
