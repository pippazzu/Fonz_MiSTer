`timescale 1ns/1ps
// The Fonz photocoupler throttle, from grip demand to the IC105A control
// voltage (network in docs/CONTROLS.md, "Throttle").
//
//   lamp (IC39.3 low) -> photocell c..a -> node a -> VR11 wiper
//   -> R107 100k -> C77 47u -> R108 3.3k -> TR10 base, emitter via D14
//   -> TR10 collector sinks IC105 pin 3 (R109 1k to +5 V, 556 divider)
//
// Wiper. The cell values are not on the drawing, but the manual's
// adjustment page gives what VR-12 (lower limit) and VR-11 (upper limit)
// are set for ("Details of logic board adjustments", standard size). Its
// two position lines run under the wheels of the player's bike: at the
// start they are 3/4 in above the bottom edge of the picture, and with the
// grip fully open 12 3/4 in above that same edge. (The 2 in at the top of
// the drawing belongs to the road, not to the bike.) The page draws the
// picture at about 52 units an inch, 18 3/4 in tall, which fits the 23 in
// tube; the 245 visible lines (13 to 257) are then 13.07 lines an inch.
// The bike is drawn from the end of IC105A's pulse (pin 5 clears IC88),
// which starts at VSYNC, line 4. Its height comes from the IC106 shape
// oscillator: with VR-1/VR-9 at 1.8k it is 42 lines at the start, the
// manual's 3 1/4 in, and 27 lines up the road (whole-machine simulation):
//   start      bike on lines 206 to 247   pulse 12.7 ms   pin 3 3.90 V
//   full grip  bike on lines  79 to 107   pulse  4.8 ms   pin 3 2.16 V
// That is the wheels 0.77 in above the bottom of the picture at the start
// and 61 % of the way up it at full grip. The page is not to one scale
// there: it writes 12 3/4 in for the full-grip line (68 % of 18 3/4 in)
// but draws that line 61 % of the way up. Set to the written figure
// (pin 3 1.85 V, WIPER_FULL_MV 3286, bike on lines 65 to 91) the bike
// still went too far up the road on the real board (12 November
// 2026), so the full-grip limit follows the drawing.
// VR-11 is on the OSD page "Board adjustments" (scripts/pot_settings.py,
// 21 November 2026): the port VR11_full_mv is the full-grip wiper voltage
// for its code, 3061 mV (the drawing) at the factory setting, higher to
// take the bike further up the road at full grip.
// (R100 56k, C68 0.15 uF: width = 8.4 ms * ln(5 / (5 - Vpin3))). Demand
// 0..255 moves the wiper linearly between the two voltages that give those
// levels with BETA 200: WIPER_DARK_MV (lamp off or grip at rest) and
// VR11_full_mv. If the bike sizes change (VR-1, VR-9, VR-2), the wheels
// move with them and these two need setting again.
// History: until 10 November 2026 the range was a guess (pin 3 from 4.6
// down to 4.0 V) and the bike wrapped round the frame. From then until
// 11 November it took the bike's top to 2 in below the top of the picture
// (pin 3 1.25 V), which put the wheels 14.9 in up, 2 in too far. Later on
// 11 November it was set for 29-line bikes (VR-1/VR-9 at 5k: pin 3 4.01 V
// and 1.94 V, WIPER_DARK_MV 1734, WIPER_FULL_MV 3220).
//
// C77. Integrated once per millisecond (explicit Euler, stable for these
// constants):
//   C77 dV/dt = (Vwiper - V)/R107 - max(0, V - VCLAMP)/R108
// VCLAMP is TR10's Vbe plus D14. Below it C77 charges with the 4.7 s time
// constant; above it the base clamps C77 and the base current follows the
// wiper within about 0.15 s (C77 with R107 and R108 in parallel).
//
// Pin 3. TR10 sinks Ic = BETA * Ib, limited by saturation. Its load is
// R109 to +5 V in parallel with the 556's internal 5k/10k divider, a
// Thevenin source of 4.615 V behind 769 ohm. TR10_collector_IC105_pin3_mv
// is IC105 pin 3 in mV, lower for more throttle; the 556 model uses it as its
// threshold.
// Ports carrying board nets are named by their endpoints (part_pin_part_pin).
module fonz_throttle #(
    parameter integer CEN_HZ        = 48_000_000,
    parameter integer TICK_HZ       = 1000,
    parameter integer WIPER_DARK_MV = 1814,
    parameter integer R107_OHMS     = 100_000,
    parameter integer R108_OHMS     = 3300,
    parameter integer R109_OHMS     = 1000,
    parameter integer C77_NF        = 47_000,
    parameter integer VCLAMP_MV     = 1300,  // Vbe(TR10) + D14
    parameter integer VCE_MIN_MV    = 850,   // Vce(sat) + D14
    parameter integer BETA          = 200,
    parameter integer VCC_MV        = 5000
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        cen,          // CEN_HZ clock enable
    input  wire        IC39_pin3_R110,               // low lights the lamp
    input  wire [ 7:0] demand,                       // fonz_accel_input
    input  wire [12:0] VR11_full_mv,                 // full-grip wiper, OSD VR-11
    output reg  [12:0] VR11_wiper_R107_mv,
    output wire [12:0] R107_C77_R108_mv,
    output wire [15:0] R108_TR10_base_na,            // base current, nA
    output wire [12:0] TR10_collector_IC105_pin3_mv  // control voltage
);
    // ---- elaboration-time constants (64-bit to avoid overflow) ----------
    localparam [63:0] DIV = CEN_HZ / TICK_HZ;
    // Euler steps in Q16 per tick: dt / (R*C)
    localparam [63:0] K_IN = (64'd1 << 16) * 64'd1_000_000_000 / TICK_HZ
                             / (64'd1 * R107_OHMS * C77_NF);
    localparam [63:0] K_B  = (64'd1 << 16) * 64'd1_000_000_000 / TICK_HZ
                             / (64'd1 * R108_OHMS * C77_NF);
    // Ib (nA) = excess (uV) * 1000 / R108, in Q16
    localparam [63:0] K_IB = (64'd1000 << 16) / R108_OHMS;
    // Pin 3 Thevenin: up via R109 and 5k, down via 10k (556 divider)
    localparam [63:0] G_UP = 64'd5000 * 10000 + 64'd1 * R109_OHMS * 10000;
    localparam [63:0] G_DN = 64'd1 * R109_OHMS * 5000;
    localparam [63:0] VTH_MV  = 64'd1 * VCC_MV * G_UP / (G_UP + G_DN);
    localparam [63:0] RTH_MOHM = 64'd1 * R109_OHMS * 5000 * 10000 * 1000 / (G_UP + G_DN);
    localparam [63:0] VCE_MIN_64 = VCE_MIN_MV;
    localparam [63:0] IC_MAX_NA = (VTH_MV - VCE_MIN_64) * 64'd1_000_000_000 / RTH_MOHM;
    // Vdrop (mV) = Ic (nA) * Rth (mOhm) / 1e9, in Q32
    localparam [63:0] K_RT = (RTH_MOHM << 32) / 64'd1_000_000_000;
    localparam [12:0] DARK = WIPER_DARK_MV;
    localparam signed [39:0] UV8   = 40'sd256_000;       // 1 mV in uV Q8
    localparam signed [39:0] CLAMP = VCLAMP_MV * 256_000;
    localparam signed [32:0] K_IN_S = {1'b0, K_IN[31:0]};
    localparam signed [32:0] K_B_S  = {1'b0, K_B[31:0]};

    // ---- wiper ----------------------------------------------------------
    // Plain Verilog-2001 (Quartus reads .v files as Verilog).
    wire [ 7:0] lit  = IC39_pin3_R110 ? 8'd0 : demand;
    // span * lit / 255 as (span * lit * 257 + 2^15) >> 16 (257 / 2^16 is
    // 1/255.004), registered in two steps to keep the divider out.
    // The span is registered first (the setting comes from the OSD and
    // changes rarely); below the dark level it is 0.
    wire [12:0] span_mv = VR11_full_mv - DARK;  // at most 4095 - 1814
    reg  [11:0] span = 12'd0;
    reg  [20:0] prod = 21'd0;
    wire [37:0] prod_257 = prod * 17'd257 + 38'd32768;
    always @(posedge clk) begin
        span <= VR11_full_mv > DARK ? span_mv[11:0] : 12'd0;
        prod <= span * lit;
        VR11_wiper_R107_mv <= DARK + prod_257[28:16];
    end

    // ---- tick -----------------------------------------------------------
    reg [31:0] div_cnt;
    reg        tick;
    always @(posedge clk) begin
        tick <= 1'b0;
        if (rst) div_cnt <= 32'd0;
        else if (cen) begin
            if ({32'd0, div_cnt} >= DIV - 64'd1) begin
                div_cnt <= 32'd0;
                tick    <= 1'b1;
            end else div_cnt <= div_cnt + 32'd1;
        end
    end

    // ---- C77, uV in Q8 ----------------------------------------------------
    reg  signed [39:0] vc = CLAMP;
    wire signed [39:0] vw     = $signed({27'd0, VR11_wiper_R107_mv}) * UV8;
    wire signed [39:0] excess = vc > CLAMP ? vc - CLAMP : 40'sd0;
    // The step is worked out in registered stages between ticks (a tick
    // comes once a millisecond, the stages take three clocks).
    reg  signed [39:0] dv_in = 40'sd0, excess_r = 40'sd0;
    reg  signed [72:0] p_in = 73'sd0, p_b = 73'sd0;
    always @(posedge clk) begin
        dv_in    <= vw - vc;
        excess_r <= excess;
        p_in     <= dv_in    * K_IN_S;
        p_b      <= excess_r * K_B_S;
    end
    wire signed [72:0] d_in   = p_in >>> 16;
    wire signed [72:0] d_b    = p_b  >>> 16;

    always @(posedge clk) begin
        // Start at the clamp, as on a board that has been on for a while
        if (rst) vc <= CLAMP;
        else if (tick) vc <= vc + d_in[39:0] - d_b[39:0];
    end

    wire [39:0] vc_pos = vc[39] ? 40'd0 : vc;
    wire [39:0] vc_mv  = vc_pos / 40'd256_000;
    assign R107_C77_R108_mv = vc_mv[12:0];

    // ---- TR10 and pin 3 ----------------------------------------------------
    // Registered a step at a time: C77 moves once a millisecond, so the few
    // clocks of delay do not matter, and the multipliers stay out of one
    // long path. ib starts from the registered excess (excess_r): from vc
    // the compare, subtract and multiply missed 57 MHz by 0.24 ns in Quartus.
    wire [63:0] excess_u = {24'd0, excess_r[39:0]};
    reg  [63:0] ib = 64'd0, ic = 64'd0, icl = 64'd0, drop = 64'd0;
    always @(posedge clk) begin
        ib   <= ((excess_u >> 8) * K_IB) >> 16;                           // nA
        ic   <= ib * BETA;
        icl  <= ic > IC_MAX_NA ? IC_MAX_NA : ic;
        drop <= (icl * K_RT) >> 32;                                       // mV
    end
    wire [63:0] pin3 = VTH_MV - drop;
    assign R108_TR10_base_na = ib > 64'hffff ? 16'hffff : ib[15:0];
    assign TR10_collector_IC105_pin3_mv = pin3[12:0];
endmodule
