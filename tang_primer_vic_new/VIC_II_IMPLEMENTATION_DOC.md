# VIC-II Video System Implementation for Tang Primer 20K

## Project Overview
This project transforms the standard Tang Primer HDMI example into a Commodore 64 VIC-II compatible video system. It integrates the `video_vicii_656x` core with a hardware scan doubler to drive the HDMI output.

## Architecture

### Block Diagram
```mermaid
graph TD
    CLK[Clock Gen (27 MHz)] --> SYS_CLK
    SYS_CLK --> VIC_DRIVER[VIC-II Driver]
    
    subgraph VIC_II_Driver
        DIV[Clock Divider] --> |Phi 1MHz| VIC_CORE
        DIV --> |PixEn 8MHz| VIC_CORE
        
        SM[Config State Machine] --> |Reg Write| VIC_CORE
        MOCK[Mock Memory] --> |Data| VIC_CORE
        
        VIC_CORE[VIC-II 656x Core] --> |HS/VS/Color| SCANDOUBLER
        
        SCANDOUBLER[Scan Doubler] --> |VGA Timing| HDMI_OUT
    end
    
    SCANDOUBLER --> |RGB/Sync| TOP[Top Level]
    TOP --> |TMDS| HDMI_PHY[DVI Transmitter]
    TOP --> |HDMI| MONITOR
```

### Signal Path
1.  **Clocking**: The system uses the 27 MHz onboard oscillator.
    *   **VIC-II Clock**: Derived via divider (approx 9 MHz pixel / 1 MHz CPU).
    *   **HDMI Clock**: 25.2 MHz (VGA Standard) provided by PLL.
2.  **VIC-II Core**: The standard `video_vicii_656x` VHDL core is instantiated.
    *   **Configuration**: A state machine initializes registers $D020 (Border), $D021 (Background), and Sprite 0 registers ($D000, $D015, $D027) to display a White Square.
    *   **Memory**: A mock memory interface provides Sprite Pointers ($07F8 -> $2000) and Sprite Data (Solid Block at $2000).
3.  **Scan Doubler**: Converts the 15 kHz (PAL) signal from the VIC-II to ~31 kHz (VGA) for HDMI compatibility.
4.  **HDMI Output**: The `DVI_TX` module serializes the video data to TMDS pairs.

## Implementation Details

### White Square Generation
The "White Square" is implemented as Hardware Sprite #0:
*   **Position**: Centered (Registers $D000/$D001 set to 160/100).
*   **Color**: White (Register $D027 set to 1).
*   **Data**: Solid block of pixels (0xFF) served by the Mock Memory.

### Timing Analysis
*   **Source Timing**: VIC-II generates ~15.6 kHz horizontal sync (PAL standard).
*   **Target Timing**: Scan Doubler outputs ~31.2 kHz horizontal sync (VGA compatible).
*   **Pixel Clock**: 25.2 MHz (Standard VGA). The output is pixel-doubled horizontally and scanline-doubled vertically.

## Verification

### Test Bench
A test bench `src/tb_vic_ii_driver.v` is provided to verify the driver logic.
To run simulation:
1.  Open the project in Gowin IDE.
2.  Navigate to the Simulation tab.
3.  Run `tb_vic_ii_driver`.
4.  Verify that `hs_out` and `vs_out` toggle and `r_out`/`g_out`/`b_out` show valid color data during the active frame.

### Hardware Validation
1.  Synthesize and Place & Route the project `tang_primer_20k.gprj`.
2.  Program the Tang Primer 20K.
3.  Connect an HDMI monitor.
4.  **Expected Output**: A Blue screen with Light Blue borders and a solid White Square in the center.

## Resource Utilization (Estimated)
*   **Logic**: ~2000 LUTs (VIC-II Core + Scandoubler Logic).
*   **Memory**: ~2 Block RAMs (Scandoubler Line Buffers).
*   **DSP**: 0.

## File Structure
*   `src/vic_ii_driver.v`: Main wrapper and driver logic.
*   `src/scandoubler.v`: Line doubling logic.
*   `../src/video_vicII_656x.vhd`: Original VIC-II Core.
*   `src/tang_primer_20k_top.v`: Top-level integration.
