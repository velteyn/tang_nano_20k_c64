//Copyright (C)2014-2022 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//GOWIN Version: 1.9.8.05
//Created Time: 2022-05-06 23:08:41
create_clock -name clk -period 15.3 -waveform {0 7.65} [get_ports {clk}]
create_clock -name clk_x4 -period 3.825 -waveform {0 1.9125} [get_nets {clk_x4}]
set_clock_groups -asynchronous -group [get_clocks {clk_x4}] -group [get_clocks {clk}]
report_timing -hold -from_clock [get_clocks {clk*}] -to_clock [get_clocks {clk*}] -max_paths 25 -max_common_paths 1
report_timing -setup -from_clock [get_clocks {clk*}] -to_clock [get_clocks {clk*}] -max_paths 25 -max_common_paths 1
