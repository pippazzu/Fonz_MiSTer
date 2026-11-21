`timescale 1ns/1ps
`default_nettype none
module tb_ce_74107;
`include "tb_ce_common.vh"
reg clk=0, clear_n=0, j=0, k=0;
wire q_ev, q_ce, qn_ev, qn_ce;
fonz_74107 ev(.clk(clk),.clear_n(clear_n),.j(j),.k(k),.q(q_ev),.q_n(qn_ev));
fonz_74107_ce ce(.clk_sys(clk_sys),.rst(rst),.clk(clk),.clear_n(clear_n),.j(j),.k(k),.q(q_ce),.q_n(qn_ce));
initial begin
    repeat(4) @(negedge clk_sys); rst=0;
    for (step=0; step<`STEPS; step=step+1) begin
        @(negedge clk_sys);
        check(q_ev,q_ce,"q"); check(qn_ev,qn_ce,"q_n");
        pick = $unsigned($random(seed)) % 12;
        case (pick)
            0: clear_n = ($unsigned($random(seed)) % 8) != 0;
            1,2: j = $random(seed);
            3,4: k = $random(seed);
            5,6,7,8,9,10: clk = ~clk;
            default: ;
        endcase
    end
    finish("74107");
end
endmodule
