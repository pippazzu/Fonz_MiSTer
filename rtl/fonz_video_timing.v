// SPDX-License-Identifier: GPL-3.0-or-later
// MiSTer video timing taken straight from the raster IC pins.
// Nothing here counts pixels: every output is one of the board's own
// signals, renamed and given the polarity the MiSTer video path expects.
// Measured values are in docs/VIDEO_TIMING.md.
//
//   pixel clock  IC67.Q3   14.305 MHz / 2 = 7.1525 MHz, 454 clocks a line
//   HBLANK       IC4.Q5    set at H=0 (IC45.6, H=453 decode), cleared at
//                          H=80 by IC27.8 = NAND(IC46.QA, IC46.QC)
//   /HSYNC       IC27.11   NAND(IC46.QB, IC4.Q5): H=32..63
//   VBLANK       IC3.Q5    set at V=0 (IC26.4, V=261 decode), cleared at
//                          V=16 by IC26.12 = /IC2.QA
//   /VSYNC       IC25.12   NAND(/IC24.QD, IC24.QC, IC3.Q5): V=4..7
//   /CSYNC       IC5.11    XNOR(IC27.11, IC25.12), the board's own
//                          serrated composite sync into the resistor mixer
//
// The board blanks its own video: IC7.8 and IC7.12 are NORs that take
// IC4.Q5 and IC3.Q5 directly. The picture is horizontal (landscape).
`timescale 1ns/1ps
`default_nettype none
module fonz_video_timing(
    // Inputs are named by source pin then signal (IC<n>_pin<p>_...).
    input  wire IC67_pin3_PIXEL_CLK, // pixel clock (one pixel per rising edge)
    input  wire IC4_pin5_HBLANK,     // HBLANK, active high
    input  wire IC27_pin11_HSYNC_n,  // /HSYNC, active low
    input  wire IC3_pin5_VBLANK,     // VBLANK, active high
    input  wire IC25_pin12_VSYNC_n,  // /VSYNC, active low
    output wire pxl_clk,   // IC67.Q3
    output wire hs, vs,    // active-high sync pulses
    output wire hb, vb,    // active-high blanking (MiSTer HBlank/VBlank)
    output wire lhbl, lvbl,// active-low blanking
    output wire csync_n    // IC5.11 composite sync, active low
);
    assign pxl_clk = IC67_pin3_PIXEL_CLK;
    assign hs      = ~IC27_pin11_HSYNC_n;
    assign vs      = ~IC25_pin12_VSYNC_n;
    assign hb      = IC4_pin5_HBLANK;
    assign vb      = IC3_pin5_VBLANK;
    assign lhbl    = ~IC4_pin5_HBLANK;
    assign lvbl    = ~IC3_pin5_VBLANK;
    assign csync_n = ~(IC27_pin11_HSYNC_n ^ IC25_pin12_VSYNC_n);
endmodule
`default_nettype wire
