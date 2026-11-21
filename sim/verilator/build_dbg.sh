#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Build the debug Verilator model: the whole machine under fonz_dbg_top,
# which taps the collision chain and the shape generators (docs/COLLISION.md).
# Run from the repository root. Same sources as build.sh plus the wrapper.
#
#   bash sim/verilator/build_dbg.sh
#   build/vl_dbg/Vfonz_dbg_top frames=800 coin=300 accel=420-800 chase=480 every=10 outdir=DIR
set -e
verilator --cc --exe --build -j 4 -O3 --x-assign fast --x-initial fast \
    -Wno-fatal -Wno-lint -Wno-style -Wno-TIMESCALEMOD \
    -Irtl/analog -DFONZ_CLK_SYS_HZ=57220000 \
    --top-module fonz_dbg_top --Mdir build/vl_dbg \
    sim/verilator/fonz_dbg_top.v \
    rtl/mister/fonz_machine_fpga.v rtl/mister/fonz_score_overlay.v rtl/mister/fonz_rumble.v \
    rtl/fpga/*.v rtl/analog/fonz_74123.v rtl/analog/fonz_556.v rtl/analog/fonz_556_timers.v \
    rtl/analog/fonz_road_timing.v rtl/analog/fonz_road_swing.v rtl/analog/fonz_shape_oscillator.v \
    rtl/ttl/*.v rtl/fonz_cabinet_inputs.v rtl/fonz_accel_input.v rtl/fonz_throttle.v \
    "$PWD/sim/verilator/sim_dbg.cpp"
