// SPDX-License-Identifier: GPL-3.0-or-later
// 74123 dual retriggerable monostable, one half per instance.
//
// The board exports every 74123 input as {A, B, /CLR} (see
// rtl/fonz_analog_connections.v) and expects Q back. These modules close
// that loop with a clocked counter, so they synthesise on an FPGA and run in
// any HDL simulator. Inputs are sampled on clk; feed them from the same clock
// domain (or synchronise them first).
//
// Function table, one half (data sheet):
//   /CLR low                      -> Q=0, /Q=1, pulse terminated at once
//   A falling while B=1, /CLR=1   -> trigger
//   B rising  while A=0, /CLR=1   -> trigger
//   /CLR rising while A=0, B=1    -> trigger ('123 only; the '122 has no such)
//   trigger while Q=1             -> retrigger: the width restarts from here
//
// Pulse width (TI SDLS043, Dec 1983 rev. Mar 1988, typical values, 25 C):
//
//  'LS123 (FAMILY_LS=1, default)
//    Cext >= 1 uF          tw = 0.33 * Rt * Cext            (text, page 8)
//    100 pF..1 uF          tw = K(Cext) * Rt * Cext, K read off Figure 7
//                          (K is independent of R): 0.495 at 100 pF,
//                          0.43 at 200 pF, 0.385 at 500 pF, 0.365 at 1 nF,
//                          0.348 at 2 nF, 0.335 at 5 nF, 0.327 at 10 nF;
//                          joined to 0.33 at 1 uF in a straight line
//    Cext < 100 pF         straight line from the Cext->0 width of Figure 6,
//                          t0 = 15 ns + 8.6 ns/kohm * Rt, to the 100 pF width
//  '123 (FAMILY_LS=0)
//    Cext >= 100 pF        tw = 0.28 * Rt * Cext * (1 + 0.7/Rt)   (page 7;
//                          Figure 4 shows it holds down to about 100 pF)
//    Cext < 100 pF         straight line from t0 = 15 ns + 6 ns/kohm * Rt
//                          (Figure 4, Cext->0) to the 100 pF width
//  Rt in kohm, Cext in pF, tw in ns. The page-7 diode network (KD=0.25) is
//  not used: the main schematic shows no diode at the electrolytics.
//
// Checks against the switching tables (Cext=1000 pF, Rt=10k): 'LS123 gives
// 3.65 us (figure; the table says 4.5 typ, 4..5); '123 gives 2.99 us (table
// 3.03 typ, 2.76..3.37). The figure and the table disagree for the 'LS123;
// this model follows the figures throughout.
// The board uses the 'LS123 (settled 9 November 2026, see TRACE.md
// "74123 family"), so FAMILY_LS=1 is the board setting; 0 is kept only for
// comparison.
`timescale 1ns/1ps
`default_nettype none

// Core: width supplied at run time, in clk cycles. Use this directly where
// Rext is a transistor/pot network (IC9, IC106, IC97B, IC102, IC104B).
module fonz_74123_core #(
    parameter integer W = 32
)(
    input  wire         clk,
    input  wire         a,
    input  wire         b,
    input  wire         clr_n,
    input  wire [W-1:0] width,     // pulse width in clk cycles (0 acts as 1)
    output wire         q,
    output wire         q_n
);
    reg         a_d = 1'b1, b_d = 1'b0, clr_d = 1'b0;
    reg [W-1:0] count = {W{1'b0}};

    // Edges are judged between the previous and current samples. The other
    // inputs must hold their enabling level in the current sample.
    wire trigger = clr_n & (
        ( a_d & ~a &  b)  |   // A falling, B high
        (~b_d &  b & ~a)  |   // B rising, A low
        (~clr_d & ~a & b)     // /CLR rising, A low, B high
    );

    always @(posedge clk) begin
        a_d   <= a;
        b_d   <= b;
        clr_d <= clr_n;
        if (!clr_n)
            count <= {W{1'b0}};
        else if (trigger)
            count <= (width == {W{1'b0}}) ? {{W-1{1'b0}}, 1'b1} : width;
        else if (count != {W{1'b0}})
            count <= count - 1'b1;
    end

    // /CLR ends the pulse without waiting for the next clock.
    assign q   = clr_n & (count != {W{1'b0}});
    assign q_n = ~q;
endmodule

// Fixed Rext/Cext: the width is computed once at elaboration.
module fonz_74123 #(
    parameter integer CLK_HZ    = 14_305_000, // sampling clock
    parameter integer R_OHM     = 10_000,     // Rext
    parameter [63:0]  C_PF      = 100,        // Cext in pF (47 uF = 47_000_000)
    parameter integer FAMILY_LS = 1,          // 1 = 'LS123, 0 = '123
    parameter integer W         = 32
)(
    input  wire clk,
    input  wire a,
    input  wire b,
    input  wire clr_n,
    output wire q,
    output wire q_n
);
    // All 64-bit integer arithmetic, so synthesis needs no reals.
    // K is held x10000; R in ohm; C in pF. K*Rk*C = K4*R*C / 1e7 ns.
    function [63:0] k4_ls(input [63:0] c);   // Figure 7, K x 10000
        begin
            if      (c <= 64'd100)      k4_ls = 4950;
            else if (c <= 64'd200)      k4_ls = 4950 - (c-100)*650/100;
            else if (c <= 64'd500)      k4_ls = 4300 - (c-200)*450/300;
            else if (c <= 64'd1000)     k4_ls = 3850 - (c-500)*200/500;
            else if (c <= 64'd2000)     k4_ls = 3650 - (c-1000)*170/1000;
            else if (c <= 64'd5000)     k4_ls = 3480 - (c-2000)*130/3000;
            else if (c <= 64'd10000)    k4_ls = 3350 - (c-5000)*80/5000;
            else if (c <= 64'd1000000)  k4_ls = 3270 + (c-10000)*30/990000;
            else                        k4_ls = 3300;
        end
    endfunction

    function [63:0] tw_big(input [63:0] r, input [63:0] c);  // C >= 100 pF
        begin
            if (FAMILY_LS != 0) tw_big = k4_ls(c) * r * c / 64'd10_000_000;
            else                tw_big = 64'd2800 * (r + 64'd700) * c / 64'd10_000_000;
        end
    endfunction

    function [63:0] tw_ns(input [63:0] r, input [63:0] c);
        reg [63:0] t0, t100;
        begin
            if (c >= 64'd100)
                tw_ns = tw_big(r, c);
            else begin
                t0   = (FAMILY_LS != 0) ? 64'd15 + r*86/10000 : 64'd15 + r*6/1000;
                t100 = tw_big(r, 64'd100);
                tw_ns = t0 + (t100 - t0) * c / 64'd100;
            end
        end
    endfunction

    localparam [63:0]  TW_NS  = tw_ns(R_OHM, C_PF);
    localparam [63:0]  CYCLES = (TW_NS * CLK_HZ + 64'd500_000_000) / 64'd1_000_000_000;
    localparam [W-1:0] WIDTH  = (CYCLES == 0) ? 1 : CYCLES[W-1:0];

    fonz_74123_core #(.W(W)) core(
        .clk(clk), .a(a), .b(b), .clr_n(clr_n),
        .width(WIDTH), .q(q), .q_n(q_n));
endmodule

// Whole 74123 package with ports named by pin, so board wiring can follow the
// project rule of naming each wire by both ends (e.g. IC97_pin13_IC102_pin9).
// Pin 6/7 and 14/15 are the Cext/Rext timing pins of halves 1 and 2; their
// values are the parameters here. Pins 8 (GND) and 16 (VCC) are omitted.
//   half 1: pin1 A, pin2 B, pin3 /CLR, pin13 Q, pin4 /Q
//   half 2: pin9 A, pin10 B, pin11 /CLR, pin5 Q, pin12 /Q
module fonz_74123_dual #(
    parameter integer CLK_HZ       = 14_305_000,
    parameter integer R1_OHM       = 10_000,  // half 1 Rext (pin 15)
    parameter [63:0]  C1_PF        = 100,     // half 1 Cext (pins 14/15)
    parameter integer R2_OHM       = 10_000,  // half 2 Rext (pin 7)
    parameter [63:0]  C2_PF        = 100,     // half 2 Cext (pins 6/7)
    parameter integer FAMILY_LS    = 1,
    parameter integer W            = 32
)(
    input  wire clk,
    input  wire pin1, pin2, pin3,
    output wire pin13, pin4,
    input  wire pin9, pin10, pin11,
    output wire pin5, pin12
);
    fonz_74123 #(.CLK_HZ(CLK_HZ), .R_OHM(R1_OHM), .C_PF(C1_PF),
        .FAMILY_LS(FAMILY_LS), .W(W))
        half1(.clk(clk), .a(pin1), .b(pin2), .clr_n(pin3), .q(pin13), .q_n(pin4));
    fonz_74123 #(.CLK_HZ(CLK_HZ), .R_OHM(R2_OHM), .C_PF(C2_PF),
        .FAMILY_LS(FAMILY_LS), .W(W))
        half2(.clk(clk), .a(pin9), .b(pin10), .clr_n(pin11), .q(pin5), .q_n(pin12));
endmodule
`default_nettype wire
