`timescale 1ns/1ps

module tb_vic_ii_driver;

    reg clk_sys;
    reg rst_n;
    
    wire hs_out;
    wire vs_out;
    wire [7:0] r_out;
    wire [7:0] g_out;
    wire [7:0] b_out;

    // Instantiate the Driver
    vic_ii_driver u_dut (
        .clk_sys(clk_sys),
        .rst_n(rst_n),
        .hs_out(hs_out),
        .vs_out(vs_out),
        .r_out(r_out),
        .g_out(g_out),
        .b_out(b_out)
    );

    // Clock Generation (27 MHz -> 37.037 ns period)
    initial begin
        clk_sys = 0;
        forever #18.518 clk_sys = ~clk_sys;
    end

    // Test Sequence
    initial begin
        $display("Starting VIC-II Driver Test...");
        rst_n = 0;
        #100;
        rst_n = 1;
        
        // Run for a few frames
        // 60Hz frame = 16.6ms.
        // We can't simulate that long easily in this snippet, but we can run enough to see HSyncs.
        // HSync period ~31.7us (VGA) or ~63.5us (PAL).
        // Scandoubler should output ~31us HSyncs.
        
        #500000; // 500 us
        
        $display("Simulation finished.");
        $finish;
    end
    
    // Monitor
    initial begin
        $monitor("Time: %t | HS: %b | VS: %b | R: %h | G: %h | B: %h", 
                 $time, hs_out, vs_out, r_out, g_out, b_out);
    end

endmodule
