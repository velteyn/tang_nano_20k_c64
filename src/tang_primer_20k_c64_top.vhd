-------------------------------------------------------------------------
--  C64 Top level for Tang Primer 20k
--  2025 Jules (Modified to use BRAM and enable C64 core)
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
    -- reset       : in std_logic; -- S2 button (Moved to internal reset)

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

    -- DDR3 Memory Interface (Unused, using BRAM)
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
  signal clk_mem : std_logic; -- 315MHz
  signal clk_ck : std_logic;
  signal clk32 : std_logic;
  
  attribute syn_keep : boolean;
  attribute syn_keep of clk_x4 : signal is true;
  attribute syn_keep of clk_mem : signal is true;
  attribute syn_keep of clk32 : signal is true;
  signal clk_ddr : std_logic;
  signal pll_locked : std_logic;
  
  -- Internal Reset
  signal reset_n_s : std_logic := '0';
  signal reset_cnt : unsigned(19 downto 0) := (others => '0');

  signal c64_addr : unsigned(15 downto 0);
  signal sdram_data : unsigned(7 downto 0);
  signal c64_data_out : unsigned(7 downto 0);
  signal ram_ce : std_logic;
  signal ram_we : std_logic;
  signal idle : std_logic;

  signal ntscMode : std_logic := '0'; -- PAL by default
  signal hsync : std_logic;
  signal vsync : std_logic;
  
  component CLKDIV
      generic (
          DIV_MODE : string := "2";
          GSREN : string := "false"
      );
      port (
          CLKOUT : out std_logic;
          HCLKIN : in std_logic;
          RESETN : in std_logic;
          CALIB : in std_logic
      );
  end component;
  signal r : unsigned(7 downto 0);
  signal g : unsigned(7 downto 0);
  signal b : unsigned(7 downto 0);
  signal audio_data_l : std_logic_vector(17 downto 0);
  signal audio_data_r : std_logic_vector(17 downto 0);
  signal joyA : std_logic_vector(6 downto 0) := (others => '0');
  signal joyB : std_logic_vector(6 downto 0) := (others => '0');
  signal pot1 : std_logic_vector(7 downto 0) := (others => '0');
  signal pot2 : std_logic_vector(7 downto 0) := (others => '0');
  signal pot3 : std_logic_vector(7 downto 0) := (others => '0');
  signal pot4 : std_logic_vector(7 downto 0) := (others => '0');

  signal nmi_ack_s : std_logic;
  signal romL_s : std_logic;
  signal romH_s : std_logic;
  signal UMAXromH_s : std_logic;
  signal IO7_s : std_logic;
  signal IOE_s : std_logic;
  signal IOF_s : std_logic;
  signal freeze_key_s : std_logic;
  signal mod_key_s : std_logic;
  signal tape_play_s : std_logic;
  signal dma_din_s : unsigned(7 downto 0);
  signal dma_addr_s : unsigned(15 downto 0);
  signal dma_dout_s : unsigned(7 downto 0);
  signal pb_o_s : unsigned(7 downto 0);
  
  signal audio_div : unsigned(8 downto 0);
  signal osd_status : std_logic;

  component Gowin_rPLL_Primer is
    port (
        clkout: out std_logic;
        clkoutp: out std_logic;
        lock: out std_logic;
        clkoutd: out std_logic;
        clkin: in std_logic
    );
  end component;

  component video is
    port (
      clk: in std_logic;
      clk_pixel_x5: in std_logic;
      pll_lock: in std_logic;
      audio_div: in unsigned(8 downto 0);
      ntscmode: in std_logic;
      vs_in_n: in std_logic;
      hs_in_n: in std_logic;
      r_in: in unsigned(3 downto 0);
      g_in: in unsigned(3 downto 0);
      b_in: in unsigned(3 downto 0);
      audio_l: in std_logic_vector(17 downto 0);
      audio_r: in std_logic_vector(17 downto 0);
      osd_status: out std_logic;
      mcu_start: in std_logic;
      mcu_osd_strobe: in std_logic;
      mcu_data: in std_logic_vector(7 downto 0);
      system_scanlines: in std_logic_vector(1 downto 0);
      system_volume: in std_logic_vector(1 downto 0);
      system_wide_screen: in std_logic;
      tmds_clk_n: out std_logic;
      tmds_clk_p: out std_logic;
      tmds_d_n: out std_logic_vector(2 downto 0);
      tmds_d_p: out std_logic_vector(2 downto 0)
    );
  end component;

  -- 64K Block RAM for C64 Main Memory
  component ram64k is
    port (
        clk     : in  std_logic;
        ce      : in  std_logic;
        we      : in  std_logic;
        addr    : in  unsigned(15 downto 0);
        din     : in  unsigned(7 downto 0);
        dout    : out unsigned(7 downto 0)
    );
  end component;

begin

  -- Unused DDR3 pins
  ddr3_ck_n <= '0';
  ddr3_ck_p <= '0';
  ddr3_cke <= '0';
  ddr3_cs_n <= '1';
  ddr3_ras_n <= '1';
  ddr3_cas_n <= '1';
  ddr3_we_n <= '1';
  ddr3_reset_n <= '0';
  ddr3_odt <= '0';
  ddr3_a <= (others => '0');
  ddr3_ba <= (others => '0');
  ddr3_dm <= (others => '0');
  ddr3_dq <= (others => 'Z');
  ddr3_dqs_p <= (others => 'Z');
  ddr3_dqs_n <= (others => 'Z');

  pll_inst: Gowin_rPLL_Primer
    port map (
      clkout => clk_mem, -- ~317MHz
      clkoutp => clk_ck,
      lock => pll_locked,
      clkoutd => clk_x4, -- ~158MHz (SDIV=2)
      clkin => clk
    );
    
  -- Video Clock Divider (Divide by 5 for 157.5MHz -> 31.5MHz)
  u_clkdiv_video: CLKDIV
    generic map (
        DIV_MODE => "5",
        GSREN => "false"
    )
    port map (
        CLKOUT => clk32,
        HCLKIN => clk_x4,
        RESETN => pll_locked,
        CALIB => '0'
    );

  -- Internal Reset Logic
  process(clk32)
  begin
    if rising_edge(clk32) then
      if pll_locked = '0' then
        reset_cnt <= (others => '0');
        reset_n_s <= '0';
      else
        if reset_cnt /= x"FFFFF" then
          reset_cnt <= reset_cnt + 1;
          reset_n_s <= '0';
        else
          reset_n_s <= '1';
        end if;
      end if;
    end if;
  end process;

  -- Instantiate C64 Core
  c64_core: entity work.fpga64_sid_iec
  generic map (
    DUAL => DUAL
  )
  port map (
    clk32        => clk32,
    reset_n      => reset_n_s,
    bios         => "00",
    pause        => '0',
    pause_out    => open,

    -- Keyboard
    usb_key      => (others => '0'),
    kbd_strobe   => '0',
    kbd_reset    => '0',
    shift_mod    => "00",

    -- External Memory (connected to BRAM)
    ramAddr      => c64_addr,
    ramDin       => sdram_data,
    ramDout      => c64_data_out,
    ramCE        => ram_ce,
    ramWE        => ram_we,
    io_cycle     => open,
    ext_cycle    => open,
    refresh      => idle,

    cia_mode     => '0',
    turbo_mode   => "00",
    turbo_speed  => "00",

    vic_variant  => "00",
    ntscMode     => ntscMode,
    hsync        => hsync,
    vsync        => vsync,
    r            => r,
    g            => g,
    b            => b,
    debugX       => open,
    debugY       => open,

    phi          => open,
    phi2_p       => open,
    phi2_n       => open,

    game         => '1',
    exrom        => '1',
    io_rom       => '1',
    io_ext       => '0',
    io_data      => (others => '0'),
    irq_n        => '1',
    nmi_n        => '1',
    nmi_ack      => nmi_ack_s,
    romL         => romL_s,
    romH         => romH_s,
    UMAXromH     => UMAXromH_s,
    IO7          => IO7_s,
    IOE          => IOE_s,
    IOF          => IOF_s,
    freeze_key   => freeze_key_s,
    mod_key      => mod_key_s,
    tape_play    => tape_play_s,

    -- DMA
    dma_req      => '0',
    dma_cycle    => open,
    dma_addr     => (others => '0'),
    dma_dout     => (others => '0'),
    dma_din      => dma_din_s,
    dma_we       => '0',
    irq_ext_n    => '1',

    -- Joystick
    joyA         => joyA,
    joyB         => joyB,
    pot1         => pot1,
    pot2         => pot2,
    pot3         => pot3,
    pot4         => pot4,

    -- SID
    audio_l      => audio_data_l,
    audio_r      => audio_data_r,
    sid_filter   => "11",
    sid_ver      => "00",
    sid_mode     => "000",
    sid_cfg      => "1111",
    sid_fc_off_l => (others => '0'),
    sid_fc_off_r => (others => '0'),
    sid_ld_clk   => clk32,
    sid_ld_addr  => (others => '0'),
    sid_ld_data  => (others => '0'),
    sid_ld_wr    => '0',
    sid_digifix  => '0',

    -- User Port
    pb_i         => (others => '1'),
    pb_o         => pb_o_s,
    pa2_i        => '1',
    pa2_o        => open,
    pc2_n_o      => open,
    flag2_n_i    => '1',
    sp2_i        => '1',
    sp2_o        => open,
    sp1_i        => '1',
    sp1_o        => open,
    cnt2_i       => '1',
    cnt2_o       => open,
    cnt1_i       => '1',
    cnt1_o       => open,

    -- IEC
    iec_data_o   => open,
    iec_data_i   => '1',
    iec_clk_o    => open,
    iec_clk_i    => '1',
    iec_atn_o    => open,

    -- ROM Loading (Disabled, using initialized internal ROMs)
    c64rom_addr  => (others => '0'),
    c64rom_data  => (others => '0'),
    c64rom_wr    => '0',

    cass_motor   => open,
    cass_write   => open,
    cass_sense   => '1',
    cass_read    => '1'
  );

  -- Instantiate 64K BRAM
  ram_inst: ram64k
  port map (
    clk     => clk32, -- Using same clock as core
    ce      => ram_ce,
    we      => ram_we,
    addr    => c64_addr,
    din     => c64_data_out,
    dout    => sdram_data
  );

  video_inst: video
  port map (
    clk => clk32,
    clk_pixel_x5 => clk_x4, -- 157.5MHz
    pll_lock => pll_locked,
    audio_div => audio_div,
    ntscmode => ntscMode,
    vs_in_n => vsync,
    hs_in_n => hsync,
    r_in => r(7 downto 4),
    g_in => g(7 downto 4),
    b_in => b(7 downto 4),
    audio_l => audio_data_l, -- Connected Audio
    audio_r => audio_data_r,
    osd_status => osd_status,
    mcu_start => '0',
    mcu_osd_strobe => '0',
    mcu_data => (others => '0'),
    system_scanlines => "00", 
    system_volume => "00", 
    system_wide_screen => '0',
    tmds_clk_n => tmds_clk_n,
    tmds_clk_p => tmds_clk_p,
    tmds_d_n => tmds_d_n,
    tmds_d_p => tmds_d_p
  );

  audio_div <= to_unsigned(327,9); -- PAL value
  leds_n(0) <= not pll_locked;
  leds_n(1) <= '1';
  uart_tx <= '1';
  
end Behavioral_top;
