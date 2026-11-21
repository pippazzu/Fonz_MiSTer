// SPDX-License-Identifier: GPL-3.0-or-later
// Single-clock 74192 for FPGA use. Same pins as fonz_74192.
`timescale 1ns/1ps
`default_nettype none
module fonz_74192_sync(
    input wire clk,
    input wire up, down, clear, load_n,
    input wire [3:0] d,
    output wire [3:0] q,
    output wire carry_n, borrow_n
);
    // UP=5 DOWN=4 CLR=14 /LOAD=11; A,B,C,D=15,1,10,9;
    // QA,QB,QC,QD=3,2,6,7; /CARRY=12 /BORROW=13.
    //
    // clk is a free-running system clock, not a board signal. The UP and
    // DOWN pins are sampled on every clk edge; a rising edge between the
    // previous sample and now is applied to q combinationally in the same
    // cycle, as are CLR and /LOAD. q therefore equals what the zero-delay
    // event model shows at each sample, and a carry or borrow that clocks a
    // following counter (IC69 -> IC91, IC76 -> IC75) settles in the same clk.
    //
    // /CARRY and /BORROW decode q_next, so a cascade sees the same edges as
    // in the event model. A net that takes a flag back to this counter's own
    // CLR or /LOAD would therefore be a combinational loop; the board has
    // one (timer IC75/76 /BORROW -> IC82 -> IC61 -> IC81 -> /LOAD) and it is
    // cut by registering IC82.13 where the board is retimed
    // (docs/74192_SYNC.md).
    //
    // Requirement: each input changes at most once per clk period. A pulse
    // shorter than one clk on UP, DOWN, CLR or /LOAD can be missed.
    // Next state from the TI SDLS074 logic diagram (T flip-flops):
    // up   TA=1, TB=QA&~QD, TC=QA&QB, TD=QA&QB&QC | QA&QD
    // down TA=1, TB=~QA&(QB|QC|QD), TC=~QA&~QB&(QC|QD), TD=~QA&~QB&~QC
    // This gives 0..9 as BCD and, for loaded values 10..15,
    // up 10>11>6, 12>13>4, 14>15>2; down 15>14>13>12>11>10>9.
    function [3:0] count_up(input [3:0] v);
        count_up = v ^ {(v[0]&v[1]&v[2]) | (v[0]&v[3]), v[0]&v[1], v[0]&~v[3], 1'b1};
    endfunction
    function [3:0] count_down(input [3:0] v);
        count_down = v ^ {~v[0]&~v[1]&~v[2], ~v[0]&~v[1]&(v[2]|v[3]),
                          ~v[0]&(v[1]|v[2]|v[3]), 1'b1};
    endfunction
    reg [3:0] q_reg=4'h0;
    // Idle-high history: a pin tied or resting high does not count at start.
    reg up_prev=1'b1, down_prev=1'b1;
    reg [3:0] q_next;
    wire up_rise   = up & ~up_prev;
    wire down_rise = down & ~down_prev;
    always @* begin
        if (clear) q_next = 4'h0;
        else if (!load_n) q_next = d;
        else if (up_rise && down) q_next = count_up(q_reg);
        else if (down_rise && up) q_next = count_down(q_reg);
        else q_next = q_reg;
    end
    always @(posedge clk) begin
        q_reg <= q_next;
        up_prev <= up;
        down_prev <= down;
    end
    assign q = q_next;
    // /CARRY decodes QA&QD only (low at 9, 11, 13, 15); /BORROW decodes 0.
    assign carry_n = ~(q_next[0] & q_next[3] & ~up);
    assign borrow_n = ~((q_next == 4'd0) & ~down);
endmodule
`default_nettype wire
