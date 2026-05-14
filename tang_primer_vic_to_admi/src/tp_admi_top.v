module tp_admi_top
(
    input  wire sys_clk,
    input  wire reset_n,
    output wire tmds_clk_p,
    output wire tmds_clk_n,
    output wire [2:0] tmds_data_p,
    output wire [2:0] tmds_data_n
);

wire serial_clk;   // ~126 MHz
wire pix_clk;      // ~25.2 MHz (serial/5)
wire pll_lock;

TMDS_rPLL u_pll (
    .clkin(sys_clk),
    .clkout(serial_clk),
    .lock(pll_lock)
);

CLKDIV u_clkdiv (
    .HCLKIN(serial_clk),
    .RESETN(pll_lock),
    .CLKOUT(pix_clk),
    .CALIB(1'b1)
);
defparam u_clkdiv.DIV_MODE = "5";

wire rst = ~(reset_n & pll_lock);

wire [2:0] tmds;
wire       tmds_clock;

dvi_640x480 u_dvi (
    .clk_pixel_x5(serial_clk),
    .clk_pixel(pix_clk),
    .reset(rst),
    .tmds(tmds),
    .tmds_clock(tmds_clock)
);

ELVDS_OBUF tmds_out_clk (
    .O(tmds_clk_p),
    .OB(tmds_clk_n),
    .I(tmds_clock)
);
ELVDS_OBUF tmds_out_d0 (.O(tmds_data_p[0]), .OB(tmds_data_n[0]), .I(tmds[0]));
ELVDS_OBUF tmds_out_d1 (.O(tmds_data_p[1]), .OB(tmds_data_n[1]), .I(tmds[1]));
ELVDS_OBUF tmds_out_d2 (.O(tmds_data_p[2]), .OB(tmds_data_n[2]), .I(tmds[2]));

endmodule

