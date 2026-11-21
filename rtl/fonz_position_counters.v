// SPDX-License-Identifier: GPL-3.0-or-later
// Upper-left counter chains. The IC18 preload bits arrive as a bus.
// Wire names follow docs/NET_NAMES.md.
`timescale 1ns/1ps
`default_nettype none
module fonz_position_counters(
    input wire IC4_pin6_HBLANK_n,
    // IC18 pins 3, 2, 6 (QA, QB, QC) preset IC22, IC44 and IC21.
    input wire [2:0] IC18_pin3_2_6,
    output wire [3:0] IC22_pin14_13_12_11,IC44_pin14_13_12_11,IC21_pin14_13_12_11,IC43_pin14_13_12_11,
    output wire IC66_pin3_IC65_pin1,IC66_pin5_IC65_pin5,IC65_pin12_POS1_LOAD_n,IC65_pin6_POS2_LOAD_n,
    output wire IC84_pin11_POSITION_n,
    output wire IC83_pin7_ADDR_CLEAR,
    input wire IC25_pin12_VSYNC_n
);
    wire IC22_pin15_POS1_CARRY,IC44_pin15_POS1_END,IC21_pin15_POS2_CARRY,IC43_pin15_POS2_END;
    wire IC66_pin2_NC,IC66_pin6_NC;
    fonz_74161 ic22(.clk(IC4_pin6_HBLANK_n),.clear_n(1'b1),
        .load_n(IC65_pin12_POS1_LOAD_n),.enp(1'b1),.ent(1'b1),
        .d({IC18_pin3_2_6[1:0],2'b00}),.q(IC22_pin14_13_12_11),.carry(IC22_pin15_POS1_CARRY));
    fonz_74161 ic44(.clk(IC4_pin6_HBLANK_n),.clear_n(1'b1),
        .load_n(IC65_pin12_POS1_LOAD_n),.enp(IC22_pin15_POS1_CARRY),.ent(IC22_pin15_POS1_CARRY),
        .d({3'b111,IC18_pin3_2_6[2]}),.q(IC44_pin14_13_12_11),.carry(IC44_pin15_POS1_END));
    // C18=220pF loads this carry/clock net; not a Boolean element.
    fonz_74107 ic66a(.clk(IC44_pin15_POS1_END),.clear_n(1'b1),
        .j(1'b1),.k(1'b1),.q(IC66_pin3_IC65_pin1),.q_n(IC66_pin2_NC));
    assign IC65_pin12_POS1_LOAD_n=~(IC22_pin15_POS1_CARRY & IC44_pin15_POS1_END & IC66_pin3_IC65_pin1); // 13,2,1 -> 12
    assign IC84_pin11_POSITION_n=~(IC22_pin14_13_12_11[3] & IC44_pin14_13_12_11[0]); // 12,13 -> 11, NAND
    // IC21/43 share the IC22/44 clock. The three preset wires also join:
    // 21.A=22.C, 21.B=22.D, 21.C=44.A. IC21 ENP/ENT are tied high.
    fonz_74161 ic21(.clk(IC4_pin6_HBLANK_n),.clear_n(1'b1),
        .load_n(IC65_pin6_POS2_LOAD_n),.enp(1'b1),.ent(1'b1),
        .d({1'b1,IC18_pin3_2_6}),.q(IC21_pin14_13_12_11),.carry(IC21_pin15_POS2_CARRY));
    fonz_74161 ic43(.clk(IC4_pin6_HBLANK_n),.clear_n(1'b1),
        .load_n(IC65_pin6_POS2_LOAD_n),.enp(IC21_pin15_POS2_CARRY),.ent(IC21_pin15_POS2_CARRY),
        .d(4'hf),.q(IC43_pin14_13_12_11),.carry(IC43_pin15_POS2_END));
    // C81=220pF loads this carry/clock net.
    fonz_74107 ic66b(.clk(IC43_pin15_POS2_END),.clear_n(1'b1),
        .j(1'b1),.k(1'b1),.q(IC66_pin5_IC65_pin5),.q_n(IC66_pin6_NC));
    assign IC65_pin6_POS2_LOAD_n=~(IC21_pin15_POS2_CARRY & IC43_pin15_POS2_END & IC66_pin5_IC65_pin5); // 3,4,5 -> 6
    fonz_74279 ic83b(.r_n(IC65_pin6_POS2_LOAD_n),.s1_n(IC25_pin12_VSYNC_n),
        .s2_n(1'b1),.q(IC83_pin7_ADDR_CLEAR));    // R5 S6 Q7
endmodule

module fonz_player_position(
    input wire IC37_pin8_PLAYER_CLK,
    // {IC61.6, IC39.8} preset IC64 B4 and A3.
    input wire IC61_pin6_STEER_RIGHT_n,IC39_pin8_IC64_pin3,
    input wire IC39_pin6_PLAYER_STEP,
    output wire [3:0] IC64_pin14_13_12_11,IC42_pin14_13_12_11,
    output wire IC20_pin3_IC19_pin3,IC20_pin2_NC,IC19_pin6_IC41_pin9,IC41_pin8_PLAYER_LOAD_n
);
    wire IC64_pin15_POS_CARRY,IC42_pin15_POS_END;
    fonz_74161 ic64(.clk(IC37_pin8_PLAYER_CLK),.clear_n(1'b1),
        .load_n(IC41_pin8_PLAYER_LOAD_n),.enp(1'b1),.ent(1'b1),
        .d({2'b10,IC61_pin6_STEER_RIGHT_n,IC39_pin8_IC64_pin3}),.q(IC64_pin14_13_12_11),.carry(IC64_pin15_POS_CARRY));
    fonz_74161 ic42(.clk(IC37_pin8_PLAYER_CLK),.clear_n(1'b1),
        .load_n(IC41_pin8_PLAYER_LOAD_n),.enp(IC64_pin15_POS_CARRY),.ent(IC64_pin15_POS_CARRY),
        .d(4'h3),.q(IC42_pin14_13_12_11),.carry(IC42_pin15_POS_END));
    // 64.C=GND, 64.D=+5V; 42.A/B=+5V and 42.C/D=GND.
    // IC20A clock is loaded by C75=220pF.
    fonz_74107 ic20a(.clk(IC42_pin15_POS_END),.clear_n(IC39_pin6_PLAYER_STEP),
        .j(1'b1),.k(1'b1),.q(IC20_pin3_IC19_pin3),.q_n(IC20_pin2_NC));
    assign IC19_pin6_IC41_pin9=~(IC64_pin15_POS_CARRY & IC42_pin15_POS_END & IC20_pin3_IC19_pin3); // 5,4,3 -> 6
    // IC41 9,10 -> 8: drawn as OR with bubbled inputs and output, i.e. AND.
    // It must be AND: as a NAND the /LOAD would sit low with both inputs
    // idle high and IC64/42 could never count. IC41 is taken as a 7408.
    assign IC41_pin8_PLAYER_LOAD_n=IC19_pin6_IC41_pin9 & IC39_pin6_PLAYER_STEP;
endmodule
`default_nettype wire
