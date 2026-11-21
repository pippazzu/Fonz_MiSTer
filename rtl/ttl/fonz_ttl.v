// SPDX-License-Identifier: GPL-3.0-or-later
// Ideal TTL functional models for a schematic transcription, not a retimed
// FPGA implementation. Pin numbers in callers refer to the original packages.
// INIT is a simulation/power-up convenience, NOT an extra PCB reset connection.
// Clocked cells act only on a clean 0->1 or 1->0 clock edge. The x->0 and
// x->1 changes every net makes at time 0 are not edges: counting them gave
// the event model power-up counts the single-clock board cannot match
// (sim/board_equiv).
`timescale 1ns/1ps
`default_nettype none

module fonz_74161 #(parameter [3:0] INIT=4'h0)(
    input wire clk, clear_n, load_n, enp, ent,
    input wire [3:0] d,
    output reg [3:0] q=INIT,
    output wire carry
);
    // CK=2, /CLR=1, /LOAD=9, ENP=7, ENT=10;
    // D[0:3]=3,4,5,6; Q[0:3]=14,13,12,11; RCO=15.
    reg clk_was=1'bx;
    always @(clk) clk_was <= clk;
    initial #0.001 clk_was = clk; // a clock that never changes at time 0
    always @(posedge clk or negedge clear_n)
        if (!clear_n) q <= 4'h0;
        else if (clk_was !== 1'b0) q <= q;
        else if (!load_n) q <= d;
        else if (enp && ent) q <= q + 4'h1;
    assign carry = ent & (&q);
endmodule

module fonz_74107 #(parameter INIT=1'b0)(
    input wire clk, clear_n, j, k,
    output reg q=INIT,
    output wire q_n
);
    // Half A: J=1, CK=12, K=4, /CLR=13, Q=3, /Q=2.
    // Half B: J=8, CK=9, K=11, /CLR=10, Q=5, /Q=6.
    reg clk_was=1'bx;
    always @(clk) clk_was <= clk;
    initial #0.001 clk_was = clk; // a clock that never changes at time 0
    always @(negedge clk or negedge clear_n)
        if (!clear_n) q <= 1'b0;
        else if (clk_was !== 1'b1) q <= q;
        else case ({j,k})
            2'b00: q <= q;
            2'b01: q <= 1'b0;
            2'b10: q <= 1'b1;
            2'b11: q <= ~q;
            default: q <= 1'bx;
        endcase
    assign q_n = ~q;
endmodule

module fonz_74393_half #(parameter [3:0] INIT=4'h0)(
    input wire clk, clear,
    output reg [3:0] q=INIT
);
    // Half A: CK=1, CLR=2, Q[0:3]=3,4,5,6.
    // Half B: CK=13, CLR=12, Q[0:3]=11,10,9,8.
    reg clk_was=1'bx;
    always @(clk) clk_was <= clk;
    initial #0.001 clk_was = clk; // a clock that never changes at time 0
    always @(negedge clk or posedge clear)
        if (clear) q <= 4'h0;
        else if (clk_was === 1'b1) q <= q + 4'h1;
endmodule

module fonz_74390_half(
    input wire clk_a, clk_b, clear,
    output reg qa=1'b0,
    output reg [2:0] qdcb=3'b000
);
    // Half A: A=1 B=4 CLR=2 QA=3 QB=5 QC=6 QD=7.
    // Half B: A=15 B=12 CLR=14 QA=13 QB=11 QC=10 QD=9.
    // Divide-by-two and divide-by-five clocks remain SEPARATE as on the IC.
    reg a_was=1'bx, b_was=1'bx;
    always @(clk_a) a_was <= clk_a;
    always @(clk_b) b_was <= clk_b;
    initial #0.001 begin a_was = clk_a; b_was = clk_b; end
    always @(negedge clk_a or posedge clear)
        if (clear) qa <= 1'b0; else if (a_was === 1'b1) qa <= ~qa;
    always @(negedge clk_b or posedge clear)
        if (clear) qdcb <= 3'b000;
        else if (b_was !== 1'b1) qdcb <= qdcb;
        else if (qdcb == 3'd4) qdcb <= 3'b000;
        else qdcb <= qdcb + 3'b001;
endmodule

module fonz_74192(
    input wire up, down, clear, load_n,
    input wire [3:0] d,
    output reg [3:0] q=4'h0,
    output wire carry_n, borrow_n
);
    // UP=5 DOWN=4 CLR=14 /LOAD=11; A,B,C,D=15,1,10,9;
    // QA,QB,QC,QD=3,2,6,7; /CARRY=12 /BORROW=13.
    // An event model is intentional: a 74192 has two independent clocks.
    // This cell is not advertised as a synthesizable single-clock register.
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
    // Idle-high history, as in fonz_74192_sync: an UP or DOWN pin that
    // settles high at time 0 is not a count.
    reg previous_up=1'b1, previous_down=1'b1;
    always @(up or down or clear or load_n or d) begin
        if (clear) q = 4'h0;
        else if (!load_n) q = d;
        else if (up && !previous_up && down) q = count_up(q);
        else if (down && !previous_down && up) q = count_down(q);
        previous_up = up;
        previous_down = down;
    end
    // /CARRY decodes QA&QD only (low at 9, 11, 13, 15); /BORROW decodes 0.
    assign carry_n = ~(q[0] & q[3] & ~up);
    assign borrow_n = ~((q == 4'd0) & ~down);
endmodule

module fonz_74153(
    input wire a, b, g1_n, g2_n,
    input wire [3:0] c1, c2,
    output wire y1, y2
);
    // A=14 B=2 /G1=1 /G2=15 Y1=7 Y2=9.
    // C1[0:3]=6,5,4,3; C2[0:3]=10,11,12,13.
    assign y1 = ~g1_n & c1[{b,a}];
    assign y2 = ~g2_n & c2[{b,a}];
endmodule

module fonz_7442(input wire [3:0] dcba, output wire [9:0] y_n);
    // A=15 B=14 C=13 D=12. Decimal 0..9 outputs active LOW.
    genvar k;
    generate for(k=0;k<10;k=k+1) begin: decode
        assign y_n[k] = dcba != k;
    end endgenerate
endmodule

module fonz_74279(input wire r_n, s1_n, s2_n, output reg q=1'b0);
    // NAND SR latch. The 74279 truth table gives HIGH with /S and /R both
    // low. Releasing both simultaneously has no guaranteed hardware result;
    // this zero-delay functional model retains the last output in that case.
    // The two-set sections use both S pins.
    always @(r_n or s1_n or s2_n) begin
        if (!s1_n || !s2_n) q = 1'b1;
        else if (!r_n) q = 1'b0;
    end
endmodule

module fonz_7448(input wire [3:0] dcba,
                  input wire rbi_n, bi_n, lt_n,
                  output reg [6:0] abcdefg,
                  output wire rbo_n);
    // TI SDLS111, table T2: pin5 is RBI, NOT unconditional blanking.
    // Pin4 is the wired-AND BI/RBO node; bi_n is its external driver.
    // rbo_n=1 means this IC releases that open-collector node.
    assign rbo_n = !(lt_n && !rbi_n && (dcba == 4'd0));
    always @* begin
        if (!bi_n) abcdefg=7'b0000000;
        else if (!lt_n) abcdefg=7'b1111111;
        else if (!rbi_n && dcba == 4'd0) abcdefg=7'b0000000;
        else case(dcba)
            0: abcdefg=7'b1111110; 1: abcdefg=7'b0110000;
            2: abcdefg=7'b1101101; 3: abcdefg=7'b1111001;
            4: abcdefg=7'b0110011; 5: abcdefg=7'b1011011;
            // Original 7448 font has no upper tail on 6 or lower tail on 9.
            6: abcdefg=7'b0011111; 7: abcdefg=7'b1110000;
            8: abcdefg=7'b1111111; 9: abcdefg=7'b1110011;
           10: abcdefg=7'b0001101;11: abcdefg=7'b0011001;
           12: abcdefg=7'b0100011;13: abcdefg=7'b1001011;
           14: abcdefg=7'b0001111;15: abcdefg=7'b0000000;
            default: abcdefg=7'bxxxxxxx;
        endcase
    end
endmodule

// The load port is not part of the board. It fills the PROM from the MRA
// download (see rtl/fonz_prom_load.v): prom_load={we,addr[10:0],data[3:0]},
// and this PROM takes the addresses BASE..BASE+2**AW-1 of that stream.
// Define FONZ_NO_PROM_INIT for builds that must not carry the dumps.
module fonz_prom #(parameter AW=8, parameter HEXFILE="", parameter [10:0] BASE=0)(
    input wire [AW-1:0] a,
    input wire enable_n,
    output wire [3:0] q,
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
