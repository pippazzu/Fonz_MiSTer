// SPDX-License-Identifier: GPL-3.0-or-later
// The three 556 packages: IC98, IC99 and IC105, from their drawn RC values.
// Wires are named by both endpoints (ICaa_pinN_ICbb_pinM). On the board
// module these are ic99_4/10 and ic105_6 (outputs) and ic98_5, ic99_5/9,
// ic105_5/9 (inputs). IC98 pin 4 and IC105 pins 4/10 are tied to +5 V here.
//
// IC count in this module: 556 x3 (IC98, IC99, IC105).
//
// Pin map per half (556): A = DISCH 1, THR 2, CTRL 3, /RESET 4, OUT 5,
// TRIG 6; B = OUT 9, /RESET 10, CTRL 11, THR 12, DISCH 13, TRIG 8.
//
//   IC98A  astable  R39 220k, R43 220k, C29 4.7uF, C26 on pin 3.  Q5 -> IC84.4
//                   About 1.43 s high, 0.72 s low (first high 2.27 s).
//   IC99B  astable  R45 100k, R44 220k, C32 10uF,  C31 on pin 11. Q9 -> IC84.5
//                   About 2.22 s high, 1.52 s low. The sheet labels the
//                   R45/R44 node "8" and the R44/C32 node "13"; that is a
//                   drafting swap (as drawn the cell latches low), so the
//                   standard astable is modelled: 13 DISCH, 8/12 on C32.
//   IC99A  astable  R54 220k, R53 470k, C36 10uF,  C37 on pin 3.  Q5 -> IC100.9
//                   About 4.78 s high, 3.26 s low.
//   IC105A monostable R100 56k, C68 0.15uF, trigger pin 6 = IC25.12 (once a
//                   frame). Pin 3 is the throttle network (R109 1k to +5 V,
//                   TR10, C67), passed in on TR10_IC105_pin3. With TR10 off pin 3
//                   sits at 4.615 V and the pulse is 21.5 ms; at 2/3 Vcc it
//                   is 9.2 ms. D18 (in series with THR pin 2) is taken as
//                   ideal. Q5 -> IC100.1, IC92.5.
//   IC105B astable  R101 3.3k + VR10 200k trimmer, R96 68k, C61 4.7uF, C63 on
//                   pin 11. Q9 -> IC82.9, the play-time count clock. The
//                   manual's adjustment page gives the standard game time
//                   as about 70 s (VR-10 range 45 to 100 s), so VR10 is set
//                   to 77.8k: 0.707 s a count (0.49 s high, 0.22 s low),
//                   99 counts in 70 s. VR10 at 0 and 200k gives 0.45 and
//                   1.10 s a count, 45 and 109 s, matching that range.
//                   That is the factory setting; vr10_code picks the OSD
//                   game time (scripts/pot_settings.py).
//
// Both IC99 resets are IC30 /Q12. IC98 pin 4 and IC105 pins 4/10 are high.
// Every cap starts discharged at power-up, so each astable's first high
// phase is longer (charging from 0 V instead of 1/3 Vcc).
`timescale 1ns/1ps
`default_nettype none
module fonz_556_timers #(
    parameter integer CE_HZ    = 100_000
)(
    input  wire        clk,
    input  wire        ce,          // CE_HZ ticks per second
    input  wire        IC30_pin12_IC99_pin4_pin10, // IC30 /Q12, both IC99 /RESETs
    input  wire        IC25_pin12_IC105_pin6,      // once-a-frame trigger
    input  wire [31:0] TR10_IC105_pin3,            // IC105A CTRL volts, 32'h8000_0000 = 5 V
    input  wire [2:0]  vr10_code,                  // VR10 game time, OSD code (0 = 70 s)
    output wire        IC98_pin5_IC84_pin4,
    output wire        IC99_pin5_IC100_pin9,
    output wire        IC99_pin9_IC84_pin5,
    output wire        IC105_pin5_THROTTLE,
    output wire        IC105_pin9_IC82_pin8
);
    wire VCC_IC98_pin4 = 1'b1, VCC_IC105_pin4 = 1'b1, VCC_IC105_pin10 = 1'b1;
    localparam [31:0] VCTL_2_3 = 32'h5555_5555; // unloaded control pin

    wire [31:0] v98a, v99a, v99b, v105a, v105b;

    fonz_556_half #(.RA_OHM(220_000), .RB_OHM(220_000), .C_NF(4_700),
                      .CE_HZ(CE_HZ), .ASTABLE(1)) ic98a (
        .clk(clk), .ce(ce), .reset_n(VCC_IC98_pin4), .trig_n(1'b1), .vctl(VCTL_2_3), .ra_code(3'd0),
        .q(IC98_pin5_IC84_pin4), .v(v98a));

    fonz_556_half #(.RA_OHM(220_000), .RB_OHM(470_000), .C_NF(10_000),
                      .CE_HZ(CE_HZ), .ASTABLE(1)) ic99a (
        .clk(clk), .ce(ce), .reset_n(IC30_pin12_IC99_pin4_pin10), .trig_n(1'b1), .vctl(VCTL_2_3), .ra_code(3'd0),
        .q(IC99_pin5_IC100_pin9), .v(v99a));

    fonz_556_half #(.RA_OHM(100_000), .RB_OHM(220_000), .C_NF(10_000),
                      .CE_HZ(CE_HZ), .ASTABLE(1)) ic99b (
        .clk(clk), .ce(ce), .reset_n(IC30_pin12_IC99_pin4_pin10), .trig_n(1'b1), .vctl(VCTL_2_3), .ra_code(3'd0),
        .q(IC99_pin9_IC84_pin5), .v(v99b));

    fonz_556_half #(.RA_OHM(56_000), .RB_OHM(0), .C_NF(150),
                      .CE_HZ(CE_HZ), .ASTABLE(0)) ic105a (
        .clk(clk), .ce(ce), .reset_n(VCC_IC105_pin4), .trig_n(IC25_pin12_IC105_pin6), .vctl(TR10_IC105_pin3), .ra_code(3'd0),
        .q(IC105_pin5_THROTTLE), .v(v105a));

    fonz_556_half #(.RA_OHM(3_300), .RA_POT(10), .RB_OHM(68_000), .C_NF(4_700),
                      .CE_HZ(CE_HZ), .ASTABLE(1)) ic105b (
        .clk(clk), .ce(ce), .reset_n(VCC_IC105_pin10), .trig_n(1'b1), .vctl(VCTL_2_3), .ra_code(vr10_code),
        .q(IC105_pin9_IC82_pin8), .v(v105b));
endmodule
`default_nettype wire
