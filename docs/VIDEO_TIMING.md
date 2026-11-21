# Video timing and orientation

Every MiSTer timing signal is one of the board's own raster outputs.
No window is invented. `rtl/fonz_video_timing.v` renames them and sets
the polarity, and `rtl/fonz_board.v` exports the five pins it needs.
`sim/video_timing_tb.v` runs the traced raster (`fonz_raster`) through it
and checks every edge listed below.

```
iverilog -o build/video_timing sim/video_timing_tb.v \
    rtl/fonz_raster.v rtl/fonz_video_timing.v rtl/ttl/fonz_ttl.v
vvp build/video_timing
```

Result on 8 November 2026:
`line 63.475 us (15.754 kHz), frame 16.5669 ms (60.361 Hz)`, `PASS: 0 errors`.

## Clock and totals

| Item | Value | Source |
| --- | --- | --- |
| Crystal | 14.305 MHz | X1 into IC45.8 |
| Pixel clock | 7.1525 MHz (139.8 ns) | IC67A Q3, the crystal divided by two |
| Line | 454 pixels, 63.475 µs, 15.754 kHz | H counts 0 to 453; IC89 decodes 453 and loads 0 |
| Frame | 261 lines, 16.567 ms, 60.36 Hz | V counts 0 to 260; IC25.8 decodes 261 and loads 0 |

H is `{IC4.Q3, IC46, IC68}` and V is `{IC3.Q3, IC2, IC24}`, QA in bit 0.
All raster flip-flops change on the rising edge of IC67.Q3 (the 74107s
clock on the falling edge of IC67./Q2). The frame is progressive, with no
interlace. V reads 261 for the first pixel clock of the first line, because
the 74161 load is synchronous, so V=0 and VBLANK start one pixel late.

## Signals

| MiSTer | Board pin | Logic | Range |
| --- | --- | --- | --- |
| HBlank (`hb`, `~lhbl`) | IC4B Q5 | J = IC45.6 (H=453), /CLR = IC27.8 = NAND(IC46.QA, IC46.QC) | H = 0 to 79 (80 pixels, 11.19 µs) |
| HSync (`hs`) | IC27.11, active low | NAND(IC46.QB, IC4.Q5) | H = 32 to 63 (32 pixels, 4.47 µs) |
| VBlank (`vb`, `~lvbl`) | IC3B Q5 | J = IC26.4 (V=261), /CLR = IC26.12 = /IC2.QA | V = 0 to 15 (16 lines) |
| VSync (`vs`) | IC25.12, active low | NAND(/IC24.QD, IC24.QC, IC3.Q5) | V = 4 to 7 (4 lines, 254 µs) |
| Composite sync (`csync_n`) | IC5.11, active low | XNOR(IC27.11, IC25.12) | HSYNC, inverted during VSYNC (serrated) |

Porches: horizontal front 32, sync 32, back 16 pixels (4.47, 4.47 and
2.24 µs); vertical front 4, sync 4, back 8 lines. HSYNC keeps running
during VSYNC on the separate outputs.

The board blanks its own picture. Both white drivers, IC7.8 and IC7.12, are
NORs with IC4.Q5 and IC3.Q5 as inputs, so the video is black whenever
HBLANK or VBLANK is set. IC5.11 is the sync part of the original resistor
mixer (1 kΩ to the junction), which is why it is the composite sync and not
a picture signal.

## Active area

| | First | Last | Size |
| --- | --- | --- | --- |
| Horizontal | H = 80 | H = 453 | 374 pixels, 52.29 µs |
| Vertical | V = 16 | V = 260 | 245 lines |

The testbench counts 374 × 245 = 91,630 unblanked pixels a frame.
The 52.3 µs active line is close to a full NTSC line, so on the original
tube the 374 pixels of a line span the whole short side of the screen and
the 245 lines span the whole long side (see Orientation).

## Orientation

**The tube stands portrait (3:4), but its scan lines are horizontal.** The
raster itself needs no rotation; only the shape of the screen changes.

Evidence for the portrait tube:

- Cabinet photos of The Fonz and of the related Sega Road Race (9 November
  2026) show the curved glass of a tube standing upright,
  taller than wide, filling a portrait bezel window.
- The KLOV screenshot of the game is 240 × 320, portrait.

Evidence for horizontal scan lines on that tube:

- The Road Race photo shows the scan lines running across the short side
  of the screen.
- The road monostable IC97 is triggered every line from IC27.11 (pin 9),
  so the road edges are horizontal delays that change from line to line.
  A road drawn that way runs along the vertical scan, and the manual and
  every photo have it running up the screen.
- The shape PROMs agree. Drawn with each 4-bit word along the scan line
  (the IC71/IC108 mux select is the fastest counter), the bikes in IC86/87
  and pr-08/09 come out upright and left-right symmetric, and the IC85
  XORs that select the banked bike mirror them left to right. On scan
  lines running up the screen they would lie on their side.
- The manual says the throttle moves the bike "up the screen" and names
  the set as a Motorola XM701-10A. It gives no rotation.

How both can be true: the most likely build is a set mounted on its side
with the deflection yoke turned 90° on the tube neck, so the lines sweep
across the narrow dimension. The board drives it with ordinary 15 kHz
timing and is unaware of it. The result is a picture whose 374-pixel lines
are 3 units wide and whose 245 lines are 4 units tall, so the pixels are
tall and narrow.

The gameplay video (docs/reference/README.md) shows the board on an ordinary landscape monitor,
so there the same raster is stretched to 4:3 and the road looks wider than
in the cabinet.

No flip is needed: V=0 is the top of the picture, where the bike heads
when accelerating.

## MiSTer settings for the core

- `CLK_VIDEO` and `CE_PIXEL`: one enable per IC67.Q3 rising edge
  (7.1525 MHz). The retimed board will give the exact enable.
- `VGA_HS`/`VGA_VS` from `hs`/`vs`, `VGA_DE` from `~(hb | vb)`.
- No rotation: the raster goes out as it is, lines horizontal.
- Aspect ratio 3:4 (`VIDEO_ARX = 3`, `VIDEO_ARY = 4`) to match the
  cabinet, so the scaler shows a tall picture with side borders. On a
  15 kHz CRT in the usual landscape position the picture fills the screen
  stretched to 4:3, as in the gameplay video; a CRT set up for this
  cabinet (on its side, yoke turned) shows it as the original did.
  An OSD choice between 3:4 and 4:3 is worth offering.

### Analogue CRT output (decided 9 November 2026)

The scaler aspect setting has no effect on direct 15 kHz output, so:

- **Default: native.** The raster goes to the CRT unchanged. A landscape
  CRT shows it stretched to 4:3, as in the gameplay video. No lag.
- **OSD option: "3:4 on CRT" squeeze.** A one-line buffer is written at the
  board pixel rate (7.1525 MHz) and read 16/9 faster (about 12.716 MHz),
  centred, with black on both sides, so a landscape CRT shows a 3:4 portrait
  picture with horizontal lines, like the cabinet. Sync and blanking timing
  are untouched (15.754 kHz, 60.36 Hz); the delay is one line.

Rotating the picture for a CRT turned on its side would need a frame buffer
and a frame of lag, and is not planned.
- 15.754 kHz / 60.36 Hz is standard 15 kHz timing, within the range of a
  15 kHz CRT and of the MiSTer scaler.

## Still to do

This is done when the output is stable on a CRT and through the
scaler. That needs the MiSTer core and real hardware,
neither of which exists yet. The timing above is confirmed only in
simulation of the traced raster.
