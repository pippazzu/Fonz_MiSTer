// SPDX-License-Identifier: GPL-3.0-or-later
// Contact and edge conditioning: the RC + threshold nodes in front of the
// coin latch, the game latches, the road load gate and the IC37 Schmitt
// inverters.
//
// These are event-driven simulation models, not synthesisable logic. Each
// node is a first-order RC: when its drive changes, the capacitor voltage
// heads exponentially for the new target with the new time constant, and the
// output changes when that voltage crosses the receiver's threshold. The
// crossing time is computed exactly from the voltage at the moment of the
// change, so a contact that bounces, or opens again before the capacitor has
// discharged, behaves as the RC would: short bounces are absorbed and a
// partly charged capacitor reaches the threshold sooner. An FPGA version
// needs counters in place of these delays; the delays it must reproduce are
// listed in docs/CONDITIONING.md.
`timescale 1ns/1ps
`default_nettype none

// Generic RC node with a threshold (plain TTL: VT_POS == VT_NEG) or
// hysteresis (7414 Schmitt: VT_POS > VT_NEG). drive=1 pulls the node toward
// V_HIGH with TAU_HIGH_NS, drive=0 toward V_LOW with TAU_LOW_NS. sense is the
// logic level the receiving input sees. X/Z on drive leaves the node alone.
module fonz_rc_threshold #(
    parameter real V_HIGH=3.4,
    parameter real V_LOW=0.2,
    parameter real TAU_HIGH_NS=100.0,
    parameter real TAU_LOW_NS=100.0,
    parameter real VT_POS=1.4,
    parameter real VT_NEG=1.4,
    // Shortest response, about one TTL gate delay. Without it a node that
    // is turned round exactly at its threshold by zero-delay feedback would
    // toggle forever in zero time.
    parameter real T_MIN_NS=10.0,
    parameter INIT=1'b0
)(
    input wire drive,
    output reg sense=INIT
);
    real v0=INIT ? V_HIGH : V_LOW;  // node voltage at t0
    real t0=0.0;
    real target=INIT ? V_HIGH : V_LOW;
    real tau=INIT ? TAU_HIGH_NS : TAU_LOW_NS;
    real v,d;
    event changed;

    function automatic real v_at(input real t);
        v_at=target+(v0-target)*$exp(-(t-t0)/tau);
    endfunction

    always @(drive) begin
        if (drive===1'b1 || drive===1'b0) begin
            v0=v_at($realtime);
            t0=$realtime;
            target=drive ? V_HIGH : V_LOW;
            tau=drive ? TAU_HIGH_NS : TAU_LOW_NS;
            ->changed;
        end
    end

    // Schedule the next threshold crossing; a new drive change cancels it.
    always begin
        v=v_at($realtime);
        d=-1.0;
        if (!sense && target>VT_POS)
            d=(v>=VT_POS) ? 0.0 : tau*$ln((target-v)/(target-VT_POS));
        else if (sense && target<VT_NEG)
            d=(v<=VT_NEG) ? 0.0 : tau*$ln((v-target)/(VT_NEG-target));
        if (d>=0.0 && d<T_MIN_NS)
            d=T_MIN_NS;
        if (d<0.0)
            @(changed);
        else begin
            fork
                begin #(d) sense=~sense; end
                @(changed);
            join_any
            disable fork;
        end
    end
endmodule

// A 220 ohm / 680 pF node between a TTL output and a TTL input: R76/C51
// (IC38.3 -> IC38.9), R77/C52 (IC59.2 -> IC60.12, IC61.11) and R67/C44
// (IC102.5 -> IC101.5). The driver's own output resistance adds to R in each
// direction, and the receiver's low-level input current (1.6 mA) through R
// lifts the low target. With the defaults the receiver sees a rising edge
// about 77 ns late and a falling edge about 189 ns late.
module fonz_rc_edge #(
    parameter real R_OHM=220.0,
    parameter real C_PF=680.0,
    parameter real R_DRIVE_HIGH_OHM=100.0,  // TTL totem-pole high, estimate
    parameter real R_DRIVE_LOW_OHM=10.0,    // TTL saturated low, estimate
    parameter real V_OH=3.4,
    parameter real V_OL=0.2,
    parameter real I_IL_MA=1.6,
    parameter INIT=1'b0
)(
    input wire drive,
    output wire sense
);
    fonz_rc_threshold #(
        .V_HIGH(V_OH),
        .V_LOW(V_OL+I_IL_MA*1.0e-3*R_OHM),
        .TAU_HIGH_NS((R_OHM+R_DRIVE_HIGH_OHM)*C_PF*1.0e-3),
        .TAU_LOW_NS((R_OHM+R_DRIVE_LOW_OHM)*C_PF*1.0e-3),
        .VT_POS(1.4),.VT_NEG(1.4),.INIT(INIT)
    ) node(.drive(drive),.sense(sense));
endmodule

// A cabinet contact: connector pin pulled up by R_PULL to +5 V, R_SERIES to
// the gate input, C from the gate input to ground. The contact grounds the
// connector pin. connector is the level on the connector wire (1 at rest,
// 0 with the contact closed); gate_input is the logic level the gate input
// sees after the RC (the same levels, delayed and debounced).
module fonz_contact_rc #(
    parameter real R_PULL_OHM=510.0,
    parameter real R_SERIES_OHM=100.0,
    parameter real C_NF=22000.0,
    parameter real I_IL_MA=1.2,      // receiver's low-level input current
    parameter SCHMITT=1'b1,          // 7414 thresholds, else plain TTL
    parameter INIT=1'b1              // settled level at power-up
)(
    input wire connector,
    output wire gate_input
);
    fonz_rc_threshold #(
        .V_HIGH(5.0),
        .V_LOW(I_IL_MA*1.0e-3*R_SERIES_OHM),
        .TAU_HIGH_NS((R_PULL_OHM+R_SERIES_OHM)*C_NF),
        .TAU_LOW_NS(R_SERIES_OHM*C_NF),
        .VT_POS(SCHMITT ? 1.7 : 1.4),
        .VT_NEG(SCHMITT ? 0.9 : 1.4),
        .INIT(INIT)
    ) node(.drive(connector),.sense(gate_input));
endmodule

// The six cabinet contacts, from the connector wires (1 at rest, 0 closed,
// as fonz_cabinet_inputs produces them) to the board's IC37 outputs and
// IC38 inputs. Values from the main schematic; see docs/CONTROLS.md. Wires are
// named as in docs/NET_NAMES.md. This is the timed replacement for the
// zero-delay fonz_contacts_direct stand-in.
module fonz_contact_conditioning(
    input wire CN16_IC37_pin13,CN17_IC37_pin5,CN18_IC37_pin3,CN1_IC37_pin1,
    input wire CN21_IC38_pin1,CN20_IC38_pin13,
    output wire IC37_pin12_ACCEL,  // also IC19 pin 2 (IC34 pin 3)
    output wire IC37_pin6_LEFT,
    output wire IC37_pin4_RIGHT,
    output wire IC37_pin2_IC82_pin2,
    output wire R93_C60_IC38_pin1,
    output wire R91_C59_IC38_pin13
);
    // Schmitt input nodes, named by the parts that meet there.
    wire R84_C47_IC37_pin13,R86_C48_IC37_pin5,R88_C49_IC37_pin3,R90_C50_IC37_pin1;
    // Connector 16: R83 510, R84 100, C47 22 uF, IC37 13 -> 12.
    fonz_contact_rc #(.C_NF(22000.0)) accel(.connector(CN16_IC37_pin13),.gate_input(R84_C47_IC37_pin13));
    // Connector 17: R85 510, R86 100, C48 22 uF, IC37 5 -> 6.
    fonz_contact_rc #(.C_NF(22000.0)) left(.connector(CN17_IC37_pin5),.gate_input(R86_C48_IC37_pin5));
    // Connector 18: R87 510, R88 100, C49 22 uF, IC37 3 -> 4.
    fonz_contact_rc #(.C_NF(22000.0)) right(.connector(CN18_IC37_pin3),.gate_input(R88_C49_IC37_pin3));
    // Connector 1: R89 510, R90 100, C50 22 uF, IC37 1 -> 2.
    fonz_contact_rc #(.C_NF(22000.0)) tilt(.connector(CN1_IC37_pin1),.gate_input(R90_C50_IC37_pin1));
    // IC37 is a 7414: inverting Schmitt.
    assign IC37_pin12_ACCEL=~R84_C47_IC37_pin13;
    assign IC37_pin6_LEFT=~R86_C48_IC37_pin5;
    assign IC37_pin4_RIGHT=~R88_C49_IC37_pin3;
    assign IC37_pin2_IC82_pin2=~R90_C50_IC37_pin1;
    // Coin changeover, common grounded. Connector 21 (normally open):
    // R94 510, R93 100, C60 0.01 uF -> IC38.1. Connector 20 (normally
    // closed): R92 510, R91 100, C59 0.01 uF -> IC38.13. Plain 7400 inputs.
    fonz_contact_rc #(.C_NF(10.0),.I_IL_MA(1.6),.SCHMITT(1'b0))
        coin_no(.connector(CN21_IC38_pin1),.gate_input(R93_C60_IC38_pin1));
    fonz_contact_rc #(.C_NF(10.0),.I_IL_MA(1.6),.SCHMITT(1'b0),.INIT(1'b0))
        coin_nc(.connector(CN20_IC38_pin13),.gate_input(R91_C59_IC38_pin13));
endmodule
`default_nettype wire
