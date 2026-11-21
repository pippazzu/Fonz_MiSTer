// SPDX-License-Identifier: GPL-3.0-or-later
// Road monostables IC97 / IC102 / IC104 (three 74123 packages, six halves)
// with the transistor networks that set four of their widths.
//
// SYNTHESISABLE MODEL. The same circuit and the same equations as the
// reference fonz_road_timing_ref.v (simulation only, `real`), which also
// holds the circuit description. Here:
//   * the control networks are stepped every 1 us (a phase accumulator on
//     clk) by forward Euler in fixed point: node voltages in microvolts,
//     coefficients dt/(R*C) as Q32 integers (ratios Q26) worked out at
//     elaboration from the integer pot parameters, each product sized for
//     one 27 x 27 DSP block;
//   * each transistor-fed width is read from a table against the base
//     voltage, 16.4 mV a step with linear interpolation inside the step
//     (rtl/analog/fonz_road_timing_table.vh, scripts/road_timing_table.py),
//     in quarter nanoseconds, and turned into clk cycles;
//   * the six pulses are fonz_74123_core / fonz_74123 halves on clk.
// The board uses the 'LS123 (TRACE.md, "74123 family"), so the table is for
// that part only; the reference keeps FAMILY_LS for comparisons.
// tests/tb_road_timing.v runs both models side by side and compares the
// widths every line.
//
// Pot settings (the resistance in circuit, ohms). The manual's adjustment
// page puts VR-4 (swing width) "approximately midway": 1k of its 2k. VR-5
// (swing frequency) has no standard setting there and is taken midway. The
// swing itself is rtl/analog/fonz_road_swing.v. VR6/VR7/VR8 (10k) are not
// on that page. VR7/VR8 (kerb widths) stay at midway. VR6 sets how fast
// TR6's base runs down through the frame, so how much the road widens down
// the screen (the slant of the right kerb): at midway the road only went
// from 18 % to 32 % of the picture width, against about 10 % to 60 % in the
// footage (docs/reference) and edge to edge on the manual's adjustment page.
// 1k of the 10k gives 19 % at the top, 45 % halfway and 59 % at the bottom.
//
// Those are the factory settings (code 0) of the OSD pot settings
// (scripts/pot_settings.py): vr3..vr8_code pick each pot's setting at run
// time, taken at the tick. Every coefficient a pot sets comes from a small
// table worked out at elaboration, one entry a code.
`timescale 1ns/1ps
`default_nettype none
module fonz_road_timing #(
    parameter integer CLK_HZ  = 14_305_000,
    // The swing network (rtl/analog/fonz_road_swing.v)
    parameter integer TR3_BETA = 120,
    parameter integer TR4_BETA = 200,
    parameter integer B3_INIT_MV = 650
)(
    input  wire       clk,                // sampling clock for the 74123s
    input  wire       IC3_pin5,           // IC3B Q, high for V=0..15
    input  wire       IC100_pin6,         // open collector, 1 = released
    input  wire       IC100_pin4,         // open collector, 1 = released
    // The swing: open collectors, 1 = released
    input  wire       IC94_pin2,          // D4 charges C18 (IC98.5 and IC99.9)
    input  wire       IC94_pin6,          // VR3 sets C18 in a crash
    input  wire       IC94_pin8,          // 0: R16 discharges C18 in a crash
    input  wire       IC100_pin8,         // D5 charges C30 (IC99.5 low)
    // Pot settings (OSD codes, 0 = factory): VR3 crash road shape, VR4
    // swing width (2k + R22 3.3k), VR5 swing frequency (500k + R37 470k),
    // VR6 road widening (10k + 3.3k), VR7 / VR8 kerb widths (10k + R68 /
    // R73 2.2k)
    input  wire [2:0] vr3_code, vr4_code, vr5_code, vr6_code, vr7_code, vr8_code,
    input  wire [2:0] ic97b_ab_clear_n, ic97a_ab_clear_n,
    input  wire [2:0] ic102b_ab_clear_n, ic102a_ab_clear_n,
    input  wire [2:0] ic104b_ab_clear_n, ic104a_ab_clear_n,
    output wire       IC97_pin5, IC97_pin13,
    output wire       IC102_pin5, IC102_pin13,
    output wire       IC104_pin5, IC104_pin13,
    // Base voltages in microvolts, for observation and tests.
    output wire signed [31:0] TR5_base_uv, TR6_base_uv, TR7_base_uv, TR8_base_uv
);
`include "fonz_road_timing_table.vh"
`include "fonz_pot_settings.vh"

    // ---- constants -------------------------------------------------------
    localparam signed [31:0] VCC_UV = 32'sd5_000_000;
    localparam signed [31:0] VS_UV  = 32'sd4_400_000;   // +5 V less a diode
    localparam integer RS = 50;                         // TR2 on: source resistance
    localparam integer C_2U2 = 2_200, C_22U = 22_000;   // nF

    // dt/(R*C) for a 1 us step, Q32: 2^32 * 1000 / (R_ohm * C_nF).
    function [25:0] kq(input [63:0] r, input [63:0] c_nf);
        reg [63:0] num, den;
        begin
            num = (64'd1 << 32) * 64'd1000;
            den = r * c_nf;
            kq  = (num + den / 2) / den;
        end
    endfunction

    // TR6 network
    localparam [25:0] K6A_D = kq(RS, C_2U2);
    localparam [25:0] K6A_AB = kq(3300, C_2U2);
    // 3.3k + VR6, one entry an OSD code
    wire [8*26-1:0] k6a_g_tab;
    genvar gi;
    generate for (gi = 0; gi < 8; gi = gi + 1) begin : vr6_tab
        assign k6a_g_tab[gi*26 +: 26] = kq(3300 + pot_vr6(gi), C_2U2);
    end endgenerate
    localparam [25:0] K6B_D = kq(RS, C_22U);
    localparam [25:0] K6B_AB = kq(3300, C_22U);

    // ---- 1 us tick -------------------------------------------------------
    localparam [63:0] TICK_INC = (64'd1_000_000 << 32) / CLK_HZ;
    // The step restarts at VBLANK rising (IC3 pin 5), so it falls at the
    // same places in every frame and a still picture repeats exactly. The
    // step in progress is cut short, by under 1 us.
    reg [32:0] tick_acc = 33'd0;
    wire tick = tick_acc[32];
    reg vblank_seen = 1'b0;
    wire frame_start = IC3_pin5 & ~vblank_seen;
    always @(posedge clk) begin
        vblank_seen <= IC3_pin5;
        tick_acc <= frame_start ? 33'd0 : {1'b0, tick_acc[31:0]} + TICK_INC[32:0];
    end

    reg s_on = 1'b0, tr7_rel = 1'b1, tr8_rel = 1'b1;
    reg [2:0] vr6_s = 3'd0;
    always @(posedge clk) if (tick) vr6_s <= vr6_code;
    wire [25:0] K6A_G = k6a_g_tab[vr6_s*26 +: 26];
    // Inputs are taken once a tick, so everything the networks read changes
    // only at the tick, and a step may take several clocks to settle
    // (multicycle paths in mister/analog_multicycle.sdc).
    always @(posedge clk) if (tick) begin
        s_on    <= IC3_pin5;
        tr7_rel <= IC100_pin6;
        tr8_rel <= IC100_pin4;
    end

    // k (Q32, unsigned) * v (uV, signed), rounded.
    // Operands are cut to 27 bits so that each product fits one 27 x 27 DSP
    // block: coefficients stay under 2^26, voltages within +-67 V.
    function signed [31:0] mulq(input [25:0] k, input signed [26:0] v);
        reg signed [53:0] p;
        begin
            p = $signed({1'b0, k}) * v + (54'sd1 <<< 31);
            mulq = p >>> 32;
        end
    endfunction
    // Diode from the TR2 line into a node at v: k * (VS - v) while TR2 is on.
    function signed [31:0] diode(input on, input [25:0] k, input signed [31:0] v);
        diode = (on && v < VS_UV) ? mulq(k, VS_UV - v) : 32'sd0;
    endfunction

    // ---- TR6: D6 -> A (C82 2.2u), A -R55 3.3k- B (C33 22u), A to ground
    // through 3.3k + VR6, D7 -> B --------------------------------------------
    reg signed [31:0] C82_D6_R55 = 32'sd0;     // node A, TR6 base side
    reg signed [31:0] C33_D7_R55 = 32'sd0;     // node B
    wire signed [31:0] a6 = C82_D6_R55, b6 = C33_D7_R55;
    wire signed [31:0] a6_next = a6 + diode(s_on, K6A_D, a6) - mulq(K6A_AB, a6 - b6)
                                    - mulq(K6A_G, a6);
    // The reference updates B with the new A (blocking assignments).
    wire signed [31:0] b6_next = b6 + diode(s_on, K6B_D, b6) + mulq(K6B_AB, a6_next - b6);

    // ---- TR5: X (C15), TR3, TR4: the swing --------------------------------
    wire signed [31:0] x5;
    fonz_road_swing #(.TR3_BETA(TR3_BETA), .TR4_BETA(TR4_BETA),
                        .B3_INIT_MV(B3_INIT_MV)) swing(
        .clk(clk), .tick(tick), .IC94_pin4(~IC3_pin5), .IC94_pin2(IC94_pin2),
        .IC94_pin6(IC94_pin6), .IC94_pin8(IC94_pin8), .IC100_pin8(IC100_pin8),
        .vr3_code(vr3_code), .vr4_code(vr4_code), .vr5_code(vr5_code),
        .TR5_base_uv(x5), .C18_uv(), .C15_uv(), .C30_uv());

    always @(posedge clk) if (tick) begin
        C82_D6_R55  <= a6_next;
        C33_D7_R55  <= b6_next;
    end

    // ---- TR7 and TR8 networks ------------------------------------------------
    wire signed [31:0] tr7_n1, tr8_n1;
    fonz_road_tr78 #(.R_MID(3900), .POT(7)) tr7(
        .clk(clk), .tick(tick), .s_on(s_on), .released(tr7_rel), .vr_code(vr7_code), .n1(tr7_n1));
    fonz_road_tr78 #(.R_MID(3300), .POT(8)) tr8(
        .clk(clk), .tick(tick), .s_on(s_on), .released(tr8_rel), .vr_code(vr8_code), .n1(tr8_n1));

    assign TR5_base_uv = x5;
    assign TR6_base_uv = a6;
    assign TR7_base_uv = tr7_n1;
    assign TR8_base_uv = tr8_n1;

    // ---- widths: one table read a clk, four stages in turn -----------------
    // The widths change by microseconds-old voltages, so reading them one
    // after the other within the 1 us step costs nothing.
    localparam [63:0] CYC_PER_Q4_Q20 = ((64'd1 << 20) * CLK_HZ + 64'd2_000_000_000) / 64'd4_000_000_000;
    reg  [1:0] stage = 2'd0;
    always @(posedge clk) stage <= stage + 2'd1;
    reg signed [31:0] v_sel;
    reg [1:0] lut_sel;
    always @* begin
        case (stage)
            2'd0: begin v_sel = x5;     lut_sel = 2'd0; end
            2'd1: begin v_sel = a6;     lut_sel = 2'd1; end
            2'd2: begin v_sel = tr7_n1; lut_sel = 2'd2; end
            default: begin v_sel = tr8_n1; lut_sel = 2'd2; end
        endcase
    end
    wire [8:0] idx = v_sel[31] ? 9'd0
                   : (v_sel >>> ROAD_LUT_SHIFT) >= ROAD_LUT_SIZE ? ROAD_LUT_SIZE[8:0]
                   : v_sel[ROAD_LUT_SHIFT+8:ROAD_LUT_SHIFT];
    wire [ROAD_LUT_SHIFT-1:0] frac = (v_sel[31] || (v_sel >>> ROAD_LUT_SHIFT) >= ROAD_LUT_SIZE)
                                   ? {ROAD_LUT_SHIFT{1'b0}} : v_sel[ROAD_LUT_SHIFT-1:0];
    // Pipeline: index, table read, interpolate, scale to cycles, store.
    reg [8:0] idx_r = 9'd0;
    reg [1:0] sel_r = 2'd0, stage_r = 2'd0;
    reg [ROAD_LUT_SHIFT-1:0] frac_r = 0;
    always @(posedge clk) begin
        idx_r   <= idx;
        sel_r   <= lut_sel;
        frac_r  <= frac;
        stage_r <= stage;
    end
    reg [47:0] entry = 48'd0;
    reg [ROAD_LUT_SHIFT-1:0] frac_d = 0;
    reg [1:0] stage_d = 2'd0, stage_dd = 2'd0, stage_ddd = 2'd0;
    always @(posedge clk) begin
        entry   <= road_width_entry(sel_r, idx_r);
        frac_d  <= frac_r;
        stage_d <= stage_r;
    end
    wire signed [24:0] slope = $signed(entry[23:0]);
    wire signed [40:0] lerp  = slope * $signed({1'b0, frac_d});
    reg  [24:0] w_q4 = 25'd0;
    always @(posedge clk) begin
        w_q4     <= $signed({1'b0, entry[47:24]}) + (lerp >>> ROAD_LUT_SHIFT);
        stage_dd <= stage_d;
    end
    reg [31:0] w_cycles = 32'd1;
    wire [63:0] w_scaled = {39'd0, w_q4} * CYC_PER_Q4_Q20;
    always @(posedge clk) begin
        w_cycles  <= w_scaled[51:20] + {31'd0, w_scaled[19]};
        stage_ddd <= stage_dd;
    end
    reg [31:0] w97b = 32'd1, w102a = 32'd1, w102b = 32'd1, w104b = 32'd1;
    always @(posedge clk)
        case (stage_ddd)
            2'd0: w97b  <= w_cycles;
            2'd1: w102a <= w_cycles;
            2'd2: w102b <= w_cycles;
            default: w104b <= w_cycles;
        endcase

    // ---- the six halves ---------------------------------------------------
    fonz_74123_core ic97b(.clk(clk),
        .a(ic97b_ab_clear_n[2]), .b(ic97b_ab_clear_n[1]), .clr_n(ic97b_ab_clear_n[0]),
        .width(w97b), .q(IC97_pin5), .q_n());
    fonz_74123 #(.CLK_HZ(CLK_HZ), .R_OHM(10_000), .C_PF(100)) ic97a(.clk(clk),
        .a(ic97a_ab_clear_n[2]), .b(ic97a_ab_clear_n[1]), .clr_n(ic97a_ab_clear_n[0]),
        .q(IC97_pin13), .q_n());
    fonz_74123_core ic102b(.clk(clk),
        .a(ic102b_ab_clear_n[2]), .b(ic102b_ab_clear_n[1]), .clr_n(ic102b_ab_clear_n[0]),
        .width(w102b), .q(IC102_pin5), .q_n());
    fonz_74123_core ic102a(.clk(clk),
        .a(ic102a_ab_clear_n[2]), .b(ic102a_ab_clear_n[1]), .clr_n(ic102a_ab_clear_n[0]),
        .width(w102a), .q(IC102_pin13), .q_n());
    fonz_74123_core ic104b(.clk(clk),
        .a(ic104b_ab_clear_n[2]), .b(ic104b_ab_clear_n[1]), .clr_n(ic104b_ab_clear_n[0]),
        .width(w104b), .q(IC104_pin5), .q_n());
    fonz_74123 #(.CLK_HZ(CLK_HZ), .R_OHM(10_000), .C_PF(100)) ic104a(.clk(clk),
        .a(ic104a_ab_clear_n[2]), .b(ic104a_ab_clear_n[1]), .clr_n(ic104a_ab_clear_n[0]),
        .q(IC104_pin13), .q_n());
endmodule

// TR7 / TR8 base network, stepped once a tick (see the reference's
// step_tr78). N1: C38 [C57] 2.2u, fed by D9 [D11]. N2: fed by D8 [D10],
// R69 3.9k [R81 3.3k] from N1. N3: the IC100.6 [IC100.4] open collector,
// R68 [R73] 2.2k + VR7 [VR8] from N1. C 22u [C41] between N2 and N3.
// n1 is TR7 [TR8]'s base side, in microvolts. R_LOW = 2.2k + the pot,
// whose setting is the OSD code vr_code (POT 7 or 8 picks the table).
module fonz_road_tr78 #(
    parameter integer R_MID = 3900,
    parameter integer POT = 7
)(
    input  wire clk,
    input  wire tick,
    input  wire s_on,       // TR2 driving the shared line
    input  wire released,   // open collector at N3 off
    input  wire [2:0] vr_code,
    output wire signed [31:0] n1
);
`include "fonz_pot_settings.vh"
    localparam signed [31:0] VS_UV = 32'sd4_400_000;
    localparam integer RS = 50;
    function [25:0] kq(input [63:0] r, input [63:0] c_nf);
        reg [63:0] num, den;
        begin
            num = (64'd1 << 32) * 64'd1000;
            den = r * c_nf;
            kq  = (num + den / 2) / den;
        end
    endfunction
    // a / b as Q26 (a < b).
    function [25:0] ratio(input [63:0] a, input [63:0] b);
        ratio = ((a << 26) + b / 2) / b;
    endfunction
    function signed [31:0] mulr(input [25:0] k, input signed [26:0] v);
        reg signed [53:0] p;
        begin
            p = $signed({1'b0, k}) * v + (54'sd1 <<< 25);
            mulr = p >>> 26;
        end
    endfunction
    // Operands are cut to 27 bits so that each product fits one 27 x 27 DSP
    // block: coefficients stay under 2^26, voltages within +-67 V.
    function signed [31:0] mulq(input [25:0] k, input signed [26:0] v);
        reg signed [53:0] p;
        begin
            p = $signed({1'b0, k}) * v + (54'sd1 <<< 31);
            mulq = p >>> 32;
        end
    endfunction

    localparam [25:0] K1_RS = kq(RS, 2_200);
    localparam [25:0] K1_MID = kq(R_MID, 2_200);
    localparam [25:0] K2_RS = kq(RS, 22_000);
    localparam [25:0] K2_MID = kq(R_MID, 22_000);
    function integer r_low(input integer code);
        r_low = 2200 + (POT == 8 ? pot_vr8(code) : pot_vr7(code));
    endfunction
    // Per OSD code: K1_LOW; floating N3: N2 = N1 + vc * R_MID / (R_MID +
    // R_LOW) (M_FLOAT, Q26); floating N3 with D8 conducting: N2 = a*N1 +
    // b*vc + c*VS, from the node equation with RS, D = RS*(R_MID+R_LOW) +
    // R_MID*R_LOW (A_ON, B_ON Q26, C_ON_VS in uV).
    wire [8*26-1:0] k1_low_tab, m_float_tab, a_on_tab, b_on_tab;
    wire [8*32-1:0] c_on_vs_tab;
    genvar gi;
    generate for (gi = 0; gi < 8; gi = gi + 1) begin : vr_tab
        localparam integer RL = r_low(gi);
        localparam [63:0] D_ON = 64'd1 * RS * (R_MID + RL) + 64'd1 * R_MID * RL;
        assign k1_low_tab[gi*26 +: 26]  = kq(RL, 2_200);
        assign m_float_tab[gi*26 +: 26] = ratio(R_MID, R_MID + RL);
        assign a_on_tab[gi*26 +: 26]    = ratio(64'd1 * RS * (R_MID + RL), D_ON);
        assign b_on_tab[gi*26 +: 26]    = ratio(64'd1 * R_MID * RS, D_ON);
        assign c_on_vs_tab[gi*32 +: 32] = (64'd4_400_000 * R_MID * RL + D_ON / 2) / D_ON;
    end endgenerate
    reg [2:0] vr_s = 3'd0;
    always @(posedge clk) if (tick) vr_s <= vr_code;
    wire [25:0] K1_LOW  = k1_low_tab[vr_s*26 +: 26];
    wire [25:0] M_FLOAT = m_float_tab[vr_s*26 +: 26];
    wire [25:0] A_ON    = a_on_tab[vr_s*26 +: 26];
    wire [25:0] B_ON    = b_on_tab[vr_s*26 +: 26];
    wire signed [31:0] C_ON_VS = $signed(c_on_vs_tab[vr_s*32 +: 32]);

    reg signed [31:0] N1 = 32'sd0;    // C38 [C57] voltage
    reg signed [31:0] VC = 32'sd0;    // 22u [C41], N2 minus N3
    assign n1 = N1;

    wire signed [31:0] n2_float = N1 + mulr(M_FLOAT, VC);
    wire signed [31:0] n2_rel = (s_on && n2_float < VS_UV)
                              ? mulr(A_ON, N1) + mulr(B_ON, VC) + C_ON_VS : n2_float;
    wire signed [31:0] n2 = released ? n2_rel : VC;
    wire signed [31:0] n3 = released ? n2_rel - VC : 32'sd0;
    wire signed [31:0] vc_next = VC + mulq(K2_MID, N1 - n2)
                               + ((released && s_on && n2 < VS_UV) ? mulq(K2_RS, VS_UV - n2) : 32'sd0);
    wire signed [31:0] n1_next = N1 + ((s_on && N1 < VS_UV) ? mulq(K1_RS, VS_UV - N1) : 32'sd0)
                               - mulq(K1_MID, N1 - n2) - mulq(K1_LOW, N1 - n3);
    always @(posedge clk) if (tick) begin
        VC <= vc_next;
        N1 <= n1_next;
    end
endmodule
`default_nettype wire
