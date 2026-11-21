#!/bin/sh
# Check: the synchronous 74192 against the event model.
# Run from the repository root after scripts/extract_proms.py. Needs iverilog.
set -e
B=build/sim74192
mkdir -p $B
# Transcription TTL library without the event 74192, for the sync build.
awk '/^module fonz_74192\(/{skip=1} !skip{print} skip&&/^endmodule/{skip=0}' \
    rtl/ttl/fonz_ttl.v > $B/ttl_no74192.v
UPPER="rtl/fonz_upper_shape.v rtl/fonz_motion.v rtl/fonz_shape_address.v"
iverilog -g2005 -o $B/states sim/74192/tb_states.v rtl/ttl/fonz_ttl.v rtl/ttl/fonz_74192_sync.v
vvp -n $B/states | grep -q "states: .* 0 errors" || { vvp -n $B/states; exit 1; }
vvp -n $B/states | grep "states:"
iverilog -g2005 -o $B/cell sim/74192/tb_cell.v rtl/ttl/fonz_ttl.v rtl/ttl/fonz_74192_sync.v
vvp -n $B/cell
iverilog -g2005 -s tb -Ptb.OUT=\"$B/event.txt\" -o $B/event \
    sim/74192/tb_upper_shape.v rtl/ttl/fonz_ttl.v $UPPER
iverilog -g2005 -s tb -Ptb.OUT=\"$B/sync.txt\" -o $B/sync \
    sim/74192/tb_upper_shape.v $B/ttl_no74192.v rtl/ttl/fonz_74192_sync.v \
    sim/74192/shim_74192_sync.v $UPPER
vvp -n $B/event
vvp -n $B/sync
if cmp -s $B/event.txt $B/sync.txt; then
    echo "upper shape: event and sync traces identical ($(wc -l < $B/event.txt) changes)"
else
    echo "upper shape: traces differ"; diff $B/event.txt $B/sync.txt | head -20; exit 1
fi
# Timer reload loop: event model closed with zero delay against the sync
# cell with IC82.13 registered. Same values in the same order; each reload
# may land one clk later, nothing else may move.
iverilog -g2005 -DEVENT -Ptb_timer.OUT=\"$B/timer_event.txt\" -o $B/timer_event \
    sim/74192/tb_timer.v rtl/ttl/fonz_ttl.v
iverilog -g2005 -Ptb_timer.OUT=\"$B/timer_sync.txt\" -o $B/timer_sync \
    sim/74192/tb_timer.v rtl/ttl/fonz_ttl.v rtl/ttl/fonz_74192_sync.v
vvp -n $B/timer_event
vvp -n $B/timer_sync
paste -d' ' $B/timer_event.txt $B/timer_sync.txt | awk '
    NF!=4 || $2!=$4 {bad++}
    {o=$3-$1; if (o==1) late++; else if (o!=0) bad++}
    END {
        if (bad) {print "timer: sequences differ"; exit 1}
        printf "timer: same %d values; %d reloads one clk later, nothing else moved\n", NR, late
    }'
