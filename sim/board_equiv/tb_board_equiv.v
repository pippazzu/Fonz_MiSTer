// SPDX-License-Identifier: GPL-3.0-or-later
// Frame-by-frame equivalence of fonz_board (event model, crystal clock)
// and fonz_board_fpga (one 48 MHz clock),
//
// Both boards run side by side. Each has its own copy of the pixel-locked
// analogue stand-ins (standins.v), stepped by its own pixel clock. Outputs
// are sampled once per crystal period, i.e. twice per pixel (the video is
// gated by IC67 Q, so it changes at half pixels):
//   event model: at each falling edge of IC45.8, before IC67A toggles;
//   FPGA board:  at the clk_sys edge where IC67A sees that same fall.
// Sample k of one board is compared with sample k of the other.
// Run from the repository root (PROM paths are rom/*.hex); see run.sh.
`timescale 1ns/1ps
`default_nettype none
module tb_board_equiv;
`ifndef FRAMES
    localparam integer FRAMES=8;
`else
    localparam integer FRAMES=`FRAMES;
`endif
    localparam integer HALVES_PER_FRAME=2*454*261;
    localparam integer TOTAL=FRAMES*HALVES_PER_FRAME;
    localparam real XTAL_HALF_NS=1.0e9/14.305e6/2.0;
    localparam real SYS_HALF_NS=1.0e9/48.0e6/2.0;

    // ---------------- event model ----------------
    reg ic45_8=1'b0;
    always #(XTAL_HALF_NS) ic45_8=~ic45_8;

    `define BOARD_WIRES(p) \
        wire p``ic9_13,p``ic9_5,p``ic106_13,p``ic106_5; \
        wire p``ic97_13,p``ic97_5,p``ic102_13,p``ic102_5,p``ic104_13,p``ic104_5; \
        wire p``ic30_13,p``ic30_5,p``ic103_13,p``ic103_5; \
        wire p``ic105_5,p``ic105_9,p``ic98_5,p``ic99_9,p``ic99_5; \
        wire p``ic37_12,p``ic37_6,p``ic37_4,p``ic37_2,p``ic37_10; \
        wire p``ic38_1,p``ic38_13,p``antenna_logic; \
        wire [2:0] p``ic9a_ab_clear_n,p``ic9b_ab_clear_n,p``ic106a_ab_clear_n,p``ic106b_ab_clear_n; \
        wire [2:0] p``ic97b_ab_clear_n,p``ic97a_ab_clear_n,p``ic102b_ab_clear_n,p``ic102a_ab_clear_n; \
        wire [2:0] p``ic104b_ab_clear_n,p``ic104a_ab_clear_n,p``ic30a_ab_clear_n,p``ic30b_ab_clear_n; \
        wire [2:0] p``ic103a_ab_clear_n,p``ic103b_ab_clear_n; \
        wire p``ic105_6,p``ic99_4,p``ic38_3,p``ic59_2; \
        wire p``ic5_11,p``ic7_8,p``ic7_12; \
        wire [5:0] p``digit_enable; wire [6:0] p``segments_abcdefg; \
        wire [3:0] p``time_tens,p``time_units,p``score_units,p``score_tens,p``score_hundreds,p``score_thousands;

    `define BOARD_PINS(p) \
        .prom_clk(1'b0),.prom_load(16'd0), \
        .ic37_12(p``ic37_12),.ic37_6(p``ic37_6),.ic37_4(p``ic37_4),.ic37_2(p``ic37_2),.ic37_10(p``ic37_10), \
        .ic105_5(p``ic105_5),.ic105_9(p``ic105_9),.ic9_5(p``ic9_5),.ic106_5(p``ic106_5), \
        .ic9_13(p``ic9_13),.ic106_13(p``ic106_13),.ic98_5(p``ic98_5),.ic99_9(p``ic99_9),.ic99_5(p``ic99_5), \
        .ic97_5(p``ic97_5),.ic97_13(p``ic97_13),.ic102_5(p``ic102_5),.ic102_13(p``ic102_13), \
        .ic104_5(p``ic104_5),.ic104_13(p``ic104_13),        .ic30_13(p``ic30_13),.ic30_5(p``ic30_5),.ic38_1(p``ic38_1),.ic38_13(p``ic38_13), \
        .ic103_13(p``ic103_13),.ic103_5(p``ic103_5),.antenna_logic(p``antenna_logic), \
        .ic5_11(p``ic5_11),.ic7_8(p``ic7_8),.ic7_12(p``ic7_12), \
        .digit_enable(p``digit_enable),.segments_abcdefg(p``segments_abcdefg), \
        .ic9a_ab_clear_n(p``ic9a_ab_clear_n),.ic9b_ab_clear_n(p``ic9b_ab_clear_n), \
        .ic106a_ab_clear_n(p``ic106a_ab_clear_n),.ic106b_ab_clear_n(p``ic106b_ab_clear_n), \
        .ic97b_ab_clear_n(p``ic97b_ab_clear_n),.ic97a_ab_clear_n(p``ic97a_ab_clear_n), \
        .ic102b_ab_clear_n(p``ic102b_ab_clear_n),.ic102a_ab_clear_n(p``ic102a_ab_clear_n), \
        .ic104b_ab_clear_n(p``ic104b_ab_clear_n),.ic104a_ab_clear_n(p``ic104a_ab_clear_n), \
        .ic30a_ab_clear_n(p``ic30a_ab_clear_n),.ic30b_ab_clear_n(p``ic30b_ab_clear_n), \
        .ic103a_ab_clear_n(p``ic103a_ab_clear_n),.ic103b_ab_clear_n(p``ic103b_ab_clear_n), \
        .ic105_6(p``ic105_6),.ic99_4(p``ic99_4),.ic38_3(p``ic38_3),.ic59_2(p``ic59_2), \
        .time_tens(p``time_tens),.time_units(p``time_units),.score_units(p``score_units), \
        .score_tens(p``score_tens),.score_hundreds(p``score_hundreds),.score_thousands(p``score_thousands)

    `define STANDIN_PINS(p) \
        .ic9a_ab_clear_n(p``ic9a_ab_clear_n),.ic9b_ab_clear_n(p``ic9b_ab_clear_n), \
        .ic106a_ab_clear_n(p``ic106a_ab_clear_n),.ic106b_ab_clear_n(p``ic106b_ab_clear_n), \
        .ic97b_ab_clear_n(p``ic97b_ab_clear_n),.ic97a_ab_clear_n(p``ic97a_ab_clear_n), \
        .ic102b_ab_clear_n(p``ic102b_ab_clear_n),.ic102a_ab_clear_n(p``ic102a_ab_clear_n), \
        .ic104b_ab_clear_n(p``ic104b_ab_clear_n),.ic104a_ab_clear_n(p``ic104a_ab_clear_n), \
        .ic30a_ab_clear_n(p``ic30a_ab_clear_n),.ic30b_ab_clear_n(p``ic30b_ab_clear_n), \
        .ic103a_ab_clear_n(p``ic103a_ab_clear_n),.ic103b_ab_clear_n(p``ic103b_ab_clear_n), \
        .ic105_6(p``ic105_6),.ic99_4(p``ic99_4),.ic38_3(p``ic38_3),.ic59_2(p``ic59_2), \
        .ic9_13(p``ic9_13),.ic9_5(p``ic9_5),.ic106_13(p``ic106_13),.ic106_5(p``ic106_5), \
        .ic97_13(p``ic97_13),.ic97_5(p``ic97_5),.ic102_13(p``ic102_13),.ic102_5(p``ic102_5), \
        .ic104_13(p``ic104_13),.ic104_5(p``ic104_5),.ic30_13(p``ic30_13),.ic30_5(p``ic30_5), \
        .ic103_13(p``ic103_13),.ic103_5(p``ic103_5), \
        .ic105_5(p``ic105_5),.ic105_9(p``ic105_9),.ic98_5(p``ic98_5),.ic99_9(p``ic99_9),.ic99_5(p``ic99_5), \
        .ic37_12(p``ic37_12),.ic37_6(p``ic37_6),.ic37_4(p``ic37_4),.ic37_2(p``ic37_2),.ic37_10(p``ic37_10), \
        .ic38_1(p``ic38_1),.ic38_13(p``ic38_13),.antenna_logic(p``antenna_logic)

    `BOARD_WIRES(ev_)
    `BOARD_WIRES(fp_)

    fonz_board ev(.ic45_8(ic45_8),`BOARD_PINS(ev_));
    wire ev_pixel=ev.scene.picture.raster_video.IC67_pin3_PIXEL_CLK;
    // The event model's stand-ins read the board at the pixel edge, like the
    // FPGA board's, but their responses arrive 17 ns later, between the
    // pixel edge and the next crystal edge. Changing them on the pixel edge
    // itself would race the board's own clocks in a zero-delay simulation.
    `BOARD_WIRES(ev_raw_)
    tb_standins ev_analogue(.clk(ev_pixel),.step(1'b1),`STANDIN_PINS(ev_raw_));
    assign #17 ev_ic9_13=ev_raw_ic9_13;
    assign #17 ev_ic9_5=ev_raw_ic9_5;
    assign #17 ev_ic106_13=ev_raw_ic106_13;
    assign #17 ev_ic106_5=ev_raw_ic106_5;
    assign #17 ev_ic97_13=ev_raw_ic97_13;
    assign #17 ev_ic97_5=ev_raw_ic97_5;
    assign #17 ev_ic102_13=ev_raw_ic102_13;
    assign #17 ev_ic102_5=ev_raw_ic102_5;
    assign #17 ev_ic104_13=ev_raw_ic104_13;
    assign #17 ev_ic104_5=ev_raw_ic104_5;
    assign #17 ev_ic30_13=ev_raw_ic30_13;
    assign #17 ev_ic30_5=ev_raw_ic30_5;
    assign #17 ev_ic103_13=ev_raw_ic103_13;
    assign #17 ev_ic103_5=ev_raw_ic103_5;
    assign #17 ev_ic105_5=ev_raw_ic105_5;
    assign #17 ev_ic105_9=ev_raw_ic105_9;
    assign #17 ev_ic98_5=ev_raw_ic98_5;
    assign #17 ev_ic99_9=ev_raw_ic99_9;
    assign #17 ev_ic99_5=ev_raw_ic99_5;
    assign #17 ev_ic37_12=ev_raw_ic37_12;
    assign #17 ev_ic37_6=ev_raw_ic37_6;
    assign #17 ev_ic37_4=ev_raw_ic37_4;
    assign #17 ev_ic37_2=ev_raw_ic37_2;
    assign #17 ev_ic37_10=ev_raw_ic37_10;
    assign #17 ev_ic38_1=ev_raw_ic38_1;
    assign #17 ev_ic38_13=ev_raw_ic38_13;
    assign #17 ev_antenna_logic=ev_raw_antenna_logic;
    assign ev_raw_ic9a_ab_clear_n=ev_ic9a_ab_clear_n;
    assign ev_raw_ic9b_ab_clear_n=ev_ic9b_ab_clear_n;
    assign ev_raw_ic106a_ab_clear_n=ev_ic106a_ab_clear_n;
    assign ev_raw_ic106b_ab_clear_n=ev_ic106b_ab_clear_n;
    assign ev_raw_ic97b_ab_clear_n=ev_ic97b_ab_clear_n;
    assign ev_raw_ic97a_ab_clear_n=ev_ic97a_ab_clear_n;
    assign ev_raw_ic102b_ab_clear_n=ev_ic102b_ab_clear_n;
    assign ev_raw_ic102a_ab_clear_n=ev_ic102a_ab_clear_n;
    assign ev_raw_ic104b_ab_clear_n=ev_ic104b_ab_clear_n;
    assign ev_raw_ic104a_ab_clear_n=ev_ic104a_ab_clear_n;
    assign ev_raw_ic30a_ab_clear_n=ev_ic30a_ab_clear_n;
    assign ev_raw_ic30b_ab_clear_n=ev_ic30b_ab_clear_n;
    assign ev_raw_ic103a_ab_clear_n=ev_ic103a_ab_clear_n;
    assign ev_raw_ic103b_ab_clear_n=ev_ic103b_ab_clear_n;
    assign ev_raw_ic105_6=ev_ic105_6;
    assign ev_raw_ic99_4=ev_ic99_4;
    assign ev_raw_ic38_3=ev_ic38_3;
    assign ev_raw_ic59_2=ev_ic59_2;


    // ---------------- FPGA board ----------------
    reg clk_sys=1'b0, rst=1'b1;
    always #(SYS_HALF_NS) clk_sys=~clk_sys;
    initial begin repeat(4) @(posedge clk_sys); rst<=1'b0; end
    wire fp_ce_pix, fp_xtal;
    fonz_board_fpga fp(.clk_sys(clk_sys),.rst(rst),.ce_pix(fp_ce_pix),.ic45_8(fp_xtal),
        `BOARD_PINS(fp_));
    wire fp_pixel=fp.core.scene.picture.raster_video.IC67_pin3_PIXEL_CLK;
    // The stand-ins step on the clk_sys edge where the board's counters see
    // IC67 Q rise, exactly like IC68.
    reg fp_pixel_l=1'b0, fp_xtal_l=1'b0;
    always @(posedge clk_sys) begin fp_pixel_l<=fp_pixel; fp_xtal_l<=fp_xtal; end
    wire fp_step=fp_pixel & ~fp_pixel_l;
    tb_standins fp_analogue(.clk(clk_sys),.step(fp_step),`STANDIN_PINS(fp_));

    // ---------------- sampling and comparison ----------------
    localparam integer W=3+6+7+24;
    `define OBS(p) {p``ic5_11,p``ic7_8,p``ic7_12,p``digit_enable,p``segments_abcdefg, \
        p``time_tens,p``time_units,p``score_units,p``score_tens,p``score_hundreds,p``score_thousands}
    `define POS(p) {p.scene.picture.raster_video.IC3_pin3_V8,p.scene.picture.raster_video.IC2_pin14_13_12_11_V, \
        p.scene.picture.raster_video.IC24_pin14_13_12_11_V,p.scene.picture.raster_video.IC4_pin3_H8, \
        p.scene.picture.raster_video.IC46_pin14_13_12_11_H,p.scene.picture.raster_video.IC68_pin14_13_12_11_H}
    localparam integer DEPTH=1<<16;
    reg [W-1:0] ev_buf[0:DEPTH-1];
    reg [17:0] ev_pos[0:DEPTH-1];
    integer ev_n=0, fp_n=0, checked=0, mismatches=0, shown=0;
    integer vid_mm=0, disp_mm=0, lags=0, vid_lags=0;
    integer ones_ev=0, frame_mm[0:63];
    integer i;
    initial for (i=0;i<64;i=i+1) frame_mm[i]=0;

    always @(negedge ic45_8) begin
        ev_buf[ev_n%DEPTH]<=`OBS(ev_);
        ev_pos[ev_n%DEPTH]<=`POS(ev);
        ones_ev<=ones_ev+(ev_ic5_11|ev_ic7_8|ev_ic7_12);
        ev_n<=ev_n+1;
    end

    reg [W-1:0] e, f;
`ifdef DEBUG_NETS
    // Internal state, to find where the two boards first part.
    `define ST(p) {p.scene.IC22_pin14_13_12_11,p.scene.IC44_pin14_13_12_11,p.scene.IC21_pin14_13_12_11,p.scene.IC43_pin14_13_12_11, \
        p.scene.position.IC66_pin3_IC65_pin1,p.scene.position.IC66_pin5_IC65_pin5,p.scene.IC83_pin7_ADDR_CLEAR, \
        p.scene.IC18_pin3_2_6_7,p.scene.IC64_pin14_13_12_11,p.scene.IC42_pin14_13_12_11,p.scene.IC20_pin3_IC19_pin3, \
        p.scene.picture.IC69_pin3_2_6_7,p.scene.picture.IC91_pin3_2_6_7,p.scene.picture.IC51_pin3_4_5_6,p.scene.picture.IC51_pin11_10_9_8, \
        p.scene.picture.IC73_pin3_4_5_6,p.scene.picture.IC73_pin11_10_9_8,p.scene.picture.upper.address.IC48_pin3_4_5_6, \
        p.scene.picture.upper.address.IC48_pin11_10_9_8,p.scene.picture.IC88_pin3_4_5_6,p.scene.picture.IC88_pin11_10_9_8, \
        p.scene.picture.IC109_pin3_4_5_6,p.scene.picture.IC109_pin11_10_9_8,p.scene.picture.lower.address.IC63_pin3_4_5_6, \
        p.scene.picture.lower.address.IC63_pin11_10_9_8,p.scene.picture.IC29_pin3_4_5_6,p.scene.picture.IC29_pin11_10_9_8, \
        p.scene.picture.IC28_pin3_4_5_6,p.scene.picture.IC28_pin11_10_9_8,p.scene.picture.IC67_pin6_BIT_CLEAR, \
        p.scene.picture.road.IC20_pin5_IC6_pin1,p.scene.player.IC20_pin3_IC19_pin3,p.scene.player.divider.IC40_pin5_DIV2,p.scene.player.IC41_pin8_PLAYER_LOAD_n}
    localparam integer SW=109;
    `define VN(p) {p.scene.picture.IC71_pin7_UPPER_SHAPE1,p.scene.picture.IC108_pin7_IC6_pin10,p.scene.picture.road.IC41_pin3_IC6_pin9, \
        p.scene.picture.road.IC65_pin8_IC41_pin1,p.scene.picture.road.IC101_pin3_IC65_pin10,p.scene.picture.road.IC101_pin8_IC65_pin9, \
        p.scene.picture.road.IC20_pin6_IC65_pin11,p.scene.IC84_pin11_POSITION_n,p.scene.picture.IC28_pin3_4_5_6[1],p.scene.IC4_pin5_HBLANK,p.scene.IC3_pin5_VBLANK, \
        p.scene.picture.IC102_pin5_LEFT_KERB,p.scene.picture.IC104_pin5_RIGHT_KERB,p.scene.picture.IC103_pin12_START_n,p.scene.IC4_pin6_HBLANK_n,p.scene.IC22_pin14_13_12_11,p.scene.IC44_pin14_13_12_11,p.scene.position.IC65_pin12_POS1_LOAD_n,p.scene.position.IC66_pin3_IC65_pin1}
    reg [24:0] ev_vn[0:DEPTH-1];
    wire [24:0] fp_vn=`VN(fp.core);
    `define VN2(p) {p.scene.picture.raster_video.video.IC27_pin3_IC7_pin13,p.scene.picture.raster_video.video.IC6_pin6_IC27_pin1, \
        p.scene.picture.IC71_pin9_UPPER_SHAPE2,p.scene.picture.IC108_pin9_LOWER_SHAPE2,p.scene.picture.IC101_pin6_ROAD_LOAD_n,p.scene.picture.IC102_pin13_ROAD, \
        p.scene.picture.IC102_pin5_LEFT_KERB,p.scene.picture.road.R67_C44_IC101_pin5}
    reg [7:0] ev_vn2[0:DEPTH-1];
    always @(negedge ic45_8) ev_vn2[ev_n%DEPTH]<=`VN2(ev);
    always @(negedge ic45_8) ev_vn[ev_n%DEPTH]<=`VN(ev);
    reg [SW-1:0] ev_st[0:DEPTH-1];
    always @(negedge ic45_8) ev_st[ev_n%DEPTH]<=`ST(ev);
    // Report internal differences that outlast two samples (shorter ones
    // are ripple counters still settling inside the FPGA board).
    integer st_shown=0, dn=0, d_start=0;
    reg st_diff=1'b0;
    reg [SW-1:0] d_ev, d_fp, d_or;
    always @(posedge clk_sys) if (!rst && fp_xtal_l && !fp_xtal) begin
        if (ev_st[dn%DEPTH]!==`ST(fp.core)) begin
            if (!st_diff) begin
                d_start=dn; d_ev=ev_st[dn%DEPTH]; d_fp=`ST(fp.core); d_or=0;
            end
            d_or=d_or|(ev_st[dn%DEPTH]^`ST(fp.core));
            st_diff=1'b1;
        end else begin
            if (st_diff && dn-d_start>2 && st_shown<40) begin
                st_shown=st_shown+1;
                $display("internal difference for %0d samples from %0d (v=%0d h=%0d.%0d)",
                    dn-d_start,d_start,ev_pos[d_start%DEPTH][17:9],
                    ev_pos[d_start%DEPTH][8:0],d_start%2);
                $display("   ev  %b",d_ev);
                $display("   fp  %b",d_fp);
                $display("   bits%b",d_or);
            end
            st_diff=1'b0;
        end
        dn=dn+1;
    end
`endif
    always @(posedge clk_sys) if (!rst && fp_xtal_l && !fp_xtal) begin
        if (fp_n>=ev_n) $fatal(1,"FPGA board ran ahead of the event model");
        if (ev_n-fp_n>=DEPTH) $fatal(1,"event model ran too far ahead");
        e=ev_buf[fp_n%DEPTH];
        f=`OBS(fp_);
        if (`POS(fp.core)!==ev_pos[fp_n%DEPTH]) begin
            $display("raster position differs at sample %0d: ev %h fp %h",
                     fp_n,ev_pos[fp_n%DEPTH],`POS(fp.core));
            $fatal(1,"FAIL: the two rasters are out of step");
        end
        if (e!==f && fp_n>0 && f===ev_buf[(fp_n-1)%DEPTH]) begin
            // Long ripple chains (IC74 to IC79 for the display, IC109/IC88 or
            // IC73/IC51 into a registered PROM for the shapes) can take more
            // than half a pixel on clk_sys, so a sample may still show the
            // event model's previous one. Counted apart, not as a difference.
            lags=lags+1;
            if (e[W-1:W-3]!==f[W-1:W-3]) vid_lags=vid_lags+1;
            if (lags<=10)
                $display("one sample late at sample %0d frame %0d v=%0d h=%0d: ev %b fp %b",
                    fp_n,fp_n/HALVES_PER_FRAME,ev_pos[fp_n%DEPTH][17:9],ev_pos[fp_n%DEPTH][8:0],e,f);
        end else if (e!==f) begin
            // Settle check: look again one clk_sys later (below).
            pend<=1'b1; pend_e<=e; pend_n<=fp_n;
        end
`ifdef DEBUG_NETS
        if (ev_pos[fp_n%DEPTH][8:0]==9'd300 && fp_n%2==0 && ev_vn[fp_n%DEPTH][10:0]!==fp_vn[10:0] && shown<80) begin
            shown=shown+1;
            $display("line v=%0d h=%0d.%0d: ev 22/44/65_12/66_3 %b fp %b",ev_pos[fp_n%DEPTH][17:9],ev_pos[fp_n%DEPTH][8:0],fp_n%2,ev_vn[fp_n%DEPTH][11:0],fp_vn[11:0]);
        end
`endif
        checked=checked+1;
        fp_n=fp_n+1;
        if (fp_n%HALVES_PER_FRAME==0)
            $display("frame %0d: %0d of %0d samples differ (score %0d%0d%0d%0d, time %0d%0d, game %b crash %b%b)",
                fp_n/HALVES_PER_FRAME-1,frame_mm[fp_n/HALVES_PER_FRAME-1],HALVES_PER_FRAME,
                fp_score_thousands,fp_score_hundreds,fp_score_tens,fp_score_units,
                fp_time_tens,fp_time_units,fp.ic83_9,fp_ic30_13,fp_ic30_5);
        if (fp_n==TOTAL+1) begin
            $display("%0d samples over %0d frames; %0d differ (video %0d, display %0d); %0d one sample late (%0d video); %0d one-clk_sys transients; event-model video lit in %0d",
                     checked-1,FRAMES,mismatches,vid_mm,disp_mm,lags,vid_lags,transients,ones_ev);
            if (mismatches==0) $display("PASS: fonz_board_fpga matches fonz_board");
            else $display("FAIL: %0d samples differ",mismatches);
            $finish;
        end
    end

    // A sample that differs is looked at again one clk_sys later. If the FPGA
    // board then shows the event model's value, the difference was a ripple
    // transient (a 74393 chain or two counters on one address still
    // settling, which the zero-delay model does in no time; on the board the
    // 470 pF on the 74153 outputs hide it) and is counted apart.
    reg pend=1'b0;
    reg [W-1:0] pend_e, pf;
    integer pend_n=0, transients=0;
    always @(posedge clk_sys) if (pend) begin
        pend<=1'b0;
        pf=`OBS(fp_);
        if (pf===pend_e) begin
            transients=transients+1;
            if (transients<=10)
                $display("transient for one clk_sys at sample %0d frame %0d v=%0d h=%0d: ev %b",
                    pend_n,pend_n/HALVES_PER_FRAME,ev_pos[pend_n%DEPTH][17:9],ev_pos[pend_n%DEPTH][8:0],pend_e);
        end else begin
            mismatches=mismatches+1;
            if (pend_e[W-1:W-3]!==pf[W-1:W-3]) vid_mm=vid_mm+1;
            if (pend_e[W-4:0]!==pf[W-4:0]) disp_mm=disp_mm+1;
            frame_mm[pend_n/HALVES_PER_FRAME]=frame_mm[pend_n/HALVES_PER_FRAME]+1;
            if (shown<40) begin
                $display("sample %0d frame %0d v=%0d h=%0d.%0d: ev %b fp %b",
                    pend_n,pend_n/HALVES_PER_FRAME,ev_pos[pend_n%DEPTH][17:9],
                    ev_pos[pend_n%DEPTH][8:0],pend_n%2,pend_e,pf);
                shown=shown+1;
`ifdef DEBUG_NETS
                $display("   ev prev %b next %b",ev_buf[(pend_n-1)%DEPTH],ev_buf[(pend_n+1)%DEPTH]);
                $display("   video nets ev %b fp %b",ev_vn[pend_n%DEPTH],`VN(fp.core));
                $display("   27_3 6_6 71_9 108_9 101_6 102_13 102_5 r67: ev %b fp %b",
                    ev_vn2[pend_n%DEPTH],`VN2(fp.core));
`endif
            end
        end
    end
endmodule
`default_nettype wire
