// SPDX-License-Identifier: GPL-3.0-or-later
// Both 74192 cells against the next-state table worked out by hand from the
// TI SDLS074 logic diagram (docs/74192_SYNC.md), all 16 states, both ways.
`timescale 1ns/1ps
`default_nettype none
module tb_states;
    reg clk=1'b0;
    always #35 clk=~clk;
    reg up=1'b1, down=1'b1, load_n=1'b1;
    reg [3:0] d=4'h0;
    wire [3:0] qe, qs;
    wire ce, be, cs, bs;
    fonz_74192 e(.up(up),.down(down),.clear(1'b0),.load_n(load_n),
        .d(d),.q(qe),.carry_n(ce),.borrow_n(be));
    fonz_74192_sync s(.clk(clk),.up(up),.down(down),.clear(1'b0),
        .load_n(load_n),.d(d),.q(qs),.carry_n(cs),.borrow_n(bs));
    reg [3:0] up_next [0:15];
    reg [3:0] down_next [0:15];
    integer v, errors=0;
    initial begin
        for (v=0;v<9;v=v+1) up_next[v]=v+1;
        up_next[9]=0;  up_next[10]=11; up_next[11]=6; up_next[12]=13;
        up_next[13]=4; up_next[14]=15; up_next[15]=2;
        down_next[0]=9;
        for (v=1;v<16;v=v+1) down_next[v]=v-1;
        for (v=0;v<16;v=v+1) begin
            // Load v, then one UP pulse; the carry is checked while UP is low.
            @(negedge clk) begin d=v; load_n=1'b0; end
            @(negedge clk) load_n=1'b1;
            @(negedge clk) up=1'b0;
            @(posedge clk)
                if (ce!==!(v[0]&v[3]) || cs!==ce) begin
                    errors=errors+1; $display("carry at %0d: event %b sync %b", v, ce, cs);
                end
            @(negedge clk) up=1'b1;
            @(posedge clk)
                if (qe!==up_next[v] || qs!==up_next[v]) begin
                    errors=errors+1; $display("up from %0d: event %0d sync %0d", v, qe, qs);
                end
            @(negedge clk) begin d=v; load_n=1'b0; end
            @(negedge clk) load_n=1'b1;
            @(negedge clk) down=1'b0;
            @(posedge clk)
                if (be!==(v!=0) || bs!==be) begin
                    errors=errors+1; $display("borrow at %0d: event %b sync %b", v, be, bs);
                end
            @(negedge clk) down=1'b1;
            @(posedge clk)
                if (qe!==down_next[v] || qs!==down_next[v]) begin
                    errors=errors+1; $display("down from %0d: event %0d sync %0d", v, qe, qs);
                end
        end
        $display("states: 16 states up and down, %0d errors", errors);
        $finish;
    end
endmodule
`default_nettype wire
