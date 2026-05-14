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
wire        genlock_vs_pulse;
wire        tp0_vs_in  ;
wire        tp0_hs_in  ;
wire        tp0_de_in ;
wire [ 7:0] tp0_data_r/*synthesis syn_keep=1*/;
wire [ 7:0] tp0_data_g/*synthesis syn_keep=1*/;
wire [ 7:0] tp0_data_b/*synthesis syn_keep=1*/;
wire        core_vs;
wire        core_hs;

reg         vs_r;
reg  [9:0]  cnt_vs;

// VIC-II integration (safe default off)
localparam USE_VIC = 1'b1;
localparam USE_VIC_SIM = 1'b1; // SET TO 1 FOR DEBUG SIMULATOR
localparam GENLOCK_USE_FALL = 1'b1;
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
    .I_genlock_vs(1'b0               ), // GENLOCK DISABLED
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
/*
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
*/

// VIC-II Simulator for Debugging (Now synchronized to pix_clk to stop rolling)
reg [11:0] sim_h_cnt;
reg [9:0]  sim_v_cnt;
reg        sim_hs, sim_vs, sim_de;
reg [7:0]  sim_r, sim_g, sim_b;

always @(posedge pix_clk or negedge hdmi4_rst_n) begin
    if(!hdmi4_rst_n) begin
        sim_h_cnt <= 12'd0;
        sim_v_cnt <= 10'd0;
    end else begin
        // Use EXACT same timing as HDMI (1650 x 750) to ensure zero drift
        if(sim_h_cnt >= 12'd1649) begin 
            sim_h_cnt <= 12'd0;
            if(sim_v_cnt >= 10'd749) sim_v_cnt <= 10'd0;
            else sim_v_cnt <= sim_v_cnt + 10'd1;
        end else begin
            sim_h_cnt <= sim_h_cnt + 12'd1;
        end
        
        sim_hs <= (sim_h_cnt < 12'd40);
        sim_vs <= (sim_v_cnt < 10'd5);
        
        // Active Area: 320x240 (standard retro resolution)
        sim_de <= (sim_h_cnt >= 12'd200 && sim_h_cnt < 12'd520) && 
                  (sim_v_cnt >= 10'd100 && sim_v_cnt < 10'd340);
        
        // White square in the middle of simulator active area
        if(sim_h_cnt >= 12'd310 && sim_h_cnt < 12'd410 && 
           sim_v_cnt >= 10'd170 && sim_v_cnt < 10'd270) begin
            sim_r <= 8'd255; sim_g <= 8'd255; sim_b <= 8'd255;
        end else begin
            sim_r <= 8'd0; sim_g <= 8'd0; sim_b <= 8'd255; // Blue background
        end
    end
end

// Connect existing C64 core video signals to HDMI pipeline
assign vic_hs = USE_VIC_SIM ? sim_hs : core_hs;
assign vic_vs = USE_VIC_SIM ? sim_vs : core_vs;
assign vic_r  = USE_VIC_SIM ? sim_r  : core_r;
assign vic_g  = USE_VIC_SIM ? sim_g  : core_g;
assign vic_b  = USE_VIC_SIM ? sim_b  : core_b;

// Precise DE generation using C64 core internal counters
// rasterX < 396 (start of hBlanking) and rasterY < 300 (start of vBlanking)
assign vic_de = USE_VIC_SIM ? sim_de : ((core_debugX < 10'd396) && (core_debugY < 9'd300));


reg [7:0]  genlock_pulse_cnt;
reg        vs_d;
always @(posedge pix_clk) begin
    vs_d <= vic_vs;
    if (~vs_d & vic_vs) begin // Rising edge of VIC VS
        genlock_pulse_cnt <= 8'd128;
    end else if (genlock_pulse_cnt != 8'd0) begin
        genlock_pulse_cnt <= genlock_pulse_cnt - 8'd1;
    end
end
assign genlock_vs_pulse = (genlock_pulse_cnt != 8'd0);

// Replaced old accumulator scaling with vic_hdmi_passthrough wrapper
wire [7:0] pass_r, pass_g, pass_b;
wire c64_clk;



vic_hdmi_passthrough u_pass (
    .pix_clk(pix_clk),
    .rst_n(hdmi4_rst_n),
    .vic_clk(c64_clk), 
    .vic_hs(vic_hs),
    .vic_vs(vic_vs),
    .vic_de(vic_de),
    .vic_r(vic_r),
    .vic_g(vic_g),
    .vic_b(vic_b),
    .hdmi_de(tp0_de_in),
    .hdmi_hs(tp0_hs_in),
    .hdmi_vs(tp0_vs_in),
    .hdmi_r(pass_r),
    .hdmi_g(pass_g),
    .hdmi_b(pass_b)
);

wire [7:0] mux_r = pass_r;
wire [7:0] mux_g = pass_g;
wire [7:0] mux_b = pass_b;

//==============================================================================
//TMDS TX(HDMI4)
TMDS_rPLL u_tmds_rpll
(.clkin     (sys_clk     )     //input clk 
,.clkout    (serial_clk)     //output clk 
,.lock      (pll_lock  )     //output lock
);

CLKDIV u_clkdiv
(.RESETN(hdmi4_rst_n)
,.HCLKIN(serial_clk) //clk  x5
,.CLKOUT(pix_clk)    //clk  x1
,.CALIB (1'b1)
);
defparam u_clkdiv.DIV_MODE="5";
defparam u_clkdiv.GSREN="false";

// Manual divider for C64 clock (74.25 / 2 = 37.125 MHz)
reg c64_clk_reg;
always @(posedge pix_clk or negedge hdmi4_rst_n) begin
    if(!hdmi4_rst_n) c64_clk_reg <= 1'b0;
    else c64_clk_reg <= ~c64_clk_reg;
end
assign c64_clk = c64_clk_reg;

assign hdmi4_rst_n = I_rst_n & pll_lock;

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

wire [7:0] c64_data_in;
wire [6:0] joyA_w = 7'b0;
wire [6:0] joyB_w = 7'b0;
wire [7:0] usb_key_w = 8'b0;
wire kbd_strobe_w = 1'b0;
wire kbd_reset_w = 1'b0;


ram64k u_ram (
    .clk(serial_clk), // 5x pixel clock (157.5MHz) to ensure data is latched quickly
    .ce(ram_ce),
    .we(ram_we),
    .addr(c64_addr),
    .din(c64_data_out),
    .dout(c64_data_in)
);

fpga64_sid_iec c64_inst (
    .clk32(c64_clk),       
    .reset_n(hdmi4_rst_n),
    .bios(2'b00),
    .pause(1'b0),
    .pause_out(),
    .usb_key(usb_key_w),
    .kbd_strobe(kbd_strobe_w),
    .kbd_reset(kbd_reset_w),
    .shift_mod(2'b0),
    .ramAddr(c64_addr),
    .ramDin(c64_data_in),
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
    .joyA(joyA_w),
    .joyB(joyB_w),
    .pot1(8'b0),
    .pot2(8'b0),
    .pot3(8'b0),
    .pot4(8'b0),
    .audio_l(audio_l_w),
    .audio_r(audio_r_w),
    .sid_filter(2'b01),
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

module ram64k (
    input clk,
    input ce,
    input we,
    input [15:0] addr,
    input [7:0] din,
    output reg [7:0] dout
);

    reg [7:0] mem [0:65535];

    always @(posedge clk) begin
        if (ce) begin
            if (we) 
                mem[addr] <= din;
            dout <= mem[addr];
        end
    end

endmodule
