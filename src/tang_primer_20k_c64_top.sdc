//Copyright (C)2014-2022 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//GOWIN Version: 1.9.8.05
//Created Time: 2022-05-06 23:08:41

// Input clock is 27 MHz on Tang Primer 20K
create_clock -name clk -period 37.037 -waveform {0 18.518} [get_ports {clk}]

// clk_x4 is approx 160 MHz (5x 32MHz pixel clock)
create_clock -name clk_x4 -period 6.173 -waveform {0 3.086} [get_nets {clk_x4}]

// clk32 is approx 32.4 MHz (Pixel Clock)
// We explicitly constrain it to ~32.4 MHz (30.864 ns) to correct the default 100MHz assumption
create_clock -name clk32 -period 30.864 -waveform {0 15.432} [get_nets {clk32}]

set_clock_groups -asynchronous -group [get_clocks {clk_x4}] -group [get_clocks {clk}]
set_clock_groups -asynchronous -group [get_clocks {clk32}] -group [get_clocks {clk}]

// Relax recovery timing for DDR3 reset synchronization
// The reset signal is a high-fanout net that doesn't need single-cycle timing.
// We allow 2 cycles for propagation.
set_multicycle_path -setup 2 -from [get_cells {*ddr3_reset_n_sync*}] 
set_multicycle_path -hold 1 -from [get_cells {*ddr3_reset_n_sync*}] 
