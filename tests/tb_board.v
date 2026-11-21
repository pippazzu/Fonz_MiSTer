// SPDX-License-Identifier: GPL-3.0-or-later
// Board test bench: runs fonz_board from the 14.305 MHz crystal with the
// stand-in timing models of tests/models/standins.v and the contact and
// edge conditioning of rtl/fonz_input_conditioning.v, samples the three mixer
// outputs once per pixel clock at the raster position given by the board's
// own counters, and writes one PGM per frame.
//
// Each image is the whole raster, blanking included: 454 columns (H, from
// IC4A Q, IC46, IC68) by 261 rows (V, from IC3A Q, IC2, IC24). Grey is the
// conductance-weighted sum of the three outputs into the mixer (R13 1k on
// IC5.11, R26 470 ohm on IC7.8, VR13+R3 taken as 2k on IC7.12), a high
// output counting as lit. That is a stand-in for the resistor mixer of
// rtl/fonz_video_mixer.v, not a monitor voltage.
//
// Plusargs:
//   +frames=N     frames to write (default 3)
//   +outdir=DIR   output directory, must exist (default build/frames)
//   +coin=F       drop a coin at the start of frame F
//   +accel        hold the accelerator switch
//   +left/+right  hold the handlebar left or right
// It prints one FRAME line per image, then PASS, or FAIL when a sample is
// X or Z, the raster position leaves 454 x 261, the video never lights, or
// no frame completes in time.
// Compile-time parameter SLOW divides every timer longer than 1 ms, so
// the crash, start and game timers fit in a short run (default 1, real time).
`timescale 1ns/1ps
`default_nettype none
module tb_board;
    parameter real SLOW=1.0;
    localparam integer H_TOTAL=454, V_TOTAL=261;
    localparam real HALF_PERIOD=1.0e9/14.305e6/2.0;   // ns

    // ---- Cabinet inputs (idle levels from docs/CONTROLS.md) ----
    reg xtal=1'b0;
    reg accel=1'b0,left=1'b0,right=1'b0,tilt=1'b0;
    reg coin_no=1'b1,coin_nc=1'b0;   // ic38_1, ic38_13
    reg antenna=1'b0;
    reg ac_sense=1'b0;               // ic37_10, mains sense, 60 Hz
    always #(HALF_PERIOD) xtal=~xtal;
    always #(1.0e9/120.0) ac_sense=~ac_sense;

    // ---- Board ----
    wire ic5_11,ic7_8,ic7_12;
    wire [5:0] digit_enable;
    wire [6:0] segments_abcdefg;
    wire [2:0] ic9a_abc,ic9b_abc,ic106a_abc,ic106b_abc;
    wire [2:0] ic97a_abc,ic97b_abc,ic102a_abc,ic102b_abc,ic104a_abc,ic104b_abc;
    wire [2:0] ic30a_abc,ic30b_abc,ic103a_abc,ic103b_abc;
    wire ic9_5,ic9_13,ic106_5,ic106_13;
    wire ic97_5,ic97_13,ic102_5,ic102_13,ic104_5,ic104_13;
    wire ic30_5,ic30_13,ic103_5,ic103_13;
    wire ic105_5,ic105_9;
    wire ic98_4,ic99_4,ic105_4,ic105_6,ic105_10,ic99_10;
    wire ic38_3,ic38_8,ic38_11,ic59_2,ic83_9,ic83_13,ic83_4;
    // Contacts through their RC networks (fonz_contact_conditioning).
    // accel/left/right/tilt are closures; the connector wires are 1 at rest.
    // coin_no/coin_nc are already connector levels (1 at rest on 21).
    wire IC37_pin12_ACCEL,IC37_pin6_LEFT,IC37_pin4_RIGHT,IC37_pin2_IC82_pin2;
    wire R93_C60_IC38_pin1,R91_C59_IC38_pin13;
    fonz_contact_conditioning contacts(
        .CN16_IC37_pin13(!accel),.CN17_IC37_pin5(!left),
        .CN18_IC37_pin3(!right),.CN1_IC37_pin1(!tilt),
        .CN21_IC38_pin1(coin_no),.CN20_IC38_pin13(coin_nc),
        .IC37_pin12_ACCEL(IC37_pin12_ACCEL),.IC37_pin6_LEFT(IC37_pin6_LEFT),
        .IC37_pin4_RIGHT(IC37_pin4_RIGHT),.IC37_pin2_IC82_pin2(IC37_pin2_IC82_pin2),
        .R93_C60_IC38_pin1(R93_C60_IC38_pin1),.R91_C59_IC38_pin13(R91_C59_IC38_pin13));
    wire [3:0] time_tens,time_units,score_units,score_tens,score_hundreds,score_thousands;
    // IC98 and IC99 only feed the analogue control nets (IC94.1, IC100.9,
    // IC84.4/5), which the stand-ins ignore. Their outputs are held low.
    wire ic98_5=1'b0,ic99_9=1'b0,ic99_5=1'b0;

    // The PROMs keep their $readmemh contents; no MRA download here.
    fonz_board dut(
        .prom_clk(1'b0),.prom_load(16'h0000),
        .ic45_8(xtal),.ic37_12(IC37_pin12_ACCEL),.ic37_6(IC37_pin6_LEFT),
        .ic37_4(IC37_pin4_RIGHT),.ic37_2(IC37_pin2_IC82_pin2),
        .ic37_10(ac_sense),
        .ic105_5(ic105_5),.ic105_9(ic105_9),
        .ic9_5(ic9_5),.ic106_5(ic106_5),.ic9_13(ic9_13),.ic106_13(ic106_13),
        .ic98_5(ic98_5),.ic99_9(ic99_9),.ic99_5(ic99_5),
        .ic97_5(ic97_5),.ic97_13(ic97_13),.ic102_5(ic102_5),.ic102_13(ic102_13),
        .ic104_5(ic104_5),.ic104_13(ic104_13),
        .ic30_13(ic30_13),.ic30_5(ic30_5),
        .ic38_1(R93_C60_IC38_pin1),.ic38_13(R91_C59_IC38_pin13),
        .ic103_13(ic103_13),.ic103_5(ic103_5),.antenna_logic(antenna),
        .ic5_11(ic5_11),.ic7_8(ic7_8),.ic7_12(ic7_12),
        .digit_enable(digit_enable),.segments_abcdefg(segments_abcdefg),
        .ic9a_ab_clear_n(ic9a_abc),.ic9b_ab_clear_n(ic9b_abc),
        .ic106a_ab_clear_n(ic106a_abc),.ic106b_ab_clear_n(ic106b_abc),
        .ic97b_ab_clear_n(ic97b_abc),.ic97a_ab_clear_n(ic97a_abc),
        .ic102b_ab_clear_n(ic102b_abc),.ic102a_ab_clear_n(ic102a_abc),
        .ic104b_ab_clear_n(ic104b_abc),.ic104a_ab_clear_n(ic104a_abc),
        .ic30a_ab_clear_n(ic30a_abc),.ic30b_ab_clear_n(ic30b_abc),
        .ic103a_ab_clear_n(ic103a_abc),.ic103b_ab_clear_n(ic103b_abc),
        .ic17_4(),.ic17_6(),.ic17_8(),.ic39_3(),.ic60_3(),.ic100_10(),
        .ic94_2(),.ic94_4(),.ic94_6(),.ic94_8(),.ic94_10(),.ic94_12(),
        .ic100_2(),.ic100_4(),.ic100_6(),.ic100_8(),.ic17_2(),.ic99_10(ic99_10),
        .ic98_4(ic98_4),.ic99_4(ic99_4),.ic105_4(ic105_4),.ic105_6(ic105_6),.ic105_10(ic105_10),
        .ic38_3(ic38_3),.ic38_11(ic38_11),.ic38_8(ic38_8),.ic59_2(ic59_2),
        .ic83_9(ic83_9),.ic83_13(ic83_13),.ic83_4(ic83_4),.ic101_11(),.ic81_6(),
        .ic82_13(),.ic82_10(),
        .time_tens(time_tens),.time_units(time_units),.score_units(score_units),
        .score_tens(score_tens),.score_hundreds(score_hundreds),.score_thousands(score_thousands));

    // ---- Stand-in timing models. Pin 13 is the A half's Q, pin 5 the B half's. ----
    // Shape oscillators (two 74123 halves each): 70 ns a half, about the
    // 7.15 MHz pixel rate. Real widths follow TR1/P1 and TR9/P6.
    tb_74123_half #(70.0)  ic9a  (.ab_clear_n(ic9a_abc),  .q(ic9_13));
    tb_74123_half #(70.0)  ic9b  (.ab_clear_n(ic9b_abc),  .q(ic9_5));
    tb_74123_half #(70.0)  ic106a(.ab_clear_n(ic106a_abc),.q(ic106_13));
    tb_74123_half #(70.0)  ic106b(.ab_clear_n(ic106b_abc),.q(ic106_5));
    // Road chain, one pass a line: 97B offset, 97A kerb, 102B, 102A road
    // width, 104B, 104A. Variable widths are fixed at mid-screen values.
    tb_74123_half #(15000.0) ic97b (.ab_clear_n(ic97b_abc), .q(ic97_5));
    tb_74123_half #(300.0)   ic97a (.ab_clear_n(ic97a_abc), .q(ic97_13));
    tb_74123_half #(300.0)   ic102b(.ab_clear_n(ic102b_abc),.q(ic102_5));
    tb_74123_half #(20000.0) ic102a(.ab_clear_n(ic102a_abc),.q(ic102_13));
    tb_74123_half #(300.0)   ic104b(.ab_clear_n(ic104b_abc),.q(ic104_5));
    tb_74123_half #(300.0)   ic104a(.ab_clear_n(ic104a_abc),.q(ic104_13));
    // Crash timers: 0.28 R C with R28/C17 and R31/C22.
    tb_74123_half #(0.28*47.0e3*47.0e-6*1.0e9/SLOW)  ic30a(.ab_clear_n(ic30a_abc),.q(ic30_13));
    tb_74123_half #(0.28*47.0e3*220.0e-6*1.0e9/SLOW) ic30b(.ab_clear_n(ic30b_abc),.q(ic30_5));
    // Antenna and start monostables: 47k with 220 uF and 100 uF.
    tb_74123_half #(0.28*47.0e3*220.0e-6*1.0e9/SLOW) ic103a(.ab_clear_n(ic103a_abc),.q(ic103_13));
    tb_74123_half #(0.28*47.0e3*100.0e-6*1.0e9/SLOW) ic103b(.ab_clear_n(ic103b_abc),.q(ic103_5));
    // IC105A: 1.1 R100 C68 with the throttle control voltage left open.
    tb_556_mono #(1.1*56.0e3*0.15e-6*1.0e9/SLOW) ic105a(.trigger_n(ic105_6),.reset_n(ic105_4),.q(ic105_5));
    // IC105B: game-time clock, taken as 1 Hz.
    tb_556_astable #(0.5e9/SLOW,0.5e9/SLOW) ic105b(.reset_n(ic105_10),.q(ic105_9));
    // R67/C44, R76/C51 and R77/C52 are modelled inside fonz_board.

    // ---- Raster position from the board's counters ----
    wire pixel_clock=dut.scene.picture.raster_video.raster.IC67_pin3_PIXEL_CLK;
    wire [8:0] h={dut.scene.picture.raster_video.raster.IC4_pin3_H8,
                  dut.scene.picture.raster_video.raster.IC46_pin14_13_12_11_H,
                  dut.scene.picture.raster_video.raster.IC68_pin14_13_12_11_H};
    wire [8:0] v_count={dut.scene.picture.raster_video.raster.IC3_pin3_V8,
                  dut.scene.picture.raster_video.raster.IC2_pin14_13_12_11_V,
                  dut.scene.picture.raster_video.raster.IC24_pin14_13_12_11_V};
    // The vertical chain shows 261 for the one pixel clock (H=0) in which
    // the IC25.8 decode reloads it; that pixel belongs to line 0.
    wire [8:0] v=(v_count==9'd261)?9'd0:v_count;

    // Grey per 3-bit code {IC7.12, IC7.8, IC5.11}, conductance weighted.
    function [7:0] grey(input [2:0] code);
        real g;
        begin
            g=(code[0]?1.0/1000.0:0.0)+(code[1]?1.0/470.0:0.0)+(code[2]?1.0/2000.0:0.0);
            grey=$rtoi(255.0*g/(1.0/1000.0+1.0/470.0+1.0/2000.0)+0.5);
        end
    endfunction

    reg [7:0] image [0:H_TOTAL*V_TOTAL-1];
    reg [1023:0] outdir;
    integer frames,coin_frame,frame,i,fd,lit5,lit78,lit712,unknown,unknown_total;
    integer bad_position,lit_total;
    reg capturing;
    reg [2:0] code;
    initial begin
        if (!$value$plusargs("frames=%d",frames)) frames=3;
        if (!$value$plusargs("outdir=%s",outdir)) outdir="build/frames";
        if (!$value$plusargs("coin=%d",coin_frame)) coin_frame=-1;
        accel=$test$plusargs("accel");
        left=$test$plusargs("left");
        right=$test$plusargs("right");
        frame=0; capturing=1'b0; unknown_total=0; bad_position=0; lit_total=0;
        lit5=0; lit78=0; lit712=0; unknown=0;
        for (i=0;i<H_TOTAL*V_TOTAL;i=i+1) image[i]=8'd0;
    end

    task write_frame;
        reg [1023:0] name;
        integer x,y;
        begin
            $sformat(name,"%0s/frame_%03d.pgm",outdir,frame);
            fd=$fopen(name,"w");
            if (fd==0) begin $display("FAIL: cannot open %0s (does the directory exist?)",name); $finish; end
            $fwrite(fd,"P2\n# Fonz board frame %0d\n%0d %0d\n255\n",frame,H_TOTAL,V_TOTAL);
            for (y=0;y<V_TOTAL;y=y+1) begin
                for (x=0;x<H_TOTAL;x=x+1)
                    $fwrite(fd,"%0d%s",image[y*H_TOTAL+x],x==H_TOTAL-1?"\n":" ");
            end
            $fclose(fd);
            $display("FRAME %0d t=%0.3fms lit IC5.11=%0d IC7.8=%0d IC7.12=%0d unknown=%0d time=%0d%0d score=%0d%0d%0d%0d game=%b -> %0s",
                frame,$realtime/1.0e6,lit5,lit78,lit712,unknown,time_tens,time_units,
                score_thousands,score_hundreds,score_tens,score_units,ic83_13,name);
            unknown_total=unknown_total+unknown;
            lit_total=lit_total+lit5+lit78+lit712;
            lit5=0; lit78=0; lit712=0; unknown=0;
            for (i=0;i<H_TOTAL*V_TOTAL;i=i+1) image[i]=8'd0;
        end
    endtask

    // Sample half way through each pixel, on the falling pixel clock, so the
    // zero-delay counters and gates have settled after the rising edge.
    always @(negedge pixel_clock) begin
        if (h===9'd0 && v===9'd0) begin
            if (capturing) begin
                write_frame;
                frame=frame+1;
                if (frame==frames) begin
                    if (unknown_total!=0)
                        $display("FAIL: %0d mixer samples were X or Z",unknown_total);
                    if (bad_position!=0)
                        $display("FAIL: %0d samples with H or V unknown or out of range",bad_position);
                    if (lit_total==0)
                        $display("FAIL: the three mixer outputs never went high");
                    if (unknown_total==0 && bad_position==0 && lit_total!=0)
                        $display("PASS: %0d board frames written to %0s, no X on the mixer outputs",
                            frames,outdir);
                    $finish;
                end
            end
            capturing=1'b1;
            if (frame==coin_frame) insert_coin;
        end
        if (capturing) begin
            code={ic7_12,ic7_8,ic5_11};
            if ((^h)===1'bx || (^v)===1'bx || h>=H_TOTAL || v>=V_TOTAL)
                bad_position=bad_position+1;
            else if ((^code)===1'bx) begin
                unknown=unknown+1;
                image[v*H_TOTAL+h]=8'd128;
            end else begin
                image[v*H_TOTAL+h]=grey(code);
                lit5=lit5+code[0]; lit78=lit78+code[1]; lit712=lit712+code[2];
            end
        end
    end

    // Coin switch changeover held for 50 ms, then released.
    task insert_coin;
        fork
            begin
                $display("COIN at frame %0d",frame);
                coin_no=1'b0; coin_nc=1'b1;
                #(50.0e6);
                coin_no=1'b1; coin_nc=1'b0;
            end
        join_none
    endtask

    // Give up if the raster stalls: a frame is 16.6 ms, and the first
    // full one starts after about 16.6 ms.
    initial begin
        #(40.0e6);
        if (!capturing) begin
            $display("FAIL: no frame start (H=0, V=0) in the first 40 ms");
            $finish;
        end
    end
    always @(frame) begin : watchdog
        integer seen;
        seen=frame;
        #(40.0e6);
        if (frame==seen && frame<frames) begin
            $display("FAIL: frame %0d did not complete within 40 ms",frame);
            $finish;
        end
    end
endmodule
`default_nettype wire
