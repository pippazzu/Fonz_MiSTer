// SPDX-License-Identifier: GPL-3.0-or-later
// Shape PROM for the single-clock board: combinational read (LUT ROM).
// Hand-written; make_fpga_board.py maps the event model's fonz_prom here
// instead of the registered fonz_prom_ce.
//
// Why not the registered read: the IC71/IC108 74153 selects come straight
// from the same counters that address the PROMs. With a registered read the
// select moves one clk_sys before the data, and for that clk_sys the mux
// shows a bit of the previous word. The equivalence bench caught it as a
// one-sample video glitch (docs/FPGA_BOARD.md). On the board the PROM is
// slower still, and C12/C14/C76/C80 (470 pF) on the 74153 outputs hide the
// glitch. These PROMs are 256 x 4 and 512 x 4, small enough for LUTs.
`timescale 1ns/1ps
`default_nettype none
module fonz_prom_comb #(parameter AW=8, parameter HEXFILE="", parameter [10:0] BASE=0)(
    input wire clk_sys, rst,
    input wire [AW-1:0] a,
    input wire enable_n,
    output wire [3:0] q,
    // MRA download, as in fonz_prom (rtl/ttl/fonz_ttl.v):
    // prom_load={we,addr[10:0],data[3:0]}; this PROM takes BASE..BASE+2**AW-1.
    input wire prom_clk,
    input wire [15:0] prom_load
);
    reg [3:0] mem[0:(1<<AW)-1];
`ifndef FONZ_NO_PROM_INIT
    initial if (HEXFILE != "") $readmemh(HEXFILE,mem);
`endif
    wire [10:0] load_addr=prom_load[14:4];
    wire load_hit=prom_load[15] && (load_addr>>AW)==(BASE>>AW);
    always @(posedge prom_clk) if (load_hit) mem[load_addr[AW-1:0]] <= prom_load[3:0];
    // Board pull-ups resolve the disabled open-collector outputs high.
    assign q = enable_n ? 4'hf : mem[a];
endmodule
`default_nettype wire
