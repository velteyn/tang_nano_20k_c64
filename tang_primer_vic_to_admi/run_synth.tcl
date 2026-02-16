set_device GW2A-LV18PG256C8/I7 -device_version C

set_option -verilog_std sysv2017
set_option -top_module tp_admi_top

add_file src/tp_admi_top.v
add_file src/TMDS_rPLL.v
add_file src\\hdmi_800x600.sv
add_file src\\dvi_640x480.sv
add_file src\\dvi_800x600.sv
add_file src\\dvi_1360x768.sv
add_file src\\serializer.sv
add_file src\\tmds_channel.sv
add_file src\\packet_assembler.sv
add_file src\\packet_picker.sv
add_file src\\audio_clock_regeneration_packet.sv
add_file src\\audio_info_frame.sv
add_file src\\audio_sample_packet.sv
add_file src\\auxiliary_video_information_info_frame.sv
add_file src\\source_product_description_info_frame.sv
add_file src\\tang_primer_20k.cst

set_option -use_mspi_as_gpio 1
set_option -use_sspi_as_gpio 1

run all
