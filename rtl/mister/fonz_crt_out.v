// SPDX-License-Identifier: GPL-3.0-or-later
// Video out to the framework: one line buffer between the board's raster and the
// screen. It does two jobs.
//
// 1. Sync placement for a modern 15 kHz CRT. The board's own HSYNC
//    (H=32..63) leaves a back porch of only 16 pixels (2.2 us), and its
//    VSYNC (V=4..7) sits near the top of the blanking. On a test CRT the
//    picture wobbled until the OSD offsets were set to H -6, V +3, which
//    moves hsync 12 pixels earlier and vsync 3 lines later. Those offsets
//    are built in here, so the OSD offsets start at 0: hsync H=20..51
//    (back porch 28 pixels, 3.9 us) and vsync on picture lines 7..10.
//
// 2. "3:4 on CRT" (squeeze=1). The cabinet's tube stands portrait, so on
//    a landscape 4:3 CRT the native raster is stretched 16/9 too wide. The
//    squeeze reads each buffered line out 16/9 faster, centred, with black
//    on both sides. The line and frame rates do not change.
//
// Every output line is the board's previous line: the picture, blanking
// and sync are all one line late, which the screen cannot see.
//
// Output pixels come from a phase accumulator on clk_sys, restarted at
// the start of each board line (HBLANK rising, H=0), so each line has the
// same pixel positions: 454 a line (native) or 807 (squeeze). ce_out2 is
// twice that rate.
`timescale 1ns/1ps
`default_nettype none
module fonz_crt_out #(
    parameter integer CLK_HZ = 57_220_000
)(
    input  wire       clk,
    input  wire       squeeze,
    // From the machine, registered at ce_pix
    input  wire       ce_pix,
    input  wire [7:0] grey_in,
    input  wire       hb_in, vb_in,
    // To the framework (arcade_video)
    output reg        ce_out = 1'b0,
    output reg        ce_out2 = 1'b0,
    output reg  [7:0] grey = 8'd0,
    output reg        hs = 1'b0,
    output reg        vs = 1'b0,
    output reg        hb = 1'b1,
    output reg        vb = 1'b1
);
    // Twice the output pixel rate. Native: the crystal, 14.305 MHz.
    localparam integer XTAL_HZ    = 14_305_000;
    localparam integer STEP_NAT   = XTAL_HZ;
    localparam integer STEP_SQ    = XTAL_HZ / 9 * 16;    // 25.431 MHz
    // Output line layout, in output pixels from the line start (H=0).
    // Native: H itself. Squeezed: the same times, 16/9 more pixels, and
    // the 374 active pixels centred on the native active area (H=80..453).
    localparam [9:0] HS0_NAT = 10'd20,  HS1_NAT = 10'd52;
    localparam [9:0] HA0_NAT = 10'd80,  HA1_NAT = 10'd454;
    localparam [9:0] HS0_SQ  = 10'd36,  HS1_SQ  = 10'd93;
    localparam [9:0] HA0_SQ  = 10'd288, HA1_SQ  = 10'd662;
    // VSYNC on picture lines 7..10 (counted from VBLANK rising, V=0)
    localparam [8:0] VS0 = 9'd7, VS1 = 9'd11;

    // ---- write side: the board's line -----------------------------------
    reg  [7:0] line_mem [0:1023];
    reg        wsel = 1'b0;
    reg  [8:0] wx = 9'd0;
    reg        hb_l = 1'b1;
    reg        line_start = 1'b0;
    // VBLANK of the line, taken at its first active pixel (IC3 changes one
    // pixel after H=0, so not at the line start)
    reg        vb_cap = 1'b1, vb_cap_l = 1'b1;
    reg  [8:0] vline = 9'd0;        // line just written, from VBLANK rising
    reg        vb_line = 1'b1;      // its VBLANK
    always @(posedge clk) begin
        line_start <= 1'b0;
        if (ce_pix) begin
            hb_l <= hb_in;
            if (!hb_in && hb_l) vb_cap <= vb_in;
            if (hb_in && !hb_l) begin     // H=0: a new board line
                line_start <= 1'b1;
                wsel <= ~wsel;
                wx <= 9'd0;
                vb_line <= vb_cap;
                vb_cap_l <= vb_cap;
                vline <= (vb_cap && !vb_cap_l) ? 9'd0 : vline + 9'd1;
            end
            if (!hb_in) begin
                line_mem[{wsel, wx}] <= grey_in;
                wx <= wx + 9'd1;
            end
        end
    end

    // ---- read side: the previous line, at the output rate --------------
    reg [31:0] acc = 32'd0;
    reg        half = 1'b0;
    reg  [9:0] ox = 10'd0;
    reg        sq = 1'b0;           // squeeze, changed only at a line start
    reg        rsel = 1'b0;         // buffer being shown
    reg  [8:0] show_v = 9'd0;       // board line being shown
    reg        show_vb = 1'b1;
    wire [31:0] step = sq ? STEP_SQ : STEP_NAT;
    wire        tick = acc + step >= CLK_HZ;
    always @(posedge clk) begin
        ce_out  <= 1'b0;
        ce_out2 <= 1'b0;
        if (line_start) begin
            acc <= 32'd0;
            half <= 1'b0;
            ox <= 10'd0;
            rsel <= ~wsel;
            // Native: the line is exactly 454 output pixels, and the last
            // one (active, H=453) is due on this very clock or the next.
            // Send it now. Squeezed, the line's 807 pixels are already out.
            if (ox <= (sq ? 10'd806 : 10'd453)) begin
                ce_out  <= 1'b1;
                ce_out2 <= 1'b1;
            end
            sq <= squeeze;
            show_v <= vline;
            show_vb <= vb_line;
        end else if (tick) begin
            acc <= acc + step - CLK_HZ;
            ce_out2 <= 1'b1;
            half <= ~half;
            if (half) begin
                ce_out <= 1'b1;
                ox <= ox + 10'd1;
            end
        end else
            acc <= acc + step;
    end

    // One output pixel of pipeline: address at ox, data and timing out at
    // the next ce_out
    wire [9:0] ha0 = sq ? HA0_SQ : HA0_NAT, ha1 = sq ? HA1_SQ : HA1_NAT;
    wire [9:0] hs0 = sq ? HS0_SQ : HS0_NAT, hs1 = sq ? HS1_SQ : HS1_NAT;
    wire       h_act = ox >= ha0 && ox < ha1;
    wire [9:0] rx = ox - ha0;
    reg  [7:0] rd = 8'd0;
    reg        act_d = 1'b0, hs_d = 1'b0, vs_d = 1'b0, vb_d = 1'b1;
    always @(posedge clk) begin
        rd <= line_mem[{rsel, rx[8:0]}];
        if (ce_out) begin
            act_d <= h_act;
            hs_d  <= ox >= hs0 && ox < hs1;
            vs_d  <= show_v >= VS0 && show_v < VS1;
            vb_d  <= show_vb;
        end
    end
    always @(posedge clk)
        if (ce_out) begin
            grey <= (act_d && !vb_d) ? rd : 8'd0;
            hb <= !act_d;
            vb <= vb_d;
            hs <= hs_d;
            vs <= vs_d;
        end
endmodule
`default_nettype wire
