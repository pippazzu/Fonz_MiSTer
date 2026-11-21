// SPDX-License-Identifier: GPL-3.0-or-later
// The road swing: the network that bends the road, from the timers IC98 and
// IC99 to TR5's base. Synthesisable; rtl/analog/fonz_road_timing_ref.v
// has the same equations in `real`, and tests/tb_road_timing.v compares
// the two. Read from the native scan, crop (1100,3350)-(2950,4200), on
// 9 November 2026.
//
//   X    C15 2.2u. Charges from +5 V through VR4 2k + R22 3.3k. TR3's
//        collector discharges it through R24 51R. TR5's base hangs on X
//        through R23 33k.
//   TR3  emitter on IC94.4 (open collector, low for V=0..15), base through
//        R25 3.3k from B3. So once a frame, in the vertical blanking, TR3
//        takes out of C15 a charge set by its base current: X starts the
//        frame low and climbs back down the screen, and the 97B delay (the
//        left road edge) is long at the top and shortens towards the
//        bottom. The road's top leans to the right by that much.
//   B3   C18 47u. Charged through D4 from IC94.2's pull-up, VR5 500k + R37
//        470k, while IC94.2 is released: IC98.5 and IC99.9 both high. It
//        is discharged by TR3's base current in each blanking. So B3 floats
//        just above TR3's Vbe and rises and falls with the two timers:
//        the bend comes and goes every few seconds. VR5 sets how fast B3
//        climbs (the manual's "side-swing frequency"), VR4 how fast X
//        recovers down the screen ("swing width").
//        In a crash IC94.8 (R16 33k) pulls B3 down and IC94.6 is released:
//        R21 10k and VR3 10k then set B3 through D3 ("road shape at the
//        time of a crash", VR-3).
//   TR4  grounds the far end of C20 0.068u, which hangs on TR5's base. Its
//        base (R38 3.3k) comes from C30 47u, charged through D5 from R41 1M
//        while IC100.8 is released (IC99.5 low). With TR4 on, R23 and C20
//        delay TR5's base behind X by 2.2 ms, which turns the lean into an
//        S; as C30 runs down TR4's collector current falls and the S fades.
//
// Simplifications: TR3 and TR4 are a Vbe of 0.65 V and a current gain;
// TR5's base current is ignored. The gains are not on the drawing. With
// TR3_BETA 120 and VR5 midway the top of the road swings between the left
// third and the right edge of the picture, as in the footage
// (docs/reference). C18 and C30 start at Vbe, so the swing starts with the
// core and not 13 s later.
//
// Voltages are in 1/256 uV. Each term is a constant multiply by a 12-bit
// coefficient, done in logic (the FPGA's DSP blocks are all taken). One
// step a microsecond; inputs are taken at the tick, so a step may take
// several clocks (multicycle paths in mister/analog_multicycle.sdc).
//
// Pots. VR3, VR4 and VR5 are OSD settings (scripts/pot_settings.py, code 0
// the factory setting), taken at the tick. Their three terms multiply by a
// 14-bit coefficient picked from a small table, at the shift of the factory
// setting, so code 0 gives the same numbers as fixed pots did. VR3 is a
// divider: R21 10k from +5 V, VR3 10k to ground, the wiper at p % gives
// 2.5 p/100 V less D3 (0.65 V at midway) behind a Thevenin resistance of
// R21 + (1 - p) VR3 in parallel with p VR3 (3.75k at midway).
`timescale 1ns/1ps
`default_nettype none
(* multstyle = "logic" *)
module fonz_road_swing #(
    parameter integer TR3_BETA = 120,
    parameter integer TR4_BETA = 200,
    parameter integer B3_INIT_MV = 650
)(
    input  wire        clk,
    input  wire        tick,               // 1 us
    input  wire        IC94_pin4,          // TR3 emitter, 0 for V=0..15
    input  wire        IC94_pin2,          // 1 = released: D4 charges C18
    input  wire        IC94_pin6,          // 1 = released: VR3 sets B3 (crash)
    input  wire        IC94_pin8,          // 0: R16 discharges C18 (crash)
    input  wire        IC100_pin8,         // 1 = released: D5 charges C30
    input  wire [2:0]  vr3_code,           // VR3: road shape in a crash (OSD code)
    input  wire [2:0]  vr4_code,           // VR4: swing width (OSD code)
    input  wire [2:0]  vr5_code,           // VR5: swing frequency (OSD code)
    output wire signed [31:0] TR5_base_uv,
    output wire signed [31:0] C18_uv, C15_uv, C30_uv
);
    // 1 uV in state units, and the fixed levels
    localparam signed [31:0] UV   = 32'sd256;
    localparam signed [31:0] VCC  = 32'sd5_000_000 * 256;
    localparam signed [31:0] VS   = 32'sd4_400_000 * 256;   // +5 V less a diode
    localparam signed [31:0] VBE  = 32'sd650_000 * 256;
    localparam signed [31:0] VSAT = 32'sd100_000 * 256;     // TR3 saturated
`include "fonz_pot_settings.vh"

    // A ratio num/den as k * 2^-sh with k in 2048..4095
    function integer ratio_sh(input [63:0] num, input [63:0] den);
        integer sh;
        begin
            sh = 0;
            while ((num << sh) / den < 64'd2048 && sh < 52) sh = sh + 1;
            ratio_sh = sh;
        end
    endfunction
    function [11:0] ratio_k(input [63:0] num, input [63:0] den);
        reg [63:0] k;
        begin
            k = (num << ratio_sh(num, den)) / den;
            ratio_k = k > 64'd4095 ? 12'd4095 : k[11:0];
        end
    endfunction
    // v * k >> sh, v not negative
    function signed [31:0] mulk(input [11:0] k, input integer sh, input signed [31:0] v);
        reg signed [47:0] p;
        begin
            p = v * $signed({1'b0, k});
            mulk = p >>> sh;
        end
    endfunction
    // The same with a 14-bit coefficient picked at run time
    function signed [31:0] mulkv(input [13:0] k, input integer sh, input signed [31:0] v);
        reg signed [47:0] p;
        begin
            p = v * $signed({1'b0, k});
            mulkv = p >>> sh;
        end
    endfunction
    // num/den at a given shift, for the tables
    function [13:0] ratio_at(input [63:0] num, input [63:0] den, input integer sh);
        reg [63:0] k;
        begin
            k = (num << sh) / den;
            ratio_at = k > 64'd16383 ? 14'd16383 : k[13:0];
        end
    endfunction
    // VR3 at p %: Thevenin resistance and level (mV, less D3). At 0 % D3
    // never conducts; the resistance of 25 % keeps the table finite.
    function integer vr3_rth(input integer p);
        integer q;
        begin
            q = (p < 25) ? 25 : p;
            vr3_rth = (100 * q) * (20_000 - 100 * q) / 20_000;
        end
    endfunction
    function signed [31:0] pos(input signed [31:0] v);
        pos = v[31] ? 32'sd0 : v;
    endfunction

    // dt/(R C) for a 1 us step is 1000 / (R_ohm * C_nF)
    // D4, VR5 + R37 into C18
    localparam [63:0]  KB_CHG_N = 64'd1000;
    localparam integer KB_CHG_SH = ratio_sh(KB_CHG_N, (64'd470_000 + pot_vr5(0)) * 64'd47_000);
    // R25 out of C18; R38 out of C30
    localparam [63:0]  KB_BASE_N = 64'd1000, KB_BASE_D = 64'd3300 * 64'd47_000;
    localparam integer KB_BASE_SH = ratio_sh(KB_BASE_N, KB_BASE_D);
    localparam [11:0]  KB_BASE_K  = ratio_k(KB_BASE_N, KB_BASE_D);
    // R16 out of C18
    localparam [63:0]  KB_R16_N = 64'd1000, KB_R16_D = 64'd33_000 * 64'd47_000;
    localparam integer KB_R16_SH = ratio_sh(KB_R16_N, KB_R16_D);
    localparam [11:0]  KB_R16_K  = ratio_k(KB_R16_N, KB_R16_D);
    // D3: R21 and VR3 (3.75k at midway)
    localparam [63:0]  KB_D3_N = 64'd1000;
    localparam integer KB_D3_SH = ratio_sh(KB_D3_N, vr3_rth(pot_vr3(0)) * 64'd47_000);
    // VR4 + R22 into C15
    localparam [63:0]  KX_CHG_N = 64'd1000;
    localparam integer KX_CHG_SH = ratio_sh(KX_CHG_N, (64'd3300 + pot_vr4(0)) * 64'd2200);

    // The pot tables, one entry an OSD code
    wire [8*14-1:0] kb_chg_tab, kb_d3_tab, kx_chg_tab;
    wire [8*32-1:0] vd3_tab;
    genvar gi;
    generate for (gi = 0; gi < 8; gi = gi + 1) begin : pot_tab
        assign kb_chg_tab[gi*14 +: 14] = ratio_at(KB_CHG_N, (64'd470_000 + pot_vr5(gi)) * 64'd47_000, KB_CHG_SH);
        assign kb_d3_tab[gi*14 +: 14]  = ratio_at(KB_D3_N, vr3_rth(pot_vr3(gi)) * 64'd47_000, KB_D3_SH);
        assign kx_chg_tab[gi*14 +: 14] = ratio_at(KX_CHG_N, (64'd3300 + pot_vr4(gi)) * 64'd2200, KX_CHG_SH);
        assign vd3_tab[gi*32 +: 32]    = (25_000 * pot_vr3(gi) - 600_000) * 256;
    end endgenerate
    // beta * Ib(R25) out of C15
    localparam [63:0]  KX_IC_N = 64'd1000 * TR3_BETA, KX_IC_D = 64'd3300 * 64'd2200;
    localparam integer KX_IC_SH = ratio_sh(KX_IC_N, KX_IC_D);
    localparam [11:0]  KX_IC_K  = ratio_k(KX_IC_N, KX_IC_D);
    // R24: TR3 saturated
    localparam [63:0]  KX_SAT_N = 64'd1000, KX_SAT_D = 64'd51 * 64'd2200;
    localparam integer KX_SAT_SH = ratio_sh(KX_SAT_N, KX_SAT_D);
    localparam [11:0]  KX_SAT_K  = ratio_k(KX_SAT_N, KX_SAT_D);
    // D5, R41 into C30
    localparam [63:0]  K30_CHG_N = 64'd1000, K30_CHG_D = 64'd1_000_000 * 64'd47_000;
    localparam integer K30_CHG_SH = ratio_sh(K30_CHG_N, K30_CHG_D);
    localparam [11:0]  K30_CHG_K  = ratio_k(K30_CHG_N, K30_CHG_D);
    // R23 into C20
    localparam [63:0]  KC20_N = 64'd1000, KC20_D = 64'd33_000 * 64'd68;
    localparam integer KC20_SH = ratio_sh(KC20_N, KC20_D);
    localparam [11:0]  KC20_K  = ratio_k(KC20_N, KC20_D);
    // beta * Ib(R38) into C20
    localparam [63:0]  KC20_LIM_N = 64'd1000 * TR4_BETA, KC20_LIM_D = 64'd3300 * 64'd68;
    localparam integer KC20_LIM_SH = ratio_sh(KC20_LIM_N, KC20_LIM_D);
    localparam [11:0]  KC20_LIM_K  = ratio_k(KC20_LIM_N, KC20_LIM_D);
    // R23 / R38 = 10: the drop on R23 when TR4 limits the current
    localparam integer DROP_GAIN = TR4_BETA * 10;

    // Inputs held at the tick
    reg vbl = 1'b0, d4_on = 1'b0, d3_on = 1'b0, r16_on = 1'b0, d5_on = 1'b0;
    reg [2:0] vr3_s = 3'd0, vr4_s = 3'd0, vr5_s = 3'd0;
    always @(posedge clk) if (tick) begin
        vr3_s  <= vr3_code;
        vr4_s  <= vr4_code;
        vr5_s  <= vr5_code;
        vbl    <= ~IC94_pin4;
        d4_on  <= IC94_pin2;
        d3_on  <= IC94_pin6;
        r16_on <= ~IC94_pin8;
        d5_on  <= IC100_pin8;
    end

    reg signed [31:0] C18_D4_R25 = B3_INIT_MV * 1000 * 256;      // B3
    reg signed [31:0] C15_R22_TR3 = 32'sd5_000_000 * 256;        // X
    reg signed [31:0] C30_D5_R38 = 32'sd650_000 * 256;           // TR4 base side
    reg signed [31:0] C20_R23 = 32'sd5_000_000 * 256;            // across C20
    wire signed [31:0] b3 = C18_D4_R25, x = C15_R22_TR3, v30 = C30_D5_R38, vc20 = C20_R23;

    wire [13:0] KB_CHG_K = kb_chg_tab[vr5_s*14 +: 14];
    wire [13:0] KB_D3_K  = kb_d3_tab[vr3_s*14 +: 14];
    wire [13:0] KX_CHG_K = kx_chg_tab[vr4_s*14 +: 14];
    wire signed [31:0] VD3 = $signed(vd3_tab[vr3_s*32 +: 32]);

    // B3
    wire signed [31:0] b3_over = pos(b3 - VBE);
    wire signed [31:0] b3_next = b3
        + (d4_on  ? mulkv(KB_CHG_K, KB_CHG_SH,  pos(VS - b3))  : 32'sd0)
        + (d3_on  ? mulkv(KB_D3_K,  KB_D3_SH,   pos(VD3 - b3)) : 32'sd0)
        - (r16_on ? mulk(KB_R16_K,  KB_R16_SH,  pos(b3))       : 32'sd0)
        - (vbl    ? mulk(KB_BASE_K, KB_BASE_SH, b3_over)       : 32'sd0);

    // X: TR3 takes beta * Ib, or what R24 lets through when it saturates
    wire signed [31:0] ic_lin = mulk(KX_IC_K,  KX_IC_SH,  b3_over);
    wire signed [31:0] ic_sat = mulk(KX_SAT_K, KX_SAT_SH, pos(x - VSAT));
    wire signed [31:0] x_next = x + mulkv(KX_CHG_K, KX_CHG_SH, pos(VCC - x))
                              - (vbl ? (ic_lin < ic_sat ? ic_lin : ic_sat) : 32'sd0);

    // C30 and TR4's base current
    wire signed [31:0] v30_over = pos(v30 - VBE);
    wire signed [31:0] v30_next = v30
        + (d5_on ? mulk(K30_CHG_K, K30_CHG_SH, pos(VS - v30)) : 32'sd0)
        - mulk(KB_BASE_K, KB_BASE_SH, v30_over);

    // C20: charged from X through R23, as far as TR4 can sink. Falling, the
    // collector-base diode of TR4 carries the current, so no limit there.
    wire signed [31:0] dx      = x - vc20;
    wire signed [31:0] dv_free = dx[31] ? -mulk(KC20_K, KC20_SH, -dx) : mulk(KC20_K, KC20_SH, dx);
    wire signed [31:0] dv_lim  = mulk(KC20_LIM_K, KC20_LIM_SH, v30_over);
    wire               limited = dv_free > dv_lim;
    wire signed [31:0] vc20_next = vc20 + (limited ? dv_lim : dv_free);
    // TR5's base: on C20 while TR4 holds its far end, else X less R23's drop
    wire signed [47:0] drop = v30_over * DROP_GAIN;
    reg  signed [31:0] R23_C20_TR5 = 32'sd5_000_000 * 256;
    wire signed [31:0] base_next = limited ? x - drop[31:0] : vc20;

    always @(posedge clk) if (tick) begin
        C18_D4_R25  <= b3_next;
        C15_R22_TR3 <= x_next;
        C30_D5_R38  <= v30_next;
        C20_R23     <= vc20_next;
        R23_C20_TR5 <= base_next;
    end

    assign TR5_base_uv = R23_C20_TR5 >>> 8;
    assign C18_uv = b3 >>> 8;
    assign C15_uv = x >>> 8;
    assign C30_uv = v30 >>> 8;
endmodule
`default_nettype wire
