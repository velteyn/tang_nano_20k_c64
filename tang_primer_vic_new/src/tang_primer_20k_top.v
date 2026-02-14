// ==============0ooo===================================================0ooo===========
// =  Copyright (C) 2014-2020 Gowin Semiconductor Technology Co.,Ltd.
// =                     All rights reserved.
// ====================================================================================
// 
//  __      __      __
//  \ \    /  \    / /   [File name   ] video_top.v
//   \ \  / /\ \  / /    [Description ] Video demo
//    \ \/ /  \ \/ /     [Timestamp   ] Friday April 10 14:00:30 2020
//     \  /    \  /      [version     ] 2.0
//      \/      \/
//
// ==============0ooo===================================================0ooo===========
// Code Revision History :
// ----------------------------------------------------------------------------------
// Ver:    |  Author    | Mod. Date    | Changes Made:
// ----------------------------------------------------------------------------------
// V1.0    | Caojie     |  4/10/20     | Initial version 
// ----------------------------------------------------------------------------------
// V2.0    | Caojie     | 10/30/20     | DVI IP update 
// ----------------------------------------------------------------------------------
// ==============0ooo===================================================0ooo===========

module tang_primer_20k_top
(
    input             sys_clk        , //27Mhz
    input             I_rst_n         ,
    output     [3:0]  led             , 
    output            tmds_clk_p    ,
    output            tmds_clk_n    ,
    output     [2:0]  tmds_data_p   ,//{r,g,b}
    output     [2:0]  tmds_data_n   
);

//==================================================
reg  [31:0] run_cnt;
wire        running;

//--------------------------
wire        tp0_vs_in  ;
wire        tp0_hs_in  ;
wire        tp0_de_in ;
wire [ 7:0] tp0_data_r/*synthesis syn_keep=1*/;
wire [ 7:0] tp0_data_g/*synthesis syn_keep=1*/;
wire [ 7:0] tp0_data_b/*synthesis syn_keep=1*/;

reg         vs_r;
reg  [9:0]  cnt_vs;

// VIC-II integration (safe default off)
localparam USE_VIC = 1'b1;
wire        vic_hs;
wire        vic_vs;
wire        vic_de;
wire [7:0]  vic_r;
wire [7:0]  vic_g;
wire [7:0]  vic_b;

//------------------------------------
//HDMI4 TX
wire serial_clk;
wire pll_lock;

wire hdmi4_rst_n;

wire pix_clk;

//===================================================
//LED test
always @(posedge sys_clk or negedge I_rst_n) //I_clk
begin
    if(!I_rst_n)
        run_cnt <= 32'd0;
    else if(run_cnt >= 32'd27_000_000)
        run_cnt <= 32'd0;
    else
        run_cnt <= run_cnt + 1'b1;
end

assign  running = (run_cnt < 32'd14_000_000) ? 1'b1 : 1'b0;

assign  led[0] = running;
assign  led[1] = running;
assign  led[2] = ~I_rst_n;
assign  led[3] = ~I_rst_n;

//===========================================================================
//testpattern
testpattern testpattern_inst
(
    .I_pxl_clk   (pix_clk            ),//pixel clock
    .I_rst_n     (hdmi4_rst_n        ),//low active 
    .I_mode      ({1'b0,cnt_vs[9:8]} ),//data select
    .I_single_r  (8'd0               ),
    .I_single_g  (8'd255             ),
    .I_single_b  (8'd0               ),                  //800x600    //1024x768   //1280x720    
    .I_h_total   (12'd1650           ),//hor total time  // 12'd1056  // 12'd1344  // 12'd1650  
    .I_h_sync    (12'd40             ),//hor sync time   // 12'd128   // 12'd136   // 12'd40    
    .I_h_bporch  (12'd220            ),//hor back porch  // 12'd88    // 12'd160   // 12'd220   
    .I_h_res     (12'd1280           ),//hor resolution  // 12'd800   // 12'd1024  // 12'd1280  
    .I_v_total   (12'd750            ),//ver total time  // 12'd628   // 12'd806   // 12'd750    
    .I_v_sync    (12'd5              ),//ver sync time   // 12'd4     // 12'd6     // 12'd5     
    .I_v_bporch  (12'd20             ),//ver back porch  // 12'd23    // 12'd29    // 12'd20    
    .I_v_res     (12'd720            ),//ver resolution  // 12'd600   // 12'd768   // 12'd720    
    .I_hs_pol    (1'b1               ),//HS polarity , 0:negetive ploarity，1：positive polarity
    .I_vs_pol    (1'b1               ),//VS polarity , 0:negetive ploarity，1：positive polarity
    .O_de        (tp0_de_in          ),   
    .O_hs        (tp0_hs_in          ),
    .O_vs        (tp0_vs_in          ),
    .O_data_r    (tp0_data_r         ),   
    .O_data_g    (tp0_data_g         ),
    .O_data_b    (tp0_data_b         )
);

always@(posedge pix_clk)
begin
    vs_r<=tp0_vs_in;
end

always@(posedge pix_clk or negedge hdmi4_rst_n)
begin
    if(!hdmi4_rst_n)
        cnt_vs<=0;
    else if(vs_r && !tp0_vs_in) //vs24 falling edge
        cnt_vs<=cnt_vs+1'b1;
end 

// VIC-II driver (runs off 27MHz system clock to avoid HDMI clock changes)
vic_ii_driver u_vic (
    .clk_sys(sys_clk),
    .rst_n(hdmi4_rst_n),
    .hs_out(vic_hs),
    .vs_out(vic_vs),
    .r_out(vic_r),
    .g_out(vic_g),
    .b_out(vic_b),
    .de_out(vic_de)
);

// -----------------------------------------------------------------------------
// Simple scaler: VIC 640x480 -> 1280x720 with 2x horizontal and approx 3:2 vertical
// - Write domain (sys_clk): sample one source line into ping-pong line buffers (640 samples)
//   using a Bresenham-like resampler based on measured line length
// - Read domain (pix_clk): read active buffer at 2x horizontally; hold line until next commit
//   Vertical effectively expands ~1.5x because HDMI runs faster (720 lines vs 480)
// -----------------------------------------------------------------------------
localparam SRC_W = 640;

reg        vic_hs_d;
always @(posedge sys_clk) vic_hs_d <= vic_hs;
wire       vic_hs_fall = vic_hs_d & ~vic_hs;

reg [11:0] line_len_cnt = 12'd0;
reg [11:0] line_len_latched = 12'd800; // sane default
reg        line_len_locked = 1'b0;
always @(posedge sys_clk or negedge hdmi4_rst_n) begin
    if(!hdmi4_rst_n) begin
        line_len_cnt     <= 12'd0;
        line_len_latched <= 12'd800;
        line_len_locked  <= 1'b0;
    end else begin
        if(vic_hs_fall) begin
            if(!line_len_locked) begin
                line_len_latched <= (line_len_cnt > 12'd100) ? line_len_cnt : 12'd800;
                line_len_locked  <= 1'b1;
            end
            line_len_cnt     <= 12'd0;
        end else begin
            line_len_cnt <= line_len_cnt + 12'd1;
        end
    end
end

reg        wr_bank = 1'b0;
reg [9:0]  wr_ptr  = 10'd0; // 0..639
reg [21:0] acc     = 22'd0; // accumulator for resampling
reg [23:0] linebuf0 [0:SRC_W-1];
reg [23:0] linebuf1 [0:SRC_W-1];
reg        commit_tgl = 1'b0;

always @(posedge sys_clk or negedge hdmi4_rst_n) begin
    if(!hdmi4_rst_n) begin
        wr_bank   <= 1'b0;
        wr_ptr    <= 10'd0;
        acc       <= 22'd0;
        commit_tgl<= 1'b0;
    end else begin
        if(vic_hs_fall) begin
            wr_bank    <= ~wr_bank;
            wr_ptr     <= 10'd0;
            acc        <= 22'd0;
            commit_tgl <= ~commit_tgl; // signal new line available
        end else begin
            // Bresenham-like: place SRC_W samples evenly across measured line_len_latched cycles
            if(wr_ptr < SRC_W) begin
                acc <= acc + SRC_W;
                if(acc >= line_len_latched) begin
                    acc   <= acc - line_len_latched;
                    if(!wr_bank) linebuf0[wr_ptr] <= {vic_r, vic_g, vic_b};
                    else         linebuf1[wr_ptr] <= {vic_r, vic_g, vic_b};
                    wr_ptr <= wr_ptr + 10'd1;
                end
            end
        end
    end
end

// Cross domain toggle to pix clock
reg commit_sync0, commit_sync1, commit_sync2;
always @(posedge pix_clk or negedge hdmi4_rst_n) begin
    if(!hdmi4_rst_n) begin
        commit_sync0 <= 1'b0;
        commit_sync1 <= 1'b0;
        commit_sync2 <= 1'b0;
    end else begin
        commit_sync0 <= commit_tgl;
        commit_sync1 <= commit_sync0;
        commit_sync2 <= commit_sync1;
    end
end
wire new_line_available = commit_sync1 ^ commit_sync2;

reg rd_bank = 1'b0;
reg pending_line = 1'b0;
wire de_rising = tp0_de_in & ~de_d;
reg  rep_toggle = 1'b0;     // 0 -> repeat 2 lines, 1 -> repeat 1 line
reg  rep_count  = 1'b0;     // remaining repeats for current source line
always @(posedge pix_clk or negedge hdmi4_rst_n) begin
    if(!hdmi4_rst_n) begin
        rd_bank <= 1'b0;
        pending_line <= 1'b0;
        rep_toggle <= 1'b0;
        rep_count  <= 1'b0;
    end else begin
        if(new_line_available) pending_line <= 1'b1;
        if(de_rising) begin
            if(rep_count != 1'b0) begin
                rep_count <= 1'b0;
            end else if(pending_line) begin
                rd_bank <= ~rd_bank;
                pending_line <= 1'b0;
                rep_toggle <= ~rep_toggle;
                rep_count  <= rep_toggle ? 1'b0 : 1'b1;
            end 
        end
    end
end

// HDMI active window horizontal counter
reg        de_d;
reg [10:0] x_cnt;
always @(posedge pix_clk or negedge hdmi4_rst_n) begin
    if(!hdmi4_rst_n) begin
        de_d <= 1'b0;
        x_cnt <= 11'd0;
    end else begin
        de_d <= tp0_de_in;
        if(tp0_de_in) begin
            if(!de_d) x_cnt <= 11'd0;
            else      x_cnt <= x_cnt + 11'd1;
        end else begin
            x_cnt <= 11'd0;
        end
    end
end

wire [9:0] src_x = x_cnt[10:1]; // divide by 2
wire [23:0] vic_pix_read = (!rd_bank) ? linebuf0[src_x] : linebuf1[src_x];
wire [7:0] vic_r_720 = vic_pix_read[23:16];
wire [7:0] vic_g_720 = vic_pix_read[15:8];
wire [7:0] vic_b_720 = vic_pix_read[7:0];

wire [7:0] src_r = USE_VIC ? vic_r_720 : tp0_data_r;
wire [7:0] src_g = USE_VIC ? vic_g_720 : tp0_data_g;
wire [7:0] src_b = USE_VIC ? vic_b_720 : tp0_data_b;

wire [7:0] mux_r = src_r;
wire [7:0] mux_g = src_g;
wire [7:0] mux_b = src_b;

//==============================================================================
//TMDS TX(HDMI4)
TMDS_rPLL u_tmds_rpll
(.clkin     (sys_clk     )     //input clk 
,.clkout    (serial_clk)     //output clk 
,.lock      (pll_lock  )     //output lock
);

assign hdmi4_rst_n = I_rst_n & pll_lock;

CLKDIV u_clkdiv
(.RESETN(hdmi4_rst_n)
,.HCLKIN(serial_clk) //clk  x5
,.CLKOUT(pix_clk)    //clk  x1
,.CALIB (1'b1)
);
defparam u_clkdiv.DIV_MODE="5";
defparam u_clkdiv.GSREN="false";

DVI_TX_Top DVI_TX_Top_inst
(
    .I_rst_n       (hdmi4_rst_n   ),  //asynchronous reset, low active
    .I_serial_clk  (serial_clk    ),
    .I_rgb_clk     (pix_clk       ),  //pixel clock
    .I_rgb_vs      (tp0_vs_in     ), 
    .I_rgb_hs      (tp0_hs_in     ),    
    .I_rgb_de      (tp0_de_in     ), 
    .I_rgb_r       (  mux_r ),  //tp0_data_r or vic
    .I_rgb_g       (  mux_g  ),  
    .I_rgb_b       (  mux_b  ),  
    .O_tmds_clk_p  (tmds_clk_p  ),
    .O_tmds_clk_n  (tmds_clk_n  ),
    .O_tmds_data_p (tmds_data_p ),  //{r,g,b}
    .O_tmds_data_n (tmds_data_n )
);



endmodule
