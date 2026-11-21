// SPDX-License-Identifier: GPL-3.0-or-later
// Test-only stand-in: the fonz_74192 module name and ports, implemented by
// fonz_74192_sync on the test bench clock. Lets the unchanged transcription
// RTL be simulated with the single-clock cell.
`timescale 1ns/1ps
`default_nettype none
module fonz_74192(
    input wire up, down, clear, load_n,
    input wire [3:0] d,
    output wire [3:0] q,
    output wire carry_n, borrow_n
);
    fonz_74192_sync u(.clk(tb.clk),.up(up),.down(down),.clear(clear),
        .load_n(load_n),.d(d),.q(q),.carry_n(carry_n),.borrow_n(borrow_n));
endmodule
`default_nettype wire
