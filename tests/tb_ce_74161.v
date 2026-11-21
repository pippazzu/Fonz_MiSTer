`timescale 1ns/1ps
`default_nettype none
module tb_ce_74161;
`include "tb_ce_common.vh"
reg clk=0, clear_n=0, load_n=1, enp=1, ent=1; reg [3:0] d=0;
wire [3:0] q_ev, q_ce; wire c_ev, c_ce;
fonz_74161 ev(.clk(clk),.clear_n(clear_n),.load_n(load_n),.enp(enp),.ent(ent),.d(d),.q(q_ev),.carry(c_ev));
fonz_74161_ce ce(.clk_sys(clk_sys),.rst(rst),.clk(clk),.clear_n(clear_n),.load_n(load_n),.enp(enp),.ent(ent),.d(d),.q(q_ce),.carry(c_ce));
initial begin
    repeat(4) @(negedge clk_sys); rst=0;
    for (step=0; step<`STEPS; step=step+1) begin
        @(negedge clk_sys);
        check(q_ev,q_ce,"q"); check(c_ev,c_ce,"carry");
        pick = $unsigned($random(seed)) % 16;
        case (pick)
            0: clear_n = ($unsigned($random(seed)) % 8) != 0;
            1: load_n = ($unsigned($random(seed)) % 4) != 0;
            2: enp = $random(seed);
            3: ent = $random(seed);
            4: d = $random(seed);
            5,6,7,8,9,10,11,12: clk = ~clk;
            default: ;
        endcase
    end
    finish("74161");
end
endmodule
