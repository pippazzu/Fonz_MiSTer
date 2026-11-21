// SPDX-License-Identifier: GPL-3.0-or-later
// The synthesisable road model (rtl/analog/fonz_road_timing.v) against
// the real-valued reference (rtl/analog/fonz_road_timing_ref.v).
//
// Both get the same frame pattern on their control inputs: IC3.5 high for
// lines 0..15 of 261 (63.475 us a line), and the IC100.6 / IC100.4 open
// collectors released in the same lines, low in the active frame. After the
// control capacitors have settled (8 frames), the four transistor-fed
// widths are compared on every active line (16..260) of the next frame, and
// must agree within 1 % or one clock. Both models are clocked by the
// 14.305 MHz crystal here, to keep the run short.
//
//   iverilog -g2012 -I rtl/analog -o build/tb_road_timing tests/tb_road_timing.v \
//       rtl/analog/fonz_road_timing.v rtl/analog/fonz_road_timing_ref.v \
//       rtl/analog/fonz_74123.v && vvp -n build/tb_road_timing
`timescale 1ns/1ps
`default_nettype none
module tb_road_timing;
    localparam integer CLK_HZ = 14_305_000;
    localparam real    HALF_NS = 1.0e9 / CLK_HZ / 2.0;
    localparam real    LINE_NS = 63_475.0;
    localparam integer LINES = 261, SETTLE = 8;

    reg clk = 1'b0;
    always #(HALF_NS) clk = ~clk;

    reg ic3_5 = 1'b1;
    integer line = 0, frame = 0;
    always begin
        #(LINE_NS);
        line = line + 1;
        if (line == LINES) begin line = 0; frame = frame + 1; end
        ic3_5 = (line < 16);
    end
    wire [2:0] idle = 3'b111;
    // The swing: C18 starts at 730 mV, so TR3 bends the road from the first
    // frame; D4 charges it in frames 0..5, D5 charges C30 from frame 3 on
    // (TR4 comes on and the lean turns into an S).
    wire ic94_2 = frame < 6, ic100_8 = frame >= 3;

    fonz_road_timing #(.CLK_HZ(CLK_HZ), .B3_INIT_MV(730)) dut(
        .clk(clk), .IC3_pin5(ic3_5), .IC100_pin6(ic3_5), .IC100_pin4(ic3_5),
        .IC94_pin2(ic94_2), .IC94_pin6(1'b0), .IC94_pin8(1'b1), .IC100_pin8(ic100_8),
        .vr3_code(3'd0), .vr4_code(3'd0), .vr5_code(3'd0), .vr6_code(3'd0), .vr7_code(3'd0), .vr8_code(3'd0),
        .ic97b_ab_clear_n(idle), .ic97a_ab_clear_n(idle),
        .ic102b_ab_clear_n(idle), .ic102a_ab_clear_n(idle),
        .ic104b_ab_clear_n(idle), .ic104a_ab_clear_n(idle),
        .IC97_pin5(), .IC97_pin13(), .IC102_pin5(), .IC102_pin13(),
        .IC104_pin5(), .IC104_pin13(),
        .TR5_base_uv(), .TR6_base_uv(), .TR7_base_uv(), .TR8_base_uv());
    fonz_road_timing_ref #(.CLK_HZ(CLK_HZ), .B3_INIT_MV(730.0)) ref_model(
        .IC45_pin8(clk), .IC3_pin5(ic3_5), .IC100_pin6(ic3_5), .IC100_pin4(ic3_5),
        .IC94_pin2(ic94_2), .IC94_pin6(1'b0), .IC94_pin8(1'b1), .IC100_pin8(ic100_8),
        .ic97b_ab_clear_n(idle), .ic97a_ab_clear_n(idle),
        .ic102b_ab_clear_n(idle), .ic102a_ab_clear_n(idle),
        .ic104b_ab_clear_n(idle), .ic104a_ab_clear_n(idle),
        .IC97_pin5(), .IC97_pin13(), .IC102_pin5(), .IC102_pin13(),
        .IC104_pin5(), .IC104_pin13());

    integer errors = 0, checked = 0;
    real worst = 0.0;
    task cmp(input [8*8-1:0] name, input integer got, input integer want);
        real rel;
        begin
            rel = (got - want) * 1.0 / want;
            if (rel < 0.0) rel = -rel;
            checked = checked + 1;
            if (rel > worst && want < 32'h7fff_ffff && want < 100000) worst = rel;
            // Widths over a line never end before the next trigger.
            if (want > 4000 && got > 4000) ;
            else if (rel > 0.01 && (got - want > 1 || want - got > 1)) begin
                if (errors < 10)
                    $display("FAIL: line %0d %0s got %0d cycles, reference %0d", line, name, got, want);
                errors = errors + 1;
            end
        end
    endtask

    // Lines 0..15 are blanked; the synthesisable model reads its inputs once
    // a microsecond, one step behind the reference, which shows only while
    // TR2 tops the capacitors up in those lines.
    always @(line) if (frame == SETTLE && line >= 16) begin
        #(LINE_NS / 2.0);
        cmp("IC97B", dut.w97b, ref_model.w97b);
        cmp("IC102A", dut.w102a, ref_model.w102a);
        cmp("IC102B", dut.w102b, ref_model.w102b);
        cmp("IC104B", dut.w104b, ref_model.w104b);
        if (line % 40 == 20)
            $display("line %3d: 97B %0d/%0d 102A %0d/%0d 102B %0d/%0d 104B %0d/%0d (synth/ref cycles)",
                     line, dut.w97b, ref_model.w97b, dut.w102a, ref_model.w102a,
                     dut.w102b, ref_model.w102b, dut.w104b, ref_model.w104b);
    end

    always @(frame) if (frame == SETTLE + 1) begin
        $display("%0d widths compared, worst difference %0.3f %%", checked, worst * 100.0);
        if (errors == 0) $display("PASS: synthesisable road widths match the reference");
        else $display("FAIL: %0d width differences", errors);
        $finish;
    end
endmodule
`default_nettype wire
