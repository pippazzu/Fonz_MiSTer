// SPDX-License-Identifier: GPL-3.0-or-later
// Single-clock (clock-enable) equivalents of the event-model TTL cells in
// fonz_ttl.v, for synthesis on an FPGA.
//
// Convention shared by every cell:
//   * clk_sys is the only clock (48 MHz); every flop is posedge clk_sys.
//   * rst is synchronous and active high; it loads the INIT value.
//   * The chip's own clock pins (clk, clk_a, clk_b) are ordinary level nets.
//     Each cell keeps a one-flop copy of them and acts on the edge it sees,
//     sampling the other inputs (J/K, D, LOAD, ENP/ENT) at that same
//     clk_sys edge.
//   * Clear and set/reset pins are level inputs applied synchronously on
//     every clk_sys edge while they are asserted.
//   * State outputs are registered, so a cell answers one clk_sys after its
//     inputs change, and a ripple chain settles one clk_sys per stage.
// Pin names and port order otherwise match fonz_ttl.v, so a cell can be
// swapped by adding .clk_sys and .rst and the _ce suffix.
`timescale 1ns/1ps
`default_nettype none

module fonz_74161_ce #(parameter [3:0] INIT=4'h0)(
    input wire clk_sys, rst,
    input wire clk, clear_n, load_n, enp, ent,
    input wire [3:0] d,
    output reg [3:0] q=INIT,
    output wire carry
);
    // CK=2, /CLR=1, /LOAD=9, ENP=7, ENT=10;
    // D[0:3]=3,4,5,6; Q[0:3]=14,13,12,11; RCO=15. Rising edge.
    reg clk_l=1'b0;
    wire rise = clk & ~clk_l;
    always @(posedge clk_sys) begin
        clk_l <= clk;
        if (rst) q <= INIT;
        else if (!clear_n) q <= 4'h0;
        else if (rise) begin
            if (!load_n) q <= d;
            else if (enp && ent) q <= q + 4'h1;
        end
    end
    assign carry = ent & (&q);
endmodule

module fonz_74107_ce #(parameter INIT=1'b0)(
    input wire clk_sys, rst,
    input wire clk, clear_n, j, k,
    output reg q=INIT,
    output wire q_n
);
    // Half A: J=1, CK=12, K=4, /CLR=13, Q=3, /Q=2.
    // Half B: J=8, CK=9, K=11, /CLR=10, Q=5, /Q=6. Falling edge.
    reg clk_l=1'b0;
    wire fall = ~clk & clk_l;
    always @(posedge clk_sys) begin
        clk_l <= clk;
        if (rst) q <= INIT;
        else if (!clear_n) q <= 1'b0;
        else if (fall) case ({j,k})
            2'b01: q <= 1'b0;
            2'b10: q <= 1'b1;
            2'b11: q <= ~q;
            default: q <= q;
        endcase
    end
    assign q_n = ~q;
endmodule

module fonz_74393_half_ce #(parameter [3:0] INIT=4'h0)(
    input wire clk_sys, rst,
    input wire clk, clear,
    output reg [3:0] q=INIT
);
    // Half A: CK=1, CLR=2, Q[0:3]=3,4,5,6.
    // Half B: CK=13, CLR=12, Q[0:3]=11,10,9,8. Falling edge.
    reg clk_l=1'b0;
    wire fall = ~clk & clk_l;
    always @(posedge clk_sys) begin
        clk_l <= clk;
        if (rst) q <= INIT;
        else if (clear) q <= 4'h0;
        else if (fall) q <= q + 4'h1;
    end
endmodule

module fonz_74390_half_ce(
    input wire clk_sys, rst,
    input wire clk_a, clk_b, clear,
    output reg qa=1'b0,
    output reg [2:0] qdcb=3'b000
);
    // Half A: A=1 B=4 CLR=2 QA=3 QB=5 QC=6 QD=7.
    // Half B: A=15 B=12 CLR=14 QA=13 QB=11 QC=10 QD=9.
    // Divide-by-two and divide-by-five clocks remain SEPARATE as on the IC.
    // When QA is wired to B, the /5 section sees QA's fall one clk_sys late.
    reg a_l=1'b0, b_l=1'b0;
    wire fall_a = ~clk_a & a_l;
    wire fall_b = ~clk_b & b_l;
    always @(posedge clk_sys) begin
        a_l <= clk_a;
        b_l <= clk_b;
        if (rst || clear) begin
            qa <= 1'b0;
            qdcb <= 3'b000;
        end else begin
            if (fall_a) qa <= ~qa;
            if (fall_b) qdcb <= qdcb == 3'd4 ? 3'b000 : qdcb + 3'b001;
        end
    end
endmodule

module fonz_74153_ce(
    input wire clk_sys, rst,
    input wire a, b, g1_n, g2_n,
    input wire [3:0] c1, c2,
    output wire y1, y2
);
    // A=14 B=2 /G1=1 /G2=15 Y1=7 Y2=9.
    // C1[0:3]=6,5,4,3; C2[0:3]=10,11,12,13.
    // Combinational, as on the chip; clk_sys and rst are unused and exist
    // only so every _ce cell has the same leading ports.
    assign y1 = ~g1_n & c1[{b,a}];
    assign y2 = ~g2_n & c2[{b,a}];
endmodule

module fonz_74279_ce #(parameter INIT=1'b0)(
    input wire clk_sys, rst,
    input wire r_n, s1_n, s2_n,
    output reg q=INIT
);
    // NAND SR latch, registered so there is no combinational loop.
    // Set wins when /S and /R are both low (output HIGH, as in the 74279
    // truth table); with neither asserted the latch holds.
    always @(posedge clk_sys)
        if (rst) q <= INIT;
        else if (!s1_n || !s2_n) q <= 1'b1;
        else if (!r_n) q <= 1'b0;
endmodule

module fonz_prom_ce #(parameter AW=8, parameter HEXFILE="")(
    input wire clk_sys, rst,
    input wire [AW-1:0] a,
    input wire enable_n,
    output wire [3:0] q
);
    // Synchronous read so the table maps to block RAM. q follows the
    // address one clk_sys later. Board pull-ups resolve the disabled
    // open-collector outputs high.
    reg [3:0] mem[0:(1<<AW)-1];
    initial if (HEXFILE != "") $readmemh(HEXFILE,mem);
    reg [3:0] data=4'hf;
    always @(posedge clk_sys) data <= mem[a];
    reg en_l=1'b0;
    always @(posedge clk_sys) en_l <= ~enable_n;
    assign q = en_l ? data : 4'hf;
endmodule

`default_nettype wire
