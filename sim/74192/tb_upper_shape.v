// SPDX-License-Identifier: GPL-3.0-or-later
// Upper-shape chain trace. Built twice by run.sh: once with the
// event-model fonz_74192 and once with shim_74192_sync.v, which puts the
// single-clock cell behind the same module name. Both runs write the same
// trace format; run.sh compares them.
//
// clk is the 14.305 MHz crystal (IC45.8). Pixel clock = clk/2, 454 pixels a
// line, 261 lines a frame (TRACE.md). The analogue and road inputs are
// stand-ins with the right kind of timing, not models of those circuits:
//  - IC101.6 (/LOAD, IC67B clock, IC9 /CLR): a 2-clk low pulse (R67 220 ohm
//    x C44 680 pF = 150 ns) at a line position that moves pseudo-randomly,
//    on most lines.
//  - IC9.5: a square wave from the IC9 oscillator, held low while IC9 is
//    cleared, half-period 2..5 clk chosen per frame.
//  - IC67.10 (IC27.11) low for the first 16 lines, IC51 clear high for the
//    first 4 lines, IC92 pins 1/2/13 pseudo-random line-rate pulses.
// Stimulus nets carry the board's names (docs/NET_NAMES.md).
// IC101_pin6_ROAD_LOAD_n also reaches IC91.11, IC67.9 and IC9 /CLR;
// IC9_pin5_UPPER_OSC also reaches IC73.1 and IC25.3. IC92.2 is on the
// IC65.6 net (docs/NET_CHECKS.md, corrected from IC27.11).
`timescale 1ns/1ps
`default_nettype none
module tb;
    parameter FRAMES=6;
    parameter OUT="trace.txt";
    localparam LINE=908, LINES=261;
    reg clk=1'b0;
    always #35 clk=~clk;  // 14.29 MHz

    reg IC9_pin5_UPPER_OSC=1'b0, IC27_pin11_HSYNC_n=1'b0, IC83_pin7_ADDR_CLEAR=1'b1, IC101_pin6_ROAD_LOAD_n=1'b1;
    reg IC25_pin12_VSYNC_n=1'b0, IC65_pin6_POS2_LOAD_n=1'b0, IC106_pin5_LOWER_OSC=1'b0;
    wire ic67_6, ic71_7, ic71_9;
    wire [7:0] prom_address;
    wire [3:0] ic69_q, ic91_q, ic51a_q, ic51b_q, ic73a_q, ic73b_q, p15, p1;
    fonz_upper_shape uut(
        .prom_clk(1'b0),.prom_load(16'h0000),
        .IC9_pin5_UPPER_OSC(IC9_pin5_UPPER_OSC),.IC27_pin11_HSYNC_n(IC27_pin11_HSYNC_n),
        .IC83_pin7_ADDR_CLEAR(IC83_pin7_ADDR_CLEAR),.IC101_pin6_ROAD_LOAD_n(IC101_pin6_ROAD_LOAD_n),
        .IC25_pin12_VSYNC_n(IC25_pin12_VSYNC_n),.IC65_pin6_POS2_LOAD_n(IC65_pin6_POS2_LOAD_n),
        .IC106_pin5_LOWER_OSC(IC106_pin5_LOWER_OSC),
        .IC67_pin6_BIT_CLEAR(ic67_6),.IC71_pin7_UPPER_SHAPE1(ic71_7),.IC71_pin9_UPPER_SHAPE2(ic71_9),
        .UPPER_SHAPE_ADDRESS(prom_address),.IC69_pin3_2_6_7(ic69_q),.IC91_pin3_2_6_7(ic91_q),
        .IC51_pin3_4_5_6(ic51a_q),.IC51_pin11_10_9_8(ic51b_q),
        .IC73_pin3_4_5_6(ic73a_q),.IC73_pin11_10_9_8(ic73b_q),
        .IC90_pin13_11_10_9(p15),.IC90_pin3_5_6_7(p1));

    wire ic69_12 = uut.IC69_pin12_CARRY_n, ic91_12 = uut.IC91_pin12_IC47_pin9;
    integer fd, frame, line, h, cycle=0, seed=7, half=3, osc=0;
    integer load_at, p1_at, p2_at, p13_at, loads=0, invalid91=0, carries91=0;
    reg [63:0] last={64{1'b1}};
    wire [63:0] state={ic69_q,ic91_q,ic69_12,ic91_12,prom_address,ic71_7,ic71_9,
        ic67_6,p15,p1,ic73a_q,ic73b_q,ic51a_q,ic51b_q,13'd0};

    // Compare point: rising clk edge, after the falling-edge input change.
    always @(posedge clk) begin
        cycle=cycle+1;
        if (state!==last) begin
            $fdisplay(fd,"%0d %h %h %b %b %h %b %b %b %h %h %h %h %h %h",
                cycle,ic69_q,ic91_q,ic69_12,ic91_12,prom_address,ic71_7,ic71_9,
                ic67_6,p15,p1,ic73a_q,ic73b_q,ic51a_q,ic51b_q);
            last=state;
        end
        if (ic91_q>4'd9) invalid91=invalid91+1;
    end
    always @(negedge ic91_12) carries91=carries91+1;

    initial begin
        fd=$fopen(OUT,"w");
        for (frame=0;frame<FRAMES;frame=frame+1) begin
            half=2+($random(seed)&3);
            for (line=0;line<LINES;line=line+1) begin
                load_at=($random(seed)&511)+100;
                if (($random(seed)&7)==0) load_at=-1; // some lines without a load
                p1_at=$random(seed)&1023; p2_at=$random(seed)&1023;
                p13_at=$random(seed)&1023;
                for (h=0;h<LINE;h=h+1) begin
                    @(negedge clk);
                    IC27_pin11_HSYNC_n = line>=16;
                    IC83_pin7_ADDR_CLEAR = line<4;
                    IC101_pin6_ROAD_LOAD_n = !(h==load_at || h==load_at+1);
                    if (!IC101_pin6_ROAD_LOAD_n) loads=loads+(h==load_at);
                    IC25_pin12_VSYNC_n = h>=p1_at && h<p1_at+40;
                    IC65_pin6_POS2_LOAD_n = (line&3)==1 && h>=p2_at && h<p2_at+20;
                    IC106_pin5_LOWER_OSC = (line%5)==2 && h>=p13_at && h<p13_at+30;
                    // IC9 oscillator: held low by its clear, else free-running.
                    if (!IC101_pin6_ROAD_LOAD_n) begin osc=0; IC9_pin5_UPPER_OSC=1'b0; end
                    else begin
                        osc=osc+1;
                        if (osc>=half) begin osc=0; IC9_pin5_UPPER_OSC=~IC9_pin5_UPPER_OSC; end
                    end
                end
            end
        end
        $fclose(fd);
        $display("upper shape: %0d frames, %0d clk, %0d loads, %0d IC91 carries, %0d clk with IC91 above 9",
            FRAMES,cycle,loads,carries91,invalid91);
        $finish;
    end
endmodule
`default_nettype wire
