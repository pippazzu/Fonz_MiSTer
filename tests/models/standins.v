// SPDX-License-Identifier: GPL-3.0-or-later
// Behavioural stand-ins for the analogue timing parts around the board, for
// simulation only. They have fixed widths: none of the transistor, pot or
// control-voltage networks is modelled, so speed and shape width do not move
// with the controls. Replace them with the real models
// as those land; tests/tb_board.v is the only place they are wired.
`timescale 1ns/1ps
`default_nettype none

// One 74123 half: retriggerable monostable with clear. Triggers on A falling
// (B high), on B rising (A low) and on /CLR rising (A low, B high), as the
// 74123 does. /CLR low forces Q low. WIDTH is in ns.
module tb_74123_half #(parameter real WIDTH=1000.0) (
    input wire [2:0] ab_clear_n,   // {A, B, /CLR}, as the board exports it
    output reg q
);
    wire a=ab_clear_n[2], b=ab_clear_n[1], clr_n=ab_clear_n[0];
    realtime deadline;
    event fire;
    initial begin q=1'b0; deadline=0; end
    always @(negedge a)     if (b===1'b1 && clr_n===1'b1) ->fire;
    always @(posedge b)     if (a===1'b0 && clr_n===1'b1) ->fire;
    always @(posedge clr_n) if (a===1'b0 && b===1'b1)     ->fire;
    always @(negedge clr_n) q=1'b0;
    always @(fire) begin q=1'b1; deadline=$realtime+WIDTH; end
    // Waits out the latest deadline, so a retrigger stretches the pulse.
    // The 1 ps margin stops a sub-picosecond remainder rounding to #0.
    always @(posedge q) begin
        while ($realtime < deadline-0.001) #(deadline-$realtime);
        q=1'b0;
    end
endmodule

// One 556 half wired as a monostable: output high from a falling trigger
// until WIDTH has passed and the trigger is high again. Reset low clears it.
module tb_556_mono #(parameter real WIDTH=1000.0) (
    input wire trigger_n, reset_n,
    output reg q
);
    initial q=1'b0;
    always @(negedge trigger_n) if (reset_n!==1'b0 && !q) begin
        q=1'b1;
        #(WIDTH);
        if (trigger_n===1'b0) @(posedge trigger_n);
        q=1'b0;
    end
    always @(negedge reset_n) q=1'b0;
endmodule

// One 556 half wired as an astable: free-running square wave.
module tb_556_astable #(parameter real HIGH=500.0, LOW=500.0) (
    input wire reset_n,
    output reg q
);
    initial q=1'b0;
    always begin
        if (reset_n===1'b0) begin q=1'b0; @(posedge reset_n); end
        q=1'b1; #(HIGH);
        q=1'b0; #(LOW);
    end
endmodule

// RC node between a gate output and a TTL input: a transport delay of
// 0.69 RC, where the input crosses its threshold.
module tb_rc_delay #(parameter real DELAY=100.0) (
    input wire d,
    output wire q
);
    assign #(DELAY) q=d;
endmodule
`default_nettype wire
