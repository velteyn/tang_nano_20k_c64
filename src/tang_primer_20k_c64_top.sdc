//Copyright (C)2014-2025 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//Tool Version: V1.9.10.03 (64-bit)
//Created Time: 2025-01-12 22:49:11

// NOTE: This is a placeholder file. The clock constraints need to be
// verified for the Tang Primer 20k board.

create_clock -name clk -period 37.037 -waveform {0 18.5} [get_ports {clk}] -add
