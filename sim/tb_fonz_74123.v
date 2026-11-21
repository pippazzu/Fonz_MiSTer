// SPDX-License-Identifier: GPL-3.0-or-later
// Unit test for rtl/analog/fonz_74123.v.
//   iverilog -g2005 -o build/tb_74123 sim/tb_fonz_74123.v rtl/analog/fonz_74123.v
//   vvp build/tb_74123
// Part 1 checks the function table on the core. Part 2 measures the pulse
// widths of the fixed-R parts on the board against the formula.
`timescale 1ns/1ps
`default_nettype none
module tb_fonz_74123;
    integer errors = 0;

    // ---------------- Part 1: function table, 10 ns clock ----------------
    // Clocks only run while their part of the test needs them, so the
    // seconds-long electrolytic pulses do not drag fast clocks along.
    reg run = 1, run_f = 0;
    reg clk = 0;
    always begin wait (run); #5 clk = ~clk; end
    reg a = 1, b = 1, clr_n = 1;
    wire q, q_n;
    fonz_74123_core #(.W(16)) fn(.clk(clk), .a(a), .b(b), .clr_n(clr_n),
                                   .width(16'd20), .q(q), .q_n(q_n));

    task expect_q(input exp, input [8*40-1:0] what);
        begin
            if (q !== exp || q_n !== ~exp) begin
                errors = errors + 1;
                $display("FAIL %0s: q=%b q_n=%b, expected q=%b", what, q, q_n, exp);
            end else
                $display("ok   %0s", what);
        end
    endtask

    task tick(input integer n); repeat (n) @(posedge clk); endtask

    // Q high time for the core, in clocks, after the stimulus already applied.
    task pulse_len(output integer n);
        begin
            n = 0;
            @(negedge clk);
            while (!q) @(negedge clk);
            while (q) begin n = n + 1; @(negedge clk); end
        end
    endtask

    integer n;

    // ---------------- Part 2: board parts ----------------
    // Fast clock for the 100 pF parts, slow clock for the electrolytics.
    reg clk_f = 0; always begin wait (run_f); #2.5 clk_f = ~clk_f; end   // 200 MHz
    reg clk_s = 0; always #5000  clk_s = ~clk_s;   // 100 kHz
    localparam integer HZ_F = 200_000_000, HZ_S = 100_000;

    reg [12:0] trig = 13'h1fff;   // one A input per part, idle high
    wire [12:0] pq;
    wire [12:0] unused_qn;  // [3:2] unused (IC30 is a dual)
    // IC97A R36=10k C23=100pF; IC104A R80=10k C55=100pF.
    fonz_74123 #(.CLK_HZ(HZ_F), .R_OHM(10_000), .C_PF(100))
        ic97a (.clk(clk_f), .a(trig[0]), .b(1'b1), .clr_n(1'b1), .q(pq[0]), .q_n(unused_qn[0]));
    fonz_74123 #(.CLK_HZ(HZ_F), .R_OHM(10_000), .C_PF(100))
        ic104a(.clk(clk_f), .a(trig[1]), .b(1'b1), .clr_n(1'b1), .q(pq[1]), .q_n(unused_qn[1]));
    // IC30 as a whole package: A = pins 1-3/13, B = pins 9-11/5.
    // IC30A R28=47k C17=47uF; IC30B R31=47k C22=220uF.
    wire IC30_pin4_CRASH_n, IC30_pin12_CRASH_HOLD_n;
    fonz_74123_dual #(.CLK_HZ(HZ_S), .R1_OHM(47_000), .C1_PF(47_000_000),
                        .R2_OHM(47_000), .C2_PF(220_000_000))
        ic30(.clk(clk_s),
             .pin1(trig[2]), .pin2(1'b1), .pin3(1'b1), .pin13(pq[2]), .pin4(IC30_pin4_CRASH_n),
             .pin9(trig[3]), .pin10(1'b1), .pin11(1'b1), .pin5(pq[3]), .pin12(IC30_pin12_CRASH_HOLD_n));
    // IC103A 47k/220uF, IC103B 47k/100uF (TRACE.md analogue table).
    fonz_74123 #(.CLK_HZ(HZ_S), .R_OHM(47_000), .C_PF(220_000_000))
        ic103a(.clk(clk_s), .a(trig[4]), .b(1'b1), .clr_n(1'b1), .q(pq[4]), .q_n(unused_qn[4]));
    fonz_74123 #(.CLK_HZ(HZ_S), .R_OHM(47_000), .C_PF(100_000_000))
        ic103b(.clk(clk_s), .a(trig[5]), .b(1'b1), .clr_n(1'b1), .q(pq[5]), .q_n(unused_qn[5]));

    // want_ns is the data sheet value; tol_pct allows for reading a graph.
    // Data sheet curve points ('LS123 Figure 6 and 7, '123 Figure 4 and page 5).
    fonz_74123 #(.CLK_HZ(HZ_F), .R_OHM(10_000), .C_PF(16))
        ls_10k_16p  (.clk(clk_f), .a(trig[6]),  .b(1'b1), .clr_n(1'b1), .q(pq[6]),  .q_n(unused_qn[6]));
    fonz_74123 #(.CLK_HZ(HZ_F), .R_OHM(20_000), .C_PF(533))
        ls_20k_533p (.clk(clk_f), .a(trig[7]),  .b(1'b1), .clr_n(1'b1), .q(pq[7]),  .q_n(unused_qn[7]));
    fonz_74123 #(.CLK_HZ(HZ_F), .R_OHM(10_000), .C_PF(756))
        ls_10k_756p (.clk(clk_f), .a(trig[8]),  .b(1'b1), .clr_n(1'b1), .q(pq[8]),  .q_n(unused_qn[8]));
    fonz_74123 #(.CLK_HZ(HZ_F), .R_OHM(10_000), .C_PF(1000), .FAMILY_LS(0))
        std_10k_1n  (.clk(clk_f), .a(trig[9]),  .b(1'b1), .clr_n(1'b1), .q(pq[9]),  .q_n(unused_qn[9]));
    fonz_74123 #(.CLK_HZ(HZ_F), .R_OHM(10_000), .C_PF(100), .FAMILY_LS(0))
        std_10k_100p(.clk(clk_f), .a(trig[10]), .b(1'b1), .clr_n(1'b1), .q(pq[10]), .q_n(unused_qn[10]));
    fonz_74123 #(.CLK_HZ(HZ_F), .R_OHM(5_000), .C_PF(0), .FAMILY_LS(0))
        std_5k_0p   (.clk(clk_f), .a(trig[11]), .b(1'b1), .clr_n(1'b1), .q(pq[11]), .q_n(unused_qn[11]));
    fonz_74123 #(.CLK_HZ(HZ_S), .R_OHM(47_000), .C_PF(220_000_000), .FAMILY_LS(0))
        std_47k_220u(.clk(clk_s), .a(trig[12]), .b(1'b1), .clr_n(1'b1), .q(pq[12]), .q_n(unused_qn[12]));

    task measure(input integer i, input [8*24-1:0] name, input real want_ns,
                 input real tol_pct, input real period_ns);
        real t0, t1, got, tol;
        begin
            #(period_ns * 3.3);
            trig[i] = 1'b0;                 // A falling, B high
            wait (pq[i] === 1'b1); t0 = $realtime;
            wait (pq[i] === 1'b0); t1 = $realtime;
            trig[i] = 1'b1;
            got = t1 - t0;
            tol = period_ns + want_ns * tol_pct / 100.0;
            if (got < want_ns - tol || got > want_ns + tol) begin
                errors = errors + 1;
                $display("FAIL %0s: width %0.4g s, data sheet %0.4g s", name, got*1e-9, want_ns*1e-9);
            end else
                $display("ok   %-24s width %0.4g s (data sheet %0.4g s, %+0.1f%%)",
                         name, got*1e-9, want_ns*1e-9, (got-want_ns)/want_ns*100.0);
        end
    endtask

    initial begin
        $display("-- function table (width 20 clocks)");
        tick(3);
        expect_q(0, "idle, no trigger");
        @(negedge clk) a = 0; pulse_len(n);
        if (n != 20) begin errors = errors + 1; $display("FAIL A falling: %0d clocks", n); end
        else $display("ok   A falling with B high: %0d clocks", n);

        @(negedge clk) b = 0; tick(2);
        @(negedge clk) b = 1; pulse_len(n);
        if (n != 20) begin errors = errors + 1; $display("FAIL B rising: %0d clocks", n); end
        else $display("ok   B rising with A low: %0d clocks", n);

        @(negedge clk) clr_n = 0; tick(2);
        expect_q(0, "/CLR low holds Q low");
        @(negedge clk) clr_n = 1; pulse_len(n);
        if (n != 20) begin errors = errors + 1; $display("FAIL /CLR rising: %0d clocks", n); end
        else $display("ok   /CLR rising with A low, B high: %0d clocks", n);

        // No trigger: A falls while B is low.
        @(negedge clk) begin a = 1; b = 0; end tick(2);
        @(negedge clk) a = 0; tick(4);
        expect_q(0, "A falling with B low ignored");
        // No trigger: B rises while A is high.
        @(negedge clk) a = 1; tick(2);
        @(negedge clk) b = 1; tick(4);
        expect_q(0, "B rising with A high ignored");

        // Retrigger: second A edge 12 clocks in gives 12 + 20 = 32.
        @(negedge clk) a = 0;
        @(posedge q); tick(11);
        @(negedge clk) a = 1;
        @(negedge clk) a = 0;
        n = 13;
        while (q) begin n = n + 1; @(negedge clk); end
        if (n < 31 || n > 34) begin errors = errors + 1; $display("FAIL retrigger: %0d clocks", n); end
        else $display("ok   retrigger extends the pulse: %0d clocks", n);

        // /CLR mid-pulse ends it at once (combinational).
        @(negedge clk) a = 1; tick(2);
        @(negedge clk) a = 0;
        @(posedge q); tick(5);
        #1 clr_n = 0; #1;
        expect_q(0, "/CLR low ends the pulse at once");
        @(negedge clk) begin clr_n = 1; a = 1; end

        run = 0; run_f = 1;
        $display("-- 'LS123 board parts (0.495 at 100 pF from Figure 7, 0.33 at >= 1 uF)");
        measure(0,  "IC97A  10k 100pF",  495.0,  1.0, 5.0);
        measure(1,  "IC104A 10k 100pF",  495.0,  1.0, 5.0);
        $display("-- 'LS123 curve points read off Figure 6");
        measure(6,  "LS 10k 16pF",       151.0, 15.0, 5.0);
        measure(7,  "LS 20k 533pF",     4393.0, 10.0, 5.0);
        measure(8,  "LS 10k 756pF",     2876.0, 10.0, 5.0);
        $display("-- '123 (FAMILY_LS=0)");
        measure(9,  "STD 10k 1nF (table)", 3030.0, 3.0, 5.0);
        measure(10, "STD 10k 100pF",     300.0, 10.0, 5.0);
        measure(11, "STD 5k 0pF (tw min)", 45.0, 10.0, 5.0);
        run_f = 0;
        $display("-- 'LS123 electrolytics, tw = 0.33 R C");
        measure(2,  "IC30A  47k 47uF",  0.33*47e3*47e-6*1e9,  0.5, 10000.0);
        measure(3,  "IC30B  47k 220uF", 0.33*47e3*220e-6*1e9, 0.5, 10000.0);
        measure(4,  "IC103A 47k 220uF", 0.33*47e3*220e-6*1e9, 0.5, 10000.0);
        measure(5,  "IC103B 47k 100uF", 0.33*47e3*100e-6*1e9, 0.5, 10000.0);
        measure(12, "STD 47k 220uF",    0.28*47.7e3*220e-6*1e9, 0.5, 10000.0);

        if (errors == 0) $display("PASS");
        else             $display("FAILED: %0d errors", errors);
        $finish;
    end
endmodule
`default_nettype wire
