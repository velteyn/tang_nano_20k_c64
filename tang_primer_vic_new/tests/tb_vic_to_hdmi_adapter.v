`timescale 1ns/1ps

module tb_vic_to_hdmi_adapter;

    // Inputs
    reg vic_clk;
    reg vic_rst_n;
    reg vic_hs;
    reg vic_vs;
    reg [7:0] vic_r;
    reg [7:0] vic_g;
    reg [7:0] vic_b;

    reg hdmi_clk;
    reg hdmi_rst_n;
    reg hdmi_de;
    reg hdmi_hs;
    reg hdmi_vs;

    // Outputs
    wire [7:0] hdmi_r;
    wire [7:0] hdmi_g;
    wire [7:0] hdmi_b;

    // Instantiate the Unit Under Test (UUT)
    vic_to_hdmi_adapter uut (
        .vic_clk(vic_clk), 
        .vic_rst_n(vic_rst_n), 
        .vic_hs(vic_hs), 
        .vic_vs(vic_vs), 
        .vic_r(vic_r), 
        .vic_g(vic_g), 
        .vic_b(vic_b), 
        .hdmi_clk(hdmi_clk), 
        .hdmi_rst_n(hdmi_rst_n), 
        .hdmi_de(hdmi_de), 
        .hdmi_hs(hdmi_hs), 
        .hdmi_vs(hdmi_vs), 
        .hdmi_r(hdmi_r), 
        .hdmi_g(hdmi_g), 
        .hdmi_b(hdmi_b)
    );

    // Clock generation
    // VIC Clock: ~8 MHz -> 125ns period
    always #62.5 vic_clk = ~vic_clk;

    // HDMI Clock: ~25.2 MHz -> ~39.6ns period (let's say 40ns for simple math)
    always #20 hdmi_clk = ~hdmi_clk;

    integer i;
    
    initial begin
        // Initialize Inputs
        vic_clk = 0;
        vic_rst_n = 0;
        vic_hs = 1; // Active low
        vic_vs = 1;
        vic_r = 0;
        vic_g = 0;
        vic_b = 0;

        hdmi_clk = 0;
        hdmi_rst_n = 0;
        hdmi_de = 0;
        hdmi_hs = 1;
        hdmi_vs = 1;

        // Reset Pulse
        #200;
        vic_rst_n = 1;
        hdmi_rst_n = 1;
        
        $display("Starting VIC-HDMI Adapter Testbench...");
        $display("Time=%t wr_bank=%b rd_bank_sel=%b", $time, uut.wr_bank, uut.rd_bank_sel);
        
        // Monitor write signals
        // $monitor("Time=%t vic_hs=%b wr_en=%b wr_addr=%d wr_bank=%b data=%h ram1[10]=%h", 
        //          $time, vic_hs, uut.wr_enable, uut.wr_addr, uut.wr_bank, {vic_r, vic_g, vic_b}, uut.ram_bank1[10]);

        // ---------------------------------------------------------------------
        // Simulation Scenario 1: Write one VIC line
        // ---------------------------------------------------------------------
        $display("Writing VIC Line 0 (Bank 0)...");
        
        // Start Line Sync
        @(posedge vic_clk);
        #1; // Delay to avoid race
        vic_hs = 0; // Sync start
        
        // Check immediate reaction
        #1;
        $display("Sync Start: vic_hs=%b wr_en=%b wr_bank=%b", vic_hs, uut.wr_enable, uut.wr_bank);
        
        // Hold HS low for 8 clocks (approx 1us)
        repeat(8) @(posedge vic_clk);
        
        #1;
        vic_hs = 1; // Sync end
        
        $display("Sync End: vic_hs=%b wr_en=%b wr_bank=%b", vic_hs, uut.wr_enable, uut.wr_bank);
        
        // Write active pixels
        // The adapter currently starts writing immediately after HS falling edge!
        // So addresses 0-7 have already been written with 0 during sync pulse.
        // We continue writing from address 8.
        
        for (i = 0; i < 640; i = i + 1) begin
            @(posedge vic_clk);
            #1; // Delay
            vic_r = i[7:0];      // Gradient R
            vic_g = 8'hFF;       // Full G
            vic_b = 8'h00;       // No B
            if (i == 10) $display("Writing pixel 10: addr=%d val=%h", uut.wr_addr, {vic_r, vic_g, vic_b});
        end
        
        // Check RAM content after write
        #10;
        $display("RAM Check: ram_bank1[10]=%h ram_bank1[20]=%h", uut.ram_bank1[10], uut.ram_bank1[20]);
        
        
        // End of VIC line
        #2000;
        
        // ---------------------------------------------------------------------
        // Simulation Scenario 2: Trigger Bank Swap
        // ---------------------------------------------------------------------
        
        $display("Start VIC Line 1 (triggers bank swap)...");
        @(posedge vic_clk);
        #1;
        vic_hs = 0; 
        repeat(8) @(posedge vic_clk);
        #1;
        vic_hs = 1;
        
        // Allow time for sync logic to propagate to HDMI domain
        #500;
        
        $display("Time=%t wr_bank=%b rd_bank_sel=%b (After Swap)", $time, uut.wr_bank, uut.rd_bank_sel);
        
        // ---------------------------------------------------------------------
        // Simulation Scenario 3: Read from HDMI side
        // ---------------------------------------------------------------------

        $display("Starting HDMI Read Line...");
        
        // HSync
        hdmi_hs = 0;
        #1000;
        hdmi_hs = 1;
        #2000; // Back porch
        
        // Active Video (DE High)
        $display("HDMI Active Video Region...");
        for (i = 0; i < 100; i = i + 1) begin // Check first 100 pixels
            @(posedge hdmi_clk);
            hdmi_de = 1;
            
            // Sample output
            #1; 
            $display("HDMI Pixel %d (Addr %d): R=%h G=%h B=%h", i, uut.rd_addr, hdmi_r, hdmi_g, hdmi_b);
        end
        
        @(posedge hdmi_clk);
        hdmi_de = 0;
        
        $display("Simulation finished.");
        $finish;
    end
      
endmodule
