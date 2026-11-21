// SPDX-License-Identifier: GPL-3.0-or-later
// Road monostables IC97 / IC102 / IC104 (three 74123 packages, six halves)
// with the transistor networks that set four of their widths.
//
// REFERENCE MODEL (simulation only). The control voltages are integrated with `real`
// arithmetic on a 1 us step, so this module is not synthesisable. The
// pulses themselves come from fonz_74123_core (rtl/analog/fonz_74123.v),
// clocked by the crystal. rtl/analog/fonz_road_timing.v is the
// synthesisable copy (fixed point and a width table), checked against this
// one by tests/tb_road_timing.v.
//
// Chain, each half triggered on A falling (B and /CLR are +5 V):
//   IC27.11 (H=32, once a line) -> 97B -> 97A -> 102B -> 102A -> 104B -> 104A
//   97B  delay to the left road edge     C27||C28 = 44 nF, Rext R40 1k from TR5
//   97A  short gap                        C23 100 pF, R36 10k to +5 V
//   102B left kerb                        C46 100 pF, Rext R72 3.3k (||P4) from TR7
//   102A road width                       C42||C43 = 9400 pF, Rext R58 2.2k (||P3) from TR6
//   104B right kerb                       100 pF, Rext R98 3.3k (||P5) from TR8
//   104A short gap, its end sets IC20     C55 100 pF, R80 10k to +5 V
//
// Which transistor feeds which Rext was followed on the native scan
// (scripts/trace_net.py, 8 November 2026). It differs from an earlier reading:
//   TR5 emitter, R40 1k   -> IC97B pin 7   (x~5312 down, y~4067 left, x~2713 up, y~3789 left)
//   TR6 emitter, P3||R58  -> IC102A        (y~3755 right, x~6286 up to y~3416)
//   TR7 emitter, P4||R72  -> IC102B pin 7  (x~5665 up, y~3821, x~5900 up to y~3526)
//   TR8 emitter, P5||R98  -> IC104B pin 7  (x~6600 up, y~3527 right to x~6821)
// TR6, TR7 and TR8 are emitter followers on the +5 V rail with 100k/68k/68k
// emitter pull-ups (R57/R71/R97).
//
// Control networks (all reset once a frame by IC3B, V=0..15):
//   TR2 (2SA484) switches +5 V onto one line while IC94.10 = NOT IC3.5 is
//   low. That line feeds D6/D7 (TR6), D8/D9 (TR7) and D10/D11 (TR8). So the
//   base capacitors are charged in V=0..15 and decay through the frame:
//   lower lines get a lower base voltage, so wider road and kerbs (the
//   perspective in the footage).
//   TR6: D6 -> A (C82 2.2u, R55 3.3k to B, 3.3k + VR6 to ground, R56 to base);
//        D7 -> B (C33 22u).
//   TR7: D9 -> N1 (C38 2.2u, R69 3.9k to N2, R68 2.2k + VR7 to N3, R70 to base);
//        D8 -> N2; C 22u between N2 and N3; N3 is IC100.6 (open collector,
//        low in the active frame, released in V=0..15).
//   TR8: the same with D11/D10, C57 2.2u, R81 3.3k, R73 2.2k + VR8, C41 22u,
//        IC100.4.
//   TR5: X (C15 2.2u) charges from +5 V through R22 3.3k + VR4, and TR3
//        takes charge out of it in V=0..15: the swing. The network (TR3,
//        C18, D3, D4, VR5; TR4, C20, C30, D5) and its simplifications are
//        described in rtl/analog/fonz_road_swing.v, which has the same
//        equations in fixed point.
//
// Not modelled here: base currents of TR5..TR8. Pot settings and the
// P3/P4/P5 select resistors are parameters; P = 0 means not fitted.
//
// 74123 width with a transistor supply. With Rext returned to a voltage V
// instead of +5 V, the timing capacitor charges toward V. Treating the end of
// the pulse as the capacitor reaching VTH from 0 V,
//     tw(V) = tw_5V * ln(V/(V-VTH)) / ln(5/(5-VTH)),
// so at V = 5 V it is the 'LS123 data-sheet width tw = K(C) * R * C used by
// fonz_74123 (TI SDLS043 Figure 7: K = 0.495 at 100 pF, 0.328 at 9.4 nF,
// 0.327 at 44 nF). VTH = 1.2 V sets only the voltage dependence;
// ln(5/3.8) = 0.274 is close to the standard '123's 0.28 factor. The
// emitter pull-up (R57/R71/R97) and the pin form a divider: once the pin
// has charged to v1 = (vt - 5a)/(1 - a), a = R/(R + Rpull), the pull-up
// alone holds the emitter above vt, the follower cuts off and the pin goes
// on charging toward +5 V through R + Rpull. If v1 is below VTH the pulse
// ends in that second piece, otherwise the follower carries it all the way.
// The two pieces meet at v1 = VTH, so the width is continuous in V_base.
// (Until 9 November 2026 the switch was taken at vt = VTH + 20 mV, which
// left a jump of about 40 % at the switch; tests/tb_road_timing.v found it.)
// TR5 has no pull-up, so its stage never ends once vt falls under VTH.
`timescale 1ns/1ps
`default_nettype none
module fonz_road_timing_ref #(
    parameter integer CLK_HZ  = 14_305_000,
    // Pot settings: the resistance in circuit, ohms.
    parameter real VR4_OHM = 1000.0,   // 2k VR, in series with R22 3.3k; midway (manual)
    parameter real VR6_OHM = 1000.0,   // 10k VR, in series with 3.3k: road widening (see fonz_road_timing.v)
    parameter real VR7_OHM = 5000.0,   // 10k VR, in series with R68 2.2k
    parameter real VR8_OHM = 5000.0,   // 10k VR, in series with R73 2.2k
    // Select resistors in parallel with the emitter resistors, 0 = not fitted.
    parameter real P3_OHM  = 0.0,
    parameter real P4_OHM  = 0.0,
    parameter real P5_OHM  = 0.0,
    // The swing network (see rtl/analog/fonz_road_swing.v)
    parameter real    VR5_OHM = 250.0e3,
    parameter real    VR3_MV = 650.0,
    parameter real    TR3_BETA = 120.0,
    parameter real    TR4_BETA = 200.0,
    parameter real    B3_INIT_MV = 650.0,
    // 1: 'LS123 timing (K from Figure 7). 0: standard '123,
    // tw = 0.28 * Rt * Cext * (1 + 0.7/Rt) (TI SDLS043 page 7, Rt in kohm).
    parameter integer FAMILY_LS = 1
)(
    input  wire       IC45_pin8,          // crystal, clocks the 74123 cores
    input  wire       IC3_pin5,           // IC3B Q, high for V=0..15
    input  wire       IC100_pin6,         // open collector, 1 = released
    input  wire       IC100_pin4,         // open collector, 1 = released
    input  wire       IC94_pin2,          // 1 = released: D4 charges C18
    input  wire       IC94_pin6,          // 1 = released: VR3 sets C18 (crash)
    input  wire       IC94_pin8,          // 0: R16 discharges C18 (crash)
    input  wire       IC100_pin8,         // 1 = released: D5 charges C30
    input  wire [2:0] ic97b_ab_clear_n, ic97a_ab_clear_n,
    input  wire [2:0] ic102b_ab_clear_n, ic102a_ab_clear_n,
    input  wire [2:0] ic104b_ab_clear_n, ic104a_ab_clear_n,
    output wire       IC97_pin5, IC97_pin13,
    output wire       IC102_pin5, IC102_pin13,
    output wire       IC104_pin5, IC104_pin13
);
    localparam real VCC = 5.0, VD = 0.6, VBE = 0.65, VTH = 1.2;
    localparam real RS = 50.0;           // TR2 on: source resistance
    localparam real DT = 1.0e-6;         // integration step, seconds
    // 'LS123 K(Cext), TI SDLS043 Figure 7, the same table as k4_ls in
    // fonz_74123 (straight lines between the read-off points).
    function real k_ls(input real c);
        real pf;
        begin
            pf = c * 1.0e12;
            if      (pf <= 100.0)     k_ls = 0.495;
            else if (pf <= 200.0)     k_ls = 0.495 - (pf-100.0)*0.065/100.0;
            else if (pf <= 500.0)     k_ls = 0.430 - (pf-200.0)*0.045/300.0;
            else if (pf <= 1000.0)    k_ls = 0.385 - (pf-500.0)*0.020/500.0;
            else if (pf <= 2000.0)    k_ls = 0.365 - (pf-1000.0)*0.017/1000.0;
            else if (pf <= 5000.0)    k_ls = 0.348 - (pf-2000.0)*0.013/3000.0;
            else if (pf <= 10000.0)   k_ls = 0.335 - (pf-5000.0)*0.008/5000.0;
            else if (pf <= 1.0e6)     k_ls = 0.327 + (pf-10000.0)*0.003/990000.0;
            else                      k_ls = 0.330;
        end
    endfunction
    // Width factor K so that tw = K * R * C at +5 V, for either family.
    function real k_fam(input real r, input real c);
        k_fam = (FAMILY_LS != 0) ? k_ls(c) : 0.28 * (1.0 + 700.0 / r);
    endfunction
    localparam real NS_PER_CYCLE = 1.0e9 / CLK_HZ;

    // Emitter resistors with their select resistors.
    function real par(input real r, input real p);
        par = (p > 0.0) ? (r * p) / (r + p) : r;
    endfunction
    localparam real RE5 = 1000.0;              // R40
    localparam real RE6 = 2200.0;              // R58 (|| P3)
    localparam real RE7 = 3300.0;              // R72 (|| P4)
    localparam real RE8 = 3300.0;              // R98 (|| P5)

    // Width in crystal cycles for a stage with Rext fed from v_src through r,
    // or (if the follower is off) from +5 V through r + r_pull.
    function [31:0] cycles(input real v_base, input real r, input real r_pull,
                           input real c);
        real vt, a, v1, tau, t1, t2, tw;
        begin
            // Capacitance scaled so that the 0 -> VTH charge from +5 V gives
            // the data-sheet width K * R * C (see k_fam).
            tau = r * k_fam(r, c) * c / $ln(VCC / (VCC - VTH));
            vt = v_base - VBE;                 // emitter-follower output
            a = (r_pull > 0.0) ? r / (r + r_pull) : 0.0;
            if ((r_pull > 0.0) ? (vt - VCC * a) / (1.0 - a) >= VTH : vt >= VTH + 0.02) begin
                // Follower supplies the Rext all the way to the threshold.
                tw = tau * $ln(vt / (vt - VTH));
            end else if (r_pull > 0.0) begin
                // Follower takes the pin to v1, where the emitter pull-up
                // takes over and the pin charges toward +5 V through
                // r + r_pull. Continuous with the case above.
                v1 = (vt - VCC * a) / (1.0 - a);
                if (v1 > 0.0) t1 = tau * $ln(vt / (vt - v1));
                else begin t1 = 0.0; v1 = 0.0; end
                t2 = tau / a * $ln((VCC - v1) / (VCC - VTH));
                tw = t1 + t2;
            end else
                tw = 1.0;                      // 1 s: no end within a frame
            tw = tw * 1.0e9;
            cycles = (tw / NS_PER_CYCLE > 4.0e9) ? 32'hFFFF_FFFF
                   : $rtoi(tw / NS_PER_CYCLE + 0.5);
        end
    endfunction

    // Diode from the TR2 line into a node at v.
    function real idiode(input real src_on, input real v);
        idiode = (src_on > 0.5 && VCC - VD - v > 0.0) ? (VCC - VD - v) / RS : 0.0;
    endfunction

    // State: capacitor voltages, all starting discharged at power-up.
    real tr6_a = 0.0, tr6_b = 0.0;
    real tr7_n1 = 0.0, tr7_vc = 0.0;
    real tr8_n1 = 0.0, tr8_vc = 0.0;
    real tr5_x = 5.0, tr5_base = 5.0;
    real sw_b3 = B3_INIT_MV / 1000.0, sw_v30 = 0.65, sw_vc20 = 5.0;
    real sw_ib, sw_ic, sw_ib4, sw_dv, sw_lim, sw_b3_n, sw_x_n, sw_v30_n;
    function real pos(input real v);
        pos = v > 0.0 ? v : 0.0;
    endfunction
    real n2, n3, s_on, i12, i13;
    reg [31:0] w97b = 32'd1, w102b = 32'd1, w102a = 32'd1, w104b = 32'd1;

    // Control nodes for the TR7/TR8 type network. vbl: the shared line is
    // driven; oc_released: N3 is floating.
    task step_tr78(inout real n1, inout real vc, input real r_mid, input real r_low,
                   input real c1, input real c2, input reg oc_released);
        real g, num;
        begin
            if (!oc_released) begin
                n3 = 0.0; n2 = vc;
            end else begin
                // N2/N3 supernode around the floating capacitor.
                g = 1.0 / r_mid + 1.0 / r_low;
                num = n1 / r_mid + (n1 + vc) / r_low;
                n2 = num / g;
                if (s_on > 0.5 && n2 < VCC - VD) begin
                    g = g + 1.0 / RS;
                    num = num + (VCC - VD) / RS;
                    n2 = num / g;
                end
                n3 = n2 - vc;
            end
            i12 = (n1 - n2) / r_mid;
            i13 = (n1 - n3) / r_low;
            vc = vc + DT * (i12 + (oc_released ? idiode(s_on, n2) : 0.0)) / c2;
            n1 = n1 + DT * (idiode(s_on, n1) - i12 - i13) / c1;
        end
    endtask

    always begin
        #1000;
        s_on = (IC3_pin5 === 1'b1) ? 1.0 : 0.0;
        // TR6
        tr6_a = tr6_a + DT * (idiode(s_on, tr6_a) - (tr6_a - tr6_b) / 3300.0
                              - tr6_a / (3300.0 + VR6_OHM)) / 2.2e-6;
        tr6_b = tr6_b + DT * (idiode(s_on, tr6_b) + (tr6_a - tr6_b) / 3300.0) / 22.0e-6;
        // TR7 (R69 3.9k, R68 2.2k + VR7, C38 2.2u, 22u, IC100.6)
        step_tr78(tr7_n1, tr7_vc, 3900.0, 2200.0 + VR7_OHM, 2.2e-6, 22.0e-6,
                  IC100_pin6 !== 1'b0);
        // TR8 (R81 3.3k, R73 2.2k + VR8, C57 2.2u, C41 22u, IC100.4)
        step_tr78(tr8_n1, tr8_vc, 3300.0, 2200.0 + VR8_OHM, 2.2e-6, 22.0e-6,
                  IC100_pin4 !== 1'b0);
        // The swing: B3 (C18), X (C15), C30, C20, all from the old values
        sw_ib  = (s_on > 0.5) ? pos(sw_b3 - VBE) / 3300.0 : 0.0;
        sw_ic  = sw_ib * TR3_BETA;
        if (sw_ic > pos(tr5_x - 0.1) / 51.0) sw_ic = pos(tr5_x - 0.1) / 51.0;
        sw_b3_n = sw_b3 + DT * (
              ((IC94_pin2 !== 1'b0) ? pos(VCC - VD - sw_b3) / (470.0e3 + VR5_OHM) : 0.0)
            + ((IC94_pin6 !== 1'b0) ? pos(VR3_MV / 1000.0 - sw_b3) / 3750.0 : 0.0)
            - ((IC94_pin8 === 1'b0) ? pos(sw_b3) / 33.0e3 : 0.0)
            - sw_ib) / 47.0e-6;
        sw_x_n = tr5_x + DT * (pos(VCC - tr5_x) / (3300.0 + VR4_OHM) - sw_ic) / 2.2e-6;
        sw_ib4 = pos(sw_v30 - VBE) / 3300.0;
        sw_v30_n = sw_v30 + DT * (
              ((IC100_pin8 !== 1'b0) ? pos(VCC - VD - sw_v30) / 1.0e6 : 0.0) - sw_ib4) / 47.0e-6;
        sw_dv  = DT * (tr5_x - sw_vc20) / 33.0e3 / 0.068e-6;
        sw_lim = DT * sw_ib4 * TR4_BETA / 0.068e-6;
        if (sw_dv > sw_lim) begin
            tr5_base = tr5_x - sw_ib4 * TR4_BETA * 33.0e3;
            sw_vc20 = sw_vc20 + sw_lim;
        end else begin
            tr5_base = sw_vc20;
            sw_vc20 = sw_vc20 + sw_dv;
        end
        sw_b3 = sw_b3_n; tr5_x = sw_x_n; sw_v30 = sw_v30_n;

        w97b  <= cycles(tr5_base,  RE5,               0.0,      44.0e-9);
        w102a <= cycles(tr6_a,  par(RE6, P3_OHM),  100.0e3,  9.4e-9);
        w102b <= cycles(tr7_n1, par(RE7, P4_OHM),  68.0e3,   100.0e-12);
        w104b <= cycles(tr8_n1, par(RE8, P5_OHM),  68.0e3,   100.0e-12);
    end

    fonz_74123_core ic97b(.clk(IC45_pin8),
        .a(ic97b_ab_clear_n[2]), .b(ic97b_ab_clear_n[1]), .clr_n(ic97b_ab_clear_n[0]),
        .width(w97b), .q(IC97_pin5), .q_n());
    fonz_74123 #(.CLK_HZ(CLK_HZ), .R_OHM(10_000), .C_PF(100), .FAMILY_LS(FAMILY_LS)) ic97a(.clk(IC45_pin8),
        .a(ic97a_ab_clear_n[2]), .b(ic97a_ab_clear_n[1]), .clr_n(ic97a_ab_clear_n[0]),
        .q(IC97_pin13), .q_n());
    fonz_74123_core ic102b(.clk(IC45_pin8),
        .a(ic102b_ab_clear_n[2]), .b(ic102b_ab_clear_n[1]), .clr_n(ic102b_ab_clear_n[0]),
        .width(w102b), .q(IC102_pin5), .q_n());
    fonz_74123_core ic102a(.clk(IC45_pin8),
        .a(ic102a_ab_clear_n[2]), .b(ic102a_ab_clear_n[1]), .clr_n(ic102a_ab_clear_n[0]),
        .width(w102a), .q(IC102_pin13), .q_n());
    fonz_74123_core ic104b(.clk(IC45_pin8),
        .a(ic104b_ab_clear_n[2]), .b(ic104b_ab_clear_n[1]), .clr_n(ic104b_ab_clear_n[0]),
        .width(w104b), .q(IC104_pin5), .q_n());
    fonz_74123 #(.CLK_HZ(CLK_HZ), .R_OHM(10_000), .C_PF(100), .FAMILY_LS(FAMILY_LS)) ic104a(.clk(IC45_pin8),
        .a(ic104a_ab_clear_n[2]), .b(ic104a_ab_clear_n[1]), .clr_n(ic104a_ab_clear_n[0]),
        .q(IC104_pin13), .q_n());
endmodule
`default_nettype wire
