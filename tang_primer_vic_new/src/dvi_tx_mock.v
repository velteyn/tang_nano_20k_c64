module DVI_TX_Top (
    input        I_rst_n,
    input        I_serial_clk,
    input        I_rgb_clk,
    input        I_rgb_vs,
    input        I_rgb_hs,
    input        I_rgb_de,
    input  [7:0] I_rgb_r,
    input  [7:0] I_rgb_g,
    input  [7:0] I_rgb_b,
    output       O_tmds_clk_p,
    output       O_tmds_clk_n,
    output [2:0] O_tmds_data_p,
    output [2:0] O_tmds_data_n
);
    assign O_tmds_clk_p = I_serial_clk;
    assign O_tmds_clk_n = ~I_serial_clk;
    assign O_tmds_data_p = {I_rgb_r[7], I_rgb_g[7], I_rgb_b[7]};
    assign O_tmds_data_n = ~O_tmds_data_p;
endmodule
