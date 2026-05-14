`timescale 1ns/1ps
module tb_vic_hdmi_passthrough;
  reg pix_clk;
  reg rst_n;
  wire tp_de, tp_hs, tp_vs;
  wire [7:0] tp_r, tp_g, tp_b;

  reg vic_hs, vic_vs, vic_de;
  reg [7:0] vic_r, vic_g, vic_b;

  wire [7:0] hdmi_r, hdmi_g, hdmi_b;

  initial begin
    pix_clk = 0;
    forever #15.873 pix_clk = ~pix_clk;
  end

  initial begin
    rst_n = 0;
    #200 rst_n = 1;
  end

  localparam H_TOTAL = 12'd1000;
  localparam H_SYNC  = 12'd40;
  localparam H_BP    = 12'd160;
  localparam H_RES   = 12'd640;
  localparam V_TOTAL = 12'd525;
  localparam V_SYNC  = 12'd5;
  localparam V_BP    = 12'd25;
  localparam V_RES   = 12'd480;

  testpattern tp (
    .I_pxl_clk(pix_clk),
    .I_rst_n(rst_n),
    .I_mode(3'b011),
    .I_single_r(8'd0),
    .I_single_g(8'd255),
    .I_single_b(8'd0),
    .I_h_total(H_TOTAL),
    .I_h_sync(H_SYNC),
    .I_h_bporch(H_BP),
    .I_h_res(H_RES),
    .I_v_total(V_TOTAL),
    .I_v_sync(V_SYNC),
    .I_v_bporch(V_BP),
    .I_v_res(V_RES),
    .I_hs_pol(1'b1),
    .I_vs_pol(1'b1),
    .I_genlock_vs(1'b0),
    .O_de(tp_de),
    .O_hs(tp_hs),
    .O_vs(tp_vs),
    .O_data_r(tp_r),
    .O_data_g(tp_g),
    .O_data_b(tp_b)
  );

  vic_hdmi_passthrough uut (
    .pix_clk(pix_clk),
    .rst_n(rst_n),
    .vic_hs(vic_hs),
    .vic_vs(vic_vs),
    .vic_de(vic_de),
    .vic_r(vic_r),
    .vic_g(vic_g),
    .vic_b(vic_b),
    .hdmi_de(tp_de),
    .hdmi_hs(tp_hs),
    .hdmi_vs(tp_vs),
    .hdmi_r(hdmi_r),
    .hdmi_g(hdmi_g),
    .hdmi_b(hdmi_b)
  );

  reg hs_d, vs_d;
  always @(posedge pix_clk) begin
    hs_d <= tp_hs;
    vs_d <= tp_vs;
  end
  wire hs_fall = hs_d & ~tp_hs;
  wire vs_fall = vs_d & ~tp_vs;

  integer x;
  integer y;
  initial begin
    vic_hs = 1'b1;
    vic_vs = 1'b1;
    vic_de = 1'b0;
    vic_r  = 8'd0;
    vic_g  = 8'd0;
    vic_b  = 8'd0;
    @(posedge rst_n);
    y = 0;
    forever begin
      @(negedge tp_hs);
      vic_hs = 1'b0;
      vic_de = 1'b0;
      #1000;
      vic_hs = 1'b1;
      vic_de = 1'b1;
      for (x = 0; x < 640; x = x + 1) begin
        @(posedge pix_clk);
        vic_r = x[7:0];
        vic_g = 8'hFF;
        vic_b = 8'h00;
      end
      vic_de = 1'b0;
      y = y + 1;
      if (y == 10) begin
        @(negedge tp_vs);
        vic_vs = 1'b0;
        #1000;
        vic_vs = 1'b1;
        y = 0;
      end
    end
  end
endmodule
