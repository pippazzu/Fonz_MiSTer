// SPDX-License-Identifier: GPL-3.0-or-later
// MiSTer pad -> The Fonz cabinet contacts.
//
// Wires are named by their endpoints: CNnn is edge-connector pin nn,
// ICnn_pinp is physical pin p of IC nn (docs/CONTROLS.md).
//
// The outputs are the logic levels on the wires from the edge connector to
// the board's input gates, with the board's 510 ohm pull-ups: 1 at rest,
// 0 while the cabinet switch holds the pin to ground. The RC networks and
// IC37 Schmitt inverters sit on these wires.
// `fonz_contacts_direct` below is a zero-delay stand-in for that stage, for
// test benches and bring-up only.
//
// IC count: none. This module stands in for the cabinet switches.
//
// All pad inputs are active high, as hps_io's joystick bits.
`timescale 1ns/1ps
`default_nettype none
module fonz_cabinet_inputs #(
    parameter integer CLK_HZ       = 48_000_000,
    // How long the coin switch's normally-open contact stays closed for one
    // coin. Real coin mechs close for tens of milliseconds.
    parameter integer COIN_MS      = 50,
    // Changeover switches break before they make: both contacts are open
    // for this long on each throw.
    parameter integer COIN_GAP_US  = 500,
    // The cabinet has no start button: the coin pulse at IC38 pin 8 triggers
    // IC103B and starts the game. With this set, MiSTer Start inserts a coin
    // as well, so a pad alone can start a game.
    parameter        START_IS_COIN = 1
)(
    input  wire clk,
    input  wire rst,

    input  wire pad_left,     // joystick left
    input  wire pad_right,    // joystick right
    input  wire pad_accel,    // button 1: ACCEL switch on the grip
    input  wire pad_coin,     // MiSTer coin
    input  wire pad_start,    // MiSTer start
    input  wire pad_tilt,     // tilt switch (tie low unless mapped)

    output wire CN16_IC37_pin13,  // accelerator switch, via R83/R84/C47
    output wire CN17_IC37_pin5,   // turn left, via R85/R86/C48
    output wire CN18_IC37_pin3,   // turn right, via R87/R88/C49
    output wire CN1_IC37_pin1,    // tilt, via R89/R90/C50
    output reg  CN21_IC38_pin1,   // coin switch NO contact, via R94/R93/C60
    output reg  CN20_IC38_pin13,  // coin switch NC contact, via R92/R91/C59
    output wire CN_X_IC103_pin1    // antenna, via C54/C53/D17/R75/R78
);
    // The handlebar closes one turn switch or the other, never both.
    assign CN17_IC37_pin5  = ~(pad_left  & ~pad_right);
    assign CN18_IC37_pin3  = ~(pad_right & ~pad_left);
    assign CN16_IC37_pin13 = ~pad_accel;
    assign CN1_IC37_pin1   = ~pad_tilt;
    // R75/R78 hold IC103A pin 1 low when the antenna picks nothing up.
    assign CN_X_IC103_pin1  = 1'b0;

    localparam integer GAP_CYCLES  = (CLK_HZ/1_000_000)*COIN_GAP_US;
    localparam integer COIN_CYCLES = (CLK_HZ/1000)*COIN_MS;
    localparam integer CW = $clog2(COIN_CYCLES+1);
    localparam [CW-1:0] GAP_LAST  = GAP_CYCLES-1;
    localparam [CW-1:0] COIN_LAST = COIN_CYCLES-1;

    localparam [1:0] IDLE = 2'd0, BREAK_NC = 2'd1, MADE_NO = 2'd2, BREAK_NO = 2'd3;
    reg [1:0]    state;
    reg [CW-1:0] count;
    reg          req_last;

    // One coin per press: a held button does not repeat, and a press during
    // a coin is ignored.
    wire req = pad_coin | (START_IS_COIN != 0 && pad_start);
    wire req_edge = req & ~req_last;

    // Contact closed = wire pulled to 0. At rest the NC contact is closed.
    always @(posedge clk) begin
        if (rst) begin
            state             <= IDLE;
            count             <= 0;
            req_last          <= 1'b1;  // no coin from a button held through reset
            CN20_IC38_pin13 <= 1'b0;
            CN21_IC38_pin1  <= 1'b1;
        end else begin
            req_last <= req;
            case (state)
            IDLE: if (req_edge) begin
                CN20_IC38_pin13 <= 1'b1;      // NC opens
                count             <= 0;
                state             <= BREAK_NC;
            end
            BREAK_NC: if (count == GAP_LAST) begin
                CN21_IC38_pin1  <= 1'b0;      // NO closes
                count             <= 0;
                state             <= MADE_NO;
            end else count <= count + 1'b1;
            MADE_NO: if (count == COIN_LAST) begin
                CN21_IC38_pin1  <= 1'b1;      // NO opens
                count             <= 0;
                state             <= BREAK_NO;
            end else count <= count + 1'b1;
            BREAK_NO: if (count == GAP_LAST) begin
                CN20_IC38_pin13 <= 1'b0;      // NC closes
                count             <= 0;
                state             <= IDLE;
            end else count <= count + 1'b1;
            default: state <= IDLE;
            endcase
        end
    end
endmodule

// Zero-delay contact conditioning: IC37 Schmitt inversion with no RC delay.
// The board models of the RC delays are in fonz_input_conditioning.v. The coin wires reach
// IC38's NAND latch directly, so they need no stand-in here.
// IC count: IC37 7414 (four of its six inverters).
module fonz_contacts_direct(
    input  wire CN16_IC37_pin13, CN17_IC37_pin5,
    input  wire CN18_IC37_pin3,  CN1_IC37_pin1,
    output wire IC37_pin12_ACCEL,  // also IC19 pin 2 (IC34 pin 3)
    output wire IC37_pin6_LEFT,
    output wire IC37_pin4_RIGHT,
    output wire IC37_pin2_IC82_pin2
);
    assign IC37_pin12_ACCEL = ~CN16_IC37_pin13;
    assign IC37_pin6_LEFT  = ~CN17_IC37_pin5;
    assign IC37_pin4_RIGHT  = ~CN18_IC37_pin3;
    assign IC37_pin2_IC82_pin2  = ~CN1_IC37_pin1;
endmodule
