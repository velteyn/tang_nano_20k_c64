`timescale 1ns / 1ps

module c64_tb;

  // Inputs
  reg clk;
  reg reset;
  reg uart_rx;
  reg [15:0] ddr3_dq_in;
  reg [1:0] ddr3_dqs_p_in;
  reg [1:0] ddr3_dqs_n_in;

  // Outputs
  wire [1:0] leds_n;
  wire uart_tx;
  wire [13:0] ddr3_a;
  wire [2:0] ddr3_ba;
  wire ddr3_ck_p;
  wire ddr3_ck_n;
  wire ddr3_cke;
  wire ddr3_cs_n;
  wire ddr3_ras_n;
  wire ddr3_cas_n;
  wire ddr3_we_n;
  wire ddr3_reset_n;
  wire [1:0] ddr3_dm;
  wire ddr3_odt;

  // Inouts
  wire [15:0] ddr3_dq;
  wire [1:0] ddr3_dqs_p;
  wire [1:0] ddr3_dqs_n;

  // Instantiate the Unit Under Test (UUT)
  tang_primer_20k_c64_top uut (
    .clk(clk),
    .reset(reset),
    .leds_n(leds_n),
    .uart_rx(uart_rx),
    .uart_tx(uart_tx),
    .m0s(),
    .tmds_clk_n(),
    .tmds_clk_p(),
    .tmds_d_n(),
    .tmds_d_p(),
    .sd_clk(),
    .sd_cmd(),
    .sd_dat(),
    .ddr3_a(ddr3_a),
    .ddr3_ba(ddr3_ba),
    .ddr3_ck_p(ddr3_ck_p),
    .ddr3_ck_n(ddr3_ck_n),
    .ddr3_cke(ddr3_cke),
    .ddr3_cs_n(ddr3_cs_n),
    .ddr3_ras_n(ddr3_ras_n),
    .ddr3_cas_n(ddr3_cas_n),
    .ddr3_we_n(ddr3_we_n),
    .ddr3_reset_n(ddr3_reset_n),
    .ddr3_dq(ddr3_dq),
    .ddr3_dqs_p(ddr3_dqs_p),
    .ddr3_dqs_n(ddr3_dqs_n),
    .ddr3_odt(ddr3_odt),
    .ddr3_dm(ddr3_dm)
  );

  initial begin
    // Initialize Inputs
    clk = 0;
    reset = 1;
    uart_rx = 1;

    // Wait 100 ns for global reset to finish
    #100;
    reset = 0;

    // Add stimulus here

  end

  always #10 clk = ~clk;

endmodule
