// SPDX-License-Identifier: GPL-3.0-or-later
// The Fonz (Sega, 1976): the core for MiSTer-devel's
// Template_MiSTer framework (mister/Fonz.sv). Not original circuitry.
//
// Fonz.sv keeps only the framework parts (hps_io, the PLL, arcade_video);
// everything between them and the machine is here, so it can be simulated
// without the framework (tests/tb_fonz_core.v):
//
// - Reset. The board has no reset line, but the machine's rst holds every
//   flip-flop of the trace. rst is held while the framework asks for a reset
//   (MiSTer reset button, OSD reset) and during the ROM download, then for
//   RST_HOLD more clocks (about 1.1 ms at 57.22 MHz, some 17 lines). The
//   machine keeps its pixel enable running during rst (docs/MISTER_CORE.md,
//   "Reset"); sync comes back within a line or two of the release
//   (tests/tb_fonz_core.v).
// - PROM download. The MRA (mra/The Fonz.mra) sends the four shape PROMs as
//   ioctl index 0, one nibble a byte at 0x000-0x5ff;
//   fonz_prom_load_fpga turns it into the board's prom_load bus.
// - Inputs. joystick is hps_io's joystick_0, active high, in the button
//   order of the MRA's <buttons> and the J1 line of Fonz.sv's CONF_STR:
//   bit 0 right, 1 left, 2 down, 3 up, 4 Accelerate (full throttle),
//   5 unused, 6 Start, 7 Coin. Start and Coin both insert a coin: the
//   cabinet has no start button.
// - Options, from hps_io's status word (CONF_STR in Fonz.sv), 0 the
//   default for each:
//     bit 23     score and time overlay: 0 on, 1 off
//     bit 24     CRT picture: 0 native, 1 the 3:4 squeeze
//     bits 26:25 throttle stick: left up, none, right up, right down
//     bit 27     rumble on crash: 0 on, 1 off
//     bits 103:64 board pots (scripts/pot_settings.py)
// - Video: the machine's grey level through fonz_crt_out (sync placed
//   for a 15 kHz CRT, the optional 3:4 squeeze). ce_out is one clk per
//   output pixel, for arcade_video's ce_pix.
`timescale 1ns/1ps
`default_nettype none
module fonz_core #(
    parameter integer CLK_HZ   = 57_220_000,
    parameter integer RST_HOLD = 65_536
)(
    input  wire        clk,
    input  wire        reset_req,       // RESET | OSD reset | MiSTer button
    // hps_io ROM download
    input  wire        ioctl_download,
    input  wire [ 7:0] ioctl_index,
    input  wire        ioctl_wr,
    input  wire [26:0] ioctl_addr,
    input  wire [ 7:0] ioctl_dout,
    // hps_io controls, player 1
    input  wire [31:0] joystick,
    input  wire [15:0] joystick_l_analog,  // Y [15:8], X [7:0], -127..127
    input  wire [15:0] joystick_r_analog,
    input  wire [ 7:0] joystick_lt,        // 0..255
    input  wire [ 7:0] joystick_rt,
    input  wire [127:0] status,
    // To arcade_video
    output wire        ce_out,
    output wire [ 7:0] grey,
    output wire        hs, vs, hb, vb,
    // To hps_io joystick_0_rumble: [15:8] large, [7:0] small motor
    output wire [15:0] rumble,
    output wire        rst
);
    // ---- reset --------------------------------------------------------------
    localparam integer RW = $clog2(RST_HOLD + 1);
    reg [RW-1:0] rst_cnt = RST_HOLD[RW-1:0];
    reg          rst_r = 1'b1;
    always @(posedge clk) begin
        if (reset_req || ioctl_download) begin
            rst_cnt <= RST_HOLD[RW-1:0];
            rst_r   <= 1'b1;
        end else if (rst_cnt != {RW{1'b0}}) begin
            rst_cnt <= rst_cnt - 1'd1;
        end else begin
            rst_r   <= 1'b0;
        end
    end
    assign rst = rst_r;

    // ---- PROM download ----------------------------------------------------------
    wire [15:0] prom_load;
    fonz_prom_load_fpga u_prom_load(
        .clk_sys     ( clk               ),
        .rst         ( rst_r             ),
        .ioctl_addr  ( ioctl_addr[25:0]  ),
        .ioctl_dout  ( ioctl_dout        ),
        .ioctl_wr    ( ioctl_wr          ),
        .ioctl_index ( ioctl_index       ),
        .downloading ( ioctl_download    ),
        .prom_load   ( prom_load         )
    );

    // ---- options ------------------------------------------------------------------
    // OSD order: left up, none, right up, right down; fonz_accel_input
    // takes 0 none, 1 left up, 2 right up, 3 right down.
    wire [1:0] stick_osd = status[26:25];
    wire [1:0] stick_sel = stick_osd == 2'd0 ? 2'd1 :
                           stick_osd == 2'd1 ? 2'd0 : stick_osd;

    // ---- machine ------------------------------------------------------------------
    wire [7:0] grey_board;
    wire       hb_board, vb_board, ce_pix, ce_out2;

    fonz_machine_fpga #(.CLK_SYS_HZ(CLK_HZ)) u_machine(
        .clk_sys        ( clk                       ),
        .rst            ( rst_r                     ),
        .pad_left       ( joystick[1]               ),
        .pad_right      ( joystick[0]               ),
        .pad_accel      ( joystick[4]               ),
        .pad_coin       ( joystick[7]               ),
        .pad_start      ( joystick[6]               ),
        .pad_tilt       ( 1'b0                      ),
        .joytrig        ( {joystick_rt, joystick_lt} ),
        .joyana_l       ( joystick_l_analog         ),
        .joyana_r       ( joystick_r_analog         ),
        .stick_sel      ( stick_sel                 ),
        .overlay_enable ( ~status[23]               ),
        .rumble_enable  ( ~status[27]               ),
        .pots           ( status[103:64]            ),
        .prom_load      ( prom_load                 ),
        .ce_pix         ( ce_pix                    ),
        .ce_xtal        (                           ),
        .ce_xtal2       (                           ),
        .grey           ( grey_board                ),
        .hs             (                           ),
        .vs             (                           ),
        .hb             ( hb_board                  ),
        .vb             ( vb_board                  ),
        .raster_h       (                           ),
        .raster_v       (                           ),
        .IC83_pin9_GAME_LATCH (                     ),
        .game_digits    (                           ),
        .IC105_pin3_mv  (                           ),
        .rumble         ( rumble                    )
    );

    // ---- video out --------------------------------------------------------------------
    fonz_crt_out #(.CLK_HZ(CLK_HZ)) u_crt(
        .clk     ( clk         ),
        .squeeze ( status[24]  ),
        .ce_pix  ( ce_pix      ),
        .grey_in ( grey_board  ),
        .hb_in   ( hb_board    ),
        .vb_in   ( vb_board    ),
        .ce_out  ( ce_out      ),
        .ce_out2 ( ce_out2     ),
        .grey    ( grey        ),
        .hs      ( hs          ),
        .vs      ( vs          ),
        .hb      ( hb          ),
        .vb      ( vb          )
    );
endmodule
`default_nettype wire
