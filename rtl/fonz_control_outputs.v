// SPDX-License-Identifier: GPL-3.0-or-later
// Open-collector gates at the transistor/RC boundary. A 1 means released,
// not actively driven high. Loads and capacitor voltages are modelled outside.
// Wire names follow docs/NET_NAMES.md; outputs are named source pin then load.
`timescale 1ns/1ps
`default_nettype none
module fonz_control_outputs(
    input wire IC3_pin5_VBLANK,IC3_pin6_VBLANK_n,IC83_pin7_ADDR_CLEAR,
    input wire IC30_pin13_CRASH,IC30_pin5_CRASH_HOLD,
    input wire IC98_pin5_IC84_pin4,IC99_pin9_IC84_pin5,IC99_pin5_IC100_pin9,IC105_pin5_THROTTLE,
    output wire IC94_pin2_VR5,IC94_pin4_TR3,IC94_pin6_R21,IC94_pin8_R16,IC94_pin10_R15,IC94_pin12_VR1,
    output wire IC100_pin2_VR9,IC100_pin4_C41,IC100_pin6_TR7,IC100_pin8_D5,IC17_pin2_CN23
);
    wire IC84_pin6_IC94_pin1=~(IC98_pin5_IC84_pin4 & IC99_pin9_IC84_pin5); // 4,5 ->6
    assign IC94_pin2_VR5=~IC84_pin6_IC94_pin1;  // variable resistance drive through VR5/R37
    assign IC94_pin4_TR3=~IC3_pin5_VBLANK;      // TR3 collector
    assign IC94_pin10_R15=~IC3_pin5_VBLANK;     // TR2 base through R15
    // Input 5 is IC30 /Q12, so the inverted output equals IC30 Q5.
    assign IC94_pin6_R21=IC30_pin5_CRASH_HOLD;  // R21/VR3 divider
    assign IC94_pin8_R16=~IC30_pin5_CRASH_HOLD; // input9=IC30.Q5; TR4/C20 via R16
    assign IC94_pin12_VR1=~IC83_pin7_ADDR_CLEAR; // IC9 timing control through VR1/R7/C11
    assign IC100_pin2_VR9=~IC105_pin5_THROTTLE;  // IC106 timing control through VR9/R99/C66
    assign IC100_pin4_C41=~IC3_pin6_VBLANK_n;    // input 3 shares the IC100.5 wire (IC3B /Q6 net); C41, TR8/P5
    assign IC100_pin6_TR7=~IC3_pin6_VBLANK_n;    // input 5 = IC3B /Q6 net (with IC28.1/13, IC84.9); TR7/P4
    assign IC100_pin8_D5=~IC99_pin5_IC100_pin9;  // D5/R38/TR4 timing control
    assign IC17_pin2_CN23=~IC30_pin13_CRASH;     // connector 23, CRUSH
endmodule
`default_nettype wire
