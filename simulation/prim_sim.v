// Dummy prim_sim.v
// This file should contain behavioral models for the Gowin primitives.
// Since I don't have access to the Gowin IDE, this is just a placeholder.

// Dummy rPLL module
module rPLL(
    output CLKOUT,
    output LOCK,
    output CLKOUTP,
    output CLKOUTD,
    output CLKOUTD3,
    input RESET,
    input RESET_P,
    input CLKIN,
    input CLKFB,
    input [5:0] FBDSEL,
    input [5:0] IDSEL,
    input [5:0] ODSEL,
    input [3:0] PSDA,
    input [3:0] DUTYDA,
    input [3:0] FDLY
);
    parameter FBDIV_SEL = 0;
    parameter IDIV_SEL = 0;
    parameter ODIV_SEL = 0;
    parameter DYN_SDIV_SEL = 0;
    parameter FCLKIN = "27";
    parameter DYN_IDIV_SEL = "false";
    parameter DYN_FBDIV_SEL = "false";
    parameter DYN_ODIV_SEL = "false";
    parameter PSDA_SEL = "0000";
    parameter DYN_DA_EN = "false";
    parameter DUTYDA_SEL = "1000";
    parameter CLKOUT_FT_DIR = 1'b1;
    parameter CLKOUTP_FT_DIR = 1'b1;
    parameter CLKOUT_DLY_STEP = 0;
    parameter CLKOUTP_DLY_STEP = 0;
    parameter CLKFB_SEL = "internal";
    parameter CLKOUT_BYPASS = "false";
    parameter CLKOUTP_BYPASS = "false";
    parameter CLKOUTD_BYPASS = "false";
    parameter CLKOUTD_SRC = "CLKOUT";
    parameter CLKOUTD3_SRC = "CLKOUT";
    parameter DEVICE = "GW2A-18C";
endmodule

// Dummy DLL module
module DLL(
    input CLKIN,
    input RESET,
    input STOP,
    input UPDNCNTL,
    output [7:0] STEP,
    output LOCK
);
    assign LOCK = 1'b1;
    assign STEP = 8'd25;
endmodule

// Dummy DQS module
module DQS(
    input FCLK,
    input PCLK,
    input DQSIN,
    input RESET,
    input HOLD,
    input RLOADN,
    input WLOADN,
    input RMOVE,
    input WMOVE,
    input [7:0] DLLSTEP,
    input [7:0] WSTEP,
    input [2:0] RCLKSEL,
    input [3:0] READ,
    output DQSR90,
    output [2:0] WPOINT,
    output [2:0] RPOINT,
    output DQSW0,
    output DQSW270,
    output RBURST
);
    parameter DQS_MODE = "X4";
    parameter HWL = "false";
endmodule

// Dummy OSER8_MEM module
module OSER8_MEM(
    input D0,
    input D1,
    input D2,
    input D3,
    input D4,
    input D5,
    input D6,
    input D7,
    input TX0,
    input TX1,
    input TX2,
    input TX3,
    input FCLK,
    input PCLK,
    input TCLK,
    input RESET,
    output Q0,
    output Q1
);
    parameter TCLK_SOURCE = "DQSW270";
endmodule

// Dummy IDES8_MEM module
module IDES8_MEM(
    input D,
    input ICLK,
    input FCLK,
    input PCLK,
    input CALIB,
    input RESET,
    output Q0,
    output Q1,
    output Q2,
    output Q3,
    output Q4,
    output Q5,
    output Q6,
    output Q7,
    input [2:0] WADDR,
    input [2:0] RADDR
);
endmodule

// Dummy OSER8 module
module OSER8(
    input D0,
    input D1,
    input D2,
    input D3,
    input D4,
    input D5,
    input D6,
    input D7,
    input FCLK,
    input PCLK,
    input RESET,
    output Q0
);
endmodule
