-------------------------------------------------------------------------
--  C64 Top level for Tang Primer 20k
--  2025 Jules
--  based on the work of many others
--
--  FPGA64 is Copyrighted 2005-2008 by Peter Wendrich (pwsoft@syntiac.com)
--  http://www.syntiac.com/fpga64.html
--
-------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.numeric_std.ALL;

entity tang_primer_20k_c64_top is
  generic
  (
   DUAL  : integer := 1; -- 0:no, 1:yes dual SID build option
   MIDI  : integer := 0; -- 0:no, 1:yes optional MIDI Interface
   U6551 : integer := 1  -- 0:no, 1:yes optional 6551 UART
   );
  port
  (
    clk         : in std_logic;
    reset       : in std_logic; -- S2 button

    -- LEDs
    leds_n      : out std_logic_vector(1 downto 0);

    -- UART
    uart_rx     : in std_logic;
    uart_tx     : out std_logic;

    -- SPI to uC
    m0s         : inout std_logic_vector(4 downto 0);

    -- HDMI
    tmds_clk_n  : out std_logic;
    tmds_clk_p  : out std_logic;
    tmds_d_n    : out std_logic_vector( 2 downto 0);
    tmds_d_p    : out std_logic_vector( 2 downto 0);

    -- SD card
    sd_clk      : out std_logic;
    sd_cmd      : inout std_logic;
    sd_dat      : inout std_logic_vector(3 downto 0);

    -- DDR3 Memory Interface
    ddr3_a      : out std_logic_vector(13 downto 0);
    ddr3_ba     : out std_logic_vector(2 downto 0);
    ddr3_ck_p   : out std_logic;
    ddr3_ck_n   : out std_logic;
    ddr3_cke    : out std_logic;
    ddr3_cs_n   : out std_logic;
    ddr3_ras_n  : out std_logic;
    ddr3_cas_n  : out std_logic;
    ddr3_we_n   : out std_logic;
    ddr3_reset_n: out std_logic;
    ddr3_dq     : inout std_logic_vector(15 downto 0);
    ddr3_dqs_p  : inout std_logic_vector(1 downto 0);
    ddr3_dqs_n  : inout std_logic_vector(1 downto 0);
    ddr3_odt    : out std_logic;
    ddr3_dm     : out std_logic_vector(1 downto 0)
    );
end;

architecture Behavioral_top of tang_primer_20k_c64_top is

  signal clk_x4 : std_logic;
  signal clk_ck : std_logic;
  signal clk32 : std_logic;
  signal pll_locked : std_logic;

  signal c64_addr : unsigned(25 downto 0);
  signal sdram_data : unsigned(7 downto 0);
  signal c64_data_out : unsigned(7 downto 0);
  signal ram_ce : std_logic;
  signal ram_we : std_logic;
  signal idle : std_logic;

  signal ddr3_busy : std_logic;
  signal ddr3_data_ready : std_logic;
  signal ddr3_dout : std_logic_vector(15 downto 0);
  signal ddr3_din : std_logic_vector(15 downto 0);
  signal ddr3_rd : std_logic;
  signal ddr3_wr : std_logic;
  signal ddr3_refresh : std_logic;

  signal ntscMode : std_logic;
  signal hsync : std_logic;
  signal vsync : std_logic;
  signal r : unsigned(7 downto 0);
  signal g : unsigned(7 downto 0);
  signal b : unsigned(7 downto 0);
  signal audio_data_l : std_logic_vector(17 downto 0);
  signal audio_data_r : std_logic_vector(17 downto 0);
  signal joyA : std_logic_vector(6 downto 0);
  signal joyB : std_logic_vector(6 downto 0);
  signal pot1 : std_logic_vector(7 downto 0);
  signal pot2 : std_logic_vector(7 downto 0);
  signal pot3 : std_logic_vector(7 downto 0);
  signal pot4 : std_logic_vector(7 downto 0);

  component Gowin_rPLL is
    port (
        clkout: out std_logic;
        clkoutp: out std_logic;
        lock: out std_logic;
        clkoutd: out std_logic;
        clkin: in std_logic
    );
  end component;

  component ddr3_controller is
    generic (
      ROW_WIDTH: integer := 13;
      COL_WIDTH: integer := 10;
      BANK_WIDTH: integer := 3
    );
    port (
      pclk: in std_logic;
      fclk: in std_logic;
      ck: in std_logic;
      resetn: in std_logic;
      rd: in std_logic;
      wr: in std_logic;
      refresh: in std_logic;
      addr: in std_logic_vector(25 downto 0);
      din: in std_logic_vector(15 downto 0);
      dout: out std_logic_vector(15 downto 0);
      dout128: out std_logic_vector(127 downto 0);
      data_ready: out std_logic;
      busy: out std_logic;
      write_level_done: out std_logic;
      wstep: out std_logic_vector(7 downto 0);
      read_calib_done: out std_logic;
      rclkpos: out std_logic_vector(1 downto 0);
      rclksel: out std_logic_vector(2 downto 0);
      debug: out std_logic_vector(63 downto 0);
      DDR3_DQ: inout std_logic_vector(15 downto 0);
      DDR3_DQS: inout std_logic_vector(1 downto 0);
      DDR3_A: out std_logic_vector(13 downto 0);
      DDR3_BA: out std_logic_vector(2 downto 0);
      DDR3_nRAS: out std_logic;
      DDR3_nCAS: out std_logic;
      DDR3_nWE: out std_logic;
      DDR3_nCS: out std_logic;
      DDR3_CK: out std_logic;
      DDR3_CKE: out std_logic;
      DDR3_nRESET: out std_logic;
      DDR3_DM: out std_logic_vector(1 downto 0);
      DDR3_ODT: out std_logic
    );
  end component;

begin

  pll_inst: Gowin_rPLL
    port map (
      clkout => clk_x4,
      clkoutp => clk_ck,
      lock => pll_locked,
      clkoutd => clk32,
      clkin => clk
    );

  ddr3_controller_inst: ddr3_controller
    port map (
      pclk => clk32,
      fclk => clk_x4,
      ck => clk_ck,
      resetn => reset and pll_locked,
      rd => ddr3_rd,
      wr => ddr3_wr,
      refresh => ddr3_refresh,
      addr => std_logic_vector(c64_addr),
      din => ddr3_din,
      dout => ddr3_dout,
      data_ready => ddr3_data_ready,
      busy => ddr3_busy,
      DDR3_DQ => ddr3_dq,
      DDR3_DQS => ddr3_dqs_p,
      DDR3_A => ddr3_a(12 downto 0),
      DDR3_BA => ddr3_ba,
      DDR3_nRAS => ddr3_ras_n,
      DDR3_nCAS => ddr3_cas_n,
      DDR3_nWE => ddr3_we_n,
      DDR3_nCS => ddr3_cs_n,
      DDR3_CK => ddr3_ck_p,
      DDR3_CKE => ddr3_cke,
      DDR3_nRESET => ddr3_reset_n,
      DDR3_DM => ddr3_dm,
      DDR3_ODT => ddr3_odt,
      write_level_done => open,
      wstep => open,
      read_calib_done => open,
      rclkpos => open,
      rclksel => open,
      debug => open,
      dout128 => open
    );

  -- Memory interface bridge
  process(clk32)
  begin
    if rising_edge(clk32) then
      ddr3_rd <= '0';
      ddr3_wr <= '0';
      if ram_ce = '1' and ddr3_busy = '0' then
        if ram_we = '1' then
          ddr3_wr <= '1';
        else
          ddr3_rd <= '1';
        end if;
      end if;
    end if;
  end process;

  ddr3_din <= std_logic_vector(c64_data_out) & std_logic_vector(c64_data_out); -- 8 to 16 bit
  sdram_data <= unsigned(ddr3_dout(7 downto 0));

  -- Instantiate the C64 core
  fpga64_sid_iec_inst: entity work.fpga64_sid_iec
  port map
  (
    clk32        => clk32,
    reset_n      => reset,
    ramAddr      => c64_addr(15 downto 0),
    ramDin       => sdram_data,
    ramDout      => c64_data_out,
    ramCE        => ram_ce,
    ramWE        => ram_we,
    io_cycle     => open,
    ext_cycle    => open,
    refresh      => idle,
    ntscMode     => ntscMode,
    hsync        => hsync,
    vsync        => vsync,
    r            => r,
    g            => g,
    b            => b,
    audio_l      => audio_data_l,
    audio_r      => audio_data_r,
    joyA         => joyA,
    joyB         => joyB,
    pot1         => pot1,
    pot2         => pot2,
    pot3         => pot3,
    pot4         => pot4,
    bios         => "00",
    pause        => '0',
    pause_out    => open,
    usb_key      => (others => '0'),
    kbd_strobe   => '0',
    kbd_reset    => '0',
    shift_mod    => "00",
    cia_mode     => '0',
    turbo_mode   => "00",
    turbo_speed  => "00",
    vic_variant  => "00",
    phi          => open,
    phi2_p       => open,
    phi2_n       => open,
    game         => '0',
    exrom        => '0',
    io_rom       => '0',
    io_ext       => '0',
    io_data      => (others => '0'),
    irq_n        => '1',
    nmi_n        => '1',
    nmi_ack      => '0',
    romL         => '0',
    romH         => '0',
    UMAXromH     => '0',
    IO7          => '0',
    IOE          => '0',
    IOF          => '0',
    freeze_key   => '0',
    mod_key      => '0',
    tape_play    => '0',
    dma_req      => open,
    dma_cycle    => open,
    dma_addr     => (others => '0'),
    dma_dout     => (others => '0'),
    dma_din      => (others => '0'),
    dma_we       => '0',
    irq_ext_n    => '1',
    sid_filter   => "00",
    sid_ver      => "00",
    sid_mode     => "000",
    sid_cfg      => "0000",
    sid_fc_off_l => (others => '0'),
    sid_fc_off_r => (others => '0'),
    sid_ld_clk   => '0',
    sid_ld_addr  => (others => '0'),
    sid_ld_data  => (others => '0'),
    sid_ld_wr    => '0',
    sid_digifix  => '0',
    pb_i         => (others => '0'),
    std_logic_vector(pb_o) => open,
    pa2_i        => '0',
    pa2_o        => open,
    pc2_n_o      => open,
    flag2_n_i    => '0',
    sp2_i        => '0',
    sp2_o        => open,
    sp1_i        => '0',
    sp1_o        => open,
    cnt2_i       => '0',
    cnt2_o       => open,
    cnt1_i       => '0',
    cnt1_o       => open,
    iec_data_o   => open,
    iec_data_i   => '0',
    iec_clk_o    => open,
    iec_clk_i    => '0',
    iec_atn_o    => open,
    c64rom_addr  => (others => '0'),
    c64rom_data  => (others => '0'),
    c64rom_wr    => '0',
    cass_motor   => open,
    cass_write   => open,
    cass_sense   => '0',
    cass_read    => '0',
    debugX       => open,
    debugY       => open
  );

  idle <= '0';

end Behavioral_top;
