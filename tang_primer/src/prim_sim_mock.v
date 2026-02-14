`timescale 1ns/1ps

module rPLL (
    output reg CLKOUT,
    output reg LOCK,
    output reg CLKOUTP,
    output reg CLKOUTD,
    output reg CLKOUTD3,
    input CLKIN,
    input CLKFB,
    input [5:0] FBDSEL,
    input [5:0] IDSEL,
    input [5:0] ODSEL,
    input [3:0] DUTYDA,
    input [3:0] PSDA,
    input [3:0] FDLY,
    input RESET,
    input RESET_P
);

    parameter FCLKIN = "27";
    parameter IDIV_SEL = 0;
    parameter FBDIV_SEL = 0;
    parameter ODIV_SEL = 8;
    parameter DYN_SDIV_SEL = 2;
    parameter DEVICE = "GW2A-18C";
    
    // Ignore other parameters for now

    // Calculate period
    // Fout = Fin * (FBDIV_SEL+1) / (IDIV_SEL+1) / ODIV_SEL
    // PeriodOut = PeriodIn * (IDIV_SEL+1) * ODIV_SEL / (FBDIV_SEL+1)
    
    real clk_period = 37.037; // Default for 27MHz
    real out_period;
    
    initial begin
        CLKOUT = 0;
        LOCK = 0;
        #100; // Wait a bit
        LOCK = 1;
    end
    
    // Simple clock generation based on parameters
    // We assume input clock is roughly matching FCLKIN
    
    always @(posedge CLKIN) begin
        // Update period calculation on every edge just in case (though params are static)
        out_period = 37.037 * (IDIV_SEL + 1.0) * ODIV_SEL / (FBDIV_SEL + 1.0);
        // Debug print
        // $display("rPLL: IDIV=%d, ODIV=%d, FBDIV=%d, Period=%f", IDIV_SEL, ODIV_SEL, FBDIV_SEL, out_period);
    end
    
    always begin
        // Use calculated period
        // For simulation, we can just toggle
        // 126 MHz -> 7.936 ns period -> 3.968 half period
        
        // Ensure out_period is valid
        if (out_period > 0)
            #(out_period/2.0) CLKOUT = ~CLKOUT;
        else
            #1 CLKOUT = ~CLKOUT;
    end

endmodule

module CLKDIV (
    output reg CLKOUT,
    input CALIB,
    input HCLKIN,
    input RESETN
);
    parameter DIV_MODE = "5";
    parameter GSREN = "false";

    reg [2:0] counter;

    always @(posedge HCLKIN or negedge RESETN) begin
        if (!RESETN) begin
            counter <= 0;
            CLKOUT <= 0;
        end else begin
            if (counter == 4) begin
                counter <= 0;
            end else begin
                counter <= counter + 1;
            end
            
            // Clean assignment
            if (counter < 2) CLKOUT <= 1;
            else CLKOUT <= 0;
        end
    end

endmodule
