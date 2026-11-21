// SPDX-License-Identifier: GPL-3.0-or-later
// MiSTer rumble from the crash outputs. NOT ORIGINAL CIRCUITRY.
//
// On a crash the board vibrates the handlebars with a 100 V AC
// solenoid in the handlebar assembly (manual: "the handle bars vibrate";
// parts list item 15, Solenoid AC 100V 5Kg). IC96 counts the AC sense after
// a crash and IC96A.QC, through IC100 11->10, sinks the LED current of the
// TR12 MCD-725 photocoupler (R30 220 ohm from +), which fires the TR11
// triac: two kicks of four AC cycles each. IC17.2 pulls connector 23 (CRUSH) low for the whole crash to
// cue the sound unit. Neither reaches a controller on the real machine; this
// module only turns them into a MiSTer rumble request when the OSD option
// enables it.
//
// Output format follows the MiSTer hps_io joystick rumble word:
// [15:8] large motor magnitude, [7:0] small motor magnitude.
//   large motor: full while the solenoid is energised (IC100.10 low)
//   small motor: SMALL_LEVEL while CRUSH is active (IC17.2 low)
// Both board signals are open-collector levels (1 = released) and are
// asynchronous to clk, so each passes a two-flop synchroniser.
//
// Board wires are named by both endpoints (IC100 pin 10 to TR12, IC17 pin 2
// to connector 23). The synchroniser registers are FPGA-only and have no
// board endpoint.
`timescale 1ns/1ps
`default_nettype none
module fonz_rumble #(
    parameter [7:0] LARGE_LEVEL = 8'hFF,
    parameter [7:0] SMALL_LEVEL = 8'h60
)(
    input  wire        clk,
    input  wire        enable,     // OSD "Rumble on crash"
    input  wire        IC100_pin10_SOLENOID, // solenoid drive, low = energised
    input  wire        IC17_pin2_CN23,   // connector 23 CRUSH, low = crash
    output reg  [15:0] rumble = 16'h0000
);
    reg [1:0] solenoid_sync = 2'b00;
    reg [1:0] crush_sync = 2'b00;

    always @(posedge clk) begin
        solenoid_sync <= {solenoid_sync[0], ~IC100_pin10_SOLENOID};
        crush_sync    <= {crush_sync[0],    ~IC17_pin2_CN23};
        rumble <= enable ? { solenoid_sync[1] ? LARGE_LEVEL : 8'h00,
                             crush_sync[1]    ? SMALL_LEVEL : 8'h00 }
                         : 16'h0000;
    end
endmodule
`default_nettype wire
