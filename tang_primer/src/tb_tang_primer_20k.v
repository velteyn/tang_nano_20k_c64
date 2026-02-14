`timescale 1ns/1ps

module tb_tang_primer_20k;

    reg sys_clk;
    reg rst_n;
    wire tmds_clk_p;
    wire tmds_clk_n;
    wire [2:0] tmds_data_p;
    wire [2:0] tmds_data_n;
    wire [3:0] led;

    // Instantiate Top Module
    tang_primer_20k_top uut (
        .sys_clk(sys_clk),
        .rst_n(rst_n),
        .tmds_clk_p(tmds_clk_p),
        .tmds_clk_n(tmds_clk_n),
        .tmds_data_p(tmds_data_p),
        .tmds_data_n(tmds_data_n),
        .led(led)
    );

    // Clock Generation (27 MHz)
    initial begin
        sys_clk = 0;
        forever #18.518 sys_clk = ~sys_clk; 
    end

    real last_hs_time;
    real last_vs_time;
    integer hs_count;

    // Test Sequence
    initial begin
        $dumpfile("tb_tang_primer_20k.vcd");
        $dumpvars(0, tb_tang_primer_20k);

        rst_n = 0;
        hs_count = 0;
        #1000;
        rst_n = 1;
        
        // Wait for PLL Lock
        wait(uut.pll_lock);
        $display("PLL Locked at time %t", $time);
        
        // Wait for first HS
        wait(uut.hs == 0);
        last_hs_time = $time;
        $display("First HS falling edge at %t", $time);
        
        // Wait for next HS
        wait(uut.hs == 1);
        wait(uut.hs == 0);
        $display("Second HS falling edge at %t. Period: %t", $time, $time - last_hs_time);
        
        if (($time - last_hs_time) > 31000 && ($time - last_hs_time) < 32500)
            $display("HS Period correct (~31.7us)");
        else
            $display("HS Period INCORRECT!");

        // Run for enough time to see color bars
        // Check middle of a line
        wait(uut.de == 1);
        $display("DE Active. Checking colors...");
        
        // Check a few points in the line
        // We need to synchronize with H_CNT
        
        // Run for 35ms to ensure full frame (VS)
        // This might take a few seconds of wall time
        #35000000; 

        $display("Simulation finished");
        $finish;
    end
    
    // Monitor VS
    always @(negedge uut.vs) begin
        $display("VS Falling Edge at %t", $time);
        if (last_vs_time > 0)
            $display("VS Period: %t", $time - last_vs_time);
        last_vs_time = $time;
    end
    
    // Check colors
    always @(posedge uut.pix_clk) begin
        if (uut.de) begin
            // Sample checking
            // We can check uut.u_tpg.h_cnt
            if (uut.u_tpg.h_cnt == 40) begin // White
                 if (uut.r !== 255 || uut.g !== 255 || uut.b !== 255) $display("Error: Expected White at h_cnt=40");
            end
            if (uut.u_tpg.h_cnt == 120) begin // Yellow
                 if (uut.r !== 255 || uut.g !== 255 || uut.b !== 0) $display("Error: Expected Yellow at h_cnt=120");
            end
            // ... check others if needed
        end
    end

endmodule
