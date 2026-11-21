// SPDX-License-Identifier: GPL-3.0-or-later
// Road monostable pin connections and the adjoining digital gates.
// Q inputs are supplied by analogue timing models; this is not an RC model.
// Wire names follow docs/NET_NAMES.md.
`timescale 1ns/1ps
`default_nettype none
module fonz_road(
    input wire IC27_pin11_HSYNC_n,
    input wire IC97_pin5_IC97_pin1,IC97_pin13_IC102_pin9,IC102_pin5_LEFT_KERB,
    input wire IC102_pin13_ROAD,IC104_pin5_RIGHT_KERB,IC104_pin13_IC20_pin9,
    input wire R67_C44_IC101_pin5,IC84_pin11_POSITION_n,IC37_pin8_PLAYER_CLK,
    output wire [2:0] ic97b_ab_clear_n,ic97a_ab_clear_n,
    output wire [2:0] ic102b_ab_clear_n,ic102a_ab_clear_n,
    output wire [2:0] ic104b_ab_clear_n,ic104a_ab_clear_n,
    output wire IC20_pin5_IC6_pin1,IC20_pin6_IC65_pin11,IC101_pin6_ROAD_LOAD_n,IC41_pin3_IC6_pin9
);
    wire IC97_pin4_IC20_pin10,IC102_pin12_NC,IC104_pin12_NC;
    wire IC101_pin3_IC65_pin10,IC101_pin8_IC65_pin9,IC65_pin8_IC41_pin1;
    fonz_road_monostable_connections timers(
        .IC27_pin11_HSYNC_n(IC27_pin11_HSYNC_n),.IC97_pin5_IC97_pin1(IC97_pin5_IC97_pin1),
        .IC97_pin13_IC102_pin9(IC97_pin13_IC102_pin9),.IC102_pin5_LEFT_KERB(IC102_pin5_LEFT_KERB),
        .IC102_pin13_ROAD(IC102_pin13_ROAD),.IC104_pin5_RIGHT_KERB(IC104_pin5_RIGHT_KERB),
        .IC104_pin13_IC20_pin9(IC104_pin13_IC20_pin9),
        .ic97b_ab_clear_n(ic97b_ab_clear_n),.ic97a_ab_clear_n(ic97a_ab_clear_n),
        .ic102b_ab_clear_n(ic102b_ab_clear_n),.ic102a_ab_clear_n(ic102a_ab_clear_n),
        .ic104b_ab_clear_n(ic104b_ab_clear_n),.ic104a_ab_clear_n(ic104a_ab_clear_n),
        .IC97_pin4_IC20_pin10(IC97_pin4_IC20_pin10),.IC102_pin12_NC(IC102_pin12_NC),
        .IC104_pin12_NC(IC104_pin12_NC));
    fonz_road_gate_chain gates(
        .IC104_pin13_IC20_pin9(IC104_pin13_IC20_pin9),.IC97_pin4_IC20_pin10(IC97_pin4_IC20_pin10),
        .IC102_pin5_LEFT_KERB(IC102_pin5_LEFT_KERB),.IC84_pin11_POSITION_n(IC84_pin11_POSITION_n),
        .IC104_pin5_RIGHT_KERB(IC104_pin5_RIGHT_KERB),.IC37_pin8_PLAYER_CLK(IC37_pin8_PLAYER_CLK),
        .IC20_pin5_IC6_pin1(IC20_pin5_IC6_pin1),.IC20_pin6_IC65_pin11(IC20_pin6_IC65_pin11),
        .IC101_pin3_IC65_pin10(IC101_pin3_IC65_pin10),.IC101_pin8_IC65_pin9(IC101_pin8_IC65_pin9),
        .IC65_pin8_IC41_pin1(IC65_pin8_IC41_pin1),.IC41_pin3_IC6_pin9(IC41_pin3_IC6_pin9));
    // 102.5 -> 101.4 directly; 102.5 -> R67=220 / C44=680p -> 101.5.
    assign IC101_pin6_ROAD_LOAD_n=~(IC102_pin5_LEFT_KERB & R67_C44_IC101_pin5); // 4,5 -> 6
endmodule
`default_nettype wire
