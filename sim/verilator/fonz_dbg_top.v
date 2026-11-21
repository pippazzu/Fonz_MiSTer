// SPDX-License-Identifier: GPL-3.0-or-later
// Debug wrapper for sim/verilator/sim_dbg.cpp: the whole machine plus
// hierarchical taps on the collision
// chain and the two shape generators. Simulation only; not part of the core.
`timescale 1ns/1ps
`default_nettype none
module fonz_dbg_top(
    input  wire        clk_sys, rst,
    input  wire        pad_left, pad_right, pad_accel, pad_coin, pad_start, pad_tilt,
    input  wire [15:0] joytrig, joyana_l, joyana_r,
    input  wire [ 1:0] stick_sel,
    input  wire        overlay_enable, rumble_enable,
    input  wire [39:0] pots,
    input  wire [15:0] prom_load,
    output wire        ce_pix, ce_xtal, ce_xtal2,
    output wire [ 7:0] grey,
    output wire        hs, vs, hb, vb,
    output wire [ 8:0] raster_h, raster_v,
    output wire        IC83_pin9_GAME_LATCH,
    output wire [23:0] game_digits,
    output wire [12:0] IC105_pin3_mv,
    output wire [15:0] rumble,
    // taps
    output wire [ 7:0] dbg_ic29,
    output wire        dbg_47_1, dbg_30a, dbg_30b, dbg_us1, dbg_us2, dbg_ls1, dbg_ls2, dbg_k20_5,
    output wire        dbg_addr_clear, dbg_lower_en_n,
    output wire [ 3:0] dbg_ic18,
    output wire [ 7:0] dbg_ic90, dbg_ic51, dbg_pos64_42,
    output wire [15:0] dbg_ic9_mv, dbg_ic106_mv,
    output wire        dbg_ic9_osc, dbg_ic106_osc, dbg_ic9_gate, dbg_ic106_gate
);
    assign dbg_ic9_mv    = dut.ic9.control_mv;
    assign dbg_ic106_mv  = dut.ic106.control_mv;
    assign dbg_ic9_osc   = dut.IC9_pin5_UPPER_OSC;
    assign dbg_ic106_osc = dut.IC106_pin5_LOWER_OSC;
    assign dbg_ic9_gate  = dut.IC94_pin12_VR1;
    assign dbg_ic106_gate= dut.IC100_pin2_VR9;
    fonz_machine_fpga #(.CLK_SYS_HZ(57220000)) dut(
        .clk_sys(clk_sys), .rst(rst),
        .pad_left(pad_left), .pad_right(pad_right), .pad_accel(pad_accel),
        .pad_coin(pad_coin), .pad_start(pad_start), .pad_tilt(pad_tilt),
        .joytrig(joytrig), .joyana_l(joyana_l), .joyana_r(joyana_r), .stick_sel(stick_sel),
        .overlay_enable(overlay_enable), .rumble_enable(rumble_enable), .pots(pots), .prom_load(prom_load),
        .ce_pix(ce_pix), .ce_xtal(ce_xtal), .ce_xtal2(ce_xtal2), .grey(grey),
        .hs(hs), .vs(vs), .hb(hb), .vb(vb), .raster_h(raster_h), .raster_v(raster_v),
        .IC83_pin9_GAME_LATCH(IC83_pin9_GAME_LATCH), .game_digits(game_digits),
        .IC105_pin3_mv(IC105_pin3_mv), .rumble(rumble));
    assign dbg_ic29   = {dut.board.core.scene.picture.collision.ic29b.q, dut.board.core.scene.picture.collision.ic29a.q};
    assign dbg_47_1   = dut.board.core.scene.picture.raster_video.video.IC47_pin1_IC29_pin1;
    assign dbg_30a    = dut.IC30_pin13_CRASH;
    assign dbg_30b    = dut.IC30_pin5_CRASH_HOLD;
    assign dbg_us1    = dut.board.core.scene.picture.raster_video.video.IC71_pin7_UPPER_SHAPE1;
    assign dbg_us2    = dut.board.core.scene.picture.raster_video.video.IC71_pin9_UPPER_SHAPE2;
    assign dbg_ls1    = dut.board.core.scene.picture.raster_video.video.IC108_pin7_IC6_pin10;
    assign dbg_ls2    = dut.board.core.scene.picture.raster_video.video.IC108_pin9_LOWER_SHAPE2;
    assign dbg_k20_5  = dut.board.core.scene.picture.raster_video.video.IC20_pin5_IC6_pin1;
    assign dbg_addr_clear = dut.board.core.scene.picture.upper.IC83_pin7_ADDR_CLEAR;
    assign dbg_lower_en_n = dut.board.core.scene.picture.lower.IC84_pin3_LOWER_ENABLE_n;
    assign dbg_ic18   = dut.board.core.scene.IC18_pin3_2_6_7;
    assign dbg_ic90   = {dut.board.core.scene.picture.upper.IC90_pin3_5_6_7, dut.board.core.scene.picture.upper.IC90_pin13_11_10_9};
    assign dbg_ic51   = {dut.board.core.scene.picture.upper.IC51_pin11_10_9_8, dut.board.core.scene.picture.upper.IC51_pin3_4_5_6};
    assign dbg_pos64_42 = {dut.board.core.scene.IC42_pin14_13_12_11, dut.board.core.scene.IC64_pin14_13_12_11};
endmodule
`default_nettype wire
