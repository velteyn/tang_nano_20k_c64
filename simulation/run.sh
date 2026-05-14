#!/bin/bash

iverilog -o ddr3_tb.vvp \
  -s ddr3_top \
  -g2012 \
  -I simulation \
  -D SIM \
  src/ddr3_controller.v \
  src/gowin_rpll/gowin_rpll.v \
  src/uart_tx_V2.v \
  simulation/prim_sim.v \
  simulation/ddr3.v \
  simulation/ddr3_top.v

vvp ddr3_tb.vvp
