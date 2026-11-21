// SPDX-License-Identifier: GPL-3.0-or-later
// Board test bench for the contact and edge conditioning.
// Drives the cabinet contacts (1 = closed to ground) through
// fonz_contact_conditioning into fonz_board, with contact bounce, and
// checks the timing the RC nodes give the logic.
//
// The board has no start button: a coin starts the game. The coin pulse at
// IC38 pin 8 triggers IC103B, the start monostable. Its real width is about
// a second (47k, 100 uF); STAND_IN_103B_NS is a shortened stand-in until
// the 74123 models exist. All other analogue Q inputs are held idle.
`timescale 1ns/1ps
`default_nettype none
module tb_conditioning;
    localparam real CLOCK_NS=1.0e9/14.305e6/2.0;
    localparam real STAND_IN_103B_NS=20000.0;

    reg clk=1'b0;
    reg sw_accel=0,sw_left=0,sw_right=0,sw_tilt=0,sw_coin_no=0,sw_coin_nc=1;
    reg ic102_5=1'b0;
    reg ic103_5=1'b0;  // IC103B Q, stand-in below
    integer errors=0;

    wire ic37_12,ic37_6,ic37_4,ic37_2,ic38_1,ic38_13;
    // The switches are written as closures (1 = closed) for readability;
    // the connector wires carry the inverse (1 at rest).
    fonz_contact_conditioning contacts(
        .CN16_IC37_pin13(!sw_accel),.CN17_IC37_pin5(!sw_left),
        .CN18_IC37_pin3(!sw_right),.CN1_IC37_pin1(!sw_tilt),
        .CN21_IC38_pin1(!sw_coin_no),.CN20_IC38_pin13(!sw_coin_nc),
        .IC37_pin12_ACCEL(ic37_12),.IC37_pin6_LEFT(ic37_6),
        .IC37_pin4_RIGHT(ic37_4),.IC37_pin2_IC82_pin2(ic37_2),
        .R93_C60_IC38_pin1(ic38_1),.R91_C59_IC38_pin13(ic38_13));

    wire ic5_11,ic7_8,ic7_12;
    wire [5:0] digit_enable;
    wire [6:0] segments_abcdefg;
    wire [2:0] ic9a_ab_clear_n,ic9b_ab_clear_n,ic106a_ab_clear_n,ic106b_ab_clear_n;
    wire [2:0] ic97b_ab_clear_n,ic97a_ab_clear_n,ic102b_ab_clear_n,ic102a_ab_clear_n;
    wire [2:0] ic104b_ab_clear_n,ic104a_ab_clear_n,ic30a_ab_clear_n,ic30b_ab_clear_n;
    wire [2:0] ic103a_ab_clear_n,ic103b_ab_clear_n;
    wire ic17_4,ic17_6,ic17_8,ic39_3,ic60_3,ic100_10;
    wire ic94_2,ic94_4,ic94_6,ic94_8,ic94_10,ic94_12;
    wire ic100_2,ic100_4,ic100_6,ic100_8,ic17_2,ic99_10;
    wire ic98_4,ic99_4,ic105_4,ic105_6,ic105_10;
    wire ic38_3,ic38_11,ic38_8,ic59_2;
    wire ic83_9,ic83_13,ic83_4,ic101_11,ic81_6,ic82_13,ic82_10;
    wire [3:0] time_tens,time_units,score_units,score_tens,score_hundreds,score_thousands;

    fonz_board board(
        .ic45_8(clk),.ic37_12(ic37_12),.ic37_6(ic37_6),.ic37_4(ic37_4),
        .ic37_2(ic37_2),.ic37_10(1'b0),
        .ic105_5(1'b0),.ic105_9(1'b0),.ic9_5(1'b0),.ic106_5(1'b0),.ic9_13(1'b0),.ic106_13(1'b0),
        .ic98_5(1'b0),.ic99_9(1'b0),.ic99_5(1'b0),
        .ic97_5(1'b0),.ic97_13(1'b0),.ic102_5(ic102_5),.ic102_13(1'b0),
        .ic104_5(1'b0),.ic104_13(1'b0),
        .ic30_13(1'b0),.ic30_5(1'b0),
        .ic38_1(ic38_1),.ic38_13(ic38_13),.ic103_13(1'b0),.ic103_5(ic103_5),
        .antenna_logic(1'b0),
        .ic5_11(ic5_11),.ic7_8(ic7_8),.ic7_12(ic7_12),
        .digit_enable(digit_enable),.segments_abcdefg(segments_abcdefg),
        .ic9a_ab_clear_n(ic9a_ab_clear_n),.ic9b_ab_clear_n(ic9b_ab_clear_n),
        .ic106a_ab_clear_n(ic106a_ab_clear_n),.ic106b_ab_clear_n(ic106b_ab_clear_n),
        .ic97b_ab_clear_n(ic97b_ab_clear_n),.ic97a_ab_clear_n(ic97a_ab_clear_n),
        .ic102b_ab_clear_n(ic102b_ab_clear_n),.ic102a_ab_clear_n(ic102a_ab_clear_n),
        .ic104b_ab_clear_n(ic104b_ab_clear_n),.ic104a_ab_clear_n(ic104a_ab_clear_n),
        .ic30a_ab_clear_n(ic30a_ab_clear_n),.ic30b_ab_clear_n(ic30b_ab_clear_n),
        .ic103a_ab_clear_n(ic103a_ab_clear_n),.ic103b_ab_clear_n(ic103b_ab_clear_n),
        .ic17_4(ic17_4),.ic17_6(ic17_6),.ic17_8(ic17_8),.ic39_3(ic39_3),.ic60_3(ic60_3),
        .ic100_10(ic100_10),
        .ic94_2(ic94_2),.ic94_4(ic94_4),.ic94_6(ic94_6),.ic94_8(ic94_8),
        .ic94_10(ic94_10),.ic94_12(ic94_12),
        .ic100_2(ic100_2),.ic100_4(ic100_4),.ic100_6(ic100_6),.ic100_8(ic100_8),
        .ic17_2(ic17_2),.ic99_10(ic99_10),
        .ic98_4(ic98_4),.ic99_4(ic99_4),.ic105_4(ic105_4),.ic105_6(ic105_6),.ic105_10(ic105_10),
        .ic38_3(ic38_3),.ic38_11(ic38_11),.ic38_8(ic38_8),.ic59_2(ic59_2),
        .ic83_9(ic83_9),.ic83_13(ic83_13),.ic83_4(ic83_4),.ic101_11(ic101_11),
        .ic81_6(ic81_6),.ic82_13(ic82_13),.ic82_10(ic82_10),
        .time_tens(time_tens),.time_units(time_units),.score_units(score_units),
        .score_tens(score_tens),.score_hundreds(score_hundreds),.score_thousands(score_thousands));

    always #(CLOCK_NS) clk=~clk;

    // IC103B stand-in: A9 falling edge with B10 and /CLR11 high fires Q5.
    always @(negedge ic103b_ab_clear_n[2])
        if (ic103b_ab_clear_n[1] && ic103b_ab_clear_n[0]) begin
            ic103_5=1'b1;
            #(STAND_IN_103B_NS) ic103_5=1'b0;
        end

    // Low-pulse recorders.
    realtime coin_fall=0.0,coin_width=0.0; integer coin_pulses=0;
    always @(negedge ic38_8) begin coin_fall=$realtime; coin_pulses=coin_pulses+1; end
    always @(posedge ic38_8) coin_width=$realtime-coin_fall;
    realtime road_fall=0.0,road_width=0.0; integer road_pulses=0;
    always @(negedge board.scene.picture.IC101_pin6_ROAD_LOAD_n) begin road_fall=$realtime; road_pulses=road_pulses+1; end
    always @(posedge board.scene.picture.IC101_pin6_ROAD_LOAD_n) road_width=$realtime-road_fall;
    realtime p61_fall=0.0,p61_width=0.0; integer p61_pulses=0;
    wire ic61_8=board.game_and_score.game.IC61_pin8_EXTEND_LOAD_n;
    always @(negedge ic61_8) begin p61_fall=$realtime; p61_pulses=p61_pulses+1; end
    always @(posedge ic61_8) p61_width=$realtime-p61_fall;

    task check(input cond, input [8*64-1:0] what);
        if (cond) $display("PASS %0s", what);
        else begin $display("FAIL %0s", what); errors=errors+1; end
    endtask

    // Close or open a contact with n bounces of b ns each.
    task bounce_coin_no(input value, input integer n, input real b);
        integer k;
        for (k=0;k<n;k=k+1) begin sw_coin_no=value; #(b); sw_coin_no=!value; #(b); end
        sw_coin_no=value;
    endtask
    task bounce_coin_nc(input value, input integer n, input real b);
        integer k;
        for (k=0;k<n;k=k+1) begin sw_coin_nc=value; #(b); sw_coin_nc=!value; #(b); end
        sw_coin_nc=value;
    endtask

    realtime t;
    initial begin
        #10000;
        check(ic37_12===0 && ic37_6===0 && ic37_4===0 && ic37_2===0, "contacts idle low at IC37");
        check(ic38_1===1 && ic38_13===0 && ic38_8===1, "coin idle: IC38.1 high, IC38.13 low, IC38.8 high");

        // Coin: NC opens, 50 us gap, NO closes with bounce; held 5 ms;
        // NO opens, gap, NC closes with bounce.
        bounce_coin_nc(0,3,300.0);
        #50000;
        bounce_coin_no(1,4,200.0);
        #20000;
        check(ic38_3===1 && ic38_11===0, "coin pressed: IC38 latch flipped");
        check(coin_pulses==0, "no coin pulse on press");
        #5000000;
        bounce_coin_no(0,3,300.0);
        #50000;
        bounce_coin_nc(1,4,200.0);
        #20000;
        check(ic38_3===0 && ic38_11===1, "coin released: IC38 latch back");
        check(coin_pulses==1, "exactly one coin pulse at IC38.8");
        $display("     coin pulse width %0.1f ns", coin_width);
        check(coin_width>150.0 && coin_width<230.0, "coin pulse width set by R76/C51");
        check(ic103_5===1, "coin pulse fired the IC103B start stand-in");
        #(STAND_IN_103B_NS);
        // Steering left: close with bounce, IC37.6 goes high about 4 ms later.
        t=$realtime;
        sw_left=1; #1000; sw_left=0; #500; sw_left=1;
        wait(ic37_6===1);
        $display("     left press delay %0.3f ms", ($realtime-t)/1.0e6);
        check(($realtime-t)>3.5e6 && ($realtime-t)<4.5e6, "left press delay (100 ohm, 22 uF, 7414)");
        #2000000;
        t=$realtime;
        sw_left=0;
        wait(ic37_6===0);
        $display("     left release delay %0.3f ms", ($realtime-t)/1.0e6);
        // 2 ms after IC37 switched the capacitor is near 0.44 V, so it
        // recharges to 1.7 V through 610 ohm in about 4.3 ms.
        check(($realtime-t)>4.0e6 && ($realtime-t)<5.5e6, "left release delay (610 ohm, 22 uF, 7414)");

        // A 1 ms tap is absorbed by the RC.
        sw_right=1; #1000000; sw_right=0; #10000000;
        check(ic37_4===0, "1 ms tap on right does not reach IC37.4");

        // Accelerator and tilt reach IC37.12 and IC37.2.
        sw_accel=1; sw_tilt=1; #6000000;
        check(ic37_12===1 && ic37_2===1, "accel and tilt reach IC37.12 and IC37.2");
        sw_accel=0; sw_tilt=0; #8000000;
        check(ic37_12===0 && ic37_2===0, "accel and tilt released");

        // Road: IC101.6 = NAND(IC102.5, R67/C44 node), so its low pulse
        // starts about 77 ns after IC102.5 rises and ends when it falls.
        road_pulses=0;
        ic102_5=1; #2000; ic102_5=0; #2000;
        $display("     road load pulse width %0.1f ns (IC102.5 high 2000 ns)", road_width);
        check(road_pulses==1 && road_width>1890.0 && road_width<1950.0, "IC101.6 leading edge delayed by R67/C44");
        // A 50 ns IC102.5 glitch never reaches the threshold.
        ic102_5=1; #50; ic102_5=0; #2000;
        check(road_pulses==1, "50 ns IC102.5 glitch absorbed by R67/C44");

        // R77/C52 one-shot. IC103B /Q (pin 12) resets IC83A and IC83D while
        // the start pulse runs and releases them when it ends. Then, with
        // IC83.13 and IC82.13 high, IC61.8 falls, sets IC83A, IC59.2 falls
        // and the R77/C52 node ends the pulse. The idle stand-ins never set
        // IC83.13 or IC82.13 (the timer), so both are forced.
        p61_pulses=0;
        ic103_5=1'b1; #1000; ic103_5=1'b0; #1000;
        check(ic83_4===0, "IC103B start pulse cleared IC83A");
        force board.game_and_score.game.ic83d.q=1'b1;
        force board.game_and_score.IC82_pin13_TIME_UP=1'b1;
        #5000;
        release board.game_and_score.game.ic83d.q;
        release board.game_and_score.IC82_pin13_TIME_UP;
        $display("     IC61.8 pulses %0d, width %0.1f ns", p61_pulses, p61_width);
        check(p61_pulses==1 && p61_width>150.0 && p61_width<230.0, "IC61.8 one-shot ended by R77/C52");
        check(ic83_4===1 && ic59_2===0, "IC83A set by the one-shot");

        if (errors) $fatal(1, "%0d failures", errors);
        $display("PASS tb_conditioning: 0 failures");
        $finish;
    end
endmodule
`default_nettype wire
