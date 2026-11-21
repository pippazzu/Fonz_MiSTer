// SPDX-License-Identifier: GPL-3.0-or-later
// Right-hand video gating. The three resistor-mixer contributions are kept
// separate. They are NOT RGB channels and no black/white threshold is invented.
// Wire names follow docs/NET_NAMES.md.
`timescale 1ns/1ps
`default_nettype none
module fonz_video_gates(
    input wire IC27_pin11_HSYNC_n,IC25_pin12_VSYNC_n,
    input wire IC4_pin5_HBLANK,IC3_pin5_VBLANK,
    input wire IC71_pin7_UPPER_SHAPE1,IC108_pin7_IC6_pin10,IC41_pin3_IC6_pin9,
    input wire IC71_pin9_UPPER_SHAPE2,IC20_pin5_IC6_pin1,
    input wire IC28_pin4_IC5_pin5,IC108_pin9_LOWER_SHAPE2,IC101_pin6_ROAD_LOAD_n,IC102_pin13_ROAD,
    output wire IC5_pin8_IC5_pin12,IC5_pin11_R13,IC5_pin6_IC7_pin9,
    output wire IC7_pin8_R26,IC7_pin12_VR13,IC6_pin8_IC5_pin4,IC6_pin12_IC47_pin2,IC6_pin6_IC27_pin1,
    output wire IC45_pin2_IC47_pin3,IC26_pin2_IC6_pin5,IC47_pin1_IC29_pin1,IC27_pin3_IC7_pin13
);
    assign IC5_pin8_IC5_pin12=IC27_pin11_HSYNC_n ^ IC25_pin12_VSYNC_n;  // 9,10 -> 8
    assign IC5_pin11_R13=IC5_pin8_IC5_pin12 ^ 1'b1;       // IC5 pin13 tied high
    assign IC6_pin8_IC5_pin4=~(IC71_pin7_UPPER_SHAPE1 | IC108_pin7_IC6_pin10 | IC41_pin3_IC6_pin9); // 11,10,9 -> 8
    // 6.13 joins 6.11.
    assign IC6_pin12_IC47_pin2=~(IC71_pin9_UPPER_SHAPE2 | IC71_pin7_UPPER_SHAPE1 | IC20_pin5_IC6_pin1); // 2,13,1 -> 12
    assign IC26_pin2_IC6_pin5=~IC101_pin6_ROAD_LOAD_n;    // 1 -> 2
    // 6.3 joins 6.2; 6.4 joins 45.1.
    assign IC6_pin6_IC27_pin1=~(IC71_pin9_UPPER_SHAPE2 | IC108_pin9_LOWER_SHAPE2 | IC26_pin2_IC6_pin5); // 3,4,5 -> 6
    assign IC5_pin6_IC7_pin9=IC6_pin8_IC5_pin4 ^ IC28_pin4_IC5_pin5;   // 4,5 -> 6
    assign IC45_pin2_IC47_pin3=~IC108_pin9_LOWER_SHAPE2;  // 1 -> 2
    assign IC47_pin1_IC29_pin1=~(IC6_pin12_IC47_pin2 | IC45_pin2_IC47_pin3); // 2,3 -> 1
    assign IC27_pin3_IC7_pin13=~(IC102_pin13_ROAD & IC6_pin6_IC27_pin1); // 2,1 -> 3
    // 7.9 returns from XOR 5.6; 7.13 returns from NAND 27.3.
    // The long 47.1 wire CROSSES the 27.3 return without a junction.
    // IC7 pins 10 and 2 share IC4.5; pins 11 and 1 share IC3.5.
    assign IC7_pin8_R26=~(IC4_pin5_HBLANK | IC3_pin5_VBLANK | IC5_pin6_IC7_pin9);    // 10,11,9 -> 8
    assign IC7_pin12_VR13=~(IC4_pin5_HBLANK | IC3_pin5_VBLANK | IC27_pin3_IC7_pin13); // 2,1,13 -> 12
    // IC5.11 -> R13=1k, IC7.8 -> R26=470, IC7.12 -> VR13=2k + R3=1k.
    // R27=220 pulls up their junction; C16=4.7uF couples it to VIDEO pin7.
endmodule

module fonz_road_gate_chain(
    input wire IC104_pin13_IC20_pin9,IC97_pin4_IC20_pin10,
    input wire IC102_pin5_LEFT_KERB,IC84_pin11_POSITION_n,IC104_pin5_RIGHT_KERB,IC37_pin8_PLAYER_CLK,
    output wire IC20_pin5_IC6_pin1,IC20_pin6_IC65_pin11,IC101_pin3_IC65_pin10,
    output wire IC101_pin8_IC65_pin9,IC65_pin8_IC41_pin1,IC41_pin3_IC6_pin9
);
    fonz_74107 ic20b(.clk(IC104_pin13_IC20_pin9),.clear_n(IC97_pin4_IC20_pin10),
        .j(1'b1),.k(1'b0),.q(IC20_pin5_IC6_pin1),.q_n(IC20_pin6_IC65_pin11));
    // IC84.11 reaches both IC101 pins 2 and 10.
    assign IC101_pin3_IC65_pin10=~(IC102_pin5_LEFT_KERB & IC84_pin11_POSITION_n); // 1,2 -> 3
    assign IC101_pin8_IC65_pin9=~(IC104_pin5_RIGHT_KERB & IC84_pin11_POSITION_n);  // 9,10 -> 8
    // IC65 negative-input OR: NAND3.
    assign IC65_pin8_IC41_pin1=~(IC101_pin3_IC65_pin10 & IC101_pin8_IC65_pin9 & IC20_pin6_IC65_pin11); // 10,9,11 -> 8
    // IC41: 1,2 -> 3. Drawn as a NAND; taken as AND (7408 package).
    // As a NAND it would hold IC6.9 high with no road, forcing IC6.8 low and
    // hiding both shapes over the whole screen.
`ifdef FONZ_IC41_DRAWN_NAND
    assign IC41_pin3_IC6_pin9=~(IC65_pin8_IC41_pin1 & IC37_pin8_PLAYER_CLK);
`else
    assign IC41_pin3_IC6_pin9=IC65_pin8_IC41_pin1 & IC37_pin8_PLAYER_CLK;
`endif
endmodule
`default_nettype wire
