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
    .I_single_b  (8'd0               ),
    .I_h_total   (12'd1650           ),// 1280x720@60 total
    .I_h_sync    (12'd40             ),// 1280x720@60 sync
    .I_h_bporch  (12'd220            ),// 1280x720@60 back porch
    .I_h_res     (12'd1280           ),// 1280x720@60 active
    .I_v_total   (12'd750            ),// 1280x720@60 total
    .I_v_sync    (12'd5              ),// 1280x720@60 sync
    .I_v_bporch  (12'd20             ),// 1280x720@60 back porch
    .I_v_res     (12'd720            ),// 1280x720@60 active
    .I_hs_pol    (1'b1               ),// positive
    .I_vs_pol    (1'b1               ),// positive
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

localparam SRC_W = 640;

reg        vic_hs_d;
always @(posedge sys_clk) vic_hs_d <= vic_hs;
wire       vic_hs_fall = vic_hs_d & ~vic_hs;

reg [11:0] line_len_cnt     = 12'd0;
reg [11:0] line_len_latched = 12'd860;
reg        line_len_locked  = 1'b0;
always @(posedge sys_clk or negedge hdmi4_rst_n) begin
    if(!hdmi4_rst_n) begin
        line_len_cnt     <= 12'd0;
        line_len_latched <= 12'd860;
        line_len_locked  <= 1'b0;
    end else begin
        if(vic_hs_fall) begin
            if(!line_len_locked && (line_len_cnt > 12'd200) && (line_len_cnt < 12'd2400)) begin
                line_len_latched <= line_len_cnt;
                line_len_locked  <= 1'b1;
            end
            line_len_cnt <= 12'd0;
        end else begin
            line_len_cnt <= line_len_cnt + 12'd1;
        end
    end
end

reg        wr_bank = 1'b0;
reg [9:0]  wr_ptr  = 10'd0;
reg [21:0] acc     = 22'd0;
reg [23:0] linebuf0 [0:SRC_W-1];
reg [23:0] linebuf1 [0:SRC_W-1];
reg        commit_tgl = 1'b0;
reg        commit_bank = 1'b0;

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
            commit_tgl <= ~commit_tgl;
            commit_bank<= wr_bank;
        end else begin
            if(wr_ptr < SRC_W) begin
                acc <= acc + 22'd640;
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

reg commit_sync0, commit_sync1, commit_sync2;
reg commit_bank_s0, commit_bank_s1, commit_bank_s2;
always @(posedge pix_clk or negedge hdmi4_rst_n) begin
    if(!hdmi4_rst_n) begin
        commit_sync0 <= 1'b0;
        commit_sync1 <= 1'b0;
        commit_sync2 <= 1'b0;
        commit_bank_s0 <= 1'b0;
        commit_bank_s1 <= 1'b0;
        commit_bank_s2 <= 1'b0;
    end else begin
        commit_sync0 <= commit_tgl;
        commit_sync1 <= commit_sync0;
        commit_sync2 <= commit_sync1;
        commit_bank_s0 <= commit_bank;
        commit_bank_s1 <= commit_bank_s0;
        commit_bank_s2 <= commit_bank_s1;
    end
end
wire new_line_available = commit_sync1 ^ commit_sync2;
wire bank_of_commit     = commit_bank_s1;

reg rd_bank = 1'b0;
reg pending_line = 1'b0;
wire de_rising;
reg        de_d;
assign de_rising = tp0_de_in & ~de_d;
reg  rep_toggle = 1'b0;
reg  rep_count  = 1'b0;
reg  next_rd_bank = 1'b0;
always @(posedge pix_clk or negedge hdmi4_rst_n) begin
    if(!hdmi4_rst_n) begin
        rd_bank <= 1'b0;
        pending_line <= 1'b0;
        rep_toggle <= 1'b0;
        rep_count  <= 1'b0;
        next_rd_bank <= 1'b0;
    end else begin
        if(new_line_available) begin
            pending_line <= 1'b1;
            next_rd_bank <= bank_of_commit;
        end
        if(de_rising) begin
            if(rep_count != 1'b0) begin
                rep_count <= 1'b0;
            end else if(pending_line) begin
                rd_bank <= next_rd_bank;
                pending_line <= 1'b0;
                rep_toggle <= ~rep_toggle;
                rep_count  <= rep_toggle ? 1'b0 : 1'b1;
            end 
        end
    end
end

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

reg [9:0]  src_x_rd;
reg [23:0] vic_pix_read;
reg [7:0]  vic_r_720, vic_g_720, vic_b_720;
reg [1:0] scale_cnt;
    always @(posedge pix_clk or negedge hdmi4_rst_n) begin
        if(!hdmi4_rst_n) begin
            src_x_rd <= 10'd0;
            vic_pix_read <= 24'd0;
            vic_r_720 <= 8'd0;
            vic_g_720 <= 8'd0;
            vic_b_720 <= 8'd0;
            scale_cnt <= 2'd0;
        end else begin
            if(tp0_de_in && !de_d) begin 
                src_x_rd <= 10'd80; // Start reading from index 80 to center the image
                scale_cnt <= 2'd0;
            end
            
            if(tp0_de_in) begin
                // 3x Scaling Logic: Advance read pointer every 3 HDMI pixels
                if (scale_cnt == 2'd2) begin
                    scale_cnt <= 2'd0;
                    if (src_x_rd < 10'd639) src_x_rd <= src_x_rd + 10'd1;
                end else begin
                    scale_cnt <= scale_cnt + 2'd1;
                end

                vic_pix_read <= (!rd_bank) ? linebuf0[src_x_rd] : linebuf1[src_x_rd];

                // Pillarbox: 160 pixels black on left/right to maintain 4:3 aspect ratio
                // 1280 (16:9) - 960 (4:3) = 320. 320/2 = 160.
                if (x_cnt < 11'd160 || x_cnt >= 11'd1120) begin
                    vic_r_720 <= 8'd0;
                    vic_g_720 <= 8'd0;
                    vic_b_720 <= 8'd0;
                end else begin
                    vic_r_720 <= vic_pix_read[23:16];
                    vic_g_720 <= vic_pix_read[15:8];
                    vic_b_720 <= vic_pix_read[7:0];
                end
            end else begin
                vic_r_720 <= 8'd0;
                vic_g_720 <= 8'd0;
                vic_b_720 <= 8'd0;
            end
        end
    end

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
    .I_rst_n       (hdmi4_rst_n   ),
    .I_serial_clk  (serial_clk    ),
    .I_rgb_clk     (pix_clk       ),
    .I_rgb_vs      (tp0_vs_in     ), 
    .I_rgb_hs      (tp0_hs_in     ),    
    .I_rgb_de      (tp0_de_in     ), 
    .I_rgb_r       (  mux_r ),
    .I_rgb_g       (  mux_g  ),  
    .I_rgb_b       (  mux_b  ),  
    .O_tmds_clk_p  (tmds_clk_p  ),
    .O_tmds_clk_n  (tmds_clk_n  ),
    .O_tmds_data_p (tmds_data_p ),
    .O_tmds_data_n (tmds_data_n )
);



wire [15:0] c64_addr;
wire [7:0] c64_data_out;
wire ram_ce;
wire ram_we;
wire io_cycle;
wire ext_cycle;
wire refresh_sig;
wire core_hs;
wire core_vs;
wire [7:0] core_r;
wire [7:0] core_g;
wire [7:0] core_b;
wire [9:0] core_debugX;
wire [8:0] core_debugY;
wire core_phi;
wire core_phi2_p;
wire core_phi2_n;
wire nmi_ack_w;
wire romL_w;
wire romH_w;
wire UMAXromH_w;
wire IO7_w;
wire IOE_w;
wire IOF_w;
wire freeze_key_w;
wire mod_key_w;
wire tape_play_w;
wire dma_cycle_w;
wire [7:0] dma_din_w;
wire [17:0] audio_l_w;
wire [17:0] audio_r_w;
wire [7:0] pb_o_w;
wire pa2_o_w;
wire pc2_n_o_w;
wire sp2_o_w;
wire sp1_o_w;
wire cnt2_o_w;
wire cnt1_o_w;
wire iec_data_o_w;
wire iec_clk_o_w;
wire iec_atn_o_w;
wire cass_motor_w;
wire cass_write_w;

fpga64_sid_iec c64_inst (
    .clk32(sys_clk),
    .reset_n(hdmi4_rst_n),
    .bios(2'b00),
    .pause(1'b0),
    .pause_out(),
    .usb_key(8'b0),
    .kbd_strobe(1'b0),
    .kbd_reset(1'b0),
    .shift_mod(2'b0),
    .ramAddr(c64_addr),
    .ramDin(8'b0),
    .ramDout(c64_data_out),
    .ramCE(ram_ce),
    .ramWE(ram_we),
    .io_cycle(io_cycle),
    .ext_cycle(ext_cycle),
    .refresh(refresh_sig),
    .cia_mode(1'b0),
    .turbo_mode(2'b00),
    .turbo_speed(2'b00),
    .vic_variant(2'b00),
    .ntscMode(1'b1),
    .hsync(core_hs),
    .vsync(core_vs),
    .r(core_r),
    .g(core_g),
    .b(core_b),
    .debugX(core_debugX),
    .debugY(core_debugY),
    .phi(core_phi),
    .phi2_p(core_phi2_p),
    .phi2_n(core_phi2_n),
    .game(1'b0),
    .exrom(1'b0),
    .io_rom(1'b0),
    .io_ext(1'b0),
    .io_data(8'b0),
    .irq_n(1'b1),
    .nmi_n(1'b1),
    .nmi_ack(nmi_ack_w),
    .romL(romL_w),
    .romH(romH_w),
    .UMAXromH(UMAXromH_w),
    .IO7(IO7_w),
    .IOE(IOE_w),
    .IOF(IOF_w),
    .freeze_key(freeze_key_w),
    .mod_key(mod_key_w),
    .tape_play(tape_play_w),
    .dma_req(1'b0),
    .dma_cycle(dma_cycle_w),
    .dma_addr(16'b0),
    .dma_dout(8'b0),
    .dma_din(dma_din_w),
    .dma_we(1'b0),
    .irq_ext_n(1'b1),
    .joyA(7'b0),
    .joyB(7'b0),
    .pot1(8'b0),
    .pot2(8'b0),
    .pot3(8'b0),
    .pot4(8'b0),
    .audio_l(audio_l_w),
    .audio_r(audio_r_w),
    .sid_filter(2'b00),
    .sid_ver(2'b00),
    .sid_mode(3'b000),
    .sid_cfg(4'b0000),
    .sid_fc_off_l(13'b0),
    .sid_fc_off_r(13'b0),
    .sid_ld_clk(1'b0),
    .sid_ld_addr(12'b0),
    .sid_ld_data(16'b0),
    .sid_ld_wr(1'b0),
    .sid_digifix(1'b0),
    .pb_i(8'b0),
    .pb_o(pb_o_w),
    .pa2_i(1'b0),
    .pa2_o(pa2_o_w),
    .pc2_n_o(pc2_n_o_w),
    .flag2_n_i(1'b1),
    .sp2_i(1'b0),
    .sp2_o(sp2_o_w),
    .sp1_i(1'b0),
    .sp1_o(sp1_o_w),
    .cnt2_i(1'b0),
    .cnt2_o(cnt2_o_w),
    .cnt1_i(1'b0),
    .cnt1_o(cnt1_o_w),
    .iec_data_o(iec_data_o_w),
    .iec_data_i(1'b1),
    .iec_clk_o(iec_clk_o_w),
    .iec_clk_i(1'b1),
    .iec_atn_o(iec_atn_o_w),
    .c64rom_addr(14'b0),
    .c64rom_data(8'b0),
    .c64rom_wr(1'b0),
    .cass_motor(cass_motor_w),
    .cass_write(cass_write_w),
    .cass_sense(1'b0),
    .cass_read(1'b0)
);

endmodule
