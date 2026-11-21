`timescale 1ns/1ps
`default_nettype none
module tb_ce_74393;
`include "tb_ce_common.vh"
reg clk=0, clear=1;
wire [3:0] q_ev, q_ce;
fonz_74393_half ev(.clk(clk),.clear(clear),.q(q_ev));
fonz_74393_half_ce ce(.clk_sys(clk_sys),.rst(rst),.clk(clk),.clear(clear),.q(q_ce));
initial begin
    repeat(4) @(negedge clk_sys); rst=0;
    for (step=0; step<`STEPS; step=step+1) begin
        @(negedge clk_sys);
        check(q_ev,q_ce,"q");
        pick = $unsigned($random(seed)) % 10;
        case (pick)
            0: clear = ($unsigned($random(seed)) % 16) == 0;
            1,2,3,4,5,6,7: clk = ~clk;
            default: ;
        endcase
    end
    finish("74393 half");
end
endmodule
