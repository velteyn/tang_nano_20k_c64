module clock_gen (
    input  wire clk_in,    // 27 MHz
    input  wire rst_n,
    output wire serial_clk, // 126 MHz (5x pixel clock)
    output wire pix_clk,    // 25.2 MHz
    output wire pll_lock
);

    wire clkout_p;
    wire clkout_d;
    wire clkout_d3;
    wire gw_gnd = 1'b0;

    // rPLL Parameters from Reference
    // Fout = Fin * (FBDIV_SEL + 1) / (IDIV_SEL + 1) / ODIV
    // 371.25 = 27 * 55 / 4 / 1 ??
    // Let's assume ODIV_SEL=2 maps to /2?
    // VCO = 27 * 55 / 4 = 371.25 MHz
    // Wait, reference says "VCO=540MHz" in my memory but file uses 54/3/2.
    // 27 * 55 / 4 = 371.25 MHz.
    // 371.25 / 2 = 185.625 MHz.
    // This doesn't seem to match 126 MHz or 135 MHz.
    
    // Let's use parameters for 126 MHz (approx 125.875)
    // 25.175 * 5 = 125.875 MHz.
    // VCO = 1007 MHz.
    // ODIV = 8.
    // 1007 / 8 = 125.875.
    // VCO = Fin * (FBDIV+1) / (IDIV+1).
    // 1007 = 27 * (FBDIV+1) / (IDIV+1).
    // Ratio = 37.29.
    // 37.29 ~ 37.333 = 112/3.
    // So FBDIV+1=112 -> FBDIV=111.
    // IDIV+1=3 -> IDIV=2.
    // This gives VCO=1008 MHz.
    // 1008 / 8 = 126 MHz.
    // 126 / 5 = 25.2 MHz. (0.1% error).
    
    // ERROR FORMULA: (FCLKIN*(FBDIV_SEL+1)*ODIV_SEL)/(IDIV_SEL+1)
    // This formula evaluates to VCO * ODIV.
    // So the tool checks (VCO * ODIV).
    // If I use ODIV_SEL=8, result is 1008 * 8 = 8064 (Invalid).
    
    // TRY: ODIV_SEL=1. (Maybe encoded? 8 is not a valid register value?)
    // If ODIV_SEL parameter is direct divider value, then 8 is fine.
    // BUT if the tool error uses ODIV_SEL in numerator, maybe I should use ODIV_SEL=1?
    // If ODIV_SEL=1 means divide by 1?
    // Then VCO = 126. Too low.
    
    // What if I use FBDIV=13, IDIV=2, ODIV=8.
    // Tool calc: 27 * 14 * 8 / 3 = 1008. (Valid).
    // Real Hardware:
    // If ODIV is in feedback: VCO = 1008. CLKOUT = 1008. Too fast.
    // If ODIV is output divider: VCO = 126. Too slow.
    
    // Let's try matching the reference file exactly first.
    // Reference: IDIV=3, FBDIV=54, ODIV=2.
    // Tool calc: 27 * 55 * 2 / 4 = 742.5 MHz. (Valid).
    // Real hardware:
    // VCO = 27 * 55 / 4 = 371.25.
    // CLKOUT = 371.25 / 2 = 185.625.
    // 185.625 / 5 = 37.125 MHz. (720p?)
    // This reference might be for 720p or 1080i? Or maybe 480p at higher rate?
    
    // I need 126 MHz.
    // Let's try to find a set that satisfies Tool Calc in [500, 1250] AND gives 126 MHz output.
    // Assume Tool Calc = Real VCO * ODIV? No, that's absurd.
    
    // Assume Tool Calc = Real VCO.
    // And Tool thinks VCO = Fin * FBDIV * ODIV / IDIV.
    // This implies ODIV is in the feedback loop.
    // If ODIV is in feedback loop, then CLKOUT = VCO = Fin * FBDIV * ODIV / IDIV?
    // No, usually CLKOUT = VCO / ODIV.
    // If ODIV is in feedback:
    // CLKOUT = Fin * FBDIV / IDIV? No.
    // Let's look at rPLL diagram.
    // Ref Clock -> /IDIV -> PFD <- /FBDIV <- Feedback.
    // If Feedback comes from CLKOUT (after ODIV).
    // Then Feedback Freq = CLKOUT / FBDIV? No, usually FBDIV is in feedback path.
    // Feedback Freq = CLKOUT / (FBDIV+1).
    // PFD locks Ref/IDIV = Feedback.
    // Fin / (IDIV+1) = CLKOUT / (FBDIV+1).
    // CLKOUT = Fin * (FBDIV+1) / (IDIV+1).
    // And VCO = CLKOUT * ODIV.
    // VCO = Fin * (FBDIV+1) * ODIV / (IDIV+1).
    
    // THIS MATCHES THE ERROR FORMULA!
    // Conclusion: The tool assumes Feedback is from CLKOUT (external/output feedback mode).
    // But I set CLKFB_SEL("internal").
    // Maybe the tool ignores CLKFB_SEL for the check?
    // OR maybe "internal" means "internal path from CLKOUT"?
    
    // IF THIS IS TRUE:
    // CLKOUT = Fin * (FBDIV+1) / (IDIV+1).
    // I want CLKOUT = 126 MHz.
    // 126 = 27 * (FBDIV+1) / (IDIV+1).
    // Ratio = 4.666 = 14/3.
    // FBDIV_SEL = 13.
    // IDIV_SEL = 2.
    // And I need VCO in [500, 1250].
    // VCO = CLKOUT * ODIV.
    // 126 * ODIV in [500, 1250].
    // ODIV=4 -> 504. (Valid).
    // ODIV=8 -> 1008. (Valid).
    
    // So, correct parameters should be:
    // FBDIV_SEL = 13
    // IDIV_SEL = 2
    // ODIV_SEL = 4 or 8
    
    // Let's try ODIV=4 (VCO=504).
    // FBDIV=13.
    // IDIV=2.


    rPLL #(
        .FCLKIN("27"),
        .DEVICE("GW2A-18C"),
        .IDIV_SEL(2),     // Div by 3
        .FBDIV_SEL(13),   // Mul by 14
        .ODIV_SEL(4),     // Div by 4. If feedback is from CLKOUT, VCO=504MHz. CLKOUT=126MHz.
        .DYN_SDIV_SEL(2),
        .CLKFB_SEL("internal"),
        .CLKOUT_BYPASS("false"),
        .CLKOUTP_BYPASS("false"),
        .CLKOUTD_BYPASS("false"),
        .DYN_IDIV_SEL("false"),
        .DYN_FBDIV_SEL("false"),
        .DYN_ODIV_SEL("false"), 
        .CLKOUT_FT_DIR(1'b1),
        .CLKOUTP_FT_DIR(1'b1),
        .CLKOUT_DLY_STEP(0),
        .CLKOUTP_DLY_STEP(0),
        .PSDA_SEL("0000"),
        .DYN_DA_EN("true"),
        .DUTYDA_SEL("1000"),
        .CLKOUTD_SRC("CLKOUT"),
        .CLKOUTD3_SRC("CLKOUT")
    ) rpll_inst (
        .CLKOUT(serial_clk),
        .LOCK(pll_lock),
        .CLKOUTP(clkout_p),
        .CLKOUTD(clkout_d),
        .CLKOUTD3(clkout_d3),
        .RESET(gw_gnd),
        .RESET_P(gw_gnd),
        .CLKIN(clk_in),
        .CLKFB(gw_gnd),
        .FBDSEL({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd}),
        .IDSEL({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd}),
        .ODSEL({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd}),
        .PSDA({gw_gnd,gw_gnd,gw_gnd,gw_gnd}),
        .DUTYDA({gw_gnd,gw_gnd,gw_gnd,gw_gnd}),
        .FDLY({gw_gnd,gw_gnd,gw_gnd,gw_gnd})
    );

    CLKDIV #(
        .DIV_MODE("5"),
        .GSREN("false")
    ) u_clkdiv (
        .RESETN(pll_lock), // Use lock as reset
        .HCLKIN(serial_clk),
        .CLKOUT(pix_clk),
        .CALIB(1'b1)
    );

endmodule
