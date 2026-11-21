`timescale 1ns/1ps
`default_nettype none
module tb_ce_74279;
`include "tb_ce_common.vh"
reg r_n=0, s1_n=1, s2_n=1;
wire q_ev, q_ce;
fonz_74279 ev(.r_n(r_n),.s1_n(s1_n),.s2_n(s2_n),.q(q_ev));
fonz_74279_ce ce(.clk_sys(clk_sys),.rst(rst),.r_n(r_n),.s1_n(s1_n),.s2_n(s2_n),.q(q_ce));
initial begin
    repeat(4) @(negedge clk_sys); rst=0;
    for (step=0; step<`STEPS; step=step+1) begin
        @(negedge clk_sys);
        check(q_ev,q_ce,"q");
        pick = $unsigned($random(seed)) % 4;
        case (pick)
            0: r_n = $random(seed);
            1: s1_n = $random(seed);
            2: s2_n = $random(seed);
            default: ;
        endcase
    end
    finish("74279");
end
endmodule
