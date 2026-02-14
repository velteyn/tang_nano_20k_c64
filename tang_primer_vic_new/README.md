# Tang Primer 20K HDMI Interface

This directory contains the board-specific implementation for the Tang Primer 20K (GW2A-18C) FPGA board. It provides a VESA-compliant 640x480@60Hz HDMI output with a test pattern generator.

## Directory Structure
- `src/`: Source code and constraints.
  - `tang_primer_20k_top.v`: Top-level module.
  - `clock_gen.v`: Clock generation (27MHz -> 25.175MHz pixel clock).
  - `test_pattern_gen.v`: 640x480 VGA timing and color bar generator.
  - `tang_primer_20k.cst`: Physical constraints (Pin assignments).
  - `tb_tang_primer_20k.v`: Verilog testbench for simulation.
  - `prim_sim_mock.v`: Simulation models for Gowin primitives (rPLL, CLKDIV) for use with Icarus Verilog.
  - `dvi_tx/`: DVI Transmitter IP (copied from reference).

## Hardware Configuration
- **FPGA**: Gowin GW2A-LV18PG256C8/I7 (GW2A-18C)
- **Clock Input**: 27 MHz (Pin H11)
- **Reset**: Internal Power-On Reset (No external button required)
- **HDMI Output**: TLVDS Differential Pairs
  - Clock: G16/H15
  - Data0 (Blue): H14/H16
  - Data1 (Green): J15/K16
  - Data2 (Red): K14/K15

## Synthesis and Programming
### Option A: Using Gowin IDE (GUI)
1. Open **Gowin IDE**.
2. Click **Open Project** and select `tang_primer/tang_primer_20k.gprj`.
3. In the **Process** tab:
   - Right-click **Synthesize** and select **Run**.
   - Right-click **Place & Route** and select **Run**.
4. Once completed successfully, connect your Tang Primer 20K board.
5. Open **Gowin Programmer** (via Tools menu or toolbar).
6. Scan for the device and program the generated `impl/pnr/tang_primer_20k.fs` bitstream to SRAM or Flash.

### Option B: Using Command Line (Tcl)
If you have the Gowin IDE binaries in your path (or know the path), you can use the provided script:
```bash
# Example (adjust path to your installation)
C:\FPGA\Gowin\Gowin_V1.9.11.03_Education_x64\IDE\bin\gw_sh.exe run_synth.tcl
```
This will generate the bitstream in `impl/pnr/tang_primer_20k.fs`.

## Simulation
To verify the design using Icarus Verilog:

1. Open a terminal in `tang_primer/src`.
2. Compile the simulation:
   ```bash
   iverilog -o tb_tang_primer_20k.vvp -I . tb_tang_primer_20k.v tang_primer_20k_top.v clock_gen.v test_pattern_gen.v dvi_tx_mock.v prim_sim_mock.v
   ```
3. Run the simulation:
   ```bash
   vvp tb_tang_primer_20k.vvp
   ```
4. View waveforms (optional):
   ```bash
   gtkwave tb_tang_primer_20k.vcd
   ```

Note: `prim_sim_mock.v` is used to bypass Gowin-specific encrypted models during Icarus simulation. For accurate timing simulation in Gowin IDE, use the official `prim_sim.v`.

## Implementation Details

### Clock Generation
- Input: 27 MHz system clock.
- Output: 
  - `serial_clk`: 125.875 MHz (5x pixel clock).
  - `pix_clk`: 25.175 MHz.
- Method: `rPLL` generates high-speed serial clock, `CLKDIV` divides by 5 for pixel clock.
- PLL Params: IDIV=2, FBDIV=55, ODIV=4. (27 * 56 / 3 / 4 = 126 MHz).
- Target Pixel Clock: 25.175 MHz. Actual: 25.2 MHz (0.1% error, well within HDMI tolerance).

### Video Timing (640x480 @ 60Hz)
- Pixel Clock: 25.175 MHz
- Horizontal:
  - Active: 640
  - Front Porch: 16
  - Sync: 96
  - Back Porch: 48
  - Total: 800
- Vertical:
  - Active: 480
  - Front Porch: 10
  - Sync: 2
  - Back Porch: 33
  - Total: 525
- Polarity: HSync (-), VSync (-)

### Color Bars
Displays 8 vertical bars: White, Yellow, Cyan, Green, Magenta, Red, Blue, Black.
Each bar is 80 pixels wide.
