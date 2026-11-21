// SPDX-License-Identifier: GPL-3.0-or-later
// Pixel-locked stand-ins for the analogue boundary of the board, used only
// by the equivalence bench. They are NOT models of the RC circuits: each
// 74123 half is a retriggerable pulse of a fixed number of pixel steps and
// the contacts follow a fixed script. (The 220 ohm / 680 pF edge nodes are
// inside the board now: fonz_rc_edge and its fonz_rc_edge_ce.)
//
// Each board gets its own copy, stepped by its own pixel clock (IC67 Q
// rising), so both boards see the same responses at the same pixel index.
// step=1 on a posedge of clk is one pixel.
`timescale 1ns/1ps
`default_nettype none

// One 74123 half: triggers on A falling with B high, B rising with A low,
// or /CLR rising with A low and B high; /CLR low clears. Width in steps.
module tb_mono #(parameter integer WIDTH=1)(
    input wire clk, step,
    input wire [2:0] ab_clear_n,
    output reg q=1'b0
);
    reg a_l=1'b1, b_l=1'b0, c_l=1'b0;
    integer left=0;
    wire a=ab_clear_n[2], b=ab_clear_n[1], c=ab_clear_n[0];
    wire trig=c && ((a_l && !a && b) || (!b_l && b && !a) || (!c_l && !a && b));
    always @(posedge clk) if (step) begin
        a_l<=a; b_l<=b; c_l<=c;
        if (!c) begin left=0; q<=1'b0; end
        else if (trig) begin left=WIDTH; q<=1'b1; end
        else if (left>1) left=left-1;
        else begin left=0; q<=1'b0; end
    end
endmodule

module tb_standins #(parameter integer LINE=454, parameter integer FRAME=454*261)(
    input wire clk, step,
    // Trigger and clear connections from the board.
    input wire [2:0] ic9a_ab_clear_n,ic9b_ab_clear_n,ic106a_ab_clear_n,ic106b_ab_clear_n,
    input wire [2:0] ic97b_ab_clear_n,ic97a_ab_clear_n,
    input wire [2:0] ic102b_ab_clear_n,ic102a_ab_clear_n,
    input wire [2:0] ic104b_ab_clear_n,ic104a_ab_clear_n,
    input wire [2:0] ic30a_ab_clear_n,ic30b_ab_clear_n,
    input wire [2:0] ic103a_ab_clear_n,ic103b_ab_clear_n,
    input wire ic105_6,ic99_4,ic38_3,ic59_2,
    // Responses into the board.
    output wire ic9_13,ic9_5,ic106_13,ic106_5,
    output wire ic97_13,ic97_5,ic102_13,ic102_5,ic104_13,ic104_5,
    output wire ic30_13,ic30_5,ic103_13,ic103_5,
    output reg ic105_5=1'b0,ic105_9=1'b0,ic98_5=1'b0,ic99_9=1'b0,ic99_5=1'b0,
    output reg ic37_12=1'b0,ic37_6=1'b0,ic37_4=1'b0,ic37_2=1'b0,ic37_10=1'b0,
    output reg ic38_1=1'b1,ic38_13=1'b0,antenna_logic=1'b0
);
    // Shape oscillators: the two halves are joined by the board's own
    // trigger wiring, so they run as on the board, at stand-in widths.
    tb_mono #(1) m9a  (clk,step,ic9a_ab_clear_n,  ic9_13);
    tb_mono #(2) m9b  (clk,step,ic9b_ab_clear_n,  ic9_5);
    tb_mono #(2) m106a(clk,step,ic106a_ab_clear_n,ic106_13);
    tb_mono #(1) m106b(clk,step,ic106b_ab_clear_n,ic106_5);
    // Road chain.
    tb_mono #(37) m97b (clk,step,ic97b_ab_clear_n, ic97_5);
    tb_mono #(3)  m97a (clk,step,ic97a_ab_clear_n, ic97_13);
    tb_mono #(5)  m102b(clk,step,ic102b_ab_clear_n,ic102_5);
    tb_mono #(90) m102a(clk,step,ic102a_ab_clear_n,ic102_13);
    tb_mono #(4)  m104b(clk,step,ic104b_ab_clear_n,ic104_5);
    tb_mono #(6)  m104a(clk,step,ic104a_ab_clear_n,ic104_13);
    // Collision (seconds on the board) and coin/antenna timers, shortened.
    tb_mono #(FRAME/2) m30a(clk,step,ic30a_ab_clear_n,ic30_13);
    tb_mono #(FRAME)   m30b(clk,step,ic30b_ab_clear_n,ic30_5);
    tb_mono #(FRAME*2) m103a(clk,step,ic103a_ab_clear_n,ic103_13);
    tb_mono #(FRAME/3) m103b(clk,step,ic103b_ab_clear_n,ic103_5);

    integer n=0, w105=0;
    reg ic105_6_l=1'b1;
    always @(posedge clk) if (step) begin
        n<=n+1;
        // IC105A: falling trigger on pin 6, fixed width. Other 556 halves:
        // free-running squares at unrelated periods; IC99 follows its reset.
        ic105_6_l<=ic105_6;
        if (ic105_6_l && !ic105_6) begin w105=LINE*7; ic105_5<=1'b1; end
        else if (w105>1) w105=w105-1;
        else begin w105=0; ic105_5<=1'b0; end
        if (n%(LINE*29)==0) ic105_9<=~ic105_9;  // seconds clock, sped up
        if (n%(LINE*53)==0) ic98_5<=~ic98_5;
        if (!ic99_4) begin ic99_9<=1'b0; ic99_5<=1'b0; end
        else begin
            if (n%(LINE*43)==0) ic99_9<=~ic99_9;
            if (n%(LINE*67)==0) ic99_5<=~ic99_5;
        end
        if (n%977==0) ic37_10<=~ic37_10;
        // Contact script, in frames from the start.
        // Coin in frame 3, after the IC103A pulse the stand-in fires at
        // power-up (its /CLR rising) has ended.
        ic38_1 <= !(n>=FRAME*3+LINE*10 && n<FRAME*3+LINE*40);   // coin
        ic38_13<=  (n>=FRAME*3+LINE*10 && n<FRAME*3+LINE*40);
        ic37_12<=  (n>=FRAME*3 && n<FRAME*7);                     // accelerator
        ic37_6 <=  (n>=FRAME*3 && n<FRAME*4+LINE*100);            // left
        ic37_4 <=  (n>=FRAME*5 && n<FRAME*6+LINE*50);             // right
        ic37_2 <=  (n>=FRAME*7+LINE*3 && n<FRAME*7+LINE*9);       // tilt
        // An antenna pulse in frame 6 fires IC103A for two frames, which
        // clears the time and sets the game latch again.
        antenna_logic <= (n>=FRAME*6+LINE*200 && n<FRAME*6+LINE*200+30);
    end
endmodule
`default_nettype wire
