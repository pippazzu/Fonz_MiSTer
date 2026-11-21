// SPDX-License-Identifier: GPL-3.0-or-later
// Not part of the traced board. Turns the MiSTer ROM download (ioctl index 0,
// one byte per PROM address, built from the MRA) into the prom_load bus that
// fills the four shape PROMs in fonz_prom.
//
// Download layout, written by scripts/make_mra.py:
//   0x000-0x1ff  IC86 ic86.86   (lower shape)
//   0x200-0x3ff  IC87 ic87.87   (lower shape)
//   0x400-0x4ff  IC49 pr-09.49  (upper shape)
//   0x500-0x5ff  IC50 pr-08.50  (upper shape)
// Each byte holds Q1 in bit 0 and Q4 in bit 3, exactly as dumped. The
// Q4..Q1 -> C0..C3 reversal stays in the IC71/IC108 multiplexer wiring.
`timescale 1ns/1ps
`default_nettype none
module fonz_prom_load(
    input wire [25:0] ioctl_addr,
    input wire [7:0] ioctl_dout,
    input wire ioctl_wr,
    input wire [7:0] ioctl_index,
    input wire downloading,
    output wire [15:0] prom_load
);
    wire hit=downloading && ioctl_wr && ioctl_index==8'd0 && ioctl_addr<26'h600;
    assign prom_load={hit,ioctl_addr[10:0],ioctl_dout[3:0]};
endmodule
`default_nettype wire
