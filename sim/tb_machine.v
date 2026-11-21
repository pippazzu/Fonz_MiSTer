// SPDX-License-Identifier: GPL-3.0-or-later
// The whole machine as the MiSTer core runs it (rtl/mister/fonz_machine_fpga.v):
// the single-clock board with every synthesisable timing model, on the
// core's 57.22 MHz clock. Writes the core's video output, one grey value a
// pixel (454 x 261 a frame, blanking included), as
// build/frames/machine_NNN.pgm, and checks that
//   - the raster is 454 pixels x 261 lines, with sync and blanking;
//   - the picture has no X and is not blank in the active area;
//   - the road (IC102 pin 13) shows on most active lines.
// Options: +frames=N (default 3), +coin=F (insert a coin in frame F), +accel
// (hold full throttle), +pin3mv=N (hold IC105 pin 3 at N mV), +outdir=DIR.
//
//   iverilog -g2012 -I rtl/analog -DFONZ_CLK_SYS_HZ=57220000 -o build/tb_machine \
//       sim/tb_machine.v rtl/mister/*.v rtl/fpga/*.v rtl/analog/fonz_*.v \
//       rtl/ttl/*.v rtl/fonz_cabinet_inputs.v rtl/fonz_accel_input.v \
//       rtl/fonz_throttle.v && vvp -n build/tb_machine +frames=3
`timescale 1ns/1ps
`default_nettype none
module tb_machine;
    localparam integer CLK_HZ = 57_220_000;
    localparam real HALF_NS = 1.0e9 / CLK_HZ / 2.0;
    localparam integer W = 454, H = 261;

    reg clk = 1'b0;
    always #(HALF_NS) clk = ~clk;
    reg rst = 1'b1;

    integer frames = 3, coin_frame = -1, frame = 0, pin3mv = 0;
    reg accel = 1'b0, coin = 1'b0;
    reg [8*128-1:0] outdir;

    wire ce_pix, ce_xtal, ce_xtal2, hs, vs, hb, vb;
    wire [7:0] grey;
    wire [8:0] raster_h, raster_v;
    wire [15:0] rumble;

    fonz_machine_fpga #(.CLK_SYS_HZ(CLK_HZ)) dut(
        .clk_sys(clk), .rst(rst),
        .pad_left(1'b0), .pad_right(1'b0), .pad_accel(accel),
        .pad_coin(coin), .pad_start(1'b0), .pad_tilt(1'b0),
        .joytrig(16'd0), .joyana_l(16'd0), .joyana_r(16'd0), .stick_sel(2'd0),
        .overlay_enable(1'b1), .rumble_enable(1'b1), .pots(40'd0), .prom_load(16'd0),
        .ce_pix(ce_pix), .ce_xtal(ce_xtal), .ce_xtal2(ce_xtal2), .grey(grey),
        .hs(hs), .vs(vs), .hb(hb), .vb(vb),
        .raster_h(raster_h), .raster_v(raster_v), .rumble(rumble));

    reg [7:0] img [0:W*H-1];
    integer x = 0, y = 0, i, fd, errors = 0;
    integer lit, road_lines, pix_in_line, max_x = 0, lines_seen = 0;
    reg vs_l = 1'b0, hs_l = 1'b0, road_this_line = 1'b0;
    reg [8*160-1:0] name;

    task write_frame;
        begin
            $sformat(name, "%0s/machine_%03d.pgm", outdir, frame);
            fd = $fopen(name, "wb");
            $fwrite(fd, "P5\n%0d %0d\n255\n", W, H);
            for (i = 0; i < W*H; i = i + 1) $fwrite(fd, "%c", img[i]);
            $fclose(fd);
        end
    endtask

    always @(posedge clk) if (!rst && ce_pix) begin
        if (hs && !hs_l) begin
            if (x > max_x) max_x = x;
            if (road_this_line) road_lines = road_lines + 1;
            road_this_line = 1'b0;
            x = 0; y = y + 1; lines_seen = lines_seen + 1;
        end
        hs_l = hs;
        if (vs && !vs_l) begin
            if (frame > 0) begin
                write_frame;
                $display("frame %0d: %0d lines, %0d samples a line, %0d lit samples, road on %0d lines, time %0d%0d score %0d%0d%0d%0d",
                         frame, lines_seen, max_x, lit, road_lines,
                         dut.board.core.time_tens, dut.board.core.time_units,
                         dut.board.core.score_thousands, dut.board.core.score_hundreds,
                         dut.board.core.score_tens, dut.board.core.score_units);
                if (lines_seen != H) begin
                    $display("FAIL: frame %0d has %0d lines", frame, lines_seen); errors = errors + 1;
                end
                if (max_x != W) begin
                    $display("FAIL: frame %0d has %0d samples a line", frame, max_x); errors = errors + 1;
                end
                if (lit == 0) begin
                    $display("FAIL: frame %0d is blank", frame); errors = errors + 1;
                end
                if (frame > 2 && road_lines < 150) begin
                    $display("FAIL: frame %0d shows the road on %0d lines", frame, road_lines); errors = errors + 1;
                end
            end
            frame = frame + 1;
            y = 0; lit = 0; road_lines = 0; lines_seen = 0; max_x = 0;
            for (i = 0; i < W*H; i = i + 1) img[i] = 8'd0;
            if (frame == coin_frame) coin = 1'b1;
            if (frame == coin_frame + 1) coin = 1'b0;
            if (frame > frames) begin
                if (errors == 0) $display("PASS: %0d machine frames written to %0s", frames, outdir);
                else $display("FAIL: %0d errors", errors);
                $finish;
            end
        end
        vs_l = vs;
        if (x < W && y < H) img[y*W + x] = grey;
        if (^grey === 1'bx) begin
            if (errors < 5) $display("FAIL: X on the video at x=%0d y=%0d", x, y);
            errors = errors + 1;
        end
        if (!hb && !vb && grey != 0) lit = lit + 1;
        if (!hb && !vb && dut.IC102_pin13_ROAD) road_this_line = 1'b1;
        x = x + 1;
    end

    initial begin
        if (!$value$plusargs("frames=%d", frames)) frames = 3;
        if (!$value$plusargs("coin=%d", coin_frame)) coin_frame = -1;
        if ($test$plusargs("accel")) accel = 1'b1;
        if (!$value$plusargs("outdir=%s", outdir)) outdir = "build/frames";
        lit = 0; road_lines = 0;
        // +pin3mv=N holds IC105 pin 3 (the throttle's control voltage) at
        // N mV, to see the player's bike at a set speed without waiting
        // for C77
        if ($value$plusargs("pin3mv=%d", pin3mv)) force dut.TR10_IC105_pin3_mv = pin3mv[12:0];
        repeat (20) @(posedge clk);
        rst = 1'b0;
    end
endmodule
`default_nettype wire
