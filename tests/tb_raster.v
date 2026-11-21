// SPDX-License-Identifier: GPL-3.0-or-later
// Raster check: IC67/68/46/4 make 454 pixel clocks a line and
// IC24/2/3 make 261 lines a frame. Run from the repository root.
`timescale 1ns/1ps
`default_nettype none
module tb_raster;
    localparam real XTAL_HALF_NS = 1.0e9 / 14.305e6 / 2.0;
    localparam integer FRAMES = 3;

    reg ic45_8 = 1'b0;
    always #(XTAL_HALF_NS) ic45_8 = ~ic45_8;

    wire ic67_3, ic67_2;
    wire [3:0] ic68_q, ic46_q, ic24_q, ic2_q;
    wire ic4_3, ic4_2, ic4_5, ic4_6, ic3_3, ic3_2, ic3_5, ic3_6;
    wire ic89_8, ic27_8, ic27_11, ic25_8, ic25_12, ic26_10, ic26_12;
    wire ic95_1, ic95_13, ic95_10;
    fonz_raster dut(
        .IC45_pin8_IC67_pin12(ic45_8), .IC67_pin3_PIXEL_CLK(ic67_3), .IC67_pin2_PIXEL_CLK_n(ic67_2),
        .IC68_pin14_13_12_11_H(ic68_q), .IC46_pin14_13_12_11_H(ic46_q), .IC24_pin14_13_12_11_V(ic24_q), .IC2_pin14_13_12_11_V(ic2_q),
        .IC4_pin3_H8(ic4_3), .IC4_pin2_H8_n(ic4_2), .IC4_pin5_HBLANK(ic4_5), .IC4_pin6_HBLANK_n(ic4_6),
        .IC3_pin3_V8(ic3_3), .IC3_pin2_NC(ic3_2), .IC3_pin5_VBLANK(ic3_5), .IC3_pin6_VBLANK_n(ic3_6),
        .IC89_pin8_LINE_END_n(ic89_8), .IC27_pin8_IC4_pin10(ic27_8), .IC27_pin11_HSYNC_n(ic27_11),
        .IC25_pin8_FRAME_END_n(ic25_8), .IC25_pin12_VSYNC_n(ic25_12), .IC26_pin10_IC25_pin2(ic26_10), .IC26_pin12_IC3_pin10(ic26_12),
        .IC95_pin1_LINE_START(ic95_1), .IC95_pin13_IC60_pin5(ic95_13), .IC95_pin10_IC38_pin4(ic95_10));

    // Ninth bits are IC4A Q3 (horizontal) and IC3A Q3 (vertical).
    wire [8:0] h = {ic4_3, ic46_q, ic68_q};
    wire [8:0] v = {ic3_3, ic2_q, ic24_q};

    // Frame boundaries are taken where V becomes 0. The IC24/2/3 load at
    // V=261 is not qualified by H, so V=261 lasts one pixel clock and V=0
    // fills the rest of that line; the period is still 261 lines.
    integer clocks = 0, frame_clocks = 0, lines = 0, errors = 0;
    integer line_count = 0, frame_count = 0;
    integer h_max = 0, v_max = 0;
    reg [8:0] h_prev = 9'd0, v_prev = 9'd0;
    reg seen_line = 1'b0, seen_frame = 1'b0;

    always @(posedge ic67_3) begin
        #1;  // let the counters settle after the edge
        if (^{h, v} === 1'bx) begin
            $display("FAIL: X on raster counters at %0t", $time);
            errors = errors + 1;
        end
        clocks = clocks + 1;
        frame_clocks = frame_clocks + 1;
        if (h > h_max) h_max = h;
        if (v > v_max) v_max = v;
        if (h == 0 && h_prev != 0) begin
            if (seen_line && clocks != 454) begin
                $display("FAIL: line %0d has %0d pixel clocks, expected 454",
                         line_count, clocks);
                errors = errors + 1;
            end
            seen_line = 1'b1;
            clocks = 0;
            line_count = line_count + 1;
            lines = lines + 1;
        end
        if (v == 0 && v_prev != 0) begin
            if (seen_frame && (lines != 261 || frame_clocks != 454*261)) begin
                $display("FAIL: frame %0d has %0d lines and %0d pixel clocks, expected 261 and %0d",
                         frame_count, lines, frame_clocks, 454*261);
                errors = errors + 1;
            end
            seen_frame = 1'b1;
            lines = 0;
            frame_clocks = 0;
            frame_count = frame_count + 1;
        end
        h_prev = h;
        v_prev = v;
        if (frame_count > FRAMES) begin
            if (h_max != 453 || v_max != 261) begin
                $display("FAIL: counter ranges h 0..%0d v 0..%0d, expected 0..453 and 0..261",
                         h_max, v_max);
                errors = errors + 1;
            end
            if (errors == 0)
                $display("PASS: %0d frames of 454 clocks x 261 lines", FRAMES);
            else
                $fatal(1, "FAIL: %0d raster errors", errors);
            $finish;
        end
    end

    initial begin
        #100_000_000;
        $fatal(1, "FAIL: timeout after %0d frames", frame_count);
    end
endmodule
`default_nettype wire
