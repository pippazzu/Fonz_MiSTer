// SPDX-License-Identifier: GPL-3.0-or-later
// Bench for the IC9 / IC106 shape oscillator models.
//
//   iverilog -g2012 -I rtl/analog -o build/shape_osc sim/shape_oscillator_tb.v \
//       rtl/analog/fonz_shape_oscillator.v rtl/analog/fonz_shape_oscillator_ref.v \
//       rtl/analog/fonz_74123.v rtl/fonz_analog_connections.v rtl/ttl/fonz_ttl.v
//   vvp -n build/shape_osc
//
// The reference (real-valued) and synthesisable models get the same drive,
// each through its own fonz_shape_oscillator_connections loop:
//   1. frequency against control voltage (the width function);
//   2. the pair alternates, /CLR stops it and restarts it;
//   3. frames: TR2 tops the control up for 778 us (IC3.5 high, measured on
//      the board), then the gate pulls for 0%, 30% or 100% of the frame.
//      Control voltage and pin-5 period are compared line by line.
`timescale 1ns/1ps
`default_nettype none
module shape_oscillator_tb;
    localparam real FRAME_NS = 16565500.0;   // 261 lines x 454 clocks at 14.305 MHz
    localparam real LINE_NS  = FRAME_NS / 261.0;
    localparam real TR2_NS   = 778000.0;
    localparam real CLK_NS   = 1.0e9 / 114440000.0;

    reg clk = 1'b0;
    always #(CLK_NS / 2.0) clk = ~clk;

    reg IC101_pin6_ROAD_LOAD_n = 1'b0;  // /CLR of both halves
    reg IC94_pin12_VR1 = 1'b1;                 // gate, 1 = released
    reg IC94_pin10_R15 = 1'b1;                 // TR2 drive, 1 = released

    // Reference model loop.
    wire ref_IC9_pin13_IC9_pin9, ref_IC9_pin5, ref_IC9_pin12_IC9_pin2;
    wire [2:0] ref_first_abc, ref_second_abc;
    fonz_shape_oscillator_connections ref_pins(
        .clear_n(IC101_pin6_ROAD_LOAD_n),.first_q(ref_IC9_pin13_IC9_pin9),.second_q(ref_IC9_pin5),
        .first_ab_clear_n(ref_first_abc),.second_ab_clear_n(ref_second_abc),.second_q_n(ref_IC9_pin12_IC9_pin2));
    fonz_shape_oscillator_ref ref_ic9(
        .first_ab_clear_n(ref_first_abc),.second_ab_clear_n(ref_second_abc),
        .gate_oc(IC94_pin12_VR1),.tr2_base_oc(IC94_pin10_R15),
        .first_q(ref_IC9_pin13_IC9_pin9),.second_q(ref_IC9_pin5));

    // Synthesisable model loop.
    wire syn_IC9_pin13_IC9_pin9, syn_IC9_pin5, syn_IC9_pin12_IC9_pin2, syn_pin4, syn_pin12;
    wire [2:0] syn_first_abc, syn_second_abc;
    wire [15:0] syn_mv;
    fonz_shape_oscillator_connections syn_pins(
        .clear_n(IC101_pin6_ROAD_LOAD_n),.first_q(syn_IC9_pin13_IC9_pin9),.second_q(syn_IC9_pin5),
        .first_ab_clear_n(syn_first_abc),.second_ab_clear_n(syn_second_abc),.second_q_n(syn_IC9_pin12_IC9_pin2));
    fonz_shape_oscillator #(.CLK_HZ(114440000)) syn_ic9(
        .clk(clk),.first_ab_clear_n(syn_first_abc),.second_ab_clear_n(syn_second_abc),
        .gate_oc(IC94_pin12_VR1),.tr2_base_oc(IC94_pin10_R15),.vr_code(3'd0),.vr2_code(3'd0),
        .first_q(syn_IC9_pin13_IC9_pin9),.first_q_n(syn_pin4),
        .second_q(syn_IC9_pin5),.second_q_n(syn_pin12),.control_mv(syn_mv));

    // Pin-5 period, averaged over the last 16 cycles; high time of the last.
    real ref_rise[0:16], syn_rise[0:16];
    real ref_high = 0.0, syn_high = 0.0;
    integer ref_edges = 0, syn_edges = 0, j;
    always @(posedge ref_IC9_pin5) begin
        for (j = 16; j > 0; j = j - 1) ref_rise[j] = ref_rise[j-1];
        ref_rise[0] = $realtime; ref_edges = ref_edges + 1;
    end
    always @(negedge ref_IC9_pin5) ref_high = $realtime - ref_rise[0];
    always @(posedge syn_IC9_pin5) begin
        for (j = 16; j > 0; j = j - 1) syn_rise[j] = syn_rise[j-1];
        syn_rise[0] = $realtime; syn_edges = syn_edges + 1;
    end
    always @(negedge syn_IC9_pin5) syn_high = $realtime - syn_rise[0];
    function real ref_period; ref_period = (ref_rise[0] - ref_rise[16]) / 16.0; endfunction
    function real syn_period; syn_period = (syn_rise[0] - syn_rise[16]) / 16.0; endfunction

    integer i, k, fails = 0;
    real v, worst_v = 0.0, worst_f = 0.0, ref_end[0:2];

    task check(input cond, input [8*72-1:0] what);
        if (!cond) begin fails = fails + 1; $display("FAIL: %0s", what); end
    endtask

    task frame(input real frac, input integer report);
        real t0, dv, df;
        begin
            t0 = $realtime;
            IC94_pin10_R15 = 1'b0;
            if (frac > 0.0) IC94_pin12_VR1 = 1'b0;
            #(TR2_NS);
            IC94_pin10_R15 = 1'b1;
            for (k = 1; $realtime - t0 < FRAME_NS - LINE_NS; k = k + 1) begin
                if ($realtime - t0 >= frac * FRAME_NS) IC94_pin12_VR1 = 1'b1;
                #(LINE_NS);
                dv = ref_ic9.C10_plus_R6_R8_R7 * 1000.0 - syn_mv;
                df = (syn_period() - ref_period()) / ref_period();
                if (dv < 0) dv = -dv;
                if (df < 0) df = -df;
                if (dv > worst_v) worst_v = dv;
                if (df > worst_f) worst_f = df;
                if (report && (k % 40 == 0))
                    $display("  line %3d  ref %5.3f V %6.1f ns %4.2f MHz | synth %5.3f V %6.1f ns %4.2f MHz",
                             k + 12, ref_ic9.C10_plus_R6_R8_R7, ref_period(), 1.0e3 / ref_period(),
                             syn_mv / 1000.0, syn_period(), 1.0e3 / syn_period());
            end
            #(FRAME_NS - ($realtime - t0));
            IC94_pin12_VR1 = 1'b1;
        end
    endtask

    initial begin
        $display("1. Frequency against control voltage (C10/C81), default parameters");
        for (i = 0; i <= 18; i = i + 1) begin
            v = i * 0.25;
            $display("  Vc %4.2f V  tw %6.1f ns  period %6.1f ns  f %5.2f MHz",
                     v, ref_ic9.thevenin_width_ns(v), 2.0 * (22.0 + ref_ic9.thevenin_width_ns(v)),
                     1.0e3 / (2.0 * (22.0 + ref_ic9.thevenin_width_ns(v))));
        end
        check(ref_ic9.thevenin_width_ns(4.0) < ref_ic9.thevenin_width_ns(2.0), "width falls as control rises");
        check(ref_ic9.thevenin_width_ns(0.0) == ref_ic9.thevenin_width_ns(0.3), "below Vbe only R5 sets width");

        $display("2. Oscillation with control at 0 V, /CLR stop and restart");
        #1000; IC101_pin6_ROAD_LOAD_n = 1'b1;
        #40000;
        $display("  ref   period %0.1f ns, high %0.1f ns", ref_period(), ref_high);
        $display("  synth period %0.1f ns, high %0.1f ns", syn_period(), syn_high);
        check(ref_edges > 20 && syn_edges > 20, "both oscillate after /CLR release");
        check(ref_period() > 0.98 * ref_ic9.period_ns && ref_period() < 1.02 * ref_ic9.period_ns,
              "ref period matches 2*(tpd+tw)");
        check(ref_high > 0.4 * ref_period() && ref_high < 0.6 * ref_period(), "ref halves alternate");
        check(syn_high > 0.4 * syn_period() && syn_high < 0.6 * syn_period(), "synth halves alternate");
        check(syn_period() > 0.97 * ref_period() && syn_period() < 1.03 * ref_period(), "synth period within 3%");
        IC101_pin6_ROAD_LOAD_n = 1'b0; ref_edges = 0; syn_edges = 0;
        #5000;
        check(ref_edges == 0 && syn_edges == 0 && !ref_IC9_pin5 && !syn_IC9_pin5, "/CLR low stops both");
        IC101_pin6_ROAD_LOAD_n = 1'b1;
        #40000;
        check(ref_edges > 20 && syn_edges > 20, "both restart after /CLR");
        check(syn_high > 0.4 * syn_period() && syn_high < 0.6 * syn_period(), "synth alternates after restart");

        $display("3. Frames, VR1 = 1.8k: line, control voltage, pin-5 period and frequency");
        frame(0.0, 0); frame(0.0, 0);
        $display(" gate released all frame:");
        frame(0.0, 1); ref_end[0] = ref_ic9.C10_plus_R6_R8_R7;
        frame(0.3, 0);
        $display(" gate pulled for the first 30%% of the frame:");
        frame(0.3, 1); ref_end[1] = ref_ic9.C10_plus_R6_R8_R7;
        frame(1.0, 0);
        $display(" gate pulled all frame:");
        frame(1.0, 1); ref_end[2] = ref_ic9.C10_plus_R6_R8_R7;
        $display("  worst synth-ref difference: %0.1f mV, %0.1f%% in period", worst_v, worst_f * 100.0);
        check(ref_end[0] > 3.8, "released gate holds the control near the top-up level");
        check(ref_end[1] < ref_end[0] - 0.3 && ref_end[2] < ref_end[1], "longer gate time, lower control");
        check(worst_v < 30.0, "synth control voltage within 30 mV of the reference");
        check(worst_f < 0.05, "synth period within 5% of the reference");
        if (fails == 0) $display("PASS"); else $display("%0d FAILED", fails);
        $finish;
    end
endmodule
`default_nettype wire
