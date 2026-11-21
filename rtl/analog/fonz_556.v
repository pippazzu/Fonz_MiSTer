// SPDX-License-Identifier: GPL-3.0-or-later
// One half of a 556 (NE555 cell) with its RC timing network, integrated in
// discrete time on a clock enable.
//
// Network, as drawn on the main schematic:
//
//   +5V --RA-- DISCH --RB-- CAP --C-- GND,   THRESHOLD on CAP
//
// ASTABLE=1: TRIGGER is also on CAP (R39/R43/C29 style). trig_n is ignored.
// ASTABLE=0: monostable. TRIGGER is the digital input trig_n, RB is 0 and
//            DISCH sits on CAP (R100/C68 style).
//
// Cell behaviour (bipolar 555):
//   /RESET low          -> OUT low, DISCH on (dominates).
//   TRIGGER < VCTL/2    -> OUT high, DISCH off (dominates THRESHOLD).
//   THRESHOLD > VCTL    -> OUT low, DISCH on.
// VCTL is pin 3/11. Unloaded it is 2/3 Vcc (internal 5k/5k/5k divider); a
// caller with a control network passes its voltage on vctl.
//
// Voltages are unsigned fixed point, 32'h8000_0000 = Vcc (5 V). With
// DISCH off the capacitor relaxes toward Vcc with tau=(RA+RB)C; with DISCH
// on, toward 0 with tau=RB*C (immediately when RB is 0). Each ce tick is
// 1/CE_HZ seconds and applies v += (target - v) * dt/tau, with dt/tau held
// as a 40-bit binary fraction. That needs tau > 256/CE_HZ.
//
// Integer parameters only (ohms, nanofarads, Hz), so Quartus needs no
// `real` support: dt/tau = 1/(CE_HZ*R*C) is formed in 64-bit integers as
// 2^40 * (1e9/CE_HZ) / (R_ohm * C_nF). CE_HZ must divide 1e9.
//
// RA_POT=10: RA is RA_OHM plus VR10, whose setting is the OSD code ra_code
// (scripts/pot_settings.py, 0 = factory); the charge coefficient comes from
// a small table, one entry a code. RA_POT=0: ra_code is ignored.
//
// A digital trigger is taken as below VCTL/2 when low and above it when
// high; this holds for TTL levels while VCTL stays under about 4.8 V.
`timescale 1ns/1ps
`default_nettype none
module fonz_556_half #(
    parameter integer RA_OHM  = 220_000,
    parameter integer RB_OHM  = 220_000,
    parameter integer C_NF    = 4_700,     // 4.7 uF
    parameter integer CE_HZ   = 100_000,
    parameter integer ASTABLE = 1,
    parameter integer RA_POT  = 0
)(
    input  wire        clk,
    input  wire        ce,
    input  wire        reset_n,  // pin 4 / 10
    input  wire        trig_n,   // pin 6 / 8 when ASTABLE=0; low = triggered
    input  wire [31:0] vctl,     // pin 3 / 11 voltage, same scale as v
    input  wire [2:0]  ra_code,  // pot in RA (RA_POT), OSD code
    output reg         q = 1'b0, // pin 5 / 9
    output reg  [31:0] v = 32'd0 // capacitor (threshold) node
);
    localparam [31:0] VCC  = 32'h8000_0000;
    localparam [63:0] NUM = (64'd1 << 40) * (64'd1_000_000_000 / CE_HZ);
`include "fonz_pot_settings.vh"
    function integer ra_ohm(input integer code);
        ra_ohm = RA_OHM + (RA_POT == 10 ? pot_vr10_ohm(code) : 0);
    endfunction
    localparam [63:0] DEN_DISCH  = 64'd1 * RB_OHM * C_NF;
    localparam [63:0] K_DISCH64  = (RB_OHM > 0) ? (NUM + DEN_DISCH / 2) / DEN_DISCH : 64'd0;
    localparam [31:0] K_DISCH  = K_DISCH64[31:0];
    wire [8*32-1:0] k_charge_tab;
    genvar gi;
    generate for (gi = 0; gi < 8; gi = gi + 1) begin : ra_tab
        localparam [63:0] DEN_CHARGE = (64'd1 * ra_ohm(gi) + RB_OHM) * C_NF;
        localparam [63:0] K_CHARGE64 = (NUM + DEN_CHARGE / 2) / DEN_CHARGE;
        assign k_charge_tab[gi*32 +: 32] = K_CHARGE64[31:0];
    end endgenerate
    reg [2:0] ra_s = 3'd0;
    always @(posedge clk) if (ce) ra_s <= (RA_POT != 0) ? ra_code : 3'd0;
    wire [31:0] K_CHARGE = k_charge_tab[ra_s*32 +: 32];

    wire [31:0] upper = vctl;
    wire [31:0] lower = {1'b0, vctl[31:1]};
    wire trig_low  = ASTABLE ? (v < lower) : ~trig_n;
    wire thr_high  = v > upper;
    wire q_next    = !reset_n ? 1'b0 : trig_low ? 1'b1 : thr_high ? 1'b0 : q;
    // The capacitor follows the output as it was at the last tick (one tick,
    // 10 us, behind the comparators), so a step reads only registers that
    // change at the tick and may take several clocks to settle (multicycle
    // paths in mister/analog_multicycle.sdc).
    wire disch     = ~q;

    wire signed [32:0] diff = disch ? -$signed({1'b0, v}) : $signed({1'b0, VCC - v});
    wire [31:0]        k    = disch ? K_DISCH : K_CHARGE;
    wire signed [65:0] prod = diff * $signed({1'b0, k});
    wire signed [65:0] prod_s = prod >>> 40;
    wire signed [33:0] step = $signed(prod_s[33:0]);  // |step| < 2^32
    wire signed [33:0] v_sum = $signed({2'b00, v}) + step;

    always @(posedge clk)
        if (ce) begin
            q <= q_next;
            if (disch && RB_OHM == 0) v <= 32'd0;
            else if (v_sum < 0)        v <= 32'd0;
            else if (v_sum > $signed({2'b00, VCC})) v <= VCC;
            else                        v <= v_sum[31:0];
        end
endmodule
`default_nettype wire
