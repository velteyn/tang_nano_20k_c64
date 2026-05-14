
module vic_to_hdmi_adapter (
    // VIC-II Side (Write Domain)
    input  wire         vic_clk,      // ~8 MHz pixel clock
    input  wire         vic_rst_n,
    input  wire         vic_hs,
    input  wire         vic_vs,
    input  wire [7:0]   vic_r,
    input  wire [7:0]   vic_g,
    input  wire [7:0]   vic_b,

    // HDMI Side (Read Domain)
    input  wire         hdmi_clk,     // ~25-30 MHz pixel clock
    input  wire         hdmi_rst_n,
    input  wire         hdmi_de,      // Data Enable from HDMI timing generator
    input  wire         hdmi_hs,      // HSync from HDMI timing generator
    input  wire         hdmi_vs,      // VSync from HDMI timing generator
    output reg  [7:0]   hdmi_r,
    output reg  [7:0]   hdmi_g,
    output reg  [7:0]   hdmi_b
);

    // -------------------------------------------------------------------------
    // 1. VIC Input Processing (Write Logic)
    // -------------------------------------------------------------------------
    
    // Detect line start (Rising edge of HS to skip Sync Pulse)
    reg vic_hs_d;
    always @(posedge vic_clk) vic_hs_d <= vic_hs;
    wire vic_line_start = ~vic_hs_d & vic_hs; // Rising Edge
    
    // Debug
    // always @(posedge vic_clk) begin
    //    if (vic_line_start) $display("Module: Line Start Detected! vic_hs=%b vic_hs_d=%b", vic_hs, vic_hs_d);
    //    if (wr_enable && wr_addr < 10) $display("Module: Write Enabled. Addr=%d Bank=%b", wr_addr, wr_bank);
    // end

    // Write Address Counter (0 to 639)
    reg [9:0] wr_addr;
    reg       wr_enable;
    
    // Double Buffer Selection
    // bank 0: write here, read from 1
    // bank 1: write here, read from 0
    reg wr_bank; 

    always @(posedge vic_clk or negedge vic_rst_n) begin
        if (!vic_rst_n) begin
            wr_addr   <= 10'd0;
            wr_enable <= 1'b0;
            wr_bank   <= 1'b0;
        end else begin
            if (vic_line_start) begin
                wr_addr   <= 10'd0;
                wr_enable <= 1'b1; // Start writing new line
                wr_bank   <= ~wr_bank; // Swap banks at end of line
            end else if (wr_enable) begin
                if (wr_addr == 10'd639) begin
                     wr_enable <= 1'b0; // Stop at end of visible line
                end else begin
                     wr_addr <= wr_addr + 1'b1;
                end
            end
        end
    end

    // -------------------------------------------------------------------------
    // 2. Dual-Port Block RAM (The "Middle Hardware")
    // -------------------------------------------------------------------------
    
    // We need 2 lines x 640 pixels x 24 bits
    // Gowin BRAM inference style
    
    reg [23:0] ram_bank0 [0:1023]; // Over-provisioned to power of 2
    reg [23:0] ram_bank1 [0:1023];

    // Write Port
    always @(posedge vic_clk) begin
        if (wr_enable) begin
            if (wr_bank == 1'b0)
                ram_bank0[wr_addr] <= {vic_r, vic_g, vic_b};
            else
                ram_bank1[wr_addr] <= {vic_r, vic_g, vic_b};
        end
    end

    // Read Port
    reg [23:0] rd_data0;
    reg [23:0] rd_data1;
    reg [9:0]  rd_addr_reg;
    
    // -------------------------------------------------------------------------
    // 3. HDMI Output Processing (Read Logic)
    // -------------------------------------------------------------------------

    // Read Logic
    // We read from the bank OPPOSITE to the write bank.
    // Ideally we sync the bank selection to avoid tearing, but for now 
    // let's just use the synchronized version of wr_bank.

    // Synchronize wr_bank to hdmi_clk domain
    reg wr_bank_sync1, wr_bank_sync2;
    always @(posedge hdmi_clk) begin
        wr_bank_sync1 <= wr_bank;
        wr_bank_sync2 <= wr_bank_sync1;
    end
    
    wire rd_bank_sel = ~wr_bank_sync2; // Read from the "stable" bank

    // Horizontal Scaling Logic
    // We need to map 1280 HDMI pixels -> 640 VIC pixels.
    // Simple 2x scaling: Read same address for 2 clocks? 
    // Or 1.5x? 
    // Let's assume we want to center 640 VIC pixels in the 1280 active area.
    // Or simpler: stretch 640 to 960 (1.5x) or 1280 (2x).
    // Let's implement a scaler counter.
    
    reg [9:0] rd_addr;
    
    // Active Region Detection
    // HDMI DE tells us when we are in active video.
    // We need to decide where to place the image.
    // Let's simply center it.
    // 1280 width. 640 VIC pixels. 2x scaling = 1280. Perfect fit.
    
    always @(posedge hdmi_clk or negedge hdmi_rst_n) begin
        if (!hdmi_rst_n) begin
            rd_addr <= 10'd0;
        end else begin
            if (hdmi_de) begin
                if (rd_addr < 10'd639)
                    rd_addr <= rd_addr + 1'b1;
            end else begin
                rd_addr <= 10'd0;
            end
        end
    end

    // RAM Read Access
    always @(posedge hdmi_clk) begin
        rd_data0 <= ram_bank0[rd_addr];
        rd_data1 <= ram_bank1[rd_addr];
    end

    // Output Mux
    always @(posedge hdmi_clk or negedge hdmi_rst_n) begin
        if (!hdmi_rst_n) begin
            hdmi_r <= 8'd0;
            hdmi_g <= 8'd0;
            hdmi_b <= 8'd0;
        end else begin
            if (hdmi_de) begin
                if (rd_bank_sel == 1'b0) begin
                    hdmi_r <= rd_data0[23:16];
                    hdmi_g <= rd_data0[15:8];
                    hdmi_b <= rd_data0[7:0];
                end else begin
                    hdmi_r <= rd_data1[23:16];
                    hdmi_g <= rd_data1[15:8];
                    hdmi_b <= rd_data1[7:0];
                end
            end else begin
                // Blanking color (optional, usually black)
                hdmi_r <= 8'd0;
                hdmi_g <= 8'd0;
                hdmi_b <= 8'd0;
            end
        end
    end

endmodule
