// SPDX-License-Identifier: GPL-3.0-or-later
// Unit checks for the functional TTL cells in rtl/ttl/fonz_ttl.v.
`timescale 1ns/1ps
`default_nettype none
module tb_ttl;
    integer errors = 0, i;

    task check(input [255:0] what, input [31:0] got, input [31:0] want);
        if (got !== want) begin
            $display("FAIL: %0s = %0h, expected %0h", what, got, want);
            errors = errors + 1;
        end
    endtask

    // 74161: count, synchronous load, asynchronous clear, carry.
    reg c161 = 0, clr161 = 1, ld161 = 1, en161 = 1;
    reg [3:0] d161 = 4'h0;
    wire [3:0] q161; wire co161;
    fonz_74161 u161(.clk(c161), .clear_n(clr161), .load_n(ld161),
        .enp(en161), .ent(en161), .d(d161), .q(q161), .carry(co161));

    // 74107: J/K modes on the falling edge, clear.
    reg c107 = 1, clr107 = 1, j107 = 0, k107 = 0;
    wire q107, qn107;
    fonz_74107 u107(.clk(c107), .clear_n(clr107), .j(j107), .k(k107),
        .q(q107), .q_n(qn107));

    // 74393 half: falling-edge ripple count, clear.
    reg c393 = 1, clr393 = 0;
    wire [3:0] q393;
    fonz_74393_half u393(.clk(c393), .clear(clr393), .q(q393));

    // 74390 half: separate divide by two and divide by five.
    reg ca390 = 1, cb390 = 1, clr390 = 0;
    wire qa390; wire [2:0] qdcb390;
    fonz_74390_half u390(.clk_a(ca390), .clk_b(cb390), .clear(clr390),
        .qa(qa390), .qdcb(qdcb390));

    // 74192: up/down decade with load, clear, carry and borrow.
    reg up192 = 1, dn192 = 1, clr192 = 0, ld192 = 1;
    reg [3:0] d192 = 4'h0;
    wire [3:0] q192; wire co192, bo192;
    fonz_74192 u192(.up(up192), .down(dn192), .clear(clr192), .load_n(ld192),
        .d(d192), .q(q192), .carry_n(co192), .borrow_n(bo192));

    reg [3:0] d42 = 0; wire [9:0] y42;
    fonz_7442 u42(.dcba(d42), .y_n(y42));

    reg a153 = 0, b153 = 0, g1 = 0, g2 = 1;
    wire y1, y2;
    fonz_74153 u153(.a(a153), .b(b153), .g1_n(g1), .g2_n(g2),
        .c1(4'b1010), .c2(4'b1111), .y1(y1), .y2(y2));

    reg r279 = 1, s1_279 = 1, s2_279 = 1; wire q279;
    fonz_74279 u279(.r_n(r279), .s1_n(s1_279), .s2_n(s2_279), .q(q279));

    reg [3:0] d48 = 0; reg rbi48 = 1, bi48 = 1, lt48 = 1;
    wire [6:0] seg48; wire rbo48;
    fonz_7448 u48(.dcba(d48), .rbi_n(rbi48), .bi_n(bi48), .lt_n(lt48),
        .abcdefg(seg48), .rbo_n(rbo48));
    reg [6:0] font [0:9];

    initial begin
        // 74161
        for (i = 1; i <= 15; i = i + 1) begin
            #5 c161 = 1; #5 c161 = 0;
            check("74161 q", q161, i);
        end
        check("74161 carry at 15", co161, 1);
        #5 c161 = 1; #5 c161 = 0;
        check("74161 wrap", q161, 0);
        d161 = 4'h9; ld161 = 0; #5 c161 = 1; #5 c161 = 0; ld161 = 1;
        check("74161 load", q161, 9);
        en161 = 0; #5 c161 = 1; #5 c161 = 0;
        check("74161 hold", q161, 9);
        clr161 = 0; #1 check("74161 clear", q161, 0); clr161 = 1;

        // 74107
        j107 = 1; k107 = 0; #5 c107 = 0; #5 c107 = 1;
        check("74107 set", {q107, qn107}, 2'b10);
        j107 = 1; k107 = 1; #5 c107 = 0; #5 c107 = 1;
        check("74107 toggle", q107, 0);
        #5 c107 = 0; #5 c107 = 1;
        check("74107 toggle again", q107, 1);
        j107 = 0; k107 = 0; #5 c107 = 0; #5 c107 = 1;
        check("74107 hold", q107, 1);
        clr107 = 0; #1 check("74107 clear", q107, 0); clr107 = 1;

        // 74393
        for (i = 1; i <= 16; i = i + 1) begin
            #5 c393 = 0; #5 c393 = 1;
            check("74393 q", q393, i % 16);
        end
        #5 c393 = 0; #5 c393 = 1;
        clr393 = 1; #1 check("74393 clear", q393, 0); clr393 = 0;

        // 74390
        #5 ca390 = 0; #5 ca390 = 1; check("74390 qa", qa390, 1);
        #5 ca390 = 0; #5 ca390 = 1; check("74390 qa", qa390, 0);
        for (i = 1; i <= 5; i = i + 1) begin
            #5 cb390 = 0; #5 cb390 = 1;
            check("74390 /5", qdcb390, i % 5);
        end
        #5 cb390 = 0; #5 cb390 = 1;
        clr390 = 1; #1 check("74390 clear", {qa390, qdcb390}, 0); clr390 = 0;

        // 74192
        for (i = 1; i <= 10; i = i + 1) begin
            #5 up192 = 0;
            #1 if (i == 10) check("74192 /carry low at 9", co192, 0);
            #5 up192 = 1; #1;
            check("74192 up", q192, i % 10);
        end
        #5 dn192 = 0; #1 check("74192 /borrow low at 0", bo192, 0);
        #5 dn192 = 1; #1 check("74192 down wrap", q192, 9);
        d192 = 4'd6; ld192 = 0; #1 check("74192 load", q192, 6); ld192 = 1;
        clr192 = 1; #1 check("74192 clear", q192, 0); clr192 = 0;

        // 7442
        for (i = 0; i < 16; i = i + 1) begin
            d42 = i; #1;
            check("7442", y42, i < 10 ? (~(10'b1 << i) & 10'h3ff) : 10'h3ff);
        end

        // 74153
        for (i = 0; i < 4; i = i + 1) begin
            {b153, a153} = i; #1;
            check("74153 y1", y1, (4'b1010 >> i) & 1);
            check("74153 y2 disabled", y2, 0);
        end
        g1 = 1; #1 check("74153 y1 disabled", y1, 0);

        // 74279
        r279 = 0; #1 check("74279 reset", q279, 0); r279 = 1;
        s2_279 = 0; #1 check("74279 set S2", q279, 1); s2_279 = 1;
        #1 check("74279 hold", q279, 1);

        // 7448
        font[0] = 7'b1111110; font[1] = 7'b0110000; font[2] = 7'b1101101;
        font[3] = 7'b1111001; font[4] = 7'b0110011; font[5] = 7'b1011011;
        font[6] = 7'b0011111; font[7] = 7'b1110000; font[8] = 7'b1111111;
        font[9] = 7'b1110011;
        // A combinational always @* first runs when an input changes.
        d48 = 4'hf; #1;
        for (i = 0; i < 10; i = i + 1) begin
            d48 = i; #1 check("7448 digit", seg48, font[i]);
        end
        d48 = 0; rbi48 = 0; #1;
        check("7448 ripple blank", {seg48, rbo48}, 0);
        rbi48 = 1; lt48 = 0; #1 check("7448 lamp test", seg48, 7'h7f);
        lt48 = 1; bi48 = 0; #1 check("7448 blank", seg48, 0);

        if (errors == 0) $display("PASS: TTL cells");
        else $fatal(1, "FAIL: %0d TTL cell errors", errors);
        $finish;
    end
endmodule
`default_nettype wire
