// Test bench for fonz_accel_input and fonz_throttle.
// Run: python scripts/test_throttle.py   (needs Icarus Verilog)
// One clock is one 1 ms tick (CEN_HZ = TICK_HZ), so seconds are cheap.
`timescale 1ns/1ps
module tb_throttle;
    reg clk = 0, rst = 1, lamp_n = 1, full = 0;
    reg [15:0] joytrig = 0, joyana_l = 0, joyana_r = 0;
    reg [ 1:0] stick_sel = 0;
    reg [12:0] full_mv = 13'd3061;   // VR-11 factory setting
    wire [7:0] demand;
    wire       grip;
    wire [12:0] wiper, vc77, vcv;
    wire [15:0] ib;
    integer errors = 0, d, i, prev, step, maxstep, t;

    always #5 clk = ~clk;

    fonz_accel_input u_in(
        .joytrig(joytrig), .joyana_l(joyana_l), .joyana_r(joyana_r),
        .stick_sel(stick_sel), .full(full), .demand(demand), .grip(grip));

    fonz_throttle #(.CEN_HZ(1000), .TICK_HZ(1000)) u_thr(
        .clk(clk), .rst(rst), .cen(1'b1), .IC39_pin3_R110(lamp_n),
        .demand(demand), .VR11_full_mv(full_mv), .VR11_wiper_R107_mv(wiper), .R107_C77_R108_mv(vc77),
        .R108_TR10_base_na(ib), .TR10_collector_IC105_pin3_mv(vcv));

    task check(input cond, input [8*64-1:0] what);
        if (!cond) begin errors = errors + 1; $display("FAIL: %0s", what); end
    endtask

    task run_ms(input integer n); repeat (n) @(posedge clk); endtask

    initial begin
        // ---- demand selection (combinational) --------------------------
        #1;
        check(demand == 0 && !grip, "idle demand 0");
        joytrig = 16'h8000; #1 check(demand == 8'h80, "R2 half");
        joytrig = 16'h00ff; #1 check(demand == 0, "L2 ignored");
        joytrig = 0; joyana_l = {8'h81, 8'h00}; #1
        check(demand == 0, "stick ignored when stick_sel 0");
        stick_sel = 1; #1 check(demand == 8'hff, "left stick fully up -> 255");
        joyana_l = {8'h40, 8'h00}; #1 check(demand == 0, "left stick down -> 0");
        joyana_l = {8'hc0, 8'h00}; #1 check(demand == 8'h81, "left stick half up (-64) -> 129");
        joytrig = 16'hc000; #1 check(demand == 8'hc0, "max of R2 and stick");
        joytrig = 16'h4000; #1 check(demand == 8'h81, "max of stick and R2");
        stick_sel = 2; joyana_r = {8'h81, 8'h00}; #1 check(demand == 8'hff, "right stick up");
        stick_sel = 3; #1 check(demand == 8'h40, "right stick down sel, stick up -> R2");
        joyana_r = {8'h7f, 8'h00}; #1 check(demand == 8'hff, "right stick down");
        stick_sel = 0; joytrig = 0; full = 1; #1
        check(demand == 8'hff && grip, "full button");
        full = 0; joytrig = 16'h0c00; #1 check(!grip, "grip open at 12");
        joytrig = 16'h0d00; #1 check(grip, "grip closed at 13");
        joytrig = 0;

        // ---- network ---------------------------------------------------
        @(posedge clk); rst = 0;
        run_ms(20000);
        $display("dark: wiper %0d mV, C77 %0d mV, pin3 %0d mV", wiper, vc77, vcv);
        check(vcv > 3890 && vcv < 3910, "pin 3 at rest 3.90 V: wheels 3/4 in above the bottom");

        // R2 pressed but lamp off (attract, crash): no speed
        joytrig = 16'hff00; run_ms(20000);
        check(vcv > 3890 && vcv < 3910, "lamp off: R2 does nothing");

        // Game starts: lamp on, full R2. Speed builds over seconds.
        lamp_n = 0;
        run_ms(300);
        check(vcv < 2500, "full R2 takes pin 3 most of the way within 0.3 s");
        run_ms(20000);
        $display("full R2: wiper %0d mV, C77 %0d mV, Ib %0d nA, pin3 %0d mV",
                 wiper, vc77, ib, vcv);
        check(vcv > 2142 && vcv < 2182, "full R2: pin 3 at 2.16 V, wheels on the drawing's full-grip line");

        // Steady state across the travel: monotonic and smooth.
        prev = vcv; maxstep = 0;
        for (d = 255; d >= 0; d = d - 5) begin
            joytrig = d << 8; run_ms(3000);
            step = vcv - prev;
            if (step < 0) begin
                errors = errors + 1;
                $display("FAIL: pin 3 not monotonic at demand %0d (%0d -> %0d)", d, prev, vcv);
            end
            if (step > maxstep) maxstep = step;
            if (d % 51 == 0) $display("  demand %3d: pin3 %0d mV, Ib %0d nA", d, vcv, ib);
            prev = vcv;
        end
        $display("largest pin 3 step for 5 demand counts: %0d mV", maxstep);
        check(maxstep < 60, "smooth: no step over 60 mV per 5 counts");
        check(vcv > 3890 && vcv < 3910, "released grip returns pin 3 to rest");

        // Crash: lamp goes dark, speed falls away.
        joytrig = 16'hff00; run_ms(10000);
        lamp_n = 1; run_ms(2000);
        check(vcv > 3890 && vcv < 3910, "lamp off returns pin 3 to rest within 2 s");

        // VR-11 at its highest OSD setting (scripts/pot_settings.py): 3898 mV
        // takes pin 3 to about 1.0 V, the bike's wheels about 80 % up the
        // picture; the dark level does not move.
        full_mv = 13'd3898; lamp_n = 0; run_ms(20000);
        $display("VR-11 3898 mV, full R2: pin3 %0d mV", vcv);
        check(vcv > 950 && vcv < 1050, "VR-11 highest: pin 3 near 1.0 V at full grip");
        joytrig = 0; run_ms(20000);
        check(vcv > 3890 && vcv < 3910, "VR-11 highest: rest still 3.90 V");

        if (errors == 0) $display("PASS");
        else $display("FAILED: %0d errors", errors);
        $finish;
    end
endmodule
