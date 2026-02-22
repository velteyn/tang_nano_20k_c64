`timescale 1ns/1ps

module tb_hdmi_vic;

    // Inputs
    reg I_pxl_clk;
    reg I_rst_n;
    reg [2:0] I_mode;
    reg [7:0] I_single_r;
    reg [7:0] I_single_g;
    reg [7:0] I_single_b;
    reg [11:0] I_h_total;
    reg [11:0] I_h_sync;
    reg [11:0] I_h_bporch;
    reg [11:0] I_h_res;
    reg [11:0] I_v_total;
    reg [11:0] I_v_sync;
    reg [11:0] I_v_bporch;
    reg [11:0] I_v_res;
    reg I_hs_pol;
    reg I_vs_pol;
    reg I_genlock_vs;

    // Outputs
    wire O_de;
    wire O_hs;
    wire O_vs;
    wire [7:0] O_data_r;
    wire [7:0] O_data_g;
    wire [7:0] O_data_b;

    // Instantiate the Unit Under Test (UUT)
    testpattern uut (
        .I_pxl_clk(I_pxl_clk), 
        .I_rst_n(I_rst_n), 
        .I_mode(I_mode), 
        .I_single_r(I_single_r), 
        .I_single_g(I_single_g), 
        .I_single_b(I_single_b), 
        .I_h_total(I_h_total), 
        .I_h_sync(I_h_sync), 
        .I_h_bporch(I_h_bporch), 
        .I_h_res(I_h_res), 
        .I_v_total(I_v_total), 
        .I_v_sync(I_v_sync), 
        .I_v_bporch(I_v_bporch), 
        .I_v_res(I_v_res), 
        .I_hs_pol(I_hs_pol), 
        .I_vs_pol(I_vs_pol), 
        .I_genlock_vs(I_genlock_vs), 
        .O_de(O_de), 
        .O_hs(O_hs), 
        .O_vs(O_vs), 
        .O_data_r(O_data_r), 
        .O_data_g(O_data_g), 
        .O_data_b(O_data_b)
    );

    // Clock generation (31.5 MHz)
    // Period = 1/31.5MHz = 31.746 ns
    real clk_period = 31.746;
    always #(clk_period/2) I_pxl_clk = ~I_pxl_clk;

    // Genlock signal generation
    // C64 frame rate ~59.8 Hz (NTSC) -> 16.7 ms period
    // Or 60Hz -> 16.666 ms
    // Let's simulate slightly faster than HDMI (which is 31.5MHz / (1000*560) = 56.25 Hz)
    // C64 (NTSC standard) is ~59.94Hz.
    // 31.5MHz pixel clock is fixed.
    // Let's use 60Hz exact for C64.
    real frame_period_ns = 16666666.0; // 60Hz
    
    initial begin
        I_genlock_vs = 0;
        forever begin
            #(frame_period_ns);
            I_genlock_vs = 1;
            // VSync pulse width (e.g. 3 lines approx 3*32us = 100us)
            #100000; 
            I_genlock_vs = 0;
        end
    end

    // Test variables
    integer h_cnt_check;
    integer v_cnt_check;
    integer frame_count;
    integer de_count;
    real last_vs_time;
    real current_vs_time;
    real frame_time;

    // Monitor signals
    initial begin
        monitor_de();
    end

    initial begin
        monitor_sync();
    end
    
    initial begin
        // Initialize Inputs
        I_pxl_clk = 0;
        I_rst_n = 0;
        I_mode = 0;
        I_single_r = 0;
        I_single_g = 0;
        I_single_b = 0;
        
        // 800x480 @ 60Hz (approx) parameters used in tang_primer_20k_top.v
        I_h_total = 1000;
        I_h_sync = 72;
        I_h_bporch = 96;
        I_h_res = 800;
        
        I_v_total = 560; // Extended for genlock
        I_v_sync = 2;
        I_v_bporch = 20;
        I_v_res = 480;
        
        I_hs_pol = 0; // Negative polarity
        I_vs_pol = 0; // Negative polarity
        // I_genlock_vs handled by separate block

        // Wait 100 ns for global reset to finish
        #100;
        I_rst_n = 1;
        
        $display("Starting HDMI VIC Testbench...");
        $display("Parameters: H_TOTAL=%d, V_TOTAL=%d, H_RES=%d, V_RES=%d", I_h_total, I_v_total, I_h_res, I_v_res);

        // Run for a few frames
        frame_count = 0;
        last_vs_time = 0;
        
        #60000000; // Run for 60ms (approx 3-4 frames)
        
        $display("Simulation finished.");
        $display("Total Frames Detected: %d", frame_count);
        
        if (frame_count < 2) begin
            $display("ERROR: Not enough frames detected!");
        end else begin
            $display("PASS: Frame generation confirmed.");
        end
        
        $finish;
    end
    
    task monitor_de;
        integer de_high_count;
        begin
            de_high_count = 0;
            forever @(posedge I_pxl_clk) begin
                if (O_de) begin
                    de_high_count = de_high_count + 1;
                end
                
                // Reset count at VSync (approx) or check periodically
            end
        end
    endtask

    task monitor_sync;
        begin
            forever @(negedge O_vs) begin // Detect start of VSync (active low)
                current_vs_time = $realtime;
                if (last_vs_time != 0) begin
                    frame_time = current_vs_time - last_vs_time;
                    $display("VSync detected at %t. Frame duration: %f ms (Freq: %f Hz)", 
                             current_vs_time, frame_time/1000000.0, 1000000000.0/frame_time);
                    
                    // Check if frequency is close to 60Hz (C64 source)
                    if (frame_time > 16000000 && frame_time < 17000000) begin
                        $display("  -> Locked to Genlock Source (Correct)");
                    end else begin
                        $display("  -> Free Running or Drift (Expected only for first frame or if genlock fails)");
                    end
                end
                last_vs_time = current_vs_time;
                frame_count = frame_count + 1;
            end
        end
    endtask

    // Check for DE activity
    reg de_seen;
    initial begin
        de_seen = 0;
        wait(I_rst_n == 1);
        forever @(posedge I_pxl_clk) begin
            if (O_de) begin
                if (!de_seen) begin
                    $display("First DE High detected at %t", $realtime);
                    de_seen = 1;
                end
            end
        end
    end
    
    // Watchdog for Black Screen
    initial begin
        #20000000; // 20ms
        if (!de_seen) begin
            $display("ERROR: BLACK SCREEN DETECTED - O_de never went high in first 20ms!");
        end
    end

endmodule
