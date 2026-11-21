// SPDX-License-Identifier: GPL-3.0-or-later
// The whole Fonz machine on one clock, for the MiSTer core.
//
// fonz_board_fpga (the traced logic board) with everything around it:
//   * the timing parts the board exports as {A, B, /CLR} and expects back:
//     IC9 / IC106 shape oscillators, IC97 / IC102 / IC104 road monostables
//     with their transistor networks, IC30 (crash) and IC103 (antenna,
//     start) 74123s, IC98 / IC99 / IC105 556s;
//   * the cabinet: contact conditioning (RC + IC37 Schmitt), the coin
//     changeover switch, the photocoupler throttle into IC105 pin 3, and the
//     60 Hz mains sense at IC37 pin 10;
//   * the video: the resistor mixer as a grey level, the raster timing
//     pins, and the score / time overlay (a MiSTer addition);
//   * the PROM download from the MRA.
// Nothing here invents game behaviour: every signal into the board is one
// of its own pins.
//
// Pot settings follow the manual's adjustment page where it gives them
// (VR-4 midway, VR-10 for a 70 s game); the others are midway. Those are
// the factory settings, code 0 of each field of `pots`: the OSD's "Board
// adjustments" page (scripts/pot_settings.py, docs/POT_SETTINGS.md) can
// change VR1-VR11 and VR13 while the game runs. rtl/mister/fonz_core.v
// joins it to the framework.
//
// Wires are named by both ends (ICa_pinX_ICb_pinY), or by the driver pin and
// a signal name where a net has more than two ends. Board ports keep their
// names. IC count in this module: 74123 x2 (IC30, IC103; the IC9, IC106,
// IC97, IC102 and IC104 packages are inside their models), 556 x3 (inside
// fonz_556_timers); the logic board's own ICs are counted in
// rtl/fonz_board.v.
`timescale 1ns/1ps
`default_nettype none
module fonz_machine_fpga #(
    parameter integer CLK_SYS_HZ = 57_220_000
)(
    input  wire        clk_sys,
    input  wire        rst,
    // Pads, active high
    input  wire        pad_left, pad_right,
    input  wire        pad_accel,       // full throttle button
    input  wire        pad_coin, pad_start, pad_tilt,
    input  wire [15:0] joytrig,         // {RT,LT}, 0 when not available
    input  wire [15:0] joyana_l, joyana_r,
    input  wire [ 1:0] stick_sel,       // fonz_accel_input
    input  wire        overlay_enable,
    input  wire        rumble_enable,
    // Board pot settings, OSD codes, all 0 = factory (scripts/pot_settings.py)
    input  wire [39:0] pots,
    // PROM download: {we, addr[10:0], data[3:0]} (fonz_prom_comb)
    input  wire [15:0] prom_load,
    // Video
    output wire        ce_pix,          // one clk_sys per pixel (IC67 Q rising)
    output wire        ce_xtal,         // one clk_sys per crystal cycle (14.305 MHz)
    output wire        ce_xtal2,        // one clk_sys per crystal edge (28.61 MHz)
    output reg  [ 7:0] grey = 8'd0,
    output reg         hs = 1'b0,
    output reg         vs = 1'b0,
    output reg         hb = 1'b1,
    output reg         vb = 1'b1,
    output wire [ 8:0] raster_h, raster_v,
    // For simulation: IC83 pin 9 (low while a game runs), the time and
    // score digits {time, score}, IC105 pin 3 in mV
    output wire        IC83_pin9_GAME_LATCH,
    output wire [23:0] game_digits,
    output wire [12:0] IC105_pin3_mv,
    output wire [15:0] rumble
);
`include "fonz_pot_settings.vh"
    // ---- pot settings ----------------------------------------------------------
    // From the OSD, so from another clock domain: two registers. A code that
    // is caught changing for a clock only picks a neighbouring setting for
    // that clock, and each model takes its code at its own tick.
    reg [39:0] pots_meta = 40'd0, pots_s = 40'd0;
    always @(posedge clk_sys) begin
        pots_meta <= pots;
        pots_s    <= pots_meta;
    end
    wire [2:0] vr1_code  = pots_s[POT_VR1_LSB +: POT_VR1_W];
    wire [2:0] vr9_code  = pots_s[POT_VR9_LSB +: POT_VR9_W];
    wire [2:0] vr2_code  = pots_s[POT_VR2_LSB +: POT_VR2_W];
    wire [2:0] vr3_code  = pots_s[POT_VR3_LSB +: POT_VR3_W];
    wire [2:0] vr4_code  = pots_s[POT_VR4_LSB +: POT_VR4_W];
    wire [2:0] vr5_code  = pots_s[POT_VR5_LSB +: POT_VR5_W];
    wire [2:0] vr6_code  = pots_s[POT_VR6_LSB +: POT_VR6_W];
    wire [2:0] vr7_code  = pots_s[POT_VR7_LSB +: POT_VR7_W];
    wire [2:0] vr8_code  = pots_s[POT_VR8_LSB +: POT_VR8_W];
    wire [2:0] vr10_code = pots_s[POT_VR10_LSB +: POT_VR10_W];
    wire [1:0] vr13_code = pots_s[POT_VR13_LSB +: POT_VR13_W];
    wire [2:0] vr11_code = pots_s[POT_VR11_LSB +: POT_VR11_W];
    // VR-11, the throttle's upper limit: the full-grip wiper voltage
    reg  [12:0] VR11_full_mv = 13'd3061;
    always @(posedge clk_sys) VR11_full_mv <= pot_vr11(vr11_code);

    // ---- clocks ------------------------------------------------------------
    wire IC45_pin8_IC67_pin12;
    reg  xtal_seen = 1'b0;
    always @(posedge clk_sys) xtal_seen <= IC45_pin8_IC67_pin12;
    assign ce_xtal  = IC45_pin8_IC67_pin12 & ~xtal_seen;
    assign ce_xtal2 = IC45_pin8_IC67_pin12 ^ xtal_seen;

    // 100 kHz enable for the 556 cells. It restarts at VBLANK rising, so
    // IC105's once-a-frame throttle pulse, which places the player's bike,
    // ends on the same clock in every frame while the grip is still.
    localparam [63:0] CE556_INC = (64'd100_000 << 32) / CLK_SYS_HZ;
    reg [32:0] ce556_acc = 33'd0;
    reg        vblank_seen = 1'b0;
    wire       IC3_pin5_VBLANK;
    always @(posedge clk_sys) begin
        vblank_seen <= IC3_pin5_VBLANK;
        ce556_acc <= (IC3_pin5_VBLANK && !vblank_seen) ? 33'd0
                   : {1'b0, ce556_acc[31:0]} + CE556_INC[32:0];
    end
    wire ce556 = ce556_acc[32];

    // Mains sense at IC37 pin 10: 60 Hz, one level change every 1/120 s.
    localparam integer MAINS_HALF = CLK_SYS_HZ / 120;
    reg [23:0] mains_count = 24'd0;
    reg        IC37_pin10_IC95_pin6 = 1'b0;
    always @(posedge clk_sys)
        if (mains_count == MAINS_HALF - 1) begin
            mains_count <= 24'd0;
            IC37_pin10_IC95_pin6 <= ~IC37_pin10_IC95_pin6;
        end else
            mains_count <= mains_count + 24'd1;

    // ---- cabinet -------------------------------------------------------------
    wire [7:0] demand;
    wire       grip;
    fonz_accel_input accel_input(
        .joytrig(joytrig), .joyana_l(joyana_l), .joyana_r(joyana_r),
        .stick_sel(stick_sel), .full(pad_accel), .demand(demand), .grip(grip));

    wire CN16_IC37_pin13, CN17_IC37_pin5, CN18_IC37_pin3, CN1_IC37_pin1;
    wire CN21_IC38_pin1, CN20_IC38_pin13, CN_X_IC103_pin1;
    fonz_cabinet_inputs #(.CLK_HZ(CLK_SYS_HZ)) cabinet(
        .clk(clk_sys), .rst(rst),
        .pad_left(pad_left), .pad_right(pad_right), .pad_accel(grip),
        .pad_coin(pad_coin), .pad_start(pad_start), .pad_tilt(pad_tilt),
        .CN16_IC37_pin13(CN16_IC37_pin13), .CN17_IC37_pin5(CN17_IC37_pin5),
        .CN18_IC37_pin3(CN18_IC37_pin3), .CN1_IC37_pin1(CN1_IC37_pin1),
        .CN21_IC38_pin1(CN21_IC38_pin1), .CN20_IC38_pin13(CN20_IC38_pin13),
        .CN_X_IC103_pin1(CN_X_IC103_pin1));

    wire IC37_pin12_ACCEL, IC37_pin6_LEFT, IC37_pin4_RIGHT, IC37_pin2_IC82_pin2;
    wire R93_C60_IC38_pin1, R91_C59_IC38_pin13;
    fonz_contact_conditioning_fpga #(.CLK_SYS_HZ(CLK_SYS_HZ)) contacts(
        .clk_sys(clk_sys), .rst(rst),
        .CN16_IC37_pin13(CN16_IC37_pin13), .CN17_IC37_pin5(CN17_IC37_pin5),
        .CN18_IC37_pin3(CN18_IC37_pin3), .CN1_IC37_pin1(CN1_IC37_pin1),
        .CN21_IC38_pin1(CN21_IC38_pin1), .CN20_IC38_pin13(CN20_IC38_pin13),
        .IC37_pin12_ACCEL(IC37_pin12_ACCEL), .IC37_pin6_LEFT(IC37_pin6_LEFT),
        .IC37_pin4_RIGHT(IC37_pin4_RIGHT), .IC37_pin2_IC82_pin2(IC37_pin2_IC82_pin2),
        .R93_C60_IC38_pin1(R93_C60_IC38_pin1), .R91_C59_IC38_pin13(R91_C59_IC38_pin13));

    // Throttle: lamp at IC39 pin 3, photocell, TR10 into IC105 pin 3.
    wire        IC39_pin3_R110;
    wire [12:0] TR10_collector_IC105_pin3_mv;
    fonz_throttle #(.CEN_HZ(CLK_SYS_HZ)) throttle(
        .clk(clk_sys), .rst(rst), .cen(1'b1),
        .IC39_pin3_R110(IC39_pin3_R110), .demand(demand), .VR11_full_mv(VR11_full_mv),
        .VR11_wiper_R107_mv(), .R107_C77_R108_mv(), .R108_TR10_base_na(),
        .TR10_collector_IC105_pin3_mv(TR10_collector_IC105_pin3_mv));
    // mV to the 556 scale (32'h8000_0000 = 5 V): x 2^31 / 5000. Registered:
    // the voltage moves once a millisecond.
    reg  [12:0] TR10_IC105_pin3_mv = 13'd4615;
    reg  [44:0] TR10_IC105_pin3_scaled = 45'd0;
    always @(posedge clk_sys) begin
        TR10_IC105_pin3_mv     <= TR10_collector_IC105_pin3_mv;
        TR10_IC105_pin3_scaled <= TR10_IC105_pin3_mv * 32'd429_497;
    end
    wire [31:0] TR10_IC105_pin3 = TR10_IC105_pin3_scaled[31:0];
    assign IC105_pin3_mv = TR10_IC105_pin3_mv;

    // ---- timing parts ---------------------------------------------------------
    wire [2:0] ic9a_ab_clear_n, ic9b_ab_clear_n, ic106a_ab_clear_n, ic106b_ab_clear_n;
    wire [2:0] ic97b_ab_clear_n, ic97a_ab_clear_n, ic102b_ab_clear_n, ic102a_ab_clear_n;
    wire [2:0] ic104b_ab_clear_n, ic104a_ab_clear_n;
    wire [2:0] ic30a_ab_clear_n, ic30b_ab_clear_n, ic103a_ab_clear_n, ic103b_ab_clear_n;
    wire IC9_pin13_IC9_pin9, IC9_pin5_UPPER_OSC;
    wire IC106_pin13_IC106_pin9, IC106_pin5_LOWER_OSC;
    wire IC97_pin5_IC97_pin1, IC97_pin13_IC102_pin9, IC102_pin5_LEFT_KERB;
    wire IC102_pin13_ROAD, IC104_pin5_RIGHT_KERB, IC104_pin13_IC20_pin9;
    wire IC30_pin13_CRASH, IC30_pin5_CRASH_HOLD;
    wire IC103_pin13_ANTENNA, IC103_pin5_START;
    wire IC98_pin5_IC84_pin4, IC99_pin5_IC100_pin9, IC99_pin9_IC84_pin5;
    wire IC105_pin5_THROTTLE, IC105_pin9_IC82_pin8;
    // Board outputs that drive the analogue networks.
    wire IC94_pin12_VR1, IC94_pin10_R15, IC100_pin2_VR9;
    wire IC100_pin6_TR7, IC100_pin4_C41;
    // The road swing (rtl/analog/fonz_road_swing.v)
    wire IC94_pin2_VR5, IC94_pin6_R21, IC94_pin8_R16, IC100_pin8_D5;
    wire IC4_pin5_HBLANK, IC27_pin11_HSYNC_n, IC25_pin12_VSYNC_n;
    wire IC67_pin3_PIXEL_CLK;
    wire IC99_pin4_pin10_RESET_n, IC105_pin6_TRIGGER_n;
    wire IC100_pin10_SOLENOID, IC17_pin2_CN23;

    fonz_shape_oscillator #(.CLK_HZ(CLK_SYS_HZ)) ic9(
        .clk(clk_sys), .first_ab_clear_n(ic9a_ab_clear_n), .second_ab_clear_n(ic9b_ab_clear_n),
        .gate_oc(IC94_pin12_VR1), .tr2_base_oc(IC94_pin10_R15),
        .vr_code(vr1_code), .vr2_code(vr2_code),
        .first_q(IC9_pin13_IC9_pin9), .first_q_n(), .second_q(IC9_pin5_UPPER_OSC),
        .second_q_n(), .control_mv());
    fonz_shape_oscillator #(.CLK_HZ(CLK_SYS_HZ)) ic106(
        .clk(clk_sys), .first_ab_clear_n(ic106a_ab_clear_n), .second_ab_clear_n(ic106b_ab_clear_n),
        .gate_oc(IC100_pin2_VR9), .tr2_base_oc(IC94_pin10_R15),
        .vr_code(vr9_code), .vr2_code(vr2_code),
        .first_q(IC106_pin13_IC106_pin9), .first_q_n(), .second_q(IC106_pin5_LOWER_OSC),
        .second_q_n(), .control_mv());

    fonz_road_timing #(.CLK_HZ(CLK_SYS_HZ)) road(
        .clk(clk_sys), .IC3_pin5(IC3_pin5_VBLANK),
        .IC100_pin6(IC100_pin6_TR7), .IC100_pin4(IC100_pin4_C41),
        .IC94_pin2(IC94_pin2_VR5), .IC94_pin6(IC94_pin6_R21), .IC94_pin8(IC94_pin8_R16),
        .IC100_pin8(IC100_pin8_D5),
        .vr3_code(vr3_code), .vr4_code(vr4_code), .vr5_code(vr5_code),
        .vr6_code(vr6_code), .vr7_code(vr7_code), .vr8_code(vr8_code),
        .ic97b_ab_clear_n(ic97b_ab_clear_n), .ic97a_ab_clear_n(ic97a_ab_clear_n),
        .ic102b_ab_clear_n(ic102b_ab_clear_n), .ic102a_ab_clear_n(ic102a_ab_clear_n),
        .ic104b_ab_clear_n(ic104b_ab_clear_n), .ic104a_ab_clear_n(ic104a_ab_clear_n),
        .IC97_pin5(IC97_pin5_IC97_pin1), .IC97_pin13(IC97_pin13_IC102_pin9),
        .IC102_pin5(IC102_pin5_LEFT_KERB), .IC102_pin13(IC102_pin13_ROAD),
        .IC104_pin5(IC104_pin5_RIGHT_KERB), .IC104_pin13(IC104_pin13_IC20_pin9),
        .TR5_base_uv(), .TR6_base_uv(), .TR7_base_uv(), .TR8_base_uv());

    // IC30: A half R28 47k / C17 47 uF, B half R31 47k / C22 220 uF.
    fonz_74123 #(.CLK_HZ(CLK_SYS_HZ), .R_OHM(47_000), .C_PF(64'd47_000_000)) ic30a(
        .clk(clk_sys), .a(ic30a_ab_clear_n[2]), .b(ic30a_ab_clear_n[1]), .clr_n(ic30a_ab_clear_n[0]),
        .q(IC30_pin13_CRASH), .q_n());
    fonz_74123 #(.CLK_HZ(CLK_SYS_HZ), .R_OHM(47_000), .C_PF(64'd220_000_000)) ic30b(
        .clk(clk_sys), .a(ic30b_ab_clear_n[2]), .b(ic30b_ab_clear_n[1]), .clr_n(ic30b_ab_clear_n[0]),
        .q(IC30_pin5_CRASH_HOLD), .q_n());
    // IC103: A half (antenna) 47k / 220 uF, B half (coin start) 47k / 100 uF.
    fonz_74123 #(.CLK_HZ(CLK_SYS_HZ), .R_OHM(47_000), .C_PF(64'd220_000_000)) ic103a(
        .clk(clk_sys), .a(ic103a_ab_clear_n[2]), .b(ic103a_ab_clear_n[1]), .clr_n(ic103a_ab_clear_n[0]),
        .q(IC103_pin13_ANTENNA), .q_n());
    fonz_74123 #(.CLK_HZ(CLK_SYS_HZ), .R_OHM(47_000), .C_PF(64'd100_000_000)) ic103b(
        .clk(clk_sys), .a(ic103b_ab_clear_n[2]), .b(ic103b_ab_clear_n[1]), .clr_n(ic103b_ab_clear_n[0]),
        .q(IC103_pin5_START), .q_n());

    fonz_556_timers #(.CE_HZ(100_000)) timers(
        .clk(clk_sys), .ce(ce556),
        .IC30_pin12_IC99_pin4_pin10(IC99_pin4_pin10_RESET_n),
        .IC25_pin12_IC105_pin6(IC105_pin6_TRIGGER_n),
        .TR10_IC105_pin3(TR10_IC105_pin3), .vr10_code(vr10_code),
        .IC98_pin5_IC84_pin4(IC98_pin5_IC84_pin4),
        .IC99_pin5_IC100_pin9(IC99_pin5_IC100_pin9),
        .IC99_pin9_IC84_pin5(IC99_pin9_IC84_pin5),
        .IC105_pin5_THROTTLE(IC105_pin5_THROTTLE),
        .IC105_pin9_IC82_pin8(IC105_pin9_IC82_pin8));

    // ---- the logic board ---------------------------------------------------------
    wire IC5_pin11_R13, IC7_pin8_R26, IC7_pin12_VR13;
    wire [5:0] digit_enable;
    wire [6:0] segments_abcdefg;
    fonz_board_fpga #(.CLK_SYS_HZ(CLK_SYS_HZ)) board(
        .clk_sys(clk_sys), .rst(rst), .ce_pix(ce_pix), .ic45_8(IC45_pin8_IC67_pin12),
        .prom_clk(clk_sys), .prom_load(prom_load),
        .ic37_12(IC37_pin12_ACCEL), .ic37_6(IC37_pin6_LEFT),
        .ic37_4(IC37_pin4_RIGHT), .ic37_2(IC37_pin2_IC82_pin2),
        .ic37_10(IC37_pin10_IC95_pin6),
        .ic105_5(IC105_pin5_THROTTLE), .ic105_9(IC105_pin9_IC82_pin8),
        .ic9_5(IC9_pin5_UPPER_OSC), .ic106_5(IC106_pin5_LOWER_OSC),
        .ic9_13(IC9_pin13_IC9_pin9), .ic106_13(IC106_pin13_IC106_pin9),
        .ic98_5(IC98_pin5_IC84_pin4), .ic99_9(IC99_pin9_IC84_pin5), .ic99_5(IC99_pin5_IC100_pin9),
        .ic97_5(IC97_pin5_IC97_pin1), .ic97_13(IC97_pin13_IC102_pin9),
        .ic102_5(IC102_pin5_LEFT_KERB), .ic102_13(IC102_pin13_ROAD),
        .ic104_5(IC104_pin5_RIGHT_KERB), .ic104_13(IC104_pin13_IC20_pin9),
        .ic30_13(IC30_pin13_CRASH), .ic30_5(IC30_pin5_CRASH_HOLD),
        .ic38_1(R93_C60_IC38_pin1), .ic38_13(R91_C59_IC38_pin13),
        .ic103_13(IC103_pin13_ANTENNA), .ic103_5(IC103_pin5_START),
        .antenna_logic(CN_X_IC103_pin1),
        .ic5_11(IC5_pin11_R13), .ic7_8(IC7_pin8_R26), .ic7_12(IC7_pin12_VR13),
        .IC67_pin3_PIXEL_CLK(IC67_pin3_PIXEL_CLK), .IC4_pin5_HBLANK(IC4_pin5_HBLANK),
        .IC27_pin11_HSYNC_n(IC27_pin11_HSYNC_n), .IC3_pin5_VBLANK(IC3_pin5_VBLANK),
        .IC25_pin12_VSYNC_n(IC25_pin12_VSYNC_n),
        .digit_enable(digit_enable), .segments_abcdefg(segments_abcdefg),
        .ic9a_ab_clear_n(ic9a_ab_clear_n), .ic9b_ab_clear_n(ic9b_ab_clear_n),
        .ic106a_ab_clear_n(ic106a_ab_clear_n), .ic106b_ab_clear_n(ic106b_ab_clear_n),
        .ic97b_ab_clear_n(ic97b_ab_clear_n), .ic97a_ab_clear_n(ic97a_ab_clear_n),
        .ic102b_ab_clear_n(ic102b_ab_clear_n), .ic102a_ab_clear_n(ic102a_ab_clear_n),
        .ic104b_ab_clear_n(ic104b_ab_clear_n), .ic104a_ab_clear_n(ic104a_ab_clear_n),
        .ic30a_ab_clear_n(ic30a_ab_clear_n), .ic30b_ab_clear_n(ic30b_ab_clear_n),
        .ic103a_ab_clear_n(ic103a_ab_clear_n), .ic103b_ab_clear_n(ic103b_ab_clear_n),
        .ic17_4(), .ic17_6(), .ic17_8(), .ic39_3(IC39_pin3_R110), .ic60_3(),
        .ic100_10(IC100_pin10_SOLENOID),
        .ic94_2(IC94_pin2_VR5), .ic94_4(), .ic94_6(IC94_pin6_R21), .ic94_8(IC94_pin8_R16),
        .ic94_10(IC94_pin10_R15),
        .ic94_12(IC94_pin12_VR1),
        .ic100_2(IC100_pin2_VR9), .ic100_4(IC100_pin4_C41),
        .ic100_6(IC100_pin6_TR7), .ic100_8(IC100_pin8_D5),
        .ic17_2(IC17_pin2_CN23), .ic99_10(), .ic98_4(), .ic99_4(IC99_pin4_pin10_RESET_n),
        .ic105_4(), .ic105_6(IC105_pin6_TRIGGER_n), .ic105_10(),
        .ic38_3(), .ic38_11(), .ic38_8(), .ic59_2(),
        .ic83_9(IC83_pin9_GAME_LATCH), .ic83_13(), .ic83_4(), .ic101_11(), .ic81_6(), .ic82_13(), .ic82_10(),
        .time_tens(game_digits[23:20]), .time_units(game_digits[19:16]),
        .score_units(game_digits[3:0]), .score_tens(game_digits[7:4]),
        .score_hundreds(game_digits[11:8]), .score_thousands(game_digits[15:12]),
        .raster_h(raster_h), .raster_v(raster_v));

    // ---- video -------------------------------------------------------------------
    // The mixer at each VR13 position (pot_vr13: 1 = mid, factory), one
    // picked by the OSD code.
    wire [7:0] mixer_grey_0, mixer_grey_1, mixer_grey_2;
    wire raster_hs, raster_vs, raster_hb, raster_vb;
    fonz_video_mixer_fpga #(.VR13_SETTING(pot_vr13(0))) mixer(.clk_sys(clk_sys), .rst(rst),
        .IC5_pin11_R13(IC5_pin11_R13), .IC7_pin8_R26(IC7_pin8_R26),
        .IC7_pin12_VR13(IC7_pin12_VR13), .grey(mixer_grey_0), .csync_n());
    fonz_video_mixer_fpga #(.VR13_SETTING(pot_vr13(1))) mixer_vr13_1(.clk_sys(clk_sys), .rst(rst),
        .IC5_pin11_R13(IC5_pin11_R13), .IC7_pin8_R26(IC7_pin8_R26),
        .IC7_pin12_VR13(IC7_pin12_VR13), .grey(mixer_grey_1), .csync_n());
    fonz_video_mixer_fpga #(.VR13_SETTING(pot_vr13(2))) mixer_vr13_2(.clk_sys(clk_sys), .rst(rst),
        .IC5_pin11_R13(IC5_pin11_R13), .IC7_pin8_R26(IC7_pin8_R26),
        .IC7_pin12_VR13(IC7_pin12_VR13), .grey(mixer_grey_2), .csync_n());
    wire [7:0] mixer_grey = vr13_code == 2'd1 ? mixer_grey_1 :
                            vr13_code == 2'd2 ? mixer_grey_2 : mixer_grey_0;
    fonz_video_timing_fpga timing(.clk_sys(clk_sys), .rst(rst),
        .IC67_pin3_PIXEL_CLK(IC67_pin3_PIXEL_CLK), .IC4_pin5_HBLANK(IC4_pin5_HBLANK),
        .IC27_pin11_HSYNC_n(IC27_pin11_HSYNC_n), .IC3_pin5_VBLANK(IC3_pin5_VBLANK),
        .IC25_pin12_VSYNC_n(IC25_pin12_VSYNC_n),
        .pxl_clk(), .hs(raster_hs), .vs(raster_vs), .hb(raster_hb), .vb(raster_vb),
        .lhbl(), .lvbl(), .csync_n());

    // Score and time digits drawn into the active picture. The active area
    // starts at H=80, V=16 (docs/VIDEO_TIMING.md).
    wire overlay_on;
    fonz_score_overlay #(.X0(9'd88), .Y0(9'd20)) overlay(
        .clk(clk_sys), .enable(overlay_enable),
        .raster_h(raster_h), .raster_v(raster_v),
        .digit_enable(digit_enable), .segments_abcdefg(segments_abcdefg),
        .overlay_on(overlay_on), .digits_abcdefg());

    // Two samples a pixel, one a crystal cycle. At ce_xtal the crystal has
    // just risen, so the board's nets still hold the settled state of the
    // half pixel that is ending. The board gates its video with IC67 Q, so
    // some areas (the off-road grey) alternate every half pixel; the
    // monitor's video bandwidth blurs that into an even tone. Each output
    // pixel is the mean of its two halves, sent at ce_pix (IC67 Q rising,
    // two clk_sys after the second half was sampled).
    reg [7:0] half_now = 8'd0, half_prev = 8'd0;
    always @(posedge clk_sys)
        if (ce_xtal) begin
            half_prev <= half_now;
            half_now  <= mixer_grey;
        end
    wire [8:0] pixel_sum = half_now + half_prev;
    always @(posedge clk_sys)
        if (ce_pix) begin
            grey <= (overlay_on && !raster_hb && !raster_vb) ? 8'd255 : pixel_sum[8:1];
            hs <= raster_hs;
            vs <= raster_vs;
            hb <= raster_hb;
            vb <= raster_vb;
        end

    fonz_rumble crash_rumble(.clk(clk_sys), .enable(rumble_enable),
        .IC100_pin10_SOLENOID(IC100_pin10_SOLENOID), .IC17_pin2_CN23(IC17_pin2_CN23),
        .rumble(rumble));
endmodule
`default_nettype wire
