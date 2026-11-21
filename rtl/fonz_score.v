// SPDX-License-Identifier: GPL-3.0-or-later
// Lower centre: score divider chain and two-digit countdown.
// Wire names follow docs/NET_NAMES.md.
`timescale 1ns/1ps
`default_nettype none
module fonz_score_counters(
    input wire IC74_pin8_IC77_pin15,IC101_pin11_COUNT_CLEAR,
    output wire [3:0] IC77_pin13_11_10_9,IC77_pin3_5_6_7,
    output wire [3:0] IC79_pin3_5_6_7,IC79_pin13_11_10_9
);
    // The drawing calls the physical pin-15 section of IC77 "1" and its
    // pin-1 section "2". Preserve physical pins instead of following that
    // misleading half-numbering. Output vector bit 0 is QA throughout.
    // Each QA also clocks its own B input (13->12, 3->4).
    wire IC77_pin3_TENS,IC77_pin13_UNITS,IC79_pin3_HUNDREDS,IC79_pin13_THOUSANDS;
    wire [2:0] IC77_pin11_10_9,IC77_pin5_6_7,IC79_pin5_6_7,IC79_pin11_10_9;
    fonz_74390_half ic77_p15(.clk_a(IC74_pin8_IC77_pin15),.clk_b(IC77_pin13_UNITS),
        .clear(IC101_pin11_COUNT_CLEAR),.qa(IC77_pin13_UNITS),.qdcb(IC77_pin11_10_9));
    // IC77 pin 9 -> IC77 pin 1, IC77 pin 7 -> IC79 pin 1, IC79 pin 7 -> IC79 pin 15.
    fonz_74390_half ic77_p1(.clk_a(IC77_pin11_10_9[2]),.clk_b(IC77_pin3_TENS),
        .clear(IC101_pin11_COUNT_CLEAR),.qa(IC77_pin3_TENS),.qdcb(IC77_pin5_6_7));
    fonz_74390_half ic79_p1(.clk_a(IC77_pin5_6_7[2]),.clk_b(IC79_pin3_HUNDREDS),
        .clear(IC101_pin11_COUNT_CLEAR),.qa(IC79_pin3_HUNDREDS),.qdcb(IC79_pin5_6_7));
    fonz_74390_half ic79_p15(.clk_a(IC79_pin5_6_7[2]),.clk_b(IC79_pin13_THOUSANDS),
        .clear(IC101_pin11_COUNT_CLEAR),.qa(IC79_pin13_THOUSANDS),.qdcb(IC79_pin11_10_9));
    assign IC77_pin13_11_10_9={IC77_pin11_10_9,IC77_pin13_UNITS};
    assign IC77_pin3_5_6_7={IC77_pin5_6_7,IC77_pin3_TENS};
    assign IC79_pin3_5_6_7={IC79_pin5_6_7,IC79_pin3_HUNDREDS};
    assign IC79_pin13_11_10_9={IC79_pin11_10_9,IC79_pin13_THOUSANDS};
endmodule

module fonz_time_counters(
    input wire IC82_pin10_IC76_pin4,IC103_pin13_ANTENNA,IC81_pin6_TIME_LOAD_n,IC83_pin13_EXTEND_ARMED,
    output wire [3:0] IC75_pin3_2_6_7,IC76_pin3_2_6_7,
    output wire IC75_pin13_IC82_pin12,IC76_pin13_BORROW_n,IC59_pin12_TIME_PRESET,IC82_pin13_TIME_UP
);
    wire IC75_pin12_NC,IC76_pin12_NC;
    assign IC59_pin12_TIME_PRESET=~IC83_pin13_EXTEND_ARMED; // IC59 pins13 ->12, timer preset selector
    // IC76 is the units counter; its /BORROW13 drives IC75.DOWN4.
    // IC75 drives scan digit 0 (time x10), IC76 digit 1 (time x1).
    fonz_74192 ic75(.up(1'b1),.down(IC76_pin13_BORROW_n),.clear(IC103_pin13_ANTENNA),
        .load_n(IC81_pin6_TIME_LOAD_n),.d({IC59_pin12_TIME_PRESET,1'b0,IC83_pin13_EXTEND_ARMED,1'b1}),
        .q(IC75_pin3_2_6_7),.carry_n(IC75_pin12_NC),.borrow_n(IC75_pin13_IC82_pin12));
    fonz_74192 ic76(.up(1'b1),.down(IC82_pin10_IC76_pin4),.clear(IC103_pin13_ANTENNA),
        .load_n(IC81_pin6_TIME_LOAD_n),.d({IC59_pin12_TIME_PRESET,2'b00,IC59_pin12_TIME_PRESET}),
        .q(IC76_pin3_2_6_7),.carry_n(IC76_pin12_NC),.borrow_n(IC76_pin13_BORROW_n));
    assign IC82_pin13_TIME_UP=~(IC75_pin13_IC82_pin12 | IC76_pin13_BORROW_n); // pins12,11 ->13, NOR
endmodule

module fonz_display(
    // IC2 pins 13, 12, 11 (QB, QC, QD) reach IC58 A15, B14, C13.
    input wire [2:0] IC2_pin13_12_11,
    input wire [3:0] IC75_pin3_2_6_7,IC76_pin3_2_6_7,
    input wire [3:0] IC77_pin13_11_10_9,IC77_pin3_5_6_7,IC79_pin3_5_6_7,
    input wire IC80_pin6_IC33_pin5,IC100_pin12_IC34_pin9,
    output wire [5:0] IC36_pin6_4_2_12_10_8_DIGIT,
    output wire [9:0] IC58_pin1_2_3_4_5_6_7_9_10_11,
    output wire [3:0] IC34_pin8_2_12_10_IC33_pin7_1_2_6,
    output wire [6:0] IC33_pin14_15_9_10_11_12_13,
    output wire [3:0] IC34_pin9_1_13_11_BCD_n
);
    fonz_7442 ic58(.dcba({1'b0,IC2_pin13_12_11}),.y_n(IC58_pin1_2_3_4_5_6_7_9_10_11));
    // IC36 inverts decoder outputs 0..5. IC35 open-collector inverters
    // then pull the six PNP digit-driver bases low. The bus is the logical
    // enable, not the 12V transistor collector voltage.
    assign IC36_pin6_4_2_12_10_8_DIGIT=~IC58_pin1_2_3_4_5_6_7_9_10_11[5:0];
    // Per-package terms of the wired bus below (output pins 6/8/3/11 = A/B/C/D);
    // they are not separate wires.
    wire [3:0] IC53_terms_n,IC54_terms_n,IC55_terms_n,IC56_terms_n,IC57_terms_n;
    assign IC53_terms_n=~(IC75_pin3_2_6_7 & {4{IC36_pin6_4_2_12_10_8_DIGIT[0]}});
    assign IC54_terms_n=~(IC76_pin3_2_6_7 & {4{IC36_pin6_4_2_12_10_8_DIGIT[1]}});
    assign IC55_terms_n=~(IC77_pin13_11_10_9 & {4{IC36_pin6_4_2_12_10_8_DIGIT[2]}});
    assign IC56_terms_n=~(IC77_pin3_5_6_7 & {4{IC36_pin6_4_2_12_10_8_DIGIT[3]}});
    assign IC57_terms_n=~(IC79_pin3_5_6_7 & {4{IC36_pin6_4_2_12_10_8_DIGIT[4]}});
    // 20 x 7403 open-collector NAND outputs share FOUR pulled-up wires.
    // They must be a wired AND, not five push-pull drivers fighting.
    // A wire with many drivers is named by its load pins (IC34 9, 1, 13, 11).
    assign IC34_pin9_1_13_11_BCD_n=IC53_terms_n & IC54_terms_n & IC55_terms_n & IC56_terms_n &
                    IC57_terms_n & {3'b111,IC100_pin12_IC34_pin9};
    // Sixth source is IC100.12, an OC inverter on the A wire, driven by
    // IC81.11 (IC79.13 AND digit selector 5). It is NOT a hardwired zero.
    assign IC34_pin8_2_12_10_IC33_pin7_1_2_6=~IC34_pin9_1_13_11_BCD_n; // A:9->8 B:1->2 C:13->12 D:11->10
    wire IC33_pin4_NC;
    // LT3 and BI4 are not drawn: inactive-high TTL assumption.
    fonz_7448 ic33(.dcba(IC34_pin8_2_12_10_IC33_pin7_1_2_6),.rbi_n(IC80_pin6_IC33_pin5),
        .bi_n(1'b1),.lt_n(1'b1),.rbo_n(IC33_pin4_NC),
        .abcdefg(IC33_pin14_15_9_10_11_12_13));
    // IC33 a..g -> TR17,16,15,14,13,19,18 -> M,L,10,9,8,P,N.
endmodule

module fonz_score_clock(
    input wire IC83_pin9_GAME_LATCH,IC24_pin14_V,IC105_pin5_THROTTLE,IC30_pin12_CRASH_HOLD_n,
    input wire IC59_pin10_SCORE_CLEAR,
    output wire IC92_pin6_IC27_pin5,IC27_pin6_IC74_pin1,
    output wire [3:0] IC74_pin3_4_5_6,IC74_pin11_10_9_8
);
    assign IC92_pin6_IC27_pin5=~(IC83_pin9_GAME_LATCH | IC24_pin14_V | IC105_pin5_THROTTLE); // 3,4,5 -> 6
    assign IC27_pin6_IC74_pin1=~(IC92_pin6_IC27_pin5 & IC30_pin12_CRASH_HOLD_n);         // NAND, pins5,4 ->6
    fonz_74393_half ic74a(.clk(IC27_pin6_IC74_pin1),.clear(IC59_pin10_SCORE_CLEAR),.q(IC74_pin3_4_5_6));
    // IC74 pin 6 (QD) clocks the second half at pin 13.
    fonz_74393_half ic74b(.clk(IC74_pin3_4_5_6[3]),.clear(IC59_pin10_SCORE_CLEAR),.q(IC74_pin11_10_9_8));
endmodule
`default_nettype wire
