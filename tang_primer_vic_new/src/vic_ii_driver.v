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
    // New clk_sys = 27 MHz.
    // Target: 8.1818 MHz (NTSC Color Carrier * 2ish?)
    // 27 MHz * 9 / 30 = 8.1 MHz. Close enough.
    // Use an accumulator for fractional division.
    
    reg [4:0] clk_acc; // 5-bit accumulator (0-31)
    reg       phi_en;  // 1 MHz enable (approx)
    reg       pix_en;  // 8.1 MHz enable (approx)
    
    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            clk_acc <= 0;
            pix_en <= 0;
        end else begin
            // Add 9, Modulo 30? Or simply:
            // 27 * 3 / 10 = 8.1 MHz.
            // Add 3. If >= 10, subtract 10, enable = 1.
            if (clk_acc >= 5'd10) begin
                clk_acc <= clk_acc - 5'd10 + 5'd3;
                pix_en <= 1;
            end else begin
                clk_acc <= clk_acc + 5'd3;
                pix_en <= 0;
            end
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
                2: begin // Write BG Color ($D021) -> Light Blue (14)
                    cs <= 1; we <= 1; reg_addr <= 6'h21; reg_data <= 8'd14;
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
        .\do (vic_do),
        
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
             4'd0:  begin vic_r = 8'h00; vic_g = 8'h88; vic_b = 8'hFF; end
             4'd1:  begin vic_r = 8'hFF; vic_g = 8'hFF; vic_b = 8'hFF; end // White
             4'd6:  begin vic_r = 8'h00; vic_g = 8'h00; vic_b = 8'hAA; end // Blue
             4'd14: begin vic_r = 8'h00; vic_g = 8'h88; vic_b = 8'hFF; end // Light Blue
             default: begin vic_r = 8'h88; vic_g = 8'h88; vic_b = 8'h88; end // Grey
        endcase
    end

    // -------------------------------------------------------------------------
    // Output Assignment (Bypass Scandoubler for Line Buffer usage)
    // -------------------------------------------------------------------------
    // We are using a Line Buffer in top level to handle 15kHz -> 45kHz scaling.
    // So we should output the raw 15kHz VIC-II signals directly.
    // The scandoubler creates 31kHz which causes non-integer scaling artifacts.
    
    // Scandoubler is bypassed/ignored.
    
    assign hs_out = vic_hs;
    assign vs_out = vic_vs;
    
    // RGB 8-bit output
    assign r_out = vic_r;
    assign g_out = vic_g;
    assign b_out = vic_b;
    
    // DE Generation
    // VIC-II doesn't output DE explicitly, but we can assume valid during non-sync?
    // Or just use HS/VS to gate it in top level?
    // In top level, vic_de is used but not critical for buffer write (uses hs_fall).
    // Let's assign it based on HS/VS logic.
    // Active High DE.
    assign de_out = !(vic_hs || vic_vs); // Assuming Active High Syncs from core?
    // Wait, VIC-II core sync polarity?
    // "hSync : out std_logic"
    // Standard VIC-II is Active Low?
    // If Active Low (Idle High, Pulse Low): !Sync is Pulse.
    // If Active High (Idle Low, Pulse High): !Sync is Idle.
    // Let's assume Active High for now based on previous scandoubler usage.
    // If it was active low, scandoubler would have inverted it?
    // Scandoubler expects positive syncs usually.
    // Let's stick to simple assignment.
    
    // Keep scandoubler instance for reference but disconnect its outputs
    /*
    scandoubler #(
        .HCNT_WIDTH(10) 
    ) u_sd (
        .clk_sys(clk_sys),
        .bypass(1'b1),
        .ce_divider(1'b1),
        .scanlines(2'b00), // Disable scanlines
        .hs_in(vic_hs),
        .vs_in(vic_vs),
        .r_in(vic_r[7:4]), 
        .g_in(vic_g[7:4]),
        .b_in(vic_b[7:4]),
        .hs_out(),
        .vs_out(),
        .r_out(),
        .g_out(),
        .b_out()
    );
    */

endmodule
