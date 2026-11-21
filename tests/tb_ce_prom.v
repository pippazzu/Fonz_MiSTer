`timescale 1ns/1ps
`default_nettype none
module tb_ce_prom;
`include "tb_ce_common.vh"
// Uses a real dump. The _ce PROM reads synchronously, so with stimulus on
// the falling edge its output is valid by the next comparison.
reg [8:0] a=0; reg enable_n=0;
wire [3:0] q_ev, q_ce;
fonz_prom #(.AW(9),.HEXFILE("rom/ic86.86.hex")) ev(.a(a),.enable_n(enable_n),.q(q_ev));
fonz_prom_ce #(.AW(9),.HEXFILE("rom/ic86.86.hex")) ce(.clk_sys(clk_sys),.rst(rst),.a(a),.enable_n(enable_n),.q(q_ce));
initial begin
    repeat(4) @(negedge clk_sys); rst=0;
    for (step=0; step<`STEPS; step=step+1) begin
        @(negedge clk_sys);
        check(q_ev,q_ce,"q");
        a = $random(seed);
        enable_n = ($unsigned($random(seed)) % 8) == 0;
    end
    finish("PROM");
end
endmodule
