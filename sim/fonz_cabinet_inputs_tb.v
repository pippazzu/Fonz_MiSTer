// SPDX-License-Identifier: GPL-3.0-or-later
// Pad -> cabinet contacts -> IC38 coin latch.
// Run: iverilog -g2012 -o build/inputs_tb sim/fonz_cabinet_inputs_tb.v \
//        rtl/fonz_cabinet_inputs.v rtl/fonz_game_control.v rtl/ttl/fonz_ttl.v
//      vvp build/inputs_tb
`timescale 1ns/1ps
`default_nettype none
module fonz_cabinet_inputs_tb;
    // 1 MHz, 1 ms coin, 10 us gap: same logic, short run.
    reg clk = 0, rst = 1;
    always #500 clk = ~clk;

    reg left = 0, right = 0, accel = 0, coin = 0, start = 0, tilt = 0;
    wire CN16_IC37_pin13, CN17_IC37_pin5, CN18_IC37_pin3, CN1_IC37_pin1;
    wire CN21_IC38_pin1, CN20_IC38_pin13, CN_X_IC103_pin1;

    fonz_cabinet_inputs #(.CLK_HZ(1_000_000), .COIN_MS(1), .COIN_GAP_US(10)) dut(
        .clk(clk), .rst(rst),
        .pad_left(left), .pad_right(right), .pad_accel(accel),
        .pad_coin(coin), .pad_start(start), .pad_tilt(tilt),
        .CN16_IC37_pin13(CN16_IC37_pin13), .CN17_IC37_pin5(CN17_IC37_pin5),
        .CN18_IC37_pin3(CN18_IC37_pin3), .CN1_IC37_pin1(CN1_IC37_pin1),
        .CN21_IC38_pin1(CN21_IC38_pin1), .CN20_IC38_pin13(CN20_IC38_pin13),
        .CN_X_IC103_pin1(CN_X_IC103_pin1));

    wire IC37_pin12_ACCEL, IC37_pin6_LEFT, IC37_pin4_RIGHT, IC37_pin2_IC82_pin2;
    fonz_contacts_direct cond(
        .CN16_IC37_pin13(CN16_IC37_pin13), .CN17_IC37_pin5(CN17_IC37_pin5),
        .CN18_IC37_pin3(CN18_IC37_pin3), .CN1_IC37_pin1(CN1_IC37_pin1),
        .IC37_pin12_ACCEL(IC37_pin12_ACCEL), .IC37_pin6_LEFT(IC37_pin6_LEFT),
        .IC37_pin4_RIGHT(IC37_pin4_RIGHT), .IC37_pin2_IC82_pin2(IC37_pin2_IC82_pin2));

    // R76/C51 (220 ohm, 680 pF): about 150 ns from IC38 pin 3 to pin 9.
    wire IC38_pin3_COIN_LATCH, IC38_pin11_COIN_LATCH_n, IC38_pin8_COIN;
    wire R76_C51_IC38_pin9;
    assign #150 R76_C51_IC38_pin9 = IC38_pin3_COIN_LATCH;
    fonz_coin_latch latch(
        .CN21_IC38_pin1(CN21_IC38_pin1), .CN20_IC38_pin13(CN20_IC38_pin13), .R76_C51_IC38_pin9(R76_C51_IC38_pin9),
        .IC38_pin3_COIN_LATCH(IC38_pin3_COIN_LATCH), .IC38_pin11_COIN_LATCH_n(IC38_pin11_COIN_LATCH_n),
        .IC38_pin8_COIN(IC38_pin8_COIN));

    integer errors = 0, pulses = 0;
    always @(negedge IC38_pin8_COIN) if (!rst) pulses = pulses + 1;
    // A changeover switch never has both contacts closed.
    always @(CN21_IC38_pin1 or CN20_IC38_pin13)
        if (!CN21_IC38_pin1 && !CN20_IC38_pin13) begin
            $display("FAIL: both coin contacts closed at %t", $time); errors = errors + 1;
        end

    task check(input cond, input [8*48-1:0] what);
        if (!cond) begin $display("FAIL: %0s", what); errors = errors + 1; end
    endtask

    task wait_ms(input integer ms); begin repeat (ms*1000) @(posedge clk); end endtask

    initial begin
        repeat (5) @(posedge clk);
        rst = 0;
        wait_ms(1);

        // Idle cabinet: docs/CONTROLS.md "Idle" column.
        check({IC37_pin12_ACCEL,IC37_pin6_LEFT,IC37_pin4_RIGHT,IC37_pin2_IC82_pin2} == 4'b0000, "idle IC37 outputs low");
        check(CN21_IC38_pin1 == 1 && CN20_IC38_pin13 == 0, "idle coin contacts");
        check(IC38_pin8_COIN == 1 && CN_X_IC103_pin1 == 0, "idle IC38.8 and antenna");

        // Steering and accelerator.
        left = 1; #1;
        check(IC37_pin6_LEFT == 1 && IC37_pin4_RIGHT == 0, "left closes TURN SW LEFT only");
        right = 1; #1;
        check(IC37_pin6_LEFT == 0 && IC37_pin4_RIGHT == 0, "left+right closes neither");
        left = 0; #1;
        check(IC37_pin6_LEFT == 0 && IC37_pin4_RIGHT == 1, "right closes TURN SW RIGHT only");
        right = 0; accel = 1; tilt = 1; #1;
        check(IC37_pin12_ACCEL == 1 && IC37_pin2_IC82_pin2 == 1, "accel and tilt");
        accel = 0; tilt = 0;

        // One coin, button held far longer than the coin pulse.
        pulses = 0;
        @(posedge clk) coin = 1;
        repeat (3) @(posedge clk);
        check(CN20_IC38_pin13 == 1 && CN21_IC38_pin1 == 1, "break before make");
        wait_ms(5);
        coin = 0;
        wait_ms(1);
        check(pulses == 1, "held coin gives one IC38.8 pulse");
        check(CN20_IC38_pin13 == 0 && CN21_IC38_pin1 == 1, "coin switch back at rest");

        // Two separate presses: two coins.
        pulses = 0;
        @(posedge clk) coin = 1; @(posedge clk) coin = 0;
        wait_ms(2);
        @(posedge clk) coin = 1; @(posedge clk) coin = 0;
        wait_ms(2);
        check(pulses == 2, "two presses give two pulses");

        // Start inserts a coin (the cabinet has no start button).
        pulses = 0;
        @(posedge clk) start = 1; @(posedge clk) start = 0;
        wait_ms(2);
        check(pulses == 1, "start gives one coin pulse");

        if (errors == 0) $display("PASS fonz_cabinet_inputs_tb");
        else $display("FAILED: %0d errors", errors);
        $finish;
    end
endmodule
