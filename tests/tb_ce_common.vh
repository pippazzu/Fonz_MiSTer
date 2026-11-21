// Shared harness for the single-clock cell comparisons.
// Stimulus changes on the falling edge of clk_sys; the event-model cell
// reacts at once, the _ce cell at the next rising edge. Outputs are compared
// on the following falling edge, just before the next stimulus change.
// Each step changes at most one input, as a TTL clock pin never moves in
// the same instant as the data it samples.
`ifndef STEPS
`define STEPS 200000
`endif
`ifndef SEED
`define SEED 1
`endif
reg clk_sys=1'b0;
always #10.4167 clk_sys = ~clk_sys;   // 48 MHz
reg rst=1'b1;
integer seed=`SEED, step, errors=0, pick;
task automatic check(input [63:0] ev, input [63:0] ce, input [255:0] what);
    if (ev !== ce) begin
        errors = errors + 1;
        if (errors <= 10)
            $display("MISMATCH step %0d %0s: event=%h ce=%h", step, what, ev, ce);
    end
endtask
task automatic finish(input [255:0] name);
    begin
        if (errors == 0) $display("PASS %0s: %0d random steps", name, `STEPS);
        else $display("FAIL %0s: %0d mismatches", name, errors);
        $finish;
    end
endtask
