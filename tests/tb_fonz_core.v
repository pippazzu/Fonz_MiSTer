// SPDX-License-Identifier: GPL-3.0-or-later
// The Template_MiSTer core wrapper (rtl/mister/fonz_core.v) driven the way
// mister/Fonz.sv drives it from hps_io. Checks
//   - the ROM download holds rst, and every board PROM ends up holding its
//     dump (each PROM is cleared first, so nothing comes from $readmemh);
//     bytes past 0x5ff, on another index or outside a download change nothing;
//   - rst falls RST_HOLD clocks after the download, and the pixel enable
//     runs while rst is high;
//   - hsync runs at 15.75 kHz after the release, and again after an OSD reset;
//   - joystick_0 bits, analogue inputs and status bits reach the machine on
//     the inputs fonz_core's header names.
// The download is assembled from rom/*.hex at the offsets of
// scripts/make_mra.py, as in tests/tb_prom_load.v.
`timescale 1ns/1ps
`default_nettype none
`define FONZ_CLK_SYS_HZ 57220000
module tb_fonz_core;
    localparam integer CLK_HZ = 57_220_000;
    localparam integer HOLD = 4096;
    localparam real HALF_NS = 1.0e9 / CLK_HZ / 2.0;

    reg clk = 1'b0;
    always #(HALF_NS) clk = ~clk;

    reg         reset_req = 1'b0;
    reg         ioctl_download = 1'b0, ioctl_wr = 1'b0;
    reg  [ 7:0] ioctl_index = 8'd0, ioctl_dout = 8'd0;
    reg  [26:0] ioctl_addr = 27'd0;
    reg  [31:0] joystick = 32'd0;
    reg  [15:0] ana_l = 16'd0, ana_r = 16'd0;
    reg  [ 7:0] lt = 8'd0, rt = 8'd0;
    reg [127:0] status = 128'd0;

    wire        ce_out, hs, vs, hb, vb, rst;
    wire [ 7:0] grey;
    wire [15:0] rumble;

    fonz_core #(.CLK_HZ(CLK_HZ), .RST_HOLD(HOLD)) dut(
        .clk(clk), .reset_req(reset_req),
        .ioctl_download(ioctl_download), .ioctl_index(ioctl_index),
        .ioctl_wr(ioctl_wr), .ioctl_addr(ioctl_addr), .ioctl_dout(ioctl_dout),
        .joystick(joystick), .joystick_l_analog(ana_l), .joystick_r_analog(ana_r),
        .joystick_lt(lt), .joystick_rt(rt), .status(status),
        .ce_out(ce_out), .grey(grey), .hs(hs), .vs(vs), .hb(hb), .vb(vb),
        .rumble(rumble), .rst(rst));

    integer errors = 0, i;
    task check(input ok, input [8*72-1:0] what);
        begin
            if (ok) $display("  ok   %0s", what);
            else begin $display("  FAIL %0s", what); errors = errors + 1; end
        end
    endtask

    // ---- counters ---------------------------------------------------------------
    integer pix_in_rst = 0, hs_pulses = 0, out_pix = 0;
    reg hs_l = 1'b0;
    always @(posedge clk) begin
        if (rst && dut.ce_pix) pix_in_rst = pix_in_rst + 1;
        if (ce_out) out_pix = out_pix + 1;
        hs_l <= hs;
        if (hs && !hs_l) hs_pulses = hs_pulses + 1;
    end

    // ---- download ------------------------------------------------------------------
    reg [3:0] ref86[0:511], ref87[0:511], ref49[0:255], ref50[0:255];
    reg [7:0] image[0:1535];
    integer prom_errors = 0;

    // hps_io raises ioctl_wr for one clk per byte, with the address and
    // data already set; bytes come a few clocks apart.
    task send(input [26:0] a, input [7:0] d, input [7:0] index);
        begin
            @(negedge clk);
            ioctl_addr = a; ioctl_dout = d; ioctl_index = index; ioctl_wr = 1'b1;
            @(negedge clk);
            ioctl_wr = 1'b0;
            repeat (3) @(negedge clk);
        end
    endtask

    task cmp(input [8*4-1:0] chip, input integer a, input [3:0] got, input [3:0] want);
        if (got !== want) begin
            prom_errors = prom_errors + 1;
            if (prom_errors < 10) $display("  %0s[%0d]: got %h, want %h", chip, a, got, want);
        end
    endtask

    // ---- one clock of wiring checks -------------------------------------------------
    task wiring;
        begin
            joystick = 32'h0000_0002; status = 128'd0; #1;
            check(dut.u_machine.pad_left && !dut.u_machine.pad_right, "joystick bit 1 is left");
            joystick = 32'h0000_0001; #1;
            check(dut.u_machine.pad_right && !dut.u_machine.pad_left, "joystick bit 0 is right");
            joystick = 32'h0000_0010; #1;
            check(dut.u_machine.pad_accel && !dut.u_machine.pad_start, "joystick bit 4 is Accelerate");
            joystick = 32'h0000_0020; #1;
            check(!dut.u_machine.pad_accel && !dut.u_machine.pad_start && !dut.u_machine.pad_coin,
                  "joystick bit 5 is unused");
            joystick = 32'h0000_0040; #1;
            check(dut.u_machine.pad_start && !dut.u_machine.pad_coin, "joystick bit 6 is Start");
            joystick = 32'h0000_0080; #1;
            check(dut.u_machine.pad_coin && !dut.u_machine.pad_start, "joystick bit 7 is Coin");
            joystick = 32'd0;
            lt = 8'h12; rt = 8'hab; ana_l = 16'h8001; ana_r = 16'h7f02; #1;
            check(dut.u_machine.joytrig == 16'hab12, "triggers reach joytrig as {RT,LT}");
            check(dut.u_machine.joyana_l == 16'h8001 && dut.u_machine.joyana_r == 16'h7f02,
                  "analogue sticks reach the machine");
            lt = 0; rt = 0; ana_l = 0; ana_r = 0;
            #1;
            check(dut.u_machine.overlay_enable && dut.u_machine.rumble_enable &&
                  dut.u_machine.stick_sel == 2'd1 && dut.u_machine.pots == 40'd0 &&
                  !dut.u_crt.squeeze, "status 0: overlay, rumble, left stick, factory pots, native");
            status[23] = 1'b1; status[24] = 1'b1; status[27] = 1'b1; #1;
            check(!dut.u_machine.overlay_enable && !dut.u_machine.rumble_enable && dut.u_crt.squeeze,
                  "status 23, 24, 27: overlay off, squeeze, rumble off");
            status[26:25] = 2'd1; #1; check(dut.u_machine.stick_sel == 2'd0, "status 26:25 = 1: no stick");
            status[26:25] = 2'd2; #1; check(dut.u_machine.stick_sel == 2'd2, "status 26:25 = 2: right up");
            status[26:25] = 2'd3; #1; check(dut.u_machine.stick_sel == 2'd3, "status 26:25 = 3: right down");
            status[103:64] = 40'hab_dead_beef; #1;
            check(dut.u_machine.pots == 40'hab_dead_beef, "status 103:64 are the pots");
            status = 128'd0; #1;
        end
    endtask

    integer t_end;
    initial begin
        $readmemh("rom/ic86.86.hex", ref86);
        $readmemh("rom/ic87.87.hex", ref87);
        $readmemh("rom/pr-09.49.hex", ref49);
        $readmemh("rom/pr-08.50.hex", ref50);
        for (i = 0; i < 512; i = i + 1) begin
            image[i] = {4'h0, ref86[i]}; image[512+i] = {4'h0, ref87[i]};
        end
        for (i = 0; i < 256; i = i + 1) begin
            image[1024+i] = {4'h0, ref49[i]}; image[1280+i] = {4'h0, ref50[i]};
        end
        #1; // after the PROMs' own $readmemh
        for (i = 0; i < 512; i = i + 1) begin
            dut.u_machine.board.core.scene.picture.lower.ic86.mem[i] = 4'h0;
            dut.u_machine.board.core.scene.picture.lower.ic87.mem[i] = 4'h0;
        end
        for (i = 0; i < 256; i = i + 1) begin
            dut.u_machine.board.core.scene.picture.upper.ic49.mem[i] = 4'h0;
            dut.u_machine.board.core.scene.picture.upper.ic50.mem[i] = 4'h0;
        end

        $display("wiring");
        wiring;

        $display("download");
        repeat (100) @(negedge clk);
        ioctl_download = 1'b1;
        for (i = 0; i < 1536; i = i + 1) send(i, image[i], 8'd0);
        for (i = 1536; i < 2048; i = i + 1) send(i, 8'h0a, 8'd0);
        send(27'd0, 8'h05, 8'd1);
        check(rst, "rst held during the download");
        @(negedge clk) ioctl_download = 1'b0;
        send(27'd0, 8'h05, 8'd0);
        for (i = 0; i < 512; i = i + 1) begin
            cmp("IC86", i, dut.u_machine.board.core.scene.picture.lower.ic86.mem[i], ref86[i]);
            cmp("IC87", i, dut.u_machine.board.core.scene.picture.lower.ic87.mem[i], ref87[i]);
        end
        for (i = 0; i < 256; i = i + 1) begin
            cmp("IC49", i, dut.u_machine.board.core.scene.picture.upper.ic49.mem[i], ref49[i]);
            cmp("IC50", i, dut.u_machine.board.core.scene.picture.upper.ic50.mem[i], ref50[i]);
        end
        check(prom_errors == 0, "1536 PROM locations loaded through fonz_core");

        $display("reset release");
        // The download ended 5 clocks ago (the last send); rst must fall
        // HOLD + 1 clocks after the download ended.
        repeat (HOLD - 20) @(negedge clk);
        check(rst, "rst still held just before RST_HOLD clocks");
        repeat (40) @(negedge clk);
        check(!rst, "rst released RST_HOLD clocks after the download");
        $display("  %0d pixel enables while rst was high", pix_in_rst);
        check(pix_in_rst > 1000, "the pixel enable runs during rst");

        $display("video");
        hs_pulses = 0; out_pix = 0;
        #(1_000_000);                 // 1 ms: about 15.75 lines
        $display("  %0d hsync pulses, %0d output pixels in 1 ms", hs_pulses, out_pix);
        check(hs_pulses >= 15 && hs_pulses <= 16, "hsync at 15.75 kHz");
        check(out_pix > 7100 && out_pix < 7200, "output pixel enable at 7.15 MHz");

        $display("OSD reset");
        @(negedge clk) reset_req = 1'b1;
        repeat (50) @(negedge clk);
        check(rst, "rst follows the reset request");
        reset_req = 1'b0;
        hs_pulses = 0;
        #(500_000);
        check(!rst, "rst released after the reset request");
        $display("  %0d hsync pulses in the 0.5 ms after the reset request", hs_pulses);
        check(hs_pulses >= 6, "hsync back after an OSD reset");

        if (errors == 0) $display("PASS: fonz_core download, reset, video and input wiring");
        else $display("FAIL: %0d checks", errors);
        $finish;
    end
endmodule
`default_nettype wire
