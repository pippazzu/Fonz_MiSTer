// SPDX-License-Identifier: GPL-3.0-or-later
// IC9 / IC106 shape oscillators, reference model. SIMULATION ONLY: real-valued,
// event-timed, not synthesisable. It answers the {A,B,/CLR} vectors that
// fonz_shape_oscillator_connections exports with the two 74123 Q pins, and
// models the transistor control network that sets the shared Rext node.
//
// Circuit (native scan, checked 8 November 2026; the
// IC106 copy is identical in values, crop (2700,4100)-(4300,4900)):
//
//   IC94.12 (7416, o.c.) --+-- VR1 10k (rheostat) -- R7 2.2k --+-- R6 33k -- TR1 base
//   [IC100.2 for IC106]    |                                   |   [R103]     [TR9]
//                          +-- C11 22u (-)(+) -- R8 3.3k ------+
//                                       |        [C66, R102]   |
//   TR2 collector -- VR2 100 -- D1 -----+                      +-- C10 2.2u -- GND
//                          \--- D2 ----------------------------+   [C81]
//   (D12/D13 for IC106 sit on the same TR2/VR2 wire, native x~2996)
//
//   TR1 emitter -- R4 2.2k || P1 --+-- R5 68k -- +5V        [R105, P6, R104]
//                                  +-- IC9 pins 15 and 7 (both Rext/Cext)
//   C4 10p: pin 14-15, C7 10p: pin 6-7.  Pin 5 load C6 470p (C70 at IC106).
//
// TR2 is a 2SA684 PNP, emitter at +5 V, base from IC94.10 through R15 510
// (R14 3.3k base-emitter). IC94.10 is the inverse of IC3.5, which is high
// for about 780 us of every frame, so once a frame TR2 tops both control
// capacitors up to about 4.1 V. During the frame the gate (IC83.7 via
// IC94.12, or IC105.5 via IC100.2) pulls the VR/R7 end low and the control
// voltage decays toward the VR/(VR+R8) share of C11's charge; with the gate
// released the node holds. A higher control voltage drives more emitter
// current into the Rext node, so the 74123 pulses shorten and the
// oscillator runs faster.
//
// Oscillator: first half A1 grounded, B2 from second /Q12; first Q13 drives
// second A9; second B10 high; both /CLR from clear_n. The halves alternate:
// period = 2 * (tpd + tw).
`timescale 1ns/1ps
`default_nettype none
module fonz_shape_oscillator_ref #(
    // Control network, IC9 names first, IC106 names in brackets.
    parameter real VR_OHMS      = 1800.0,  // VR1 [VR9] 10k rheostat, set for the manual's bike size (docs/SHAPE_OSCILLATORS.md)
    parameter real R_SERIES     = 2200.0,  // R7 [R99]
    parameter real R_COUPLE     = 3300.0,  // R8 [R102]
    parameter real C_COUPLE     = 22e-6,   // C11 [C66]
    parameter real C_HOLD       = 2.2e-6,  // C10 [C81]
    parameter real R_BASE       = 33000.0, // R6 [R103]
    parameter real R_EMITTER    = 2200.0,  // R4 [R105]
    parameter real R_P          = 1.0e12,  // P1 [P6]; part not identified, taken as absent
    parameter real R_PULLUP     = 68000.0, // R5 [R104]
    parameter real VR2_OHMS     = 50.0,    // VR2 100 rheostat, shared TR2 feed; mid
    parameter real BETA         = 100.0,   // TR1 [TR9] current gain (type not drawn)
    parameter real VBE          = 0.65,
    parameter real VDIODE       = 0.65,    // D1/D2 [D12/D13] MA150
    parameter real RDIODE       = 10.0,
    parameter real VOL_OC       = 0.2,     // 7416 output low
    parameter real VCESAT       = 0.2,     // TR2 saturated
    parameter real VCC          = 5.0,
    parameter real STEP_NS      = 1000.0,  // integration step of the control network
    // 74123 timing, the '123 rule of fonz_74123.v (TI SDLS043): below
    // 100 pF a straight line from tw(Cext->0) = 15 ns + 6 ns/k * Rt (Figure 4)
    // to 0.28*Rt*Cext*(1+0.7/Rt[k]) at 100 pF. At Cext = 10 pF that line is
    // tw = 15.46 ns + 8.2 ns/k * Rt = T_INTRINSIC + 0.28*(Rt+700)*C_EFF with
    // C_EFF = C_TIMING + C_INTERNAL = 29.29 pF and T_INTRINSIC = 9.72 ns.
    // The 0.28 is written as charging toward the Rext node's Thevenin voltage
    // to an equivalent threshold of 1.22 V (ln(5/3.78) = 0.28 at Veq = Vcc),
    // so a source below Vcc slows it. For an 'LS123 (Figure 6/7: 15 ns +
    // 8.6 ns/k * Rt at Cext->0, K = 0.495 at 100 pF) use C_INTERNAL = 35.4p,
    // R_INTERNAL = 0, T_INTRINSIC = 13.5.
    parameter real C_TIMING     = 10e-12,  // C4/C7 [C69/C71]
    parameter real C_INTERNAL   = 19.29e-12,
    parameter real R_INTERNAL   = 700.0,
    parameter real V_THRESHOLD  = 1.22,
    parameter real T_INTRINSIC  = 9.72,    // ns
    parameter real TPD_NS       = 22.0,    // trigger to Q
    parameter real MISMATCH     = 0.01     // second half 1% longer: real parts never match,
                                           // and equal widths would lock the pair in phase
)(
    input  wire [2:0] first_ab_clear_n,    // {A1, B2, /CLR3}
    input  wire [2:0] second_ab_clear_n,   // {A9, B10, /CLR11}
    input  wire gate_oc,                   // IC94.12 [IC100.2]; 1 = released
    input  wire tr2_base_oc,               // IC94.10; 1 = released, TR2 off
    output reg  first_q = 1'b0,            // pin 13
    output reg  second_q = 1'b0            // pin 5
);
    // ---- control network state -------------------------------------------
    real C10_plus_R6_R8_R7 = 0.0;          // control voltage on C10 [C81]
    real C11_charge = 0.0;                 // C11 [C66] voltage, (+) minus (-)
    real IC94_pin12_VR1 = VCC;         // gate end of VR1 and C11 (-)
    real C11_plus_R8_D1 = 0.0;             // C11 (+), R8, D1 cathode

    function real thevenin_width_ns(input real vcontrol);
        real c, rp, vs, req, veq, t;
        begin
            c  = C_TIMING + C_INTERNAL;
            rp = (R_EMITTER * R_P / (R_EMITTER + R_P)) + R_BASE / (BETA + 1.0);
            vs = vcontrol - VBE;           // emitter-follower source behind rp
            if (vs <= 0.0)
                t = (R_PULLUP + R_INTERNAL) * c * $ln(VCC / (VCC - V_THRESHOLD));
            else begin
                req = 1.0 / (1.0 / R_PULLUP + 1.0 / rp);
                veq = (VCC / R_PULLUP + vs / rp) * req;
                if (vs >= V_THRESHOLD)
                    t = (req + R_INTERNAL) * c * $ln(veq / (veq - V_THRESHOLD));
                else // emitter cuts off once the node passes vs; R5 alone after
                    t = (req + R_INTERNAL) * c * $ln(veq / (veq - vs))
                      + (R_PULLUP + R_INTERNAL) * c * $ln((VCC - vs) / (VCC - V_THRESHOLD));
            end
            thevenin_width_ns = T_INTRINSIC + t * 1.0e9;
        end
    endfunction

    // Average base current drawn from C10 while the pair runs: the shared
    // node sits between 0 and the threshold, so take its mean V_THRESHOLD/2.
    function real base_current(input real vcontrol);
        real rp, vs;
        begin
            rp = (R_EMITTER * R_P / (R_EMITTER + R_P)) + R_BASE / (BETA + 1.0);
            vs = vcontrol - VBE - V_THRESHOLD / 2.0;
            base_current = (vs > 0.0) ? vs / rp / (BETA + 1.0) : 0.0;
        end
    endfunction

    real period_ns = 0.0;                  // for observation: 2*(tpd+tw), each step

    // Forward Euler, STEP_NS. Diodes are ideal VDIODE + RDIODE; the floating
    // gate end (no capacitance of its own) is solved algebraically.
    always begin : control_network
        real dt, vsrc, rs, rv, u, i_d1, i_d2, i_p, i_y, x, p, vy, vc;
        reg tr2_on, gate_on;
        #(STEP_NS);
        dt = STEP_NS * 1.0e-9;
        tr2_on  = (tr2_base_oc === 1'b0);
        gate_on = (gate_oc === 1'b0);
        vsrc = VCC - VCESAT - VDIODE;      // TR2 collector less one diode drop
        rs = VR2_OHMS + RDIODE;
        rv = VR_OHMS + R_SERIES;
        vy = C10_plus_R6_R8_R7;
        vc = C11_charge;
        i_d2 = (tr2_on && vsrc > vy) ? (vsrc - vy) / rs : 0.0;
        if (gate_on) begin
            x = VOL_OC;
            p = x + vc;
            i_d1 = (tr2_on && vsrc > p) ? (vsrc - p) / rs : 0.0;
            i_p = (vy - p) / R_COUPLE + i_d1;              // into C11 (+)
            i_y = (p - vy) / R_COUPLE + (x - vy) / rv;     // into C10 from the loop
        end else begin
            // u = vy - x. KCL at x: u/rv + i_p = 0, i_p = (u - vc)/R_COUPLE + i_d1.
            u = vc * rv / (rv + R_COUPLE);
            i_d1 = 0.0;
            if (tr2_on && vsrc > vy - u + vc) begin
                u = (vc / R_COUPLE + (vy + vc - vsrc) / rs)
                  / (1.0 / rv + 1.0 / R_COUPLE + 1.0 / rs);
                i_d1 = (vsrc - (vy - u + vc)) / rs;
                if (i_d1 < 0.0) begin
                    u = vc * rv / (rv + R_COUPLE);
                    i_d1 = 0.0;
                end
            end
            x = vy - u;
            p = x + vc;
            i_p = (vy - p) / R_COUPLE + i_d1;
            i_y = i_d1;                                    // loop current returns through C11
        end
        if (first_ab_clear_n[0] === 1'b1) i_y = i_y - base_current(vy);
        C10_plus_R6_R8_R7  = vy + (i_y + i_d2) * dt / C_HOLD;
        C11_charge         = vc + i_p * dt / C_COUPLE;
        IC94_pin12_VR1 = x;
        C11_plus_R8_D1     = p;
        period_ns = 2.0 * (TPD_NS + thevenin_width_ns(C10_plus_R6_R8_R7));
    end

    // ---- the 74123 pair -----------------------------------------------------
    // Retriggerable halves. A trigger schedules Q high after TPD_NS and low
    // TPD_NS + tw later; a retrigger moves the end; /CLR low cancels both.
    // Generation numbers retire stale scheduled events.
    integer first_rise_gen = 0, first_end_gen = 0, second_rise_gen = 0, second_end_gen = 0;
    integer first_rise_tag = -1, first_end_tag = -1, second_rise_tag = -1, second_end_tag = -1;
    reg first_running = 1'b0, second_running = 1'b0;
    reg [2:0] first_prev = 3'b000, second_prev = 3'b000;

    function automatic triggered(input [2:0] prev, input [2:0] now);
        // A falling with B high, B rising with A low, /CLR rising with A low, B high
        triggered = (now[0] === 1'b1) &&
                    (( prev[2] && !now[2] && now[1]) ||
                     (!prev[1] &&  now[1] && !now[2]) ||
                     (!prev[0] && !now[2] &&  now[1]));
    endfunction

    always @(first_ab_clear_n) begin : first_half
        real w;
        if (first_ab_clear_n[0] !== 1'b1) begin
            first_rise_gen = first_rise_gen + 1;
            first_end_gen  = first_end_gen + 1;
            first_running = 1'b0;
            first_q = 1'b0;
        end else if (triggered(first_prev, first_ab_clear_n)) begin
            w = thevenin_width_ns(C10_plus_R6_R8_R7);
            if (!first_running) begin
                first_rise_gen = first_rise_gen + 1;
                first_rise_tag <= #(TPD_NS) first_rise_gen;
            end
            first_running = 1'b1;
            first_end_gen = first_end_gen + 1;
            first_end_tag <= #(TPD_NS + w) first_end_gen;
        end
        first_prev = first_ab_clear_n;
    end
    always @(first_rise_tag) if (first_rise_tag == first_rise_gen && first_running) first_q = 1'b1;
    always @(first_end_tag) if (first_end_tag == first_end_gen && first_running) begin
        first_running = 1'b0;
        first_q = 1'b0;
    end

    always @(second_ab_clear_n) begin : second_half
        real w;
        if (second_ab_clear_n[0] !== 1'b1) begin
            second_rise_gen = second_rise_gen + 1;
            second_end_gen  = second_end_gen + 1;
            second_running = 1'b0;
            second_q = 1'b0;
        end else if (triggered(second_prev, second_ab_clear_n)) begin
            w = thevenin_width_ns(C10_plus_R6_R8_R7) * (1.0 + MISMATCH);
            if (!second_running) begin
                second_rise_gen = second_rise_gen + 1;
                second_rise_tag <= #(TPD_NS) second_rise_gen;
            end
            second_running = 1'b1;
            second_end_gen = second_end_gen + 1;
            second_end_tag <= #(TPD_NS + w) second_end_gen;
        end
        second_prev = second_ab_clear_n;
    end
    always @(second_rise_tag) if (second_rise_tag == second_rise_gen && second_running) second_q = 1'b1;
    always @(second_end_tag) if (second_end_tag == second_end_gen && second_running) begin
        second_running = 1'b0;
        second_q = 1'b0;
    end
endmodule
`default_nettype wire
