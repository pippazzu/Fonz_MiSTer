// SPDX-License-Identifier: GPL-3.0-or-later
// Joined digital section around IC18, IC40 and the IC64/42 position pair.
// Schmitt/556 outputs remain analogue boundary inputs.
// Wire names follow docs/NET_NAMES.md.
`timescale 1ns/1ps
`default_nettype none
module fonz_player_control(
    input wire IC37_pin8_PLAYER_CLK,IC47_pin13_STEER_WINDOW,IC95_pin1_LINE_START,IC28_pin8_STEER_GATE,
    input wire IC37_pin12_ACCEL,IC37_pin6_LEFT,IC37_pin4_RIGHT,
    input wire IC95_pin10_IC38_pin4,IC95_pin13_IC60_pin5,IC62_pin6_GAME_LATCH_n,
    input wire IC30_pin4_CRASH_n,IC103_pin5_START,
    output wire [3:0] IC18_pin3_2_6_7,IC64_pin14_13_12_11,IC42_pin14_13_12_11,
    output wire IC20_pin3_IC19_pin3,IC20_pin2_NC,IC41_pin8_PLAYER_LOAD_n,IC62_pin10_LOWER_CLEAR,
    output wire IC39_pin3_R110,IC17_pin6_CN_Y,IC17_pin4_CN24,
    output wire IC60_pin3_STEER_DECODE,IC61_pin12_IC39_pin10,IC61_pin6_STEER_RIGHT_n,IC39_pin8_IC64_pin3
);
    wire IC34_pin4_ACCEL_n,IC39_pin6_PLAYER_STEP,IC40_pin5_DIV2,IC40_pin2_IC39_pin4,IC19_pin6_IC41_pin9;
    wire IC39_pin11_IC19_pin10,IC82_pin4_IC62_pin13,IC62_pin12_IC19_pin1;
    wire IC19_pin8_IC18_pin5,IC19_pin12_IC18_pin4,IC41_pin11_IC18_pin11;
    wire IC38_pin6_IC61_pin13,IC60_pin6_IC61_pin5,IC59_pin4_IC60_pin1,IC59_pin6_IC60_pin2;
    assign IC34_pin4_ACCEL_n=~IC37_pin12_ACCEL;      // 3 -> 4
    // Open-collector IC17 outputs: value shown with the load pulled up.
    assign IC17_pin4_CN24=~IC34_pin4_ACCEL_n;        // 3 -> 4, ACCEL to the sound board
    assign IC17_pin6_CN_Y=~IC62_pin6_GAME_LATCH_n;   // 5 -> 6, GAME
    assign IC39_pin3_R110=~(IC62_pin6_GAME_LATCH_n & IC30_pin4_CRASH_n); // 1,2 -> 3; photocoupler LED via R110
    fonz_control_gate_bank input_gates(
        // The IC62.10 return reaches IC38.5 and IC60.4.
        .IC95_pin10_IC38_pin4(IC95_pin10_IC38_pin4),.IC62_pin10_LOWER_CLEAR(IC62_pin10_LOWER_CLEAR),
        .IC95_pin13_IC60_pin5(IC95_pin13_IC60_pin5),.IC47_pin13_STEER_WINDOW(IC47_pin13_STEER_WINDOW),
        .IC37_pin6_LEFT(IC37_pin6_LEFT),.IC37_pin4_RIGHT(IC37_pin4_RIGHT),
        .IC38_pin6_IC61_pin13(IC38_pin6_IC61_pin13),.IC60_pin6_IC61_pin5(IC60_pin6_IC61_pin5),
        .IC59_pin4_IC60_pin1(IC59_pin4_IC60_pin1),.IC59_pin6_IC60_pin2(IC59_pin6_IC60_pin2),
        .IC60_pin3_STEER_DECODE(IC60_pin3_STEER_DECODE),.IC61_pin12_IC39_pin10(IC61_pin12_IC39_pin10),
        .IC61_pin6_STEER_RIGHT_n(IC61_pin6_STEER_RIGHT_n));
    fonz_steering steering(
        .IC28_pin8_STEER_GATE(IC28_pin8_STEER_GATE),.IC34_pin4_ACCEL_n(IC34_pin4_ACCEL_n),
        .IC37_pin12_ACCEL(IC37_pin12_ACCEL),
        .IC61_pin12_IC39_pin10(IC61_pin12_IC39_pin10),.IC61_pin6_STEER_RIGHT_n(IC61_pin6_STEER_RIGHT_n),
        .IC30_pin4_CRASH_n(IC30_pin4_CRASH_n),.IC62_pin6_GAME_LATCH_n(IC62_pin6_GAME_LATCH_n),
        .IC18_pin3_2_6_7(IC18_pin3_2_6_7),.IC39_pin11_IC19_pin10(IC39_pin11_IC19_pin10),
        .IC82_pin4_IC62_pin13(IC82_pin4_IC62_pin13),.IC62_pin12_IC19_pin1(IC62_pin12_IC19_pin1),
        .IC39_pin8_IC64_pin3(IC39_pin8_IC64_pin3),.IC19_pin8_IC18_pin5(IC19_pin8_IC18_pin5),
        .IC19_pin12_IC18_pin4(IC19_pin12_IC18_pin4),.IC41_pin11_IC18_pin11(IC41_pin11_IC18_pin11));
    fonz_control_divider divider(
        // IC40A J1, /CLR13 and IC40B /CLR10 are the IC103.Q5 coin-meter
        // wire (shared with IC17.11). It crosses the IC62.10 vertical
        // without a junction (native 3372,5286).
        .IC37_pin8_PLAYER_CLK(IC37_pin8_PLAYER_CLK),.IC95_pin1_LINE_START(IC95_pin1_LINE_START),
        .IC103_pin5_START(IC103_pin5_START),
        .IC40_pin5_DIV2(IC40_pin5_DIV2),.IC40_pin2_IC39_pin4(IC40_pin2_IC39_pin4),
        .IC39_pin6_PLAYER_STEP(IC39_pin6_PLAYER_STEP));
    fonz_player_position position(
        .IC37_pin8_PLAYER_CLK(IC37_pin8_PLAYER_CLK),
        .IC61_pin6_STEER_RIGHT_n(IC61_pin6_STEER_RIGHT_n),.IC39_pin8_IC64_pin3(IC39_pin8_IC64_pin3),
        .IC39_pin6_PLAYER_STEP(IC39_pin6_PLAYER_STEP),
        .IC64_pin14_13_12_11(IC64_pin14_13_12_11),.IC42_pin14_13_12_11(IC42_pin14_13_12_11),
        .IC20_pin3_IC19_pin3(IC20_pin3_IC19_pin3),.IC20_pin2_NC(IC20_pin2_NC),
        .IC19_pin6_IC41_pin9(IC19_pin6_IC41_pin9),.IC41_pin8_PLAYER_LOAD_n(IC41_pin8_PLAYER_LOAD_n));
    // IC62 pin11 is driven by IC41 pin8, not IC39 pin6.
    assign IC62_pin10_LOWER_CLEAR=~IC41_pin8_PLAYER_LOAD_n;
endmodule
`default_nettype wire
