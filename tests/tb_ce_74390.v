`timescale 1ns/1ps
`default_nettype none
module tb_ce_74390;
`include "tb_ce_common.vh"
// Two halves: one with independent random A and B clocks, one wired as a
// decade counter (QA -> B) so the one-clk_sys ripple through QA is covered.
reg clk_a=0, clk_b=0, clear=1, dec_clk=0, dec_clear=1;
wire qa_ev, qa_ce, dqa_ev, dqa_ce; wire [2:0] q5_ev, q5_ce, dq5_ev, dq5_ce;
fonz_74390_half ev(.clk_a(clk_a),.clk_b(clk_b),.clear(clear),.qa(qa_ev),.qdcb(q5_ev));
fonz_74390_half_ce ce(.clk_sys(clk_sys),.rst(rst),.clk_a(clk_a),.clk_b(clk_b),.clear(clear),.qa(qa_ce),.qdcb(q5_ce));
fonz_74390_half dev(.clk_a(dec_clk),.clk_b(dqa_ev),.clear(dec_clear),.qa(dqa_ev),.qdcb(dq5_ev));
fonz_74390_half_ce dce(.clk_sys(clk_sys),.rst(rst),.clk_a(dec_clk),.clk_b(dqa_ce),.clear(dec_clear),.qa(dqa_ce),.qdcb(dq5_ce));
// The decade pair needs two clk_sys to ripple, so dec_clk moves every
// other step and its outputs are compared only once the ripple has settled.
reg dec_phase=0;
initial begin
    repeat(4) @(negedge clk_sys); rst=0;
    for (step=0; step<`STEPS; step=step+1) begin
        @(negedge clk_sys);
        check(qa_ev,qa_ce,"qa"); check(q5_ev,q5_ce,"qdcb");
        if (!dec_phase) begin
            check(dqa_ev,dqa_ce,"decade qa"); check(dq5_ev,dq5_ce,"decade qdcb");
        end
        pick = $unsigned($random(seed)) % 10;
        case (pick)
            0: clear = ($unsigned($random(seed)) % 16) == 0;
            1,2,3,4: clk_a = ~clk_a;
            5,6,7,8: clk_b = ~clk_b;
            default: ;
        endcase
        if (dec_phase) dec_phase = 0;
        else begin
            pick = $unsigned($random(seed)) % 8;
            if (pick == 0) begin dec_clear = ($unsigned($random(seed)) % 8) == 0; dec_phase = 1; end
            else if (pick < 6) begin dec_clk = ~dec_clk; dec_phase = 1; end
        end
    end
    finish("74390 half");
end
endmodule
