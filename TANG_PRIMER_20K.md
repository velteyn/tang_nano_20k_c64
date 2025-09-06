# C64 Nano on Tang Primer 20K

C64 Nano can be used in the [Tang Primer 20K](https://wiki.sipeed.com/hardware/en/tang/tang-primer-20k/primer-20k.html).<br>
This board uses a GW2A-18C FPGA and has on-board DDR3 memory. It is a core board that connects to an extension board (Dock or Lite).

The peripherals like HDMI and SD card are on the extension boards. Please refer to the documentation of the extension boards for more details.

On the software side the setup is very simuilar to the other boards. The core needs to be built specifically
for the different FPGA of the Tang Primer 20k using either the [TCL script with the GoWin command line interface](build_tp20k.tcl) or the
[project file for the graphical GoWin IDE](tang_primer_20k_c64.gprj). The resulting bitstream is flashed to the TP20K as usual. So are the c1541 DOS ROMs which are flashed exactly like they are on the Tang Nano 20K. And also the firmware for the M0S Dock is the [same version as for
the Tang Nano 20K](https://github.com/harbaum/MiSTeryNano/tree/main/firmware/misterynano_fw/). Latest binary can be found in the [release](https://github.com/harbaum/MiSTeryNano/releases) section.
