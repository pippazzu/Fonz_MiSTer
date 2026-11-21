`timescale 1ns/1ps
`default_nettype none
module tb_ce_74153;
`include "tb_ce_common.vh"
reg a=0, b=0, g1_n=0, g2_n=0; reg [3:0] c1=0, c2=0;
wire y1_ev, y2_ev, y1_ce, y2_ce;
fonz_74153 ev(.a(a),.b(b),.g1_n(g1_n),.g2_n(g2_n),.c1(c1),.c2(c2),.y1(y1_ev),.y2(y2_ev));
fonz_74153_ce ce(.clk_sys(clk_sys),.rst(rst),.a(a),.b(b),.g1_n(g1_n),.g2_n(g2_n),.c1(c1),.c2(c2),.y1(y1_ce),.y2(y2_ce));
initial begin
    repeat(4) @(negedge clk_sys); rst=0;
    for (step=0; step<`STEPS; step=step+1) begin
        @(negedge clk_sys);
        check(y1_ev,y1_ce,"y1"); check(y2_ev,y2_ce,"y2");
        {a,b,g1_n,g2_n} = $random(seed); c1 = $random(seed); c2 = $random(seed);
        #1 check(y1_ev,y1_ce,"y1 same instant"); check(y2_ev,y2_ce,"y2 same instant");
    end
    finish("74153");
end
endmodule
