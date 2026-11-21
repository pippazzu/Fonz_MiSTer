// SPDX-License-Identifier: GPL-3.0-or-later
// Test of the score/time overlay (NOT ORIGINAL CIRCUITRY) against the board.
// The board runs from its crystal input. The score counts from the board's
// own IC92 clock; the timer is stepped through its IC105.9 input pin. The
// overlay must show, every frame, what the counters hold.
// The thousands digit has only the IC100.12 A wire, so it shows 0 or 1.
// Writes build/overlay_NN.pgm, one picture of the overlay per checked frame.
`timescale 1ns/1ps
`default_nettype none
module tb_score_overlay;
    reg clk=0;
    always #34.95 clk=~clk;   // 14.305 MHz crystal
    // Cabinet contacts at rest (docs/CONTROLS.md), through the board's own
    // contact networks. Nothing is pressed and no coin is dropped.
    reg accel=1'b0,left=1'b0,right=1'b0,tilt=1'b0;
    reg coin_no=1'b1,coin_nc=1'b0;
    wire IC37_pin12_ACCEL,IC37_pin6_LEFT,IC37_pin4_RIGHT,IC37_pin2_IC82_pin2;
    wire R93_C60_IC38_pin1,R91_C59_IC38_pin13;
    fonz_contact_conditioning contacts(
        .CN16_IC37_pin13(!accel),.CN17_IC37_pin5(!left),
        .CN18_IC37_pin3(!right),.CN1_IC37_pin1(!tilt),
        .CN21_IC38_pin1(coin_no),.CN20_IC38_pin13(coin_nc),
        .IC37_pin12_ACCEL(IC37_pin12_ACCEL),.IC37_pin6_LEFT(IC37_pin6_LEFT),
        .IC37_pin4_RIGHT(IC37_pin4_RIGHT),.IC37_pin2_IC82_pin2(IC37_pin2_IC82_pin2),
        .R93_C60_IC38_pin1(R93_C60_IC38_pin1),.R91_C59_IC38_pin13(R91_C59_IC38_pin13));
    reg ic103_13=0,ic103_5=0,ic105_9=0,ic105_5=0,ic30_5=0,ic30_13=1;
    wire [5:0] digit_enable;
    wire [6:0] segments_abcdefg;
    wire [3:0] tt,tu,su,st,sh,sk;
    wire [8:0] raster_h,raster_v;
    fonz_board board(
        .prom_clk(1'b0),.prom_load(16'h0000),
        .ic45_8(clk),.ic37_12(IC37_pin12_ACCEL),.ic37_6(IC37_pin6_LEFT),
        .ic37_4(IC37_pin4_RIGHT),.ic37_2(IC37_pin2_IC82_pin2),.ic37_10(1'b0),
        .ic105_5(ic105_5),.ic105_9(ic105_9),.ic9_5(1'b0),.ic106_5(1'b0),.ic9_13(1'b0),.ic106_13(1'b0),
        .ic98_5(1'b0),.ic99_9(1'b0),.ic99_5(1'b0),
        .ic97_5(1'b0),.ic97_13(1'b0),.ic102_5(1'b0),.ic102_13(1'b0),.ic104_5(1'b0),.ic104_13(1'b0),
        .ic30_13(ic30_13),.ic30_5(ic30_5),
        .ic38_1(R93_C60_IC38_pin1),.ic38_13(R91_C59_IC38_pin13),
        .ic103_13(ic103_13),.ic103_5(ic103_5),.antenna_logic(1'b0),
        .ic5_11(),.ic7_8(),.ic7_12(),
        .digit_enable(digit_enable),.segments_abcdefg(segments_abcdefg),
        .ic9a_ab_clear_n(),.ic9b_ab_clear_n(),.ic106a_ab_clear_n(),.ic106b_ab_clear_n(),
        .ic97b_ab_clear_n(),.ic97a_ab_clear_n(),.ic102b_ab_clear_n(),.ic102a_ab_clear_n(),
        .ic104b_ab_clear_n(),.ic104a_ab_clear_n(),.ic30a_ab_clear_n(),.ic30b_ab_clear_n(),
        .ic103a_ab_clear_n(),.ic103b_ab_clear_n(),
        .ic17_4(),.ic17_6(),.ic17_8(),.ic39_3(),.ic60_3(),.ic100_10(),
        .ic94_2(),.ic94_4(),.ic94_6(),.ic94_8(),.ic94_10(),.ic94_12(),
        .ic100_2(),.ic100_4(),.ic100_6(),.ic100_8(),.ic17_2(),.ic99_10(),
        .ic98_4(),.ic99_4(),.ic105_4(),.ic105_6(),.ic105_10(),
        .ic38_3(),.ic38_11(),.ic38_8(),.ic59_2(),
        .ic83_9(),.ic83_13(),.ic83_4(),.ic101_11(),.ic81_6(),.ic82_13(),.ic82_10(),
        .time_tens(tt),.time_units(tu),.score_units(su),.score_tens(st),
        .score_hundreds(sh),.score_thousands(sk),
        .raster_h(raster_h),.raster_v(raster_v));
    wire overlay_on;
    wire [41:0] digits;
    fonz_score_overlay overlay(
        .clk(clk),.enable(1'b1),.raster_h(raster_h),.raster_v(raster_v),
        .digit_enable(digit_enable),.segments_abcdefg(segments_abcdefg),
        .overlay_on(overlay_on),.digits_abcdefg(digits));

    // 7448 font, as drawn by the overlay; 4'hf means blank.
    function [3:0] decode(input [6:0] s);
        case(s)
            7'b1111110: decode=0; 7'b0110000: decode=1; 7'b1101101: decode=2;
            7'b1111001: decode=3; 7'b0110011: decode=4; 7'b1011011: decode=5;
            7'b0011111: decode=6; 7'b1110000: decode=7; 7'b1111111: decode=8;
            7'b1110011: decode=9; 7'b0000000: decode=4'hf; default: decode=4'he;
        endcase
    endfunction
    function ok(input [3:0] shown,input [3:0] bcd);
        ok = (shown==bcd) || (shown==4'hf && bcd==0); // RBI may blank a zero
    endfunction

    // One picture of the overlay window per frame (H 0..199, V 0..39).
    reg [7:0] pic [0:199][0:39];
    integer x,y,fd,frame=0,errors=0,checks=0;
    reg [8*32-1:0] name;
    always @(posedge clk) if(raster_h<200 && raster_v<40)
        pic[raster_h][raster_v] <= overlay_on ? 8'd255 : 8'd0;

    // The score can step between two scan slots of one frame, as on the
    // LEDs, so each digit is checked against its counter as it was when the
    // overlay sampled that slot.
    reg [3:0] at_sample [0:5];
    always @(posedge clk) if(overlay.sample) begin
        if(digit_enable[0]) at_sample[0]<=tt;
        if(digit_enable[1]) at_sample[1]<=tu;
        if(digit_enable[2]) at_sample[2]<=su;
        if(digit_enable[3]) at_sample[3]<=st;
        if(digit_enable[4]) at_sample[4]<=sh;
        if(digit_enable[5]) at_sample[5]<=sk;
    end

    task check_frame;
        reg [3:0] d0,d1,d2,d3,d4,d5;
        begin
            d0=decode(digits[6:0]);  d1=decode(digits[13:7]);
            d2=decode(digits[20:14]);d3=decode(digits[27:21]);
            d4=decode(digits[34:28]);d5=decode(digits[41:35]);
            checks=checks+1;
            $display("frame %0d  board time %0d%0d score %0d%0d%0d%0d | overlay time %h%h score %h%h%h%h",
                frame,tt,tu,sk,sh,st,su,d0,d1,d5,d4,d3,d2);
            if(!(ok(d0,at_sample[0])&&ok(d1,at_sample[1])&&ok(d2,at_sample[2])&&ok(d3,at_sample[3])&&
                 ok(d4,at_sample[4])&&ok(d5,{3'b000,at_sample[5][0]}))) begin
                errors=errors+1; $display("  MISMATCH");
            end
            $sformat(name,"build/overlay_%02d.pgm",frame);
            fd=$fopen(name,"w");
            $fwrite(fd,"P2\n200 40\n255\n");
            for(y=0;y<40;y=y+1) begin
                for(x=0;x<200;x=x+1) $fwrite(fd,"%0d ",pic[x][y]);
                $fwrite(fd,"\n");
            end
            $fclose(fd);
        end
    endtask

    // Wait for the end of the scan (V=240), when all six digits were sampled.
    task next_frame;
        begin
            do @(posedge clk); while(!(raster_v==9'd240 && raster_h==9'd0));
            do @(posedge clk); while(raster_v!=9'd241);
            frame=frame+1;
        end
    endtask
    // One timer pulse into IC105.9 (task arguments are copied, so the
    // signal is named directly).
    task timer_pulse;
        begin ic105_9=1; repeat(40) @(posedge clk); ic105_9=0; repeat(40) @(posedge clk); end
    endtask

    integer k,first_score,last_score;
    initial begin
        // Idle game state: IC103A Q13 and IC103B Q5 low. IC37.2 (tilt at rest) low keeps
        // IC82.1 high, so IC83.Q9 stays reset and IC92 passes the IC24.QA
        // line clock; IC30.5 low makes IC27.4 high and opens IC27. The score counts on
        // its own, one step per 256 IC92 pulses (about every two frames).
        next_frame; check_frame;
        first_score=sk*1000+sh*100+st*10+su;
        for(k=0;k<16;k=k+1) begin next_frame; if(k%4==3) check_frame; end
        last_score=sk*1000+sh*100+st*10+su;
        if(last_score<=first_score) begin
            errors=errors+1; $display("FAIL score did not count (%0d -> %0d)",first_score,last_score);
        end
        // A start: an IC103B pulse (Q5 high, /Q12 low) clears the score
        // through IC101.11 and loads the timer preset through IC81.6. After
        // it, each IC105.9 pulse is one countdown step through IC82.10 into
        // IC76.DOWN while the score keeps counting.
        ic103_5=1; repeat(2000) @(posedge clk); ic103_5=0;
        next_frame; check_frame;
        if({tt,tu}!=8'h99) begin errors=errors+1; $display("FAIL timer preset %0d%0d",tt,tu); end
        for(k=0;k<6;k=k+1) begin
            repeat(k%3+1) timer_pulse;
            next_frame; check_frame;
        end
        if({tt,tu}!=8'h87) begin errors=errors+1; $display("FAIL timer at %0d%0d, expected 87",tt,tu); end
        $display("%0d frames checked, %0d mismatches", checks, errors);
        if(errors!=0 || checks==0) $fatal(1,"overlay test failed");
        $display("PASS score overlay");
        $finish;
    end
endmodule
`default_nettype wire
