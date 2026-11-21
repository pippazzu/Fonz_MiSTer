// SPDX-License-Identifier: GPL-3.0-or-later
// Resistor mixer at connector 7, reduced to an 8-bit grey value for MiSTer.
//
// Parts in this module: no ICs. Passives: R13 1k, R26 470, R3 1k, VR13 2k,
// R27 220, C16 4.7 uF.
//
// Wires are named for both ends:
//   IC5_pin11_R13   IC5.11 -> R13 1k
//   IC7_pin8_R26    IC7.8  -> R26 470
//   IC7_pin12_VR13  IC7.12 -> VR13 2k + R3 1k
// R27 220 pulls the junction of R13, R26 and R3 to +5 V; C16 couples it to
// connector pin 7.
//
// Levels come from scripts/video_mixer_levels.py (table in TRACE.md):
// grey = 255 * (V - V_blank) / (V_white - V_blank), blank = 100, white = 111.
// IC5.11 low is composite sync; it only occurs while IC4.Q5 or IC3.Q5 holds
// IC7.8 and IC7.12 low, so every IC5.11-low state is shown as black.
// VR13_SETTING: 0 = VR13 at 0 ohm, 1 = mid (1k), 2 = full (2k).
// grey and csync_n are MiSTer outputs, not board wires.
`timescale 1ns/1ps
`default_nettype none
module fonz_video_mixer #(
    parameter integer VR13_SETTING = 1
)(
    input  wire IC5_pin11_R13,IC7_pin8_R26,IC7_pin12_VR13,
    output reg  [7:0] grey,
    output wire csync_n
);
    assign csync_n=IC5_pin11_R13;
    always @* begin
        grey=8'd0;
        if(IC5_pin11_R13) case({IC7_pin8_R26,IC7_pin12_VR13})
            2'b01: grey = VR13_SETTING==0 ? 8'd51  : VR13_SETTING==2 ? 8'd22  : 8'd31;
            2'b10: grey = VR13_SETTING==0 ? 8'd140 : VR13_SETTING==2 ? 8'd205 : 8'd185;
            2'b11: grey = 8'd255;
            default: grey = 8'd0;
        endcase
    end
endmodule
`default_nettype wire
