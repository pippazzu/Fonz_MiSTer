// SPDX-License-Identifier: GPL-3.0-or-later
// Single-clock stand-in for fonz_rc_edge (rtl/fonz_input_conditioning.v),
// the 220 ohm / 680 pF edge nodes R67/C44, R76/C51 and R77/C52 (
// docs/CONDITIONING.md). Hand-written: make_fpga_board.py maps the event
// model's fonz_rc_edge here.
//
// sense follows drive after RISE_CLK clk_sys for a rising edge (~77 ns on
// the board) and FALL_CLK for a falling one (~189 ns), rounded to whole
// clk_sys: at 48 MHz 4 and 9 (83 and 188 ns), at the core's 57.22 MHz 4 and
// 11 (70 and 192 ns). The clock comes from the FONZ_CLK_SYS_HZ macro
// (default 48 MHz, the equivalence bench); mister/files.qip defines it
// for the core. A drive that turns back before its delay is up is
// dropped, as the RC absorbs a short glitch. The real node keeps a partial
// charge after such a glitch; this counter starts again from zero.
`timescale 1ns/1ps
`default_nettype none
`ifndef FONZ_CLK_SYS_HZ
`define FONZ_CLK_SYS_HZ 48000000
`endif
module fonz_rc_edge_ce #(
    parameter INIT=1'b0,
    parameter integer RISE_CLK=(77*(`FONZ_CLK_SYS_HZ/1000)+500000)/1000000,
    parameter integer FALL_CLK=(189*(`FONZ_CLK_SYS_HZ/1000)+500000)/1000000
)(
    input wire clk_sys, rst,
    input wire drive,
    output reg sense=INIT
);
    reg [3:0] count=4'd0;
    always @(posedge clk_sys)
        if (rst) begin
            sense<=INIT;
            count<=4'd0;
        end else if (drive==sense)
            count<=4'd0;
        else if (count+4'd1>=(drive ? RISE_CLK : FALL_CLK)) begin
            sense<=drive;
            count<=4'd0;
        end else
            count<=count+4'd1;
endmodule
`default_nettype wire
