#!/bin/sh
# Frame-by-frame equivalence of the event-model board and fonz_board_fpga.
# Usage (from the repository root): sh sim/board_equiv/run.sh [FRAMES]
set -e
FRAMES=${1:-8}
mkdir -p build
python3 scripts/make_fpga_board.py --check
iverilog -g2012 -DFRAMES=$FRAMES $IVFLAGS -o build/board_equiv.vvp -s tb_board_equiv \
    rtl/fonz_*.v rtl/ttl/fonz_ttl.v \
    rtl/fpga/*.v rtl/ttl/fonz_ttl_ce.v \
    rtl/ttl/fonz_74192_sync.v \
    sim/board_equiv/standins.v sim/board_equiv/tb_board_equiv.v
vvp -n build/board_equiv.vvp
