// SPDX-License-Identifier: GPL-3.0-or-later
// Timer reload loop. IC75/76 /BORROW -> IC82.13 (NOR) ->
// IC61.8 (NAND with IC83.13 and the R77/C52 node) -> IC81.6 (AND with
// IC101.11) -> IC75.11 and IC76.11 (/LOAD). The gates copy
// rtl/fonz_score.v (fonz_time_counters), rtl/fonz_game_control.v and
// rtl/fonz_game_and_score.v (IC82.10 = NOR(IC82.13, IC105.9) -> IC76.4).
//
// Built twice by run.sh. EVENT: event-model 74192, loop closed with zero
// delay as in the transcription. Otherwise: fonz_74192_sync with IC82.13
// registered on clk, which is the loop cut (docs/74192_SYNC.md).
// Output is the sequence of time values with the clock each one appeared.
`timescale 1ns/1ps
`default_nettype none
module tb_timer;
    parameter OUT="timer.txt";
    reg clk=1'b0;
    always #35 clk=~clk;
    // Stimulus nets carry the board's names (docs/NET_NAMES.md).
    reg IC105_pin9_IC82_pin8=1'b0;   // IC105 556 seconds clock (scaled)
    reg IC83_pin13_EXTEND_ARMED=1'b1;   // extended-play latch; also IC75.10
    reg IC59_pin12_TIME_PRESET=1'b0;   // preset select (via IC59.13/12)
    reg IC103_pin13_ANTENNA=1'b1; // time clear, also IC76.14
    wire R77_C52_IC61_pin11=1'b1, IC101_pin11_COUNT_CLEAR=1'b1;
    wire [3:0] q75, q76;
    wire IC75_pin13_IC82_pin12, IC76_pin13_BORROW_n, unused75, unused76;
    wire IC82_pin13_TIME_UP = ~(IC75_pin13_IC82_pin12 | IC76_pin13_BORROW_n);
`ifdef EVENT
    wire ic82_13_loop = IC82_pin13_TIME_UP;
`else
    reg ic82_13_loop=1'b0;   // loop cut: IC82.13 registered
    always @(posedge clk) ic82_13_loop <= IC82_pin13_TIME_UP;
`endif
    wire IC61_pin8_EXTEND_LOAD_n = ~(IC83_pin13_EXTEND_ARMED & R77_C52_IC61_pin11 & ic82_13_loop);
    wire IC81_pin6_TIME_LOAD_n = IC101_pin11_COUNT_CLEAR & IC61_pin8_EXTEND_LOAD_n;
    wire IC82_pin10_IC76_pin4 = ~(ic82_13_loop | IC105_pin9_IC82_pin8);
    wire IC59_pin12 = IC59_pin12_TIME_PRESET;
`ifdef EVENT
    fonz_74192 ic75(
`else
    fonz_74192_sync ic75(.clk(clk),
`endif
        .up(1'b1),.down(IC76_pin13_BORROW_n),.clear(IC103_pin13_ANTENNA),
        .load_n(IC81_pin6_TIME_LOAD_n),.d({IC59_pin12,1'b0,IC83_pin13_EXTEND_ARMED,1'b1}),
        .q(q75),.carry_n(unused75),.borrow_n(IC75_pin13_IC82_pin12));
`ifdef EVENT
    fonz_74192 ic76(
`else
    fonz_74192_sync ic76(.clk(clk),
`endif
        .up(1'b1),.down(IC82_pin10_IC76_pin4),.clear(IC103_pin13_ANTENNA),
        .load_n(IC81_pin6_TIME_LOAD_n),.d({IC59_pin12,2'b00,IC59_pin12}),
        .q(q76),.carry_n(unused76),.borrow_n(IC76_pin13_BORROW_n));

    integer fd, cycle=0, reloads=0, k;
    reg [7:0] last=8'hff;
    always @(posedge clk) begin
        cycle=cycle+1;
        if ({q75,q76}!==last) begin
            $fdisplay(fd,"%0d %h%h",cycle,q75,q76);
            last={q75,q76};
        end
    end
    always @(negedge IC81_pin6_TIME_LOAD_n) reloads=reloads+1;
    initial begin
        fd=$fopen(OUT,"w");
        repeat (3) @(negedge clk);
        IC103_pin13_ANTENNA=1'b0;
        // Run the clock: 64 clk a "second". Change preset select and, near the
        // end, drop the extended-play latch so the timer stops at 00.
        for (k=0;k<9000;k=k+1) begin
            repeat (32) @(negedge clk);
            IC105_pin9_IC82_pin8=~IC105_pin9_IC82_pin8;
            if (k==1500) IC59_pin12_TIME_PRESET=1'b1;
            if (k==6000) IC83_pin13_EXTEND_ARMED=1'b0;
        end
        $fclose(fd);
        $display("timer: %0d clk, %0d reloads", cycle, reloads);
        $finish;
    end
endmodule
`default_nettype wire
