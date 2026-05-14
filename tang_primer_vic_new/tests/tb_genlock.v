`timescale 1ns/1ps

module tb_genlock;
    reg pix_clk;
    reg rst_n;
    reg genlock_vs;
    wire de;
    wire hs;
    wire vs;
    wire [7:0] r;
    wire [7:0] g;
    wire [7:0] b;

    testpattern dut (
        .I_pxl_clk(pix_clk),
        .I_rst_n(rst_n),
        .I_mode(3'b000),
        .I_single_r(8'd0),
        .I_single_g(8'd0),
        .I_single_b(8'd0),
        .I_h_total(12'd1650),
        .I_h_sync(12'd40),
        .I_h_bporch(12'd220),
        .I_h_res(12'd1280),
        .I_v_total(12'd750),
        .I_v_sync(12'd5),
        .I_v_bporch(12'd20),
        .I_v_res(12'd720),
        .I_hs_pol(1'b1),
        .I_vs_pol(1'b1),
        .I_genlock_vs(genlock_vs),
        .O_de(de),
        .O_hs(hs),
        .O_vs(vs),
        .O_data_r(r),
        .O_data_g(g),
        .O_data_b(b)
    );

    initial begin
        pix_clk = 1'b0;
        forever #6.734 pix_clk = ~pix_clk;
    end

    integer pix_cnt;
    time last_vs;
    time last_genlock;
    integer vs_count;
    always @(posedge pix_clk or negedge rst_n) begin
        if(!rst_n) begin
            pix_cnt <= 0;
            genlock_vs <= 1'b0;
        end else begin
            if(pix_cnt == 100000) begin
                genlock_vs <= 1'b1;
                pix_cnt <= 0;
            end else begin
                genlock_vs <= 1'b0;
                pix_cnt <= pix_cnt + 1;
            end
        end
    end

    always @(posedge vs or negedge rst_n) begin
        if(!rst_n) begin
            last_vs <= 0;
            vs_count <= 0;
        end else begin
            vs_count <= vs_count + 1;
            if(last_vs != 0) $display("VS period: %0t", $time - last_vs);
            if(last_genlock != 0) $display("VS after genlock: %0t", $time - last_genlock);
            last_vs <= $time;
        end
    end

    always @(posedge genlock_vs or negedge rst_n) begin
        if(!rst_n) last_genlock <= 0;
        else begin
            last_genlock <= $time;
            $display("Genlock pulse: %0t", $time);
        end
    end

    initial begin
        rst_n = 1'b0;
        last_vs = 0;
        last_genlock = 0;
        vs_count = 0;
        #200;
        rst_n = 1'b1;
        #2000000;
        $display("VS count: %0d", vs_count);
        $finish;
    end
endmodule
