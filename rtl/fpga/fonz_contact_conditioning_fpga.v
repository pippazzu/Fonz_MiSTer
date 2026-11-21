// SPDX-License-Identifier: GPL-3.0-or-later
// Single-clock copy of fonz_contact_conditioning
// (rtl/fonz_input_conditioning.v): the six cabinet contacts from their
// connector wires to the IC37 outputs and the IC38 inputs. Hand-written;
// the event model's RC nodes use `real` and timed waits.
//
// Each contact's capacitor is an up/down counter between 0 (discharged,
// the gate sees 0) and FULL (charged, the gate sees 1). Closing the contact
// (connector at 0) discharges it, opening it charges it. The rates are
// set so that a full swing takes the delays of docs/CONDITIONING.md
// (closing ~4.0 ms, opening ~5.3 ms on the 22 uF contacts, ~1.4 and ~1.8 us
// on the coin's 0.01 uF), and the gate switches only at the ends, like the
// Schmitt trigger's two thresholds. So a tap shorter than the delay is
// absorbed, and a contact that reopens before its capacitor has settled
// comes back sooner, as on the board. The curve is a straight line instead
// of an exponential; only the end points are matched.
//
// Wires are named as in the event model (docs/NET_NAMES.md). IC count: IC37 7414
// (four of six inverters), shared with the board's own IC37.
`timescale 1ns/1ps
`default_nettype none
module fonz_contact_rc_ce #(
    parameter integer CLOSE_TICKS = 4000,  // closed -> gate sees 0
    parameter integer OPEN_TICKS  = 5300,  // open -> gate sees 1
    parameter         INIT        = 1'b1
)(
    input  wire clk_sys, rst,
    input  wire tick,
    input  wire connector,    // 1 at rest (open), 0 closed
    output reg  gate_input = INIT
);
    // Level in units of 1/(CLOSE_TICKS*OPEN_TICKS) of the swing.
    localparam [31:0] FULL = CLOSE_TICKS * OPEN_TICKS;
    reg [31:0] level = INIT ? FULL : 32'd0;
    always @(posedge clk_sys)
        if (rst) begin
            level      <= INIT ? FULL : 32'd0;
            gate_input <= INIT;
        end else if (tick) begin
            if (connector) begin
                if (level + CLOSE_TICKS >= FULL) begin
                    level      <= FULL;
                    gate_input <= 1'b1;
                end else
                    level <= level + CLOSE_TICKS;
            end else begin
                if (level <= OPEN_TICKS) begin
                    level      <= 32'd0;
                    gate_input <= 1'b0;
                end else
                    level <= level - OPEN_TICKS;
            end
        end
endmodule

module fonz_contact_conditioning_fpga #(
    parameter integer CLK_SYS_HZ = 48_000_000
)(
    input  wire clk_sys, rst,
    input  wire CN16_IC37_pin13, CN17_IC37_pin5, CN18_IC37_pin3, CN1_IC37_pin1,
    input  wire CN21_IC38_pin1, CN20_IC38_pin13,
    output wire IC37_pin12_ACCEL,  // also IC19 pin 2 (IC34 pin 3)
    output wire IC37_pin6_LEFT,
    output wire IC37_pin4_RIGHT,
    output wire IC37_pin2_IC82_pin2,
    output wire R93_C60_IC38_pin1,
    output wire R91_C59_IC38_pin13
);
    // 1 us tick for the 22 uF contacts.
    localparam [63:0] US_INC = (64'd1_000_000 << 32) / CLK_SYS_HZ;
    reg [32:0] us_acc = 33'd0;
    wire us = us_acc[32];
    always @(posedge clk_sys) us_acc <= {1'b0, us_acc[31:0]} + US_INC[32:0];
    // Coin contacts in clk_sys cycles: 1.4 us closing, 1.8 us opening.
    localparam integer COIN_CLOSE = (CLK_SYS_HZ / 1000) * 14 / 10000;
    localparam integer COIN_OPEN  = (CLK_SYS_HZ / 1000) * 18 / 10000;

    wire R84_C47_IC37_pin13, R86_C48_IC37_pin5, R88_C49_IC37_pin3, R90_C50_IC37_pin1;
    // Connector 16: R83 510, R84 100, C47 22 uF, IC37 13 -> 12.
    fonz_contact_rc_ce accel(.clk_sys(clk_sys), .rst(rst), .tick(us),
        .connector(CN16_IC37_pin13), .gate_input(R84_C47_IC37_pin13));
    // Connector 17: R85 510, R86 100, C48 22 uF, IC37 5 -> 6.
    fonz_contact_rc_ce left(.clk_sys(clk_sys), .rst(rst), .tick(us),
        .connector(CN17_IC37_pin5), .gate_input(R86_C48_IC37_pin5));
    // Connector 18: R87 510, R88 100, C49 22 uF, IC37 3 -> 4.
    fonz_contact_rc_ce right(.clk_sys(clk_sys), .rst(rst), .tick(us),
        .connector(CN18_IC37_pin3), .gate_input(R88_C49_IC37_pin3));
    // Connector 1: R89 510, R90 100, C50 22 uF, IC37 1 -> 2.
    fonz_contact_rc_ce tilt(.clk_sys(clk_sys), .rst(rst), .tick(us),
        .connector(CN1_IC37_pin1), .gate_input(R90_C50_IC37_pin1));
    // IC37 is a 7414: inverting Schmitt.
    assign IC37_pin12_ACCEL = ~R84_C47_IC37_pin13;
    assign IC37_pin6_LEFT  = ~R86_C48_IC37_pin5;
    assign IC37_pin4_RIGHT  = ~R88_C49_IC37_pin3;
    assign IC37_pin2_IC82_pin2  = ~R90_C50_IC37_pin1;
    // Coin changeover. Connector 21 (normally open): R94, R93, C60 0.01 uF ->
    // IC38.1. Connector 20 (normally closed): R92, R91, C59 0.01 uF -> IC38.13.
    fonz_contact_rc_ce #(.CLOSE_TICKS(COIN_CLOSE), .OPEN_TICKS(COIN_OPEN)) coin_no(
        .clk_sys(clk_sys), .rst(rst), .tick(1'b1),
        .connector(CN21_IC38_pin1), .gate_input(R93_C60_IC38_pin1));
    fonz_contact_rc_ce #(.CLOSE_TICKS(COIN_CLOSE), .OPEN_TICKS(COIN_OPEN), .INIT(1'b0)) coin_nc(
        .clk_sys(clk_sys), .rst(rst), .tick(1'b1),
        .connector(CN20_IC38_pin13), .gate_input(R91_C59_IC38_pin13));
endmodule
`default_nettype wire
