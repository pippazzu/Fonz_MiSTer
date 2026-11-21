// SPDX-License-Identifier: GPL-3.0-or-later
// IC9 / IC106 shape oscillators, synthesisable model.
//
// Each oscillator is a 74123 pair in a loop whose two Rext/Cext pins share
// one node, fed by R5 68k [R104] from +5 V and by the emitter of TR1 [TR9]
// through R4 2.2k || P1 [R105 || P6]. The transistor's base sits on the
// control capacitor C10 [C81] through R6 33k [R103]. The control network,
// its circuit drawing and the analogue reasoning are in
// fonz_shape_oscillator_ref.v (the real-valued reference this model is
// checked against) and docs/SHAPE_OSCILLATORS.md.
//
// Here:
//   * the control network is stepped every 1 us (phase accumulator on clk)
//     in fixed point: microvolts, Q32 coefficients from
//     fonz_shape_osc_table.vh (scripts/shape_osc_table.py). The ones set
//     by VR1 [VR9] and VR2 are picked by the OSD codes vr_code / vr2_code
//     (scripts/pot_settings.py, code 0 the factory setting), taken at the
//     tick like every other input;
//   * the control voltage looks up the half period (trigger delay + pulse
//     width) in the same file;
//   * each half is a fonz_74123_core given that half period in
//     clk cycles less its one-cycle trigger latency, with the fraction
//     carried to the next pulse so the mean frequency is exact (and dropped
//     while /CLR holds the half, so each run starts the same way);
//   * the second half runs 1% long (the real pair never matches exactly; a
//     perfectly matched pair started together by /CLR would lock in phase at
//     twice the frequency), and one extra cycle when /CLR starts both at once.
//
// The oscillator reaches about 7 MHz, so clk must be well above that for
// the output to keep its shape: at 14.305 MHz a half period is one or two
// cycles. At 8 x 14.305 MHz the bench matches the reference within 1%.
`timescale 1ns/1ps
`default_nettype none
module fonz_shape_oscillator #(
    parameter integer CLK_HZ = 114_440_000
)(
    input  wire clk,
    input  wire [2:0] first_ab_clear_n,   // {A1, B2, /CLR3}
    input  wire [2:0] second_ab_clear_n,  // {A9, B10, /CLR11}
    input  wire gate_oc,                  // IC94.12 [IC100.2]; 1 = released
    input  wire tr2_base_oc,              // IC94.10; 1 = released, TR2 off
    input  wire [2:0] vr_code,            // VR1 [VR9] setting (OSD code)
    input  wire [2:0] vr2_code,           // VR2 setting (OSD code)
    output wire first_q,                  // pin 13
    output wire first_q_n,                // pin 4
    output wire second_q,                 // pin 5
    output wire second_q_n,               // pin 12
    output wire [15:0] control_mv         // C10 [C81] voltage, for observation
);
`include "fonz_shape_osc_table.vh"

    // ---- 1 us tick ----------------------------------------------------------
    localparam [63:0] TICK_INC = (64'd1_000_000 << 32) / CLK_HZ;
    // The step restarts when TR2 turns on (VBLANK rising, once a frame), so
    // it falls at the same places in every frame and a still picture
    // repeats exactly. The step in progress is cut short, by under 1 us.
    reg [32:0] tick_acc = 33'd0;
    wire tick = tick_acc[32];
    reg tr2_seen = 1'b1;
    wire frame_start = tr2_seen & ~tr2_base_oc;
    always @(posedge clk) begin
        tr2_seen <= tr2_base_oc;
        tick_acc <= frame_start ? 33'd0 : {1'b0, tick_acc[31:0]} + TICK_INC[32:0];
    end

    // ---- control network (microvolts) -------------------------------------
    reg signed [31:0] C10_plus_R6_R8_R7 = 32'sd0;   // control voltage
    reg signed [31:0] C11_charge = 32'sd0;          // C11 (+) minus (-)

    // Products sized for one 27 x 27 DSP block each: coefficients under
    // 2^26 (Q32), or Q31 for G1 and for 1 - G2; voltages within +-67 V.
    function signed [31:0] mulq(input [25:0] k, input signed [26:0] v);
        reg signed [53:0] p;
        begin
            p = $signed({1'b0, k}) * v + (54'sd1 <<< 31);
            mulq = p >>> 32;
        end
    endfunction
    function signed [31:0] mulq30(input [25:0] k, input signed [26:0] v);
        reg signed [53:0] p;
        begin
            p = $signed({1'b0, k}) * v + (54'sd1 <<< 29);
            mulq30 = p >>> 30;
        end
    endfunction
    function signed [31:0] mulq29(input [25:0] k, input signed [26:0] v);
        reg signed [53:0] p;
        begin
            p = $signed({1'b0, k}) * v + (54'sd1 <<< 28);
            mulq29 = p >>> 29;
        end
    endfunction

    reg sync_gate = 1'b1, sync_tr2 = 1'b1, sync_clr = 1'b0;
    // Inputs are taken once a tick, so everything the network reads changes
    // only at the tick, and the 1 us step may take several clocks to settle
    // (multicycle paths in mister/analog_multicycle.sdc).
    always @(posedge clk) if (tick) begin
        sync_gate <= gate_oc;
        sync_tr2  <= tr2_base_oc;
        sync_clr  <= first_ab_clear_n[0];
    end

    // The pot settings, held at the tick, and the coefficients they set
    // (G1 Q30, 1 - G2 Q29): small constant tables.
    reg [2:0] sync_vr = 3'd0, sync_vr2 = 3'd0;
    always @(posedge clk) if (tick) begin
        sync_vr  <= vr_code;
        sync_vr2 <= vr2_code;
    end
    wire [25:0] K_Y_RV   = k_y_rv(sync_vr);
    wire [25:0] K_C_LOOP = k_c_loop(sync_vr);
    wire [25:0] K_Y_RS   = k_y_rs(sync_vr2);
    wire [25:0] K_C_RS   = k_c_rs(sync_vr2);
    wire [25:0] G1_Q30   = g1_q30(sync_vr, sync_vr2);
    wire [25:0] G2C_Q29  = g2c_q29(sync_vr, sync_vr2);

    wire signed [31:0] vy = C10_plus_R6_R8_R7;
    wire signed [31:0] vc = C11_charge;
    wire tr2_on  = ~sync_tr2;
    wire gate_on = ~sync_gate;

    // D2 [D13] straight into C10.
    wire signed [31:0] d2 = (tr2_on && V_SRC > vy) ? V_SRC - vy : 32'sd0;
    // Base current while the pair runs.
    wire signed [31:0] ib = (sync_clr && vy > V_IB0) ? mulq(K_Y_IB[25:0], vy - V_IB0) : 32'sd0;

    // Gate pulling: the VR1 end sits at V_OL, C11 (+) at V_OL + vc.
    wire signed [31:0] p_on  = V_OL + vc;
    wire signed [31:0] d1_on = (tr2_on && V_SRC > p_on) ? V_SRC - p_on : 32'sd0;
    wire signed [31:0] dvc_on = mulq(K_C_RC[25:0], vy - p_on) + mulq(K_C_RS, d1_on);
    wire signed [31:0] dvy_on = mulq(K_Y_RC[25:0], p_on - vy) + mulq(K_Y_RV, V_OL - vy);

    // Gate released, VR1 end floating: u = vy - x. With D1 [D12] conducting
    // u = G1*vc + G2*(vy + vc - V_SRC), else u = vc*rv/(rv+R8).
    wire signed [31:0] g2_in = vy + vc - V_SRC;
    wire signed [31:0] u_d  = mulq30(G1_Q30, vc) + g2_in - mulq29(G2C_Q29, g2_in);
    wire signed [31:0] d1_f = V_SRC - vy + u_d - vc;
    wire d1_conducts = tr2_on && (d1_f > 0);
    wire signed [31:0] dvc_off = d1_conducts ? mulq(K_C_RC[25:0], u_d - vc) + mulq(K_C_RS, d1_f)
                                             : -mulq(K_C_LOOP, vc);
    wire signed [31:0] dvy_off = d1_conducts ? mulq(K_Y_RS, d1_f) : 32'sd0;

    always @(posedge clk) if (tick) begin
        C10_plus_R6_R8_R7 <= vy + (gate_on ? dvy_on : dvy_off) + mulq(K_Y_RS, d2) - ib;
        C11_charge        <= vc + (gate_on ? dvc_on : dvc_off);
    end

    wire [57:0] vy_scaled = vy[25:0] * 32'd67109;      // uV / 1000 as * 2^26/1000
    assign control_mv = vy[31] ? 16'd0 : vy_scaled[41:26];

    // ---- half period in clk cycles, Q8 --------------------------------------
    localparam [63:0] CYC_PER_NS_Q16 = (64'd65536 * CLK_HZ) / 64'd1_000_000_000;
    wire [8:0] lut_index = (vy < 0) ? 9'd0
                         : ((vy >>> LUT_SHIFT) >= LUT_SIZE) ? LUT_SIZE[8:0]
                         : vy[LUT_SHIFT+8:LUT_SHIFT];
    reg  [15:0] half_ns_x16 = 16'd0;
    always @(posedge clk) half_ns_x16 <= half_period_ns_x16(lut_index);
    // ns*16 (Q4) times cycles/ns (Q16) = Q20; >> 12 gives Q8 cycles.
    // Registered, so that a trigger loads a width without the multiplies in
    // its path; the control voltage moves once a microsecond.
    reg  [31:0] first_half_q8 = 32'd0, second_half_q8 = 32'd0;
    wire [31:0] first_half_next = (half_ns_x16 * CYC_PER_NS_Q16) >> 12;
    always @(posedge clk) begin
        first_half_q8  <= first_half_next;
        second_half_q8 <= (first_half_next * 32'd259) >> 8;   // +1.2%
    end

    // Same trigger rule as fonz_74123_core, to know when a width is taken.
    reg [2:0] first_prev = 3'b100, second_prev = 3'b100;
    always @(posedge clk) begin
        first_prev  <= first_ab_clear_n;
        second_prev <= second_ab_clear_n;
    end
    function automatic trig(input [2:0] p, input [2:0] n);
        trig = n[0] & ((p[2] & ~n[2] & n[1]) | (~p[1] & n[1] & ~n[2]) | (~p[0] & ~n[2] & n[1]));
    endfunction
    wire first_trig  = trig(first_prev, first_ab_clear_n);
    wire second_trig = trig(second_prev, second_ab_clear_n);

    // Width = half period - 1 cycle of trigger latency, fraction carried.
    reg [7:0] first_frac = 8'd0, second_frac = 8'd0;
    wire [31:0] first_w_q8  = first_half_q8  + first_frac  - 32'd256;
    wire [31:0] second_w_q8 = second_half_q8 + second_frac - 32'd256
                            + ((first_trig && second_trig) ? 32'd256 : 32'd0);
    // A half held by /CLR has no phase to remember: its fraction starts
    // again from 0, so every run after a clear has the same widths.
    always @(posedge clk) begin
        if (!first_ab_clear_n[0])  first_frac  <= 8'd0;
        else if (first_trig)       first_frac  <= first_w_q8[7:0];
        if (!second_ab_clear_n[0]) second_frac <= 8'd0;
        else if (second_trig)      second_frac <= second_w_q8[7:0];
    end
    wire [15:0] first_width  = first_w_q8[31]  ? 16'd1 : first_w_q8[23:8];
    wire [15:0] second_width = second_w_q8[31] ? 16'd1 : second_w_q8[23:8];

    fonz_74123_core #(.W(16)) half1(
        .clk(clk), .a(first_ab_clear_n[2]), .b(first_ab_clear_n[1]), .clr_n(first_ab_clear_n[0]),
        .width(first_width), .q(first_q), .q_n(first_q_n));
    fonz_74123_core #(.W(16)) half2(
        .clk(clk), .a(second_ab_clear_n[2]), .b(second_ab_clear_n[1]), .clr_n(second_ab_clear_n[0]),
        .width(second_width), .q(second_q), .q_n(second_q_n));
endmodule
`default_nettype wire
