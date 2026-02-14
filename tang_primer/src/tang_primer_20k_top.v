module tang_primer_20k_top (
    input  wire       sys_clk,    // 27 MHz
    output wire       tmds_clk_p,
    output wire       tmds_clk_n,
    output wire [2:0] tmds_data_p,
    output wire [2:0] tmds_data_n,
    output wire [3:0] led         // For debug
);

    wire serial_clk;
    wire pix_clk;
    wire pll_lock;
    wire hdmi_rst_n;

    // Internal Power-On Reset (POR)
    // Hold reset low for a brief period after power up
    reg [15:0] por_cnt = 0;
    wire sys_rst_n = por_cnt[15]; // Active low, releases after ~2ms at 27MHz

    always @(posedge sys_clk) begin
        if (!sys_rst_n)
            por_cnt <= por_cnt + 1;
    end

    // Clock Generation
    clock_gen u_clock_gen (
        .clk_in(sys_clk),
        .rst_n(sys_rst_n),
        .serial_clk(serial_clk),
        .pix_clk(pix_clk),
        .pll_lock(pll_lock)
    );

    assign hdmi_rst_n = sys_rst_n & pll_lock;

    // Debug LEDs
    assign led[0] = pll_lock;
    assign led[1] = !sys_rst_n;
    assign led[2] = 1'b1; // Power indicator
    assign led[3] = 1'b0;

    // Test Pattern Generator
    wire hs, vs, de;
    wire [7:0] r, g, b;

    test_pattern_gen u_tpg (
        .clk(pix_clk),
        .rst_n(hdmi_rst_n),
        .hs(hs),
        .vs(vs),
        .de(de),
        .r(r),
        .g(g),
        .b(b)
    );

    // DVI Transmitter
    DVI_TX_Top u_dvi_tx (
        .I_rst_n(hdmi_rst_n),
        .I_serial_clk(serial_clk),
        .I_rgb_clk(pix_clk),
        .I_rgb_vs(vs),
        .I_rgb_hs(hs),
        .I_rgb_de(de),
        .I_rgb_r(r),
        .I_rgb_g(g),
        .I_rgb_b(b),
        .O_tmds_clk_p(tmds_clk_p),
        .O_tmds_clk_n(tmds_clk_n),
        .O_tmds_data_p(tmds_data_p),
        .O_tmds_data_n(tmds_data_n)
    );

endmodule
