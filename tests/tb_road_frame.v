// SPDX-License-Identifier: GPL-3.0-or-later
// Road frame test. Runs fonz_board with the road monostable
// model (rtl/analog/fonz_road_timing.v, synthesisable) closing the IC97/102/104 loop,
// and writes the last frame twice, as PGM images of 454 x 261 pixel clocks:
//   build/frames/road_signals.pgm  the road nets themselves: IC20 Q
//       (off road, light grey), IC102 pin 13 (road, dark grey), IC41 pin 3
//       (kerb dashes, white); black elsewhere.
//   build/frames/road_mixer.pgm    the three mixer bits as a 3-bit code
//       (IC7.8 x4 + IC7.12 x2 + IC5.11), not the monitor's grey levels.
//   build/frames/road_debug.raw    one byte a pixel after a PGM header, bits
//       7..0 = IC20.5, IC102.13, IC102.5, IC104.5, IC84.11, IC41.3, IC97.5,
//       IC97.13, for looking at each net on its own.
// Then it checks that, on the active lines, the road is present with the
// left kerb before the road and the right kerb after it, and that the road
// gets wider down the screen.
//
// Everything outside the road stays a crude stand-in, as in tests/tb_board.v:
// shape oscillators are free-running square waves, other timing responses
// idle, contacts released. R67/C44 (220R, 680p) is a 100 ns delay.
//
// Run from the repository root:
//   iverilog -g2012 -o build/tb_road_frame tests/tb_road_frame.v rtl/*.v \
//       rtl/ttl/*.v rtl/analog/*.v && vvp -n build/tb_road_frame
`timescale 1ns/1ps
`default_nettype none
module tb_road_frame #(
    // 74123 family for the road timing: 1 = 'LS123, 0 = standard '123.
    // iverilog -P tb_road_frame.FAMILY_LS=0 to try the standard part.
    parameter integer FAMILY_LS = 1
);
    localparam real XTAL_HALF_NS = 1.0e9 / 14.305e6 / 2.0;
    localparam integer FRAMES = 10;        // control capacitors settle in ~6
    localparam integer HMAX = 454, VMAX = 261;

    reg IC45_pin8 = 1'b0;
    always #(XTAL_HALF_NS) IC45_pin8 = ~IC45_pin8;

    reg ic9_5 = 1'b0, ic9_13 = 1'b0, ic106_5 = 1'b0, ic106_13 = 1'b0;
    always #(1000) ic9_5 = ~ic9_5;
    always #(1130) ic9_13 = ~ic9_13;
    always #(1270) ic106_5 = ~ic106_5;
    always #(1410) ic106_13 = ~ic106_13;

    // Road monostable loop, wires named by both ends.
    wire [2:0] ic97b_ab_clear_n, ic97a_ab_clear_n, ic102b_ab_clear_n,
               ic102a_ab_clear_n, ic104b_ab_clear_n, ic104a_ab_clear_n;
    wire IC97_pin5_IC97_pin1, IC97_pin13_IC102_pin9, IC102_pin5_LEFT_KERB,
         IC102_pin13_ROAD, IC104_pin5_RIGHT_KERB, IC104_pin13_IC20_pin9;
    wire IC100_pin6_TR7, IC100_pin4_C41;

    wire ic5_11, ic7_8, ic7_12;
    wire [5:0] digit_enable;
    wire [6:0] segments_abcdefg;
    wire [3:0] time_tens, time_units, score_units, score_tens,
               score_hundreds, score_thousands;

    fonz_board dut(
        .ic45_8(IC45_pin8),
        .ic37_12(1'b1), .ic37_6(1'b1), .ic37_4(1'b1), .ic37_2(1'b1), .ic37_10(1'b1),
        .ic38_1(1'b1), .ic38_13(1'b1), .antenna_logic(1'b0),
        .ic105_5(1'b0), .ic105_9(1'b0),
        .ic9_5(ic9_5), .ic106_5(ic106_5), .ic9_13(ic9_13), .ic106_13(ic106_13),
        .ic98_5(1'b0), .ic99_9(1'b0), .ic99_5(1'b0),
        .ic97_5(IC97_pin5_IC97_pin1), .ic97_13(IC97_pin13_IC102_pin9),
        .ic102_5(IC102_pin5_LEFT_KERB), .ic102_13(IC102_pin13_ROAD),
        .ic104_5(IC104_pin5_RIGHT_KERB), .ic104_13(IC104_pin13_IC20_pin9),
        .ic30_13(1'b0), .ic30_5(1'b0), .ic103_13(1'b0), .ic103_5(1'b0),
        .ic5_11(ic5_11), .ic7_8(ic7_8), .ic7_12(ic7_12),
        .ic97b_ab_clear_n(ic97b_ab_clear_n), .ic97a_ab_clear_n(ic97a_ab_clear_n),
        .ic102b_ab_clear_n(ic102b_ab_clear_n), .ic102a_ab_clear_n(ic102a_ab_clear_n),
        .ic104b_ab_clear_n(ic104b_ab_clear_n), .ic104a_ab_clear_n(ic104a_ab_clear_n),
        .ic100_6(IC100_pin6_TR7), .ic100_4(IC100_pin4_C41),
        .digit_enable(digit_enable), .segments_abcdefg(segments_abcdefg),
        .time_tens(time_tens), .time_units(time_units),
        .score_units(score_units), .score_tens(score_tens),
        .score_hundreds(score_hundreds), .score_thousands(score_thousands));

    // The synthesisable road model on the crystal for the board's 'LS123s;
    // the real-valued reference when another family is asked for.
    generate if (FAMILY_LS != 0) begin : synth
    fonz_road_timing road_timing(
        .clk(IC45_pin8), .IC3_pin5(dut.scene.IC3_pin5_VBLANK),
        .IC100_pin6(IC100_pin6_TR7), .IC100_pin4(IC100_pin4_C41),
        // The timers are not in this bench: D4 and D5 off, so the road is straight
        .IC94_pin2(1'b0), .IC94_pin6(1'b0), .IC94_pin8(1'b1), .IC100_pin8(1'b0),
        .vr3_code(3'd0), .vr4_code(3'd0), .vr5_code(3'd0), .vr6_code(3'd0), .vr7_code(3'd0), .vr8_code(3'd0),
        .ic97b_ab_clear_n(ic97b_ab_clear_n), .ic97a_ab_clear_n(ic97a_ab_clear_n),
        .ic102b_ab_clear_n(ic102b_ab_clear_n), .ic102a_ab_clear_n(ic102a_ab_clear_n),
        .ic104b_ab_clear_n(ic104b_ab_clear_n), .ic104a_ab_clear_n(ic104a_ab_clear_n),
        .IC97_pin5(IC97_pin5_IC97_pin1), .IC97_pin13(IC97_pin13_IC102_pin9),
        .IC102_pin5(IC102_pin5_LEFT_KERB), .IC102_pin13(IC102_pin13_ROAD),
        .IC104_pin5(IC104_pin5_RIGHT_KERB), .IC104_pin13(IC104_pin13_IC20_pin9),
        .TR5_base_uv(), .TR6_base_uv(), .TR7_base_uv(), .TR8_base_uv());
    end else begin : reference
    fonz_road_timing_ref #(.FAMILY_LS(FAMILY_LS)) road_timing(
        .IC45_pin8(IC45_pin8), .IC3_pin5(dut.scene.IC3_pin5_VBLANK),
        .IC100_pin6(IC100_pin6_TR7), .IC100_pin4(IC100_pin4_C41),
        // The timers are not in this bench: D4 and D5 off, so the road is straight
        .IC94_pin2(1'b0), .IC94_pin6(1'b0), .IC94_pin8(1'b1), .IC100_pin8(1'b0),
        .ic97b_ab_clear_n(ic97b_ab_clear_n), .ic97a_ab_clear_n(ic97a_ab_clear_n),
        .ic102b_ab_clear_n(ic102b_ab_clear_n), .ic102a_ab_clear_n(ic102a_ab_clear_n),
        .ic104b_ab_clear_n(ic104b_ab_clear_n), .ic104a_ab_clear_n(ic104a_ab_clear_n),
        .IC97_pin5(IC97_pin5_IC97_pin1), .IC97_pin13(IC97_pin13_IC102_pin9),
        .IC102_pin5(IC102_pin5_LEFT_KERB), .IC102_pin13(IC102_pin13_ROAD),
        .IC104_pin5(IC104_pin5_RIGHT_KERB), .IC104_pin13(IC104_pin13_IC20_pin9));
    end endgenerate

    wire pixel = dut.scene.IC67_pin3_PIXEL_CLK;
    wire [8:0] h = {dut.scene.IC4_pin3_H8, dut.scene.IC46_pin14_13_12_11_H, dut.scene.IC68_pin14_13_12_11_H};
    wire [8:0] v = {dut.scene.IC3_pin3_V8, dut.scene.IC2_pin14_13_12_11_V, dut.scene.IC24_pin14_13_12_11_V};
    wire off_road = dut.scene.picture.IC20_pin5_IC6_pin1;
    wire road     = IC102_pin13_ROAD;
    wire kerb_any = IC102_pin5_LEFT_KERB | IC104_pin5_RIGHT_KERB;
    wire kerb_dash = dut.scene.picture.IC41_pin3_IC6_pin9;

    reg [7:0] sig_img [0:HMAX*VMAX-1];
    reg [7:0] mix_img [0:HMAX*VMAX-1];
    reg [7:0] dbg_img [0:HMAX*VMAX-1];
    integer frame = 0, errors = 0, i, fd;
    reg [8:0] v_prev = 9'd0;

    // Per-line measurements of the last frame.
    integer road_first [0:VMAX-1];
    integer road_len   [0:VMAX-1];
    integer lk_last    [0:VMAX-1];
    integer rk_first   [0:VMAX-1];
    initial for (i = 0; i < VMAX; i = i + 1) begin
        road_first[i] = -1; road_len[i] = 0; lk_last[i] = -1; rk_first[i] = -1;
    end

    always @(posedge pixel) begin
        #1;
        if (v == 0 && v_prev != 0) frame = frame + 1;
        v_prev = v;
        if (frame == FRAMES && h < HMAX && v < VMAX) begin
            sig_img[v*HMAX+h] = kerb_dash ? 8'd255 : road ? 8'd70 :
                                off_road ? 8'd170 : 8'd0;
            mix_img[v*HMAX+h] = {ic7_8, ic7_12, ic5_11} * 8'd36;
            dbg_img[v*HMAX+h] = {dut.scene.picture.IC20_pin5_IC6_pin1, IC102_pin13_ROAD,
                                 IC102_pin5_LEFT_KERB, IC104_pin5_RIGHT_KERB,
                                 dut.scene.picture.road.IC84_pin11_POSITION_n, kerb_dash,
                                 IC97_pin5_IC97_pin1, IC97_pin13_IC102_pin9};
            if (road === 1'b1) begin
                if (road_first[v] < 0) road_first[v] = h;
                road_len[v] = road_len[v] + 1;
            end
            if (IC102_pin5_LEFT_KERB === 1'b1) lk_last[v] = h;
            if (IC104_pin5_RIGHT_KERB === 1'b1 && rk_first[v] < 0) rk_first[v] = h;
            if (^{ic5_11, ic7_8, ic7_12, road, kerb_any, off_road} === 1'bx) begin
                if (errors < 10) $display("FAIL: X on video or road nets at h=%0d v=%0d", h, v);
                errors = errors + 1;
            end
        end
        if (frame > FRAMES) finish_frame;
    end

    task write_pgm(input [8*64-1:0] name, input integer which);
        begin
            fd = $fopen(name, "wb");
            $fwrite(fd, "P5\n%0d %0d\n255\n", HMAX, VMAX);
            for (i = 0; i < HMAX*VMAX; i = i + 1)
                $fwrite(fd, "%c", which == 2 ? dbg_img[i] : which ? mix_img[i] : sig_img[i]);
            $fclose(fd);
        end
    endtask

    task finish_frame;
        integer line, n_road, top, bottom;
        begin
            write_pgm("build/frames/road_signals.pgm", 0);
            write_pgm("build/frames/road_mixer.pgm", 1);
            write_pgm("build/frames/road_debug.raw", 2);
            n_road = 0; top = -1; bottom = -1;
            for (line = 16; line < VMAX; line = line + 1) begin
                if (road_len[line] > 0) begin
                    n_road = n_road + 1;
                    if (top < 0) top = line;
                    bottom = line;
                    if (!(lk_last[line] >= 0 && lk_last[line] < road_first[line] + 2 &&
                          rk_first[line] >= road_first[line] + road_len[line] - 2)) begin
                        if (errors < 10)
                            $display("FAIL: line %0d kerbs not either side of the road (left kerb ends %0d, road %0d+%0d, right kerb %0d)",
                                     line, lk_last[line], road_first[line], road_len[line], rk_first[line]);
                        errors = errors + 1;
                    end
                end
            end
            for (line = 16; line < VMAX; line = line + 20)
                $display("line %3d: road from h=%0d, %0d pixels; left kerb ends %0d, right kerb from %0d",
                         line, road_first[line], road_len[line], lk_last[line], rk_first[line]);
            $display("road on %0d of %0d active lines (%0d..%0d)", n_road, VMAX-16, top, bottom);
            if (n_road < (VMAX-16)/2) begin
                $display("FAIL: road on fewer than half the active lines");
                errors = errors + 1;
            end else if (!(road_len[bottom] > road_len[top] + 10)) begin
                $display("FAIL: road not wider at the bottom (%0d) than at the top (%0d)",
                         road_len[bottom], road_len[top]);
                errors = errors + 1;
            end
            // The slant of the right kerb (VR6): on the manual's adjustment
            // page and in the footage the road is several times wider at the
            // bottom than at the top.
            if (FAMILY_LS != 0 && top >= 0 && !(2 * road_len[bottom] >= 5 * road_len[top])) begin
                $display("FAIL: road widens too little down the screen (%0d at the top, %0d at the bottom)",
                         road_len[top], road_len[bottom]);
                errors = errors + 1;
            end
            if (errors == 0) $display("PASS: road visible in frame %0d", FRAMES);
            else $fatal(1, "FAIL: %0d road frame errors", errors);
            $finish;
        end
    endtask

    initial begin
        #(FRAMES * 20_000_000 + 40_000_000);
        $fatal(1, "FAIL: timeout after %0d frames", frame);
    end
endmodule
`default_nettype wire
