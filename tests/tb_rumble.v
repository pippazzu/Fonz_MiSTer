// SPDX-License-Identifier: GPL-3.0-or-later
// Crash divider + rumble check. Not original circuitry under test: the
// traced IC96/IC100 divider feeds the MiSTer-only rumble module.
// Run: python scripts/run_tests.py tb_rumble
`timescale 1ns/1ps
`default_nettype none
module tb_rumble;
    reg clk = 0, enable = 1;
    reg IC37_pin10_IC95_pin6 = 0;       // conditioned AC sense
    reg IC30_pin13_CRASH = 0;       // crash latch, high during a crash
    wire IC95_pin4_IC96_pin1, IC100_pin10_SOLENOID;
    wire [3:0] ic96a_q, ic96b_q;
    wire IC17_pin2_CN23 = ~IC30_pin13_CRASH;   // IC17 1->2, 7406
    wire IC30_pin4_CRASH_n = ~IC30_pin13_CRASH; // /Q4 clears both IC96 halves
    wire [15:0] rumble;
    integer fails = 0, kicks = 0, ac_high = 0, kick_len = 0;
    reg large_d = 0;

    always #10 clk = ~clk;              // 50 MHz
    always #8333 IC37_pin10_IC95_pin6 = ~IC37_pin10_IC95_pin6;              // 60 Hz AC sense, scaled 1000x faster

    fonz_crash_divider div(.IC37_pin10_IC95_pin6(IC37_pin10_IC95_pin6), .IC30_pin4_CRASH_n(IC30_pin4_CRASH_n),
        .IC95_pin4_IC96_pin1(IC95_pin4_IC96_pin1), .IC100_pin10_SOLENOID(IC100_pin10_SOLENOID),
        .IC96_pin3_4_5_6(ic96a_q), .IC96_pin11_10_9_8(ic96b_q));
    fonz_rumble dut(.clk(clk), .enable(enable), .IC100_pin10_SOLENOID(IC100_pin10_SOLENOID),
        .IC17_pin2_CN23(IC17_pin2_CN23), .rumble(rumble));

    always @(posedge IC37_pin10_IC95_pin6) if (rumble[15:8] != 0) kick_len = kick_len + 1;
    always @(posedge clk) begin
        if (rumble[15:8] != 0 && !large_d) kicks = kicks + 1;
        if (rumble[15:8] == 0 && large_d) begin
            if (kick_len != 4) begin $display("FAIL kick %0d lasted %0d AC cycles", kicks, kick_len); fails = fails + 1; end
            kick_len = 0;
        end
        large_d <= rumble[15:8] != 0;
    end

    task check(input [15:0] want, input [127:0] what);
        if (rumble !== want) begin $display("FAIL %0s: rumble=%h want %h", what, rumble, want); fails = fails + 1; end
    endtask

    initial begin
        #200000; check(16'h0000, "idle");
        IC30_pin13_CRASH = 1; #1000; check(16'h0060, "crash start");
        #400000;                         // 24 AC cycles: divider has stopped
        check(16'h0060, "crash after kicks");
        if (kicks != 2) begin $display("FAIL %0d solenoid kicks, want 2", kicks); fails = fails + 1; end
        IC30_pin13_CRASH = 0; #1000; check(16'h0000, "crash over");
        enable = 0; IC30_pin13_CRASH = 1; #400000; check(16'h0000, "disabled");
        if (kicks != 2) begin $display("FAIL rumble while disabled"); fails = fails + 1; end
        if (fails == 0) $display("PASS: 2 solenoid kicks of 4 AC cycles, CRUSH buzz, off when disabled");
        $finish;
    end
endmodule
`default_nettype wire
