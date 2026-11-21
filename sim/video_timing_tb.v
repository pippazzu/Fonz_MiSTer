// SPDX-License-Identifier: GPL-3.0-or-later
// Runs the traced raster (fonz_raster) through fonz_video_timing and
// checks every edge against docs/VIDEO_TIMING.md. Prints PASS or FAIL.
//   iverilog -o build/video_timing sim/video_timing_tb.v \
//       rtl/fonz_raster.v rtl/fonz_video_timing.v rtl/ttl/fonz_ttl.v
//   vvp build/video_timing
`timescale 1ns/1ps
`default_nettype none
module video_timing_tb;
    // 14.305 MHz crystal at IC45.8
    reg xtal=1'b0; always #34.953 xtal=~xtal;
    wire ic67_3,ic67_2; wire [3:0] ic68_q,ic46_q,ic24_q,ic2_q;
    wire ic4_3,ic4_2,ic4_5,ic4_6,ic3_3,ic3_2,ic3_5,ic3_6;
    wire ic89_8,ic27_8,ic27_11,ic25_8,ic25_12,ic26_10,ic26_12;
    wire ic95_1,ic95_13,ic95_10;
    fonz_raster raster(.ic45_8(xtal),.ic67_3(ic67_3),.ic67_2(ic67_2),
        .ic68_q(ic68_q),.ic46_q(ic46_q),.ic24_q(ic24_q),.ic2_q(ic2_q),
        .ic4_3(ic4_3),.ic4_2(ic4_2),.ic4_5(ic4_5),.ic4_6(ic4_6),
        .ic3_3(ic3_3),.ic3_2(ic3_2),.ic3_5(ic3_5),.ic3_6(ic3_6),
        .ic89_8(ic89_8),.ic27_8(ic27_8),.ic27_11(ic27_11),
        .ic25_8(ic25_8),.ic25_12(ic25_12),.ic26_10(ic26_10),.ic26_12(ic26_12),
        .ic95_1(ic95_1),.ic95_13(ic95_13),.ic95_10(ic95_10));
    wire pxl_clk,hs,vs,hb,vb,lhbl,lvbl,csync_n;
    fonz_video_timing timing(.IC67_pin3_PIXEL_CLK(ic67_3),.IC4_pin5_HBLANK(ic4_5),
        .IC27_pin11_HSYNC_n(ic27_11),.IC3_pin5_VBLANK(ic3_5),.IC25_pin12_VSYNC_n(ic25_12),.pxl_clk(pxl_clk),.hs(hs),.vs(vs),
        .hb(hb),.vb(vb),.lhbl(lhbl),.lvbl(lvbl),.csync_n(csync_n));

    // Counters of our own, aligned on the first VBLANK edge after warm-up.
    integer x=0, y=0, frame=0, errors=0, n=0;
    integer hs_on=-1, hs_off=-1, hb_on=-1, hb_off=-1, line_len=0;
    integer vs_on=-1, vs_off=-1, vb_on=-1, vb_off=-1, active_px=0;
    reg phs=0, pvs=0, phb=0, pvb=0, locked=0;
    real t_line0=0.0, t_line=0.0, t_frame0=0.0, t_frame=0.0;
    task check(input integer got, input integer want, input [8*16-1:0] what);
        if (got!==want) begin
            $display("FAIL %0s: got %0d, expected %0d", what, got, want);
            errors=errors+1;
        end
    endtask
    always @(posedge pxl_clk) begin
        #1;
        n=n+1;
        if (locked) begin
            x=x+1;
            if (hb && !phb) begin
                if (y>0 && x!==454) begin
                    $display("FAIL line %0d length %0d", y, x); errors=errors+1;
                end
                x=0; y=y+1;
                t_line=$realtime-t_line0; t_line0=$realtime;
            end
            if (vb && !pvb) begin
                if (frame>0) check(y, 261, "lines per frame");
                y=0; frame=frame+1;
                t_frame=$realtime-t_frame0; t_frame0=$realtime;
            end
            if (frame==2) begin
                if (hs && !phs && y==20) hs_on=x;
                if (!hs && phs && y==20) hs_off=x;
                if (!hb && phb && y==20) hb_off=x;
                if (vs && !pvs) vs_on=y;
                if (!vs && pvs) vs_off=y;
                if (!vb && pvb) vb_off=y;
                if (!hb && !vb) active_px=active_px+1;
                // Composite sync is HSYNC outside VSYNC, inverted inside.
                if (csync_n !== (vs ? hs : ~hs)) begin
                    $display("FAIL csync at y=%0d x=%0d", y, x); errors=errors+1;
                end
            end
            if (frame==3) begin
                check(hs_on, 32, "HSYNC start");
                check(hs_off, 64, "HSYNC end");
                check(hb_off, 80, "HBLANK end");
                check(vs_on, 4, "VSYNC start");
                check(vs_off, 8, "VSYNC end");
                check(vb_off, 16, "VBLANK end");
                check(active_px, 374*245, "active pixels");
                $display("line %.3f us (%.3f kHz), frame %.4f ms (%.3f Hz)",
                    t_line/1000.0, 1.0e6/t_line, t_frame/1.0e6, 1.0e9/t_frame);
                $display("%0s: %0d errors", errors ? "FAIL" : "PASS", errors);
                $finish;
            end
        end else if (n>454*262 && vb && !pvb) begin
            locked=1; x=0; y=0; frame=1; t_line0=$realtime; t_frame0=$realtime;
        end
        phs=hs; pvs=vs; phb=hb; pvb=vb;
    end
endmodule
`default_nettype wire
