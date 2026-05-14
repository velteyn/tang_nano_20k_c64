module vic_hdmi_passthrough (
    input wire         pix_clk,
    input wire         rst_n,
    input wire         vic_clk,
    input wire         vic_hs,
    input wire         vic_vs,
    input wire         vic_de,
    input wire [7:0]   vic_r,
    input wire [7:0]   vic_g,
    input wire [7:0]   vic_b,
    input wire         hdmi_de,
    input wire         hdmi_hs,
    input wire         hdmi_vs,
    output reg [7:0]   hdmi_r,
    output reg [7:0]   hdmi_g,
    output reg [7:0]   hdmi_b
);

    // VIC Domain Logic: Capture pixels into a Ping-Pong Double Buffer
    reg [9:0] wr_addr;
    reg vic_hs_d;
    reg wr_bank;
    reg [23:0] linebuf0 [0:1023]; 
    reg [23:0] linebuf1 [0:1023]; 

    always @(posedge vic_clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_addr <= 10'd0;
            vic_hs_d <= 1'b0;
            wr_bank <= 1'b0;
        end else begin
            vic_hs_d <= vic_hs;
            if (vic_hs_d && !vic_hs) begin // Falling edge of VIC HSync (Start of new line)
                wr_addr <= 10'd0;
                wr_bank <= !wr_bank; // Switch capture bank
            end else if (vic_de) begin
                if (wr_addr < 10'd1023) begin
                    if (!wr_bank) linebuf0[wr_addr] <= {vic_r, vic_g, vic_b};
                    else          linebuf1[wr_addr] <= {vic_r, vic_g, vic_b};
                    wr_addr <= wr_addr + 10'd1;
                end
            end
        end
    end

    // HDMI Domain Logic: Read out with 3x stretch and centering
    reg [9:0]  rd_addr;
    reg [1:0]  stretch_cnt; 
    reg [11:0] h_cnt;       
    reg [1:0]  v_rep_cnt;   // Vertical repeat counter (3x)
    reg hdmi_hs_d;
    reg hdmi_vs_d;
    reg rd_bank;

    always @(posedge pix_clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_addr <= 10'd0;
            stretch_cnt <= 2'd0;
            h_cnt <= 12'd0;
            v_rep_cnt <= 2'd0;
            hdmi_hs_d <= 1'b0;
            hdmi_vs_d <= 1'b0;
            hdmi_r  <= 8'd0;
            hdmi_g  <= 8'd0;
            hdmi_b  <= 8'd0;
            rd_bank <= 1'b0;
        end else begin
            hdmi_hs_d <= hdmi_hs;
            hdmi_vs_d <= hdmi_vs;
            
            if (hdmi_vs_d && !hdmi_vs) begin // Frame Start
                v_rep_cnt <= 2'd0;
            end else if (hdmi_hs_d && !hdmi_hs) begin // Line Start
                rd_addr <= 10'd0;
                stretch_cnt <= 2'd0;
                h_cnt <= 12'd0;
                
                // Only pick a new bank every 3 HDMI lines to match 3x vertical stretch
                if (v_rep_cnt == 2'd2) begin
                    v_rep_cnt <= 2'd0;
                    rd_bank <= !wr_bank; // Latch the bank that just finished writing
                end else begin
                    v_rep_cnt <= v_rep_cnt + 2'd1;
                    // rd_bank remains the same for the repeats
                end
            end else if (hdmi_de) begin
                h_cnt <= h_cnt + 12'd1;
                
                // Centering: 160-pixel black bar on left
                if (h_cnt >= 12'd160 && h_cnt < 12'd1120) begin
                    // Fetch from the latched rd_bank
                    if (rd_bank) begin
                        hdmi_r <= linebuf1[rd_addr][23:16];
                        hdmi_g <= linebuf1[rd_addr][15:8];
                        hdmi_b <= linebuf1[rd_addr][7:0];
                    end else begin
                        hdmi_r <= linebuf0[rd_addr][23:16];
                        hdmi_g <= linebuf0[rd_addr][15:8];
                        hdmi_b <= linebuf0[rd_addr][7:0];
                    end
                    
                    // 3x Horizontal Stretch: increment rd_addr every 3rd pixel
                    if (stretch_cnt == 2'd2) begin
                        stretch_cnt <= 2'd0;
                        if (rd_addr < 10'd1023) rd_addr <= rd_addr + 10'd1;
                    end else begin
                        stretch_cnt <= stretch_cnt + 2'd1;
                    end
                end else begin
                    // CLEAR OUTPUTS outside the 960px active window
                    hdmi_r <= 8'd0;
                    hdmi_g <= 8'd0;
                    hdmi_b <= 8'd0;
                end
            end else begin
                // CLEAR OUTPUTS during HDMI blanking
                hdmi_r <= 8'd0;
                hdmi_g <= 8'd0;
                hdmi_b <= 8'd0;
            end
        end
    end
endmodule
