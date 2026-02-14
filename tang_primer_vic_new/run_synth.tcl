set_option -output_base_name tang_primer_20k
set_option -top_module tang_primer_20k_top
set_option -use_sspi_as_gpio 1
set_option -verilog_std sysv2017
set_device GW2A-LV18PG256C8/I7 -device_version C

add_file src/tang_primer_20k_top.v
add_file src/testpattern.v
add_file src/TMDS_rPLL.v
add_file src/dvi_tx/dvi_tx.v
add_file src/tang_primer_20k.cst
add_file src/tang_primer_20k.sdc

run pnr
