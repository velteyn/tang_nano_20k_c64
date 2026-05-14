set_option -synthesis_tool gowinsynthesis
set_option -output_base_name tang_primer_20k
set_option -top_module tang_primer_20k_top
set_option -use_sspi_as_gpio 1
set_option -verilog_std sysv2017
set_option -vhdl_std vhd2008
set_device GW2A-LV18PG256C8/I7 -device_version C

add_file src/tang_primer_20k_top.v
add_file src/testpattern.v
add_file src/TMDS_rPLL.v
add_file src/scandoubler.v
add_file src/vic_ii_driver.v
add_file src/vic_hdmi_passthrough.v
add_file src/dvi_tx/dvi_tx.v
add_file ..\\src\\hdmi\\audio_info_frame.sv
add_file ..\\src\\video_vicII_656x.vhd
add_file ..\\src\\fpga64_sid_iec.vhd
add_file ..\\src\\fpga64_buslogic.vhd
add_file ..\\src\\fpga64_rgbcolor.vhd
add_file ..\\src\\cpu_6510.vhd
add_file ..\\src\\mos6526.v
add_file ..\\src\\gowin_prom\\gowin_prom_basic.vhd
add_file ..\\src\\gowin_prom\\gowin_prom_chargen.vhd
add_file ..\\src\\gowin_sdpb\\gowin_sdpb_kernal_8k.vhd
add_file ..\\src\\gowin_sp\\gowin_sp_2k.vhd
add_file ..\\src\\gowin_sp\\gowin_sp_8k.vhd
add_file ..\\src\\gowin_sp\\gowin_sp_cram.vhd
add_file ..\\src\\t65\\T65.vhd
add_file ..\\src\\t65\\T65_ALU.vhd
add_file ..\\src\\t65\\T65_MCode.vhd
add_file ..\\src\\t65\\T65_Pack.vhd
add_file ..\\src\\fpga64_keyboard.vhd
add_file ..\\src\\sid\\sid_top.sv
add_file ..\\src\\sid\\sid_voice.sv
add_file ..\\src\\sid\\sid_filter.sv
add_file ..\\src\\sid\\sid_envelope.sv
add_file ..\\src\\sid\\sid_tables.sv
add_file ..\\src\\sid\\sid_dac.sv
add_file src/tang_primer_20k.cst

run all
