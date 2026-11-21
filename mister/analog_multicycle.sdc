# SPDX-License-Identifier: GPL-3.0-or-later
# Multicycle paths of the analogue models (docs/MISTER_CORE.md, "Fitting and timing").
#
# Each network below is stepped on a slow tick: 1 us for the shape
# oscillators and the road networks, 10 us for the 556 cells; clk is
# 57.22 MHz, so at least 57 clocks pass between steps. Every register a
# step reads is either the network's own state or an input held at the tick
# (the OSD pot codes among them: sync_vr*, vr*_s, ra_s),
# and the state registers load only at the tick, so a step may take up to
# four clocks to settle.

# IC9 / IC106 control networks (rtl/analog/fonz_shape_oscillator.v)
set shape_state [get_registers {*fonz_shape_oscillator:*|C11_charge* *fonz_shape_oscillator:*|C10_plus_R6_R8_R7*}]
set shape_from  [get_registers {*fonz_shape_oscillator:*|C11_charge* *fonz_shape_oscillator:*|C10_plus_R6_R8_R7* *fonz_shape_oscillator:*|sync_gate* *fonz_shape_oscillator:*|sync_tr2* *fonz_shape_oscillator:*|sync_clr* *fonz_shape_oscillator:*|sync_vr*}]
set_multicycle_path -setup -end 4 -from $shape_from -to $shape_state
set_multicycle_path -hold  -end 3 -from $shape_from -to $shape_state

# Road base networks (rtl/analog/fonz_road_timing.v) and the swing
# (rtl/analog/fonz_road_swing.v)
set road_state [get_registers {*fonz_road_timing:*|C82_D6_R55* *fonz_road_timing:*|C33_D7_R55* *fonz_road_tr78:*|N1* *fonz_road_tr78:*|VC*}]
set road_from  [get_registers {*fonz_road_timing:*|C82_D6_R55* *fonz_road_timing:*|C33_D7_R55* *fonz_road_tr78:*|N1* *fonz_road_tr78:*|VC* *fonz_road_timing:*|s_on* *fonz_road_timing:*|tr7_rel* *fonz_road_timing:*|tr8_rel* *fonz_road_timing:*|vr6_s* *fonz_road_tr78:*|vr_s*}]
set_multicycle_path -setup -end 4 -from $road_from -to $road_state
set_multicycle_path -hold  -end 3 -from $road_from -to $road_state
set swing_state [get_registers {*fonz_road_swing:*|C18_D4_R25* *fonz_road_swing:*|C15_R22_TR3* *fonz_road_swing:*|C30_D5_R38* *fonz_road_swing:*|C20_R23* *fonz_road_swing:*|R23_C20_TR5*}]
set swing_from  [get_registers {*fonz_road_swing:*|C18_D4_R25* *fonz_road_swing:*|C15_R22_TR3* *fonz_road_swing:*|C30_D5_R38* *fonz_road_swing:*|C20_R23* *fonz_road_swing:*|vbl* *fonz_road_swing:*|d4_on* *fonz_road_swing:*|d3_on* *fonz_road_swing:*|r16_on* *fonz_road_swing:*|d5_on* *fonz_road_swing:*|vr3_s* *fonz_road_swing:*|vr4_s* *fonz_road_swing:*|vr5_s*}]
set_multicycle_path -setup -end 4 -from $swing_from -to $swing_state
set_multicycle_path -hold  -end 3 -from $swing_from -to $swing_state

# 556 cells (rtl/analog/fonz_556.v): the capacitor step reads v and q
set t556_state [get_registers {*fonz_556_half:*|v[*]*}]
set t556_from  [get_registers {*fonz_556_half:*|v[*]* *fonz_556_half:*|q* *fonz_556_half:*|ra_s*}]
set_multicycle_path -setup -end 4 -from $t556_from -to $t556_state
set_multicycle_path -hold  -end 3 -from $t556_from -to $t556_state
