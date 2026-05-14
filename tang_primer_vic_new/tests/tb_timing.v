`timescale 1ns/1ps
module tb_timing;
  reg pix_clk;
  reg rst_n;
  wire de, hs, vs;
  wire [7:0] r, g, b;

  // Generate ~31.5 MHz pixel clock: period ~31.746 ns -> half ~15.873 ns
  initial begin
    pix_clk = 0;
    forever #15.873 pix_clk = ~pix_clk;
  end

  initial begin
    rst_n = 0;
    #200 rst_n = 1;
  end

  // Parameters copied from top (current VGA-like 640x480@60)
  localparam H_TOTAL = 12'd1000;
  localparam H_SYNC  = 12'd40;
  localparam H_BP    = 12'd160;
  localparam H_RES   = 12'd640;
  localparam V_TOTAL = 12'd525;
  localparam V_SYNC  = 12'd5;
  localparam V_BP    = 12'd25;
  localparam V_RES   = 12'd480;

  reg [2:0] mode;
  initial mode = 3'b011; // single color

  testpattern uut (
    .I_pxl_clk(pix_clk),
    .I_rst_n(rst_n),
    .I_mode({1'b0, mode}),
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
    .O_de(de),
    .O_hs(hs),
    .O_vs(vs),
    .O_data_r(r),
    .O_data_g(g),
    .O_data_b(b)
  );

  integer line_pixels;
  integer frame_lines;
  time t_line_start, t_line_end, t_frame_start, t_frame_end;
  integer frames_counted;

  reg hs_d, vs_d, de_d;
  always @(posedge pix_clk) begin
    hs_d <= hs;
    vs_d <= vs;
    de_d <= de;
  end

  wire hs_fall = hs_d & ~hs;
  wire vs_fall = vs_d & ~vs;
  wire de_rise = ~de_d & de;
  wire de_fall = de_d & ~de;

  initial begin
    frames_counted = 0;
    line_pixels = 0;
    frame_lines = 0;
    @(posedge rst_n);
    // Observe a few frames
    repeat (3) begin
      @(negedge vs); // frame start (active low vs)
      t_frame_start = $time;
      frame_lines = 0;
      // Count lines in this frame
      while (vs == 1'b0) begin
        @(negedge hs);
        frame_lines = frame_lines + 1;
      end
      t_frame_end = $time;
      frames_counted = frames_counted + 1;
      $display("Frame %0d: lines=%0d, frame_time_ns=%0t", frames_counted, frame_lines, (t_frame_end - t_frame_start));
    end
    $finish;
  end

  // Measure one line pixel count and period
  initial begin
    @(posedge rst_n);
    @(negedge hs);
    t_line_start = $time;
    line_pixels = 0;
    // Count pixels in one full line period based on DE toggle
    @(negedge hs);
    t_line_end = $time;
    $display("Line time ns = %0t", (t_line_end - t_line_start));
  end
endmodule
