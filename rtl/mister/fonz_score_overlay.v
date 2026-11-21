// SPDX-License-Identifier: GPL-3.0-or-later
// ---------------------------------------------------------------------------
// NOT ORIGINAL CIRCUITRY. MiSTer addition, not part of the original schematic.
//
// The cabinet shows time and score on six separate 7-segment LED digits,
// driven by IC33 (7448) and scanned by IC58; nothing of it reaches the
// monitor. This module redraws those digits on the picture so they can be
// seen on MiSTer. It reads only the board's real display outputs:
// digit_enable (IC58 selectors 0..5 after IC36/IC35) and segments_abcdefg
// (IC33 a..g). It never looks at the counters directly, so blanking by
// IC33 RBI and any wiring error in the scan show up here as on the cabinet.
//
// Scan timing: IC58 A/B/C are IC2.QB/QC/QD, i.e. V count bits 5..7, so
// each digit is lit for 32 lines and the six digits take 192 of the 261
// lines of a frame. The segments of the selected digit are sampled once per
// slot, at the start of line 16 of the slot, while the mux has long settled.
//
// The drawing position is a parameter: the active window is set by the
// video timing work, and the overlay must sit inside it.
// ---------------------------------------------------------------------------
`timescale 1ns/1ps
`default_nettype none
module fonz_score_overlay #(
    parameter [8:0] X0=9'd24,     // left edge of the time digits, H count
    parameter [8:0] Y0=9'd16,     // top edge of all digits, V count
    parameter [8:0] PITCH=9'd14,  // horizontal distance between digits
    parameter [8:0] GAP=9'd28     // extra space between time and score
)(
    input  wire       clk,        // board crystal clock (IC45.8)
    input  wire       enable,     // OSD option: overlay shown when high
    input  wire [8:0] raster_h,raster_v,
    input  wire [5:0] digit_enable,
    input  wire [6:0] segments_abcdefg,
    output wire       overlay_on, // 1 = draw a lit segment at this pixel
    // Latched segments per scan index, for tests and other uses.
    output wire [41:0] digits_abcdefg
);
    // ---- sample each scan slot -------------------------------------------
    reg [6:0] seg [0:5];
    integer i;
    initial for(i=0;i<6;i=i+1) seg[i]=7'd0;
    wire sample=(raster_h==9'd0) && (raster_v[4:0]==5'd16) && !raster_v[8];
    always @(posedge clk)
        if(sample)
            for(i=0;i<6;i=i+1)
                if(digit_enable[i]) seg[i]<=segments_abcdefg;
    assign digits_abcdefg={seg[5],seg[4],seg[3],seg[2],seg[1],seg[0]};

    // ---- draw ------------------------------------------------------------
    // Screen order, left to right: time tens, time units, then
    // score thousands, hundreds, tens, units (scan 0,1,5,4,3,2).
    // A digit cell is 10 x 18 with 2-pixel strokes:
    //   cols 0-1 f/e, 2-7 a/g/d, 8-9 b/c; rows 0-1 a, 2-7 f/b,
    //   8-9 g, 10-15 e/c, 16-17 d.
    wire [8:0] dy=raster_v-Y0;
    wire in_rows=(raster_v>=Y0) && (dy<9'd18);
    reg  [2:0] slot;     // screen position 0..5, 7 = none
    reg  [8:0] dx;
    always @* begin
        slot=3'd7; dx=9'd0;
        if(raster_h>=X0 && raster_h<X0+2*PITCH) begin
            dx=raster_h-X0;
            slot=(dx>=PITCH) ? 3'd1 : 3'd0;
            if(slot==3'd1) dx=dx-PITCH;
        end else if(raster_h>=X0+2*PITCH+GAP && raster_h<X0+6*PITCH+GAP) begin
            dx=raster_h-(X0+2*PITCH+GAP);
            slot=3'd2;
            if(dx>=PITCH) begin dx=dx-PITCH; slot=3'd3; end
            if(dx>=PITCH) begin dx=dx-PITCH; slot=3'd4; end
            if(dx>=PITCH) begin dx=dx-PITCH; slot=3'd5; end
        end
    end
    reg [6:0] lit;
    always @*
        case(slot)
            3'd0: lit=seg[0];  // time tens
            3'd1: lit=seg[1];  // time units
            3'd2: lit=seg[5];  // score thousands
            3'd3: lit=seg[4];  // score hundreds
            3'd4: lit=seg[3];  // score tens
            3'd5: lit=seg[2];  // score units
            default: lit=7'd0;
        endcase
    wire left =(dx<9'd2);
    wire mid  =(dx>=9'd2 && dx<9'd8);
    wire right=(dx>=9'd8 && dx<9'd10);
    wire top  =(dy<9'd2);
    wire upper=(dy>=9'd2  && dy<9'd8);
    wire cent =(dy>=9'd8  && dy<9'd10);
    wire lower=(dy>=9'd10 && dy<9'd16);
    wire bot  =(dy>=9'd16 && dy<9'd18);
    // abcdefg: bit 6 is a, bit 0 is g.
    wire hit=(lit[6] & top   & mid)   |  // a
             (lit[5] & upper & right) |  // b
             (lit[4] & lower & right) |  // c
             (lit[3] & bot   & mid)   |  // d
             (lit[2] & lower & left)  |  // e
             (lit[1] & upper & left)  |  // f
             (lit[0] & cent  & mid);     // g
    assign overlay_on=enable && in_rows && hit;
endmodule
`default_nettype wire
