// Streams the MRA download into fonz_board the way the MiSTer
// does and checks that each board PROM ends up holding its dump.
// The download is assembled here from rom/*.hex at the offsets that
// scripts/make_mra.py uses (tests/test_prom_load.py checks that the MRA
// produces exactly these bytes). Every PROM is cleared first, so nothing
// comes from the board's own $readmemh.
`timescale 1ns/1ps
module tb_prom_load;
    reg clk=0;
    always #10 clk=~clk;
    reg [25:0] ioctl_addr=0;
    reg [7:0] ioctl_dout=0, ioctl_index=0;
    reg ioctl_wr=0, downloading=0;
    wire [15:0] prom_load;
    fonz_prom_load loader(
        .ioctl_addr(ioctl_addr),.ioctl_dout(ioctl_dout),.ioctl_wr(ioctl_wr),
        .ioctl_index(ioctl_index),.downloading(downloading),.prom_load(prom_load));
    fonz_board dut(.prom_clk(clk),.prom_load(prom_load));

    reg [3:0] ref86[0:511], ref87[0:511], ref49[0:255], ref50[0:255];
    reg [7:0] image[0:1535];
    integer i, errors=0;

    task send(input [25:0] a, input [7:0] d, input [7:0] index);
    begin
        @(negedge clk);
        ioctl_addr=a; ioctl_dout=d; ioctl_index=index; ioctl_wr=1;
        @(negedge clk);
        ioctl_wr=0;
    end
    endtask

    task check(input [8*4-1:0] chip, input integer a, input [3:0] got, input [3:0] want);
        if (got!==want) begin
            errors=errors+1;
            if (errors<10) $display("%0s[%0d]: got %h, want %h", chip, a, got, want);
        end
    endtask

    initial begin
        $readmemh("rom/ic86.86.hex", ref86);
        $readmemh("rom/ic87.87.hex", ref87);
        $readmemh("rom/pr-09.49.hex", ref49);
        $readmemh("rom/pr-08.50.hex", ref50);
        for (i=0; i<512; i=i+1) begin
            image[i]={4'h0,ref86[i]}; image[512+i]={4'h0,ref87[i]};
        end
        for (i=0; i<256; i=i+1) begin
            image[1024+i]={4'h0,ref49[i]}; image[1280+i]={4'h0,ref50[i]};
        end
        #1; // after the board's own $readmemh
        for (i=0; i<512; i=i+1) begin
            dut.scene.picture.lower.ic86.mem[i]=4'h0;
            dut.scene.picture.lower.ic87.mem[i]=4'h0;
        end
        for (i=0; i<256; i=i+1) begin
            dut.scene.picture.upper.ic49.mem[i]=4'h0;
            dut.scene.picture.upper.ic50.mem[i]=4'h0;
        end
        downloading=1;
        for (i=0; i<1536; i=i+1) send(i, image[i], 0);
        // Bytes past the PROMs, on another index or outside a download
        // change nothing.
        for (i=1536; i<2048; i=i+1) send(i, 8'h0a, 0);
        send(0, 8'h05, 1);
        downloading=0;
        send(0, 8'h05, 0);
        @(negedge clk);
        for (i=0; i<512; i=i+1) begin
            check("IC86", i, dut.scene.picture.lower.ic86.mem[i], ref86[i]);
            check("IC87", i, dut.scene.picture.lower.ic87.mem[i], ref87[i]);
        end
        for (i=0; i<256; i=i+1) begin
            check("IC49", i, dut.scene.picture.upper.ic49.mem[i], ref49[i]);
            check("IC50", i, dut.scene.picture.upper.ic50.mem[i], ref50[i]);
        end
        if (errors) $display("FAIL: %0d PROM locations differ", errors);
        else $display("PASS: 1536 PROM locations loaded from the download");
        $finish;
    end
endmodule
