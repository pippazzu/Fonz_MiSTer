// SPDX-License-Identifier: GPL-3.0-or-later
// Cell check: event-model fonz_74192 against fonz_74192_sync, alone and
// as a carry/borrow cascade, under random stimulus. Inputs change on clk
// falling edges (one change per clk); outputs are compared on rising edges.
`timescale 1ns/1ps
`default_nettype none
module tb_cell;
    reg clk=1'b0;
    always #35 clk=~clk;
    reg up=1'b1, down=1'b1, clear=1'b1, load_n=1'b1;
    reg [3:0] d=4'h0;
    wire [3:0] qe, qs, qe2, qs2;
    wire ce, be, cs, bs, ce2, be2, cs2, bs2;
    // Stage 1 and a second stage clocked by its carry and borrow.
    fonz_74192 e1(.up(up),.down(down),.clear(clear),.load_n(load_n),
        .d(d),.q(qe),.carry_n(ce),.borrow_n(be));
    fonz_74192 e2(.up(ce),.down(be),.clear(clear),.load_n(load_n),
        .d(~d),.q(qe2),.carry_n(ce2),.borrow_n(be2));
    fonz_74192_sync s1(.clk(clk),.up(up),.down(down),.clear(clear),
        .load_n(load_n),.d(d),.q(qs),.carry_n(cs),.borrow_n(bs));
    fonz_74192_sync s2(.clk(clk),.up(cs),.down(bs),.clear(clear),
        .load_n(load_n),.d(~d),.q(qs2),.carry_n(cs2),.borrow_n(bs2));
    integer i, errors=0, seed=20;
    integer r;
    initial begin
        // Hold CLR for two clocks first: at time 0 the event model sees UP
        // rise from its initial history and counts once; the sync cell does
        // not. Neither is a board behaviour, so both start from a clear.
        repeat (2) @(negedge clk);
        clear=1'b0;
        for (i=0;i<200000;i=i+1) begin
            @(negedge clk);
            r=$random(seed) & 255;
            // Mostly counting; occasional direction swap, load and clear.
            if (r<90) up=~up;
            else if (r<170) down=~down;
            else if (r<176) load_n=~load_n;
            else if (r<179) clear=~clear;
            else if (r<200) d=$random(seed);
            // Keep loads and clears short so most cycles count.
            if (r>=200 && !load_n) load_n=1'b1;
            if (r>=200 && clear) clear=1'b0;
            @(posedge clk);
            if ({qe,ce,be,qe2,ce2,be2}!=={qs,cs,bs,qs2,cs2,bs2}) begin
                errors=errors+1;
                if (errors<10) $display("cell mismatch at %0d: event %h %b%b %h %b%b, sync %h %b%b %h %b%b",
                    i,qe,ce,be,qe2,ce2,be2,qs,cs,bs,qs2,cs2,bs2);
            end
        end
        $display("cell: %0d cycles, %0d mismatches", i, errors);
        $finish;
    end
endmodule
`default_nettype wire
