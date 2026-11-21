// SPDX-License-Identifier: GPL-3.0-or-later
// rtl/mister/fonz_crt_out.v against a stand-in raster with the board's
// timing (454 pixels a line at 7.1525 MHz, 261 lines, HBLANK H=0..79,
// VBLANK V=0..15). Each pixel carries a value made from its line and
// column, so the bench can check that every output line is the previous
// board line, complete and in order. For the native picture and the 3:4
// squeeze it checks:
//   (two frames each)
//   - pixels a line (454 or 807) and ce_out2 at twice ce_out;
//   - 374 active pixels, starting at output pixel 80 or 288;
//   - hsync 32 or 57 pixels wide, starting at output pixel 20 or 36;
//   - 245 active lines, vsync 4 lines wide, 7 lines after VBLANK starts;
//   - the active pixels are the previous board line's, in order.
`timescale 1ns/1ps
`default_nettype none
module tb_crt_out;
    localparam integer CLK_HZ = 57_220_000;
    localparam real HALF_NS = 1.0e9 / CLK_HZ / 2.0;
    reg clk = 1'b0;
    always #(HALF_NS) clk = ~clk;

    // Stand-in raster, registered at ce_pix like the machine's outputs
    reg [31:0] pacc = 32'd0;
    reg ce_pix = 1'b0;
    reg [8:0] h = 9'd0, v = 9'd0;
    reg [7:0] grey_in = 8'd0;
    reg hb_in = 1'b1, vb_in = 1'b1;
    function [7:0] pix(input [8:0] line, input [8:0] col);
        pix = col[7:0] ^ {line[4:0], 3'b101};
    endfunction
    always @(posedge clk) begin
        ce_pix <= 1'b0;
        if (pacc + 7_152_500 >= CLK_HZ) begin
            pacc <= pacc + 7_152_500 - CLK_HZ;
            ce_pix <= 1'b1;
        end else
            pacc <= pacc + 7_152_500;
        if (ce_pix) begin
            if (h == 9'd453) begin
                h <= 9'd0;
                v <= (v == 9'd260) ? 9'd0 : v + 9'd1;
            end else
                h <= h + 9'd1;
            // outputs for the pixel h (as the machine registers them)
            hb_in <= h < 9'd80;
            vb_in <= v < 9'd16;
            grey_in <= (h < 9'd80 || v < 9'd16) ? 8'd0 : pix(v, h - 9'd80);
        end
    end

    reg squeeze = 1'b0;
    wire ce_out, ce_out2, hs, vs, hb, vb;
    wire [7:0] grey;
    fonz_crt_out #(.CLK_HZ(CLK_HZ)) dut(
        .clk(clk), .squeeze(squeeze), .ce_pix(ce_pix), .grey_in(grey_in),
        .hb_in(hb_in), .vb_in(vb_in), .ce_out(ce_out), .ce_out2(ce_out2),
        .grey(grey), .hs(hs), .vs(vs), .hb(hb), .vb(vb));

    // Measure the output, one line at a time (a line starts at hs rising)
    integer errors = 0;
    integer ox = 0, n2 = 0, act_n = 0, act0 = -1, hs0 = -1, hs_w = 0;
    integer lines = 0, act_lines = 0, vs_lines = 0, vs_after_vb = -1, vb_rise_line = -1;
    integer bad_pix = 0, line_px = 0;
    integer src_line = -1, col = 0;
    reg hs_l = 1'b0, vb_l = 1'b0, vs_l = 1'b0, measuring = 1'b0, started = 1'b0;
    integer exp_px, exp_act0, exp_hs0, exp_hsw;

    task end_line;
        begin
            if (measuring && started) begin
                // hs rose at ox = hs0 of the previous line; the line length
                // is the count between hs edges
                if (ox < exp_px - 1 || ox > exp_px + 1) begin
                    if (errors < 5) $display("  line %0d: %0d pixels", lines, ox);
                    errors = errors + 1;
                end
                if (n2 < 2*ox - 2 || n2 > 2*ox + 2) begin
                    if (errors < 5) $display("  line %0d: %0d ce_out2 for %0d ce_out", lines, n2, ox);
                    errors = errors + 1;
                end
                if (act_n != 0) begin
                    act_lines = act_lines + 1;
                    if (act_n != 374 || act0 != exp_act0) begin
                        if (errors < 5) $display("  line %0d: %0d active from %0d", lines, act_n, act0);
                        errors = errors + 1;
                    end
                end
                if (hs_w != exp_hsw) begin
                    if (errors < 5) $display("  line %0d: hsync %0d wide", lines, hs_w);
                    errors = errors + 1;
                end
                if (vs) vs_lines = vs_lines + 1;
                lines = lines + 1;
            end
            started = measuring;
            ox = 0; n2 = 0; act_n = 0; act0 = -1; hs_w = 0;
        end
    endtask

    // ox counts from the hsync start; positions are relative to it
    always @(posedge clk) begin
        if (ce_out2) n2 = n2 + 1;
        if (ce_out) begin
            if (hs && !hs_l) end_line;
            hs_l = hs;
            if (hs) hs_w = hs_w + 1;
            if (!hb && !vb) begin
                if (act_n == 0) begin
                    act0 = ox + exp_hs0;
                    // a board line with this first pixel (lines 32 apart look alike)
                    src_line = -1;
                    for (col = 0; col < 261 && src_line < 0; col = col + 1)
                        if (col >= 16 && pix(col, 0) == grey) src_line = col;
                end
                if (src_line >= 0 && grey !== pix(src_line, act_n)) begin
                    if (bad_pix < 3) $display("    bad: line %0d col %0d got %h want %h", src_line, act_n, grey, pix(src_line, act_n));
                    bad_pix = bad_pix + 1;
                end
                act_n = act_n + 1;
            end
            if (vb && !vb_l) vb_rise_line = lines;
            if (vs && !vs_l && vb_rise_line >= 0) vs_after_vb = lines - vb_rise_line;
            vb_l = vb; vs_l = vs;
            ox = ox + 1;
        end
    end

    task run(input sq, input integer px, input integer a0, input integer h0, input integer hw);
        begin
            squeeze = sq; exp_px = px; exp_act0 = a0; exp_hs0 = h0; exp_hsw = hw;
            measuring = 1'b0;
            #(17_000_000);                  // settle one frame
            lines = 0; act_lines = 0; vs_lines = 0; bad_pix = 0; vs_after_vb = -1; vb_rise_line = -1;
            measuring = 1'b1;
            #(33_132_000);                  // two frames
            measuring = 1'b0;
            $display("  %0s: %0d lines, %0d active, %0d vsync, vsync %0d lines after VBLANK, %0d bad pixels",
                     sq ? "squeeze" : "native", lines, act_lines, vs_lines, vs_after_vb, bad_pix);
            if (lines < 521 || lines > 522) errors = errors + 1;
            if (act_lines < 489 || act_lines > 490) errors = errors + 1;
            if (vs_lines != 8) errors = errors + 1;
            if (vs_after_vb != 7) errors = errors + 1;
            if (bad_pix != 0) errors = errors + 1;
        end
    endtask

    initial begin
        run(1'b0, 454, 80, 20, 32);
        run(1'b1, 807, 288, 36, 57);
        if (errors == 0) $display("PASS: CRT out, native and 3:4 squeeze");
        else $display("FAIL: %0d errors", errors);
        $finish;
    end
endmodule
`default_nettype wire
