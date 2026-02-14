module vic_ii_driver (
    input  wire       clk_sys,    // 27 MHz
    input  wire       rst_n,
    
    output wire       hs_out,
    output wire       vs_out,
    output wire [7:0] r_out,
    output wire [7:0] g_out,
    output wire [7:0] b_out,
    output wire       de_out
);

    // -------------------------------------------------------------------------
    // Clock Generation for VIC-II
    // -------------------------------------------------------------------------
    // VIC-II needs ~8.18 MHz (NTSC). 
    // New clk_sys = 31.5 MHz.
    // 31.5 / 4 = 7.875 MHz (Close enough for testing).
    
    reg [1:0] clk_div;
    reg       phi_en;   // 1 MHz enable (approx)
    reg       pix_en;   // 8 MHz enable (approx)
    
    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            clk_div <= 0;
            pix_en <= 0;
        end else begin
            clk_div <= clk_div + 2'd1;
            pix_en <= (clk_div == 2'd3); // Pulse every 4 cycles -> 7.875 MHz
        end
    end
    
    // Generate Phi (1 MHz) - 1 cycle every 8 pixel cycles
    reg [2:0] phi_cnt;
    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            phi_cnt <= 0;
            phi_en <= 0;
        end else if (pix_en) begin
            if (phi_cnt == 7) begin
                phi_cnt <= 0;
                phi_en <= 1;
            end else begin
                phi_cnt <= phi_cnt + 3'd1;
                phi_en <= 0;
            end
        end else begin
            phi_en <= 0;
        end
    end

    // -------------------------------------------------------------------------
    // VIC-II Signals
    // -------------------------------------------------------------------------
    wire [13:0] vic_addr;
    reg  [7:0]  vic_di;
    wire [7:0]  vic_do;
    wire        vic_irq_n;
    wire        vic_hs, vic_vs;
    wire [3:0]  vic_color_idx;
    wire        vic_refresh;
    
    // Control Interface
    reg         cs, we;
    reg  [5:0]  reg_addr;
    reg  [7:0]  reg_data;
    
    // -------------------------------------------------------------------------
    // Configuration State Machine
    // -------------------------------------------------------------------------
    reg [3:0] state;
    reg [15:0] delay_cnt;
    
    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            state <= 0;
            delay_cnt <= 0;
            cs <= 0;
            we <= 0;
            reg_addr <= 0;
            reg_data <= 0;
        end else if (phi_en) begin // Run config logic at CPU speed
            case (state)
                0: begin // Wait for Reset settling
                    if (delay_cnt < 1000) delay_cnt <= delay_cnt + 16'd1;
                    else state <= 1;
                end
                1: begin // Write Border Color ($D020) -> Light Blue (14)
                    cs <= 1; we <= 1; reg_addr <= 6'h20; reg_data <= 8'd14;
                    state <= 2;
                end
                2: begin // Write BG Color ($D021) -> Blue (6)
                    cs <= 1; we <= 1; reg_addr <= 6'h21; reg_data <= 8'd6;
                    state <= 3;
                end
                3: begin // Enable Sprite 0 ($D015) -> 1
                    cs <= 1; we <= 1; reg_addr <= 6'h15; reg_data <= 8'd1;
                    state <= 4;
                end
                4: begin // Sprite 0 X ($D000) -> 160 (approx center)
                    cs <= 1; we <= 1; reg_addr <= 6'h00; reg_data <= 8'd160;
                    state <= 5;
                end
                5: begin // Sprite 0 Y ($D001) -> 100 (approx center)
                    cs <= 1; we <= 1; reg_addr <= 6'h01; reg_data <= 8'd100;
                    state <= 6;
                end
                6: begin // Sprite 0 Color ($D027) -> White (1)
                    cs <= 1; we <= 1; reg_addr <= 6'h27; reg_data <= 8'd1;
                    state <= 7;
                end
                7: begin // Done
                    cs <= 0; we <= 0;
                end
            endcase
        end
    end

    // -------------------------------------------------------------------------
    // Memory Simulation (Mock)
    // -------------------------------------------------------------------------
    // VIC Address Map (Default Bank 0: $0000-$3FFF)
    // Screen RAM: $0400 (Default)
    // Sprite Pointers: $07F8-$07FF (Screen RAM + $3F8)
    // Sprite Data: We'll put it at $2000 (Pointer = $80)
    
    always @(*) begin
        vic_di = 8'd0; // Default
        
        // Sprite Pointers at $07F8 (Sprite 0)
        if (vic_addr == 14'h07F8) begin
            vic_di = 8'h80; // Pointer to $2000 ($80 * 64)
        end 
        // Sprite Data at $2000-$203F (64 bytes)
        else if (vic_addr >= 14'h2000 && vic_addr < 14'h2040) begin
            vic_di = 8'hFF; // Solid Block
        end
        // Screen RAM (Chars) - Just spaces
        else if (vic_addr >= 14'h0400 && vic_addr < 14'h07E8) begin
            vic_di = 8'h20; // Space
        end
    end

    // -------------------------------------------------------------------------
    // VIC-II Instance
    // -------------------------------------------------------------------------
    // Note: Parameter passing to VHDL might vary. Assuming default generics for now.
    // If needed, we use defparam or #(...)
    
    video_vicii_656x #(
        .emulateRefresh(0),
        .emulateLightpen(0),
        .emulateGraphics(1)
    ) u_vic (
        .clk(clk_sys),
        .phi(phi_en),        // Use Enable as Phi? No, Phi is input. 
                             // Logic: "phi = 0 is VIC cycle, phi = 1 is CPU cycle"
                             // Wait, real 656x uses Phi as clock input or phase?
                             // Port def: "phi : in std_logic"
                             // It usually toggles at 1 MHz.
                             // But my phi_en is a 1-cycle pulse.
                             // I should generate a 50% duty cycle 1 MHz signal?
                             // OR is it an enable?
                             // "phi = 0 is VIC cycle... phi = 1 is CPU cycle"
                             // It looks like a phase signal.
                             // I need to generate a toggling Phi.
        .enaData(1'b1),      // Always enable data?
        .enaPixel(pix_en),   // Pixel clock enable
        
        .baSync(1'b0),
        .ba(),
        .ba_dma(),
        
        .mode6569(1'b0),       // PAL
        .mode6567old(1'b0),
        .mode6567R8(1'b1),     // NTSC (60Hz)
        .mode6572(1'b0),
        
        .turbo_en(1'b0),
        .turbo_state(),
        
        .variant(2'b00),    // NMOS
        .reset(!rst_n),
        .cs(cs),
        .we(we),
        .lp_n(1'b1),
        
        .aRegisters(reg_addr),
        .diRegisters(reg_data),
        
        .di(vic_di),
        .diColor(4'd1),     // Color RAM Data (White)
        .do(vic_do),
        
        .vicAddr(vic_addr),
        .irq_n(vic_irq_n),
        
        .hSync(vic_hs),
        .vSync(vic_vs),
        .colorIndex(vic_color_idx),
        
        .debugX(),
        .debugY(),
        .vicRefresh(vic_refresh),
        .addrValid()
    );
    
    // Logic for phi_level is replaced by phi_out above

    
    // -------------------------------------------------------------------------
    // Palette
    // -------------------------------------------------------------------------
    reg [7:0] vic_r, vic_g, vic_b;
    always @(*) begin
        case (vic_color_idx)
             4'd0:  begin vic_r = 8'h00; vic_g = 8'h00; vic_b = 8'h00; end // Black
             4'd1:  begin vic_r = 8'hFF; vic_g = 8'hFF; vic_b = 8'hFF; end // White
             4'd6:  begin vic_r = 8'h00; vic_g = 8'h00; vic_b = 8'hAA; end // Blue
             4'd14: begin vic_r = 8'h00; vic_g = 8'h88; vic_b = 8'hFF; end // Light Blue
             default: begin vic_r = 8'h88; vic_g = 8'h88; vic_b = 8'h88; end // Grey
        endcase
    end

    // -------------------------------------------------------------------------
    // Scan Doubler
    // -------------------------------------------------------------------------
    wire sd_hs, sd_vs;
    wire [5:0] sd_r, sd_g, sd_b; // Scan doubler outputs 6-bit?
    // Check scandoubler source: output reg [5:0] r_out
    
    scandoubler #(
        .HCNT_WIDTH(10) 
    ) u_sd (
        .clk_sys(clk_sys),
        .bypass(1'b0),
        .ce_divider(1'b1), // Force 1:2 mode (Input 15.75MHz, Output 31.5MHz)
        .pixel_ena(),      
        .scanlines(2'b00), 
        
        .hs_in(vic_hs),
        .vs_in(vic_vs),
        .r_in(vic_r[7:4]), 
        .g_in(vic_g[7:4]),
        .b_in(vic_b[7:4]),
        
        .hs_out(sd_hs),
        .vs_out(sd_vs),
        .r_out(sd_r),
        .g_out(sd_g),
        .b_out(sd_b)
    );

    // Sync Polarity Correction for HDMI
    // Based on memory: Syncs should NOT be inverted if monitor expects standard VGA syncs.
    // VIC-II core outputs active-low syncs?
    // Let's assume the scandoubler preserves polarity.
    // Most HDMI monitors expect active-high VS/HS for 640x480?
    // Wait, VGA 640x480 standard is Active LOW for both.
    // So if sd_hs/sd_vs are 0 during sync, it's correct.
    
    assign hs_out = sd_hs;
    assign vs_out = sd_vs;
    assign r_out  = {sd_r, 2'b00};
    assign g_out  = {sd_g, 2'b00};
    assign b_out  = {sd_b, 2'b00};
    
    // Precise DE Generation
    // Active High DE. Must be LOW during HS/VS pulses.
    assign de_out = (sd_hs & sd_vs); 

endmodule
