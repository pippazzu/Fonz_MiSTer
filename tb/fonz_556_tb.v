// SPDX-License-Identifier: GPL-3.0-or-later
// Unit test for fonz_556_half / fonz_556_timers.
// One clock = one ce tick = 10 us. Edge times are compared against the
// RC formulas: charge from a to b toward Vcc takes tau*ln((1-a)/(1-b)),
// discharge from b to a toward 0 takes tau*ln(b/a), in fractions of Vcc.
//
//   iverilog -g2005 -o build/tb_556 tb/fonz_556_tb.v rtl/analog/fonz_556.v \
//            rtl/analog/fonz_556_timers.v && vvp build/tb_556
`timescale 1ns/1ps
`default_nettype none
module fonz_556_tb;
    localparam integer CE_HZ_I = 100_000;
    localparam real CE_HZ = 100.0e3;
    localparam real TOL   = 0.005;   // 0.5 %

    reg clk = 1'b0;
    always #5 clk = ~clk;
    integer t = 0;                   // ticks since start
    always @(posedge clk) t <= t + 1;

    reg        ic99_reset_n = 1'b1;
    reg        ic105_6 = 1'b1;
    reg [31:0] vctl105 = 32'h5555_5555;
    wire ic98_5, ic99_5, ic99_9, ic105_5, ic105_9;

    fonz_556_timers #(.CE_HZ(CE_HZ_I)) dut (
        .clk(clk), .ce(1'b1),
        .IC30_pin12_IC99_pin4_pin10(ic99_reset_n),
        .IC25_pin12_IC105_pin6(ic105_6),
        .TR10_IC105_pin3(vctl105), .vr10_code(3'd0),
        .IC98_pin5_IC84_pin4(ic98_5), .IC99_pin5_IC100_pin9(ic99_5),
        .IC99_pin9_IC84_pin5(ic99_9),
        .IC105_pin5_THROTTLE(ic105_5), .IC105_pin9_IC82_pin8(ic105_9));

    integer errors = 0;

    task check(input [8*40-1:0] name, input real got_s, input real want_s);
        real rel;
        begin
            rel = (got_s - want_s) / want_s;
            if (rel < 0) rel = -rel;
            $display("%-36s got %9.5f s  want %9.5f s  (%0.3f %%) %s",
                     name, got_s, want_s, rel * 100.0, rel <= TOL ? "ok" : "FAIL");
            if (rel > TOL) errors = errors + 1;
        end
    endtask

    // Astable: first high (0 -> 2/3), then low (2/3 -> 1/3), then high
    // (1/3 -> 2/3) and the full period.
    task astable(input [8*24-1:0] name, input real ra, input real rb, input real c,
                 input integer rise0, input integer fall0, input integer rise1,
                 input integer fall1);
        real tc, td;
        begin
            tc = (ra + rb) * c;
            td = rb * c;
            check({name, " first high"}, (fall0 - rise0) / CE_HZ, tc * $ln(3.0));
            check({name, " low"},        (rise1 - fall0) / CE_HZ, td * $ln(2.0));
            check({name, " high"},       (fall1 - rise1) / CE_HZ, tc * $ln(2.0));
        end
    endtask

    // Edge capture: first two rising and falling edges of each astable.
    integer r[0:3][0:1], f[0:3][0:1], nr[0:3], nf[0:3];
    reg [3:0] prev = 4'b0;
    wire [3:0] now = {ic105_9, ic99_9, ic99_5, ic98_5};
    integer i;
    initial for (i = 0; i < 4; i = i + 1) begin nr[i] = 0; nf[i] = 0; end
    always @(posedge clk) begin
        for (i = 0; i < 4; i = i + 1) begin
            if (now[i] & ~prev[i] & nr[i] < 2) begin r[i][nr[i]] = t; nr[i] = nr[i] + 1; end
            if (~now[i] & prev[i] & nf[i] < 2) begin f[i][nf[i]] = t; nf[i] = nf[i] + 1; end
        end
        prev <= now;
    end

    // IC105A pulse width capture.
    integer p_rise = -1, p_width = -1, p_count = 0;
    reg p_prev = 1'b0;
    always @(posedge clk) begin
        if (ic105_5 & ~p_prev) p_rise = t;
        if (~ic105_5 & p_prev) begin p_width = t - p_rise; p_count = p_count + 1; end
        p_prev <= ic105_5;
    end

    // One-tick trigger on IC105 pin 6 every 1667 ticks (about one frame).
    integer frame_ticks = 1667;
    always @(posedge clk)
        ic105_6 <= ((t % frame_ticks) != 100);

    real v_at_reset, v_after;
    integer k, saw_high;
    initial begin
        // ---- astables from power-up, and IC105A at 2/3 Vcc ----
        repeat (1600000) @(posedge clk);   // 16 s
        $display("-- astables from power-up (cap discharged) --");
        for (k = 0; k < 4; k = k + 1)
            if (nr[k] < 2 || nf[k] < 2) begin
                $display("astable %0d: too few edges (%0d rises, %0d falls) FAIL", k, nr[k], nf[k]);
                errors = errors + 1;
            end
        if (errors == 0) begin
            astable("IC98A  (Q5)",  220.0e3, 220.0e3, 4.7e-6,  r[0][0], f[0][0], r[0][1], f[0][1]);
            astable("IC99A  (Q5)",  220.0e3, 470.0e3, 10.0e-6, r[1][0], f[1][0], r[1][1], f[1][1]);
            astable("IC99B  (Q9)",  100.0e3, 220.0e3, 10.0e-6, r[2][0], f[2][0], r[2][1], f[2][1]);
            astable("IC105B (Q9)",  81.06e3, 68.0e3,  4.7e-6,  r[3][0], f[3][0], r[3][1], f[3][1]);
            check("IC105B period (70 s / 99)", (f[3][1] - f[3][0]) / CE_HZ, 70.0 / 99.0);
        end

        $display("-- IC105A monostable --");
        check("IC105A width, Vctl 2/3", p_width / CE_HZ, 56.0e3 * 0.15e-6 * $ln(3.0));
        // TR10 off: R109 1k to +5 V against the internal 3.33k/3.33 V -> 4.615 V.
        vctl105 = 32'h7623_B13B; // 4.6154 V / 5 V * 2^31
        p_count = 0;
        wait (p_count == 3);
        check("IC105A width, Vctl 4.615", p_width / CE_HZ,
              56.0e3 * 0.15e-6 * $ln(5.0 / (5.0 - 4.6154)));
        // Pulse longer than a frame: the trigger arriving while OUT is high
        // is ignored, so it fires every other frame.
        p_count = 0;
        k = t;
        wait (p_count == 4);
        check("IC105A repeat, 2 frames", (t - k) / CE_HZ / 4.0, 2.0 * frame_ticks / CE_HZ);

        // ---- IC99 reset (IC30 /Q12) ----
        $display("-- IC99 reset --");
        wait (ic99_9 == 1'b1);
        @(posedge clk);
        ic99_reset_n = 1'b0;
        v_at_reset = dut.v99b;
        @(posedge clk); @(posedge clk);
        if (ic99_5 !== 1'b0 || ic99_9 !== 1'b0) begin
            $display("reset: outputs not low FAIL"); errors = errors + 1;
        end else $display("reset: both IC99 outputs low          ok");
        saw_high = 0;
        repeat (100000) begin @(posedge clk); if (ic99_5 | ic99_9) saw_high = 1; end
        v_after = dut.v99b;
        // 1 s through R44 220k into C32 10uF: v falls by exp(-1/2.2).
        check("IC99B cap, 1 s in reset", v_after / v_at_reset, $exp(-1.0 / 2.2));
        if (saw_high) begin $display("reset: output went high FAIL"); errors = errors + 1; end
        ic99_reset_n = 1'b1;
        repeat (1000000) begin @(posedge clk); if (ic99_9) saw_high = 1; end
        if (!saw_high) begin $display("release: IC99B never restarted FAIL"); errors = errors + 1; end
        else $display("release: IC99B oscillates again       ok");

        if (errors == 0) $display("PASS");
        else $display("FAIL: %0d check(s)", errors);
        $finish;
    end
endmodule
`default_nettype wire
