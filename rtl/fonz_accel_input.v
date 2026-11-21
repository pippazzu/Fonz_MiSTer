`timescale 1ns/1ps
// MiSTer throttle demand for The Fonz's photocoupler grip.
//
// The grip has a continuous range, so the demand is 0..255 and comes from
// whichever source is pressed furthest:
//   * the right analogue trigger R2 (hps_io command 0x46, {RT,LT});
//   * a stick axis chosen on the OSD (stick_sel);
//   * a full-throttle button (active high, as hps_io's joystick bits).
// A Main_MiSTer without trigger support leaves joytrig at 0, so the stick
// and the button still work.
//
// MiSTer analogue sticks are signed -127..+127, Y in [15:8], up negative.
// stick_sel: 0 none, 1 left stick up, 2 right stick up, 3 right stick down.
//
// grip is the separate ACCEL contact on the grip (connector 16): closed as
// soon as the grip leaves rest, taken here as demand above GRIP_ON.
module fonz_accel_input #(
    parameter [7:0] GRIP_ON = 8'd12
)(
    input  wire [15:0] joytrig,     // {RT,LT}, 0..255 each
    input  wire [15:0] joyana_l,
    input  wire [15:0] joyana_r,
    input  wire [ 1:0] stick_sel,
    input  wire        full,
    output wire [ 7:0] demand,
    output wire        grip
);
    wire [7:0] trig = joytrig[15:8];

    reg signed [7:0] axis;
    always @* begin
        case (stick_sel)
            2'd1:    axis = -$signed(joyana_l[15:8]);
            2'd2:    axis = -$signed(joyana_r[15:8]);
            2'd3:    axis =  $signed(joyana_r[15:8]);
            default: axis = 8'sd0;
        endcase
    end

    // 1..127 -> 2..255 (bit 6 copied into bit 0 so +127 reaches 255);
    // -128 negates to itself and reads as zero.
    wire [6:0] mag   = axis[7] ? 7'd0 : axis[6:0];
    wire [7:0] stick = {mag, mag[6]};

    wire [7:0] analog = trig > stick ? trig : stick;
    assign demand = full ? 8'hff : analog;
    assign grip   = demand > GRIP_ON;
endmodule
