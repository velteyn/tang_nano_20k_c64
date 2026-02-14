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
  signal clk_mem : std_logic; -- 315MHz for DDR3
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

  -- DDR3 Reset Synchronization
  signal ddr3_rst_sync1 : std_logic := '0';
  signal ddr3_rst_sync2 : std_logic := '0';
  signal ddr3_reset_n_sync : std_logic := '0';

  signal c64_addr : unsigned(26 downto 0);
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

  -- CDC Signals
  signal req_toggle : std_logic := '0';
  signal ack_toggle : std_logic := '0';
  signal ack_sync1, ack_sync2 : std_logic := '0';
  signal req_sync1, req_sync2 : std_logic := '0';
  signal req_prev : std_logic := '0';
  
  signal ddr_cmd_reg : std_logic; -- 0:Read, 1:Write
  signal ddr_addr_reg : std_logic_vector(26 downto 0);
  signal ddr_din_reg : std_logic_vector(15 downto 0);
  signal ddr_dout_reg : std_logic_vector(15 downto 0);
  
  signal mem_busy : std_logic := '0';
   
   type cdc_state_t is (S_IDLE, S_ISSUE, S_WAIT_READ, S_WAIT_WRITE);
   signal cdc_state : cdc_state_t := S_IDLE;
 
   signal ntscMode : std_logic;
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
  signal joyA : std_logic_vector(6 downto 0);
  signal joyB : std_logic_vector(6 downto 0);
  signal pot1 : std_logic_vector(7 downto 0);
  signal pot2 : std_logic_vector(7 downto 0);
  signal pot3 : std_logic_vector(7 downto 0);
  signal pot4 : std_logic_vector(7 downto 0);

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

  component ddr3_controller is
    generic (
      ROW_WIDTH: integer := 14;
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
      addr: in std_logic_vector(26 downto 0);
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

begin

  -- DDR3 Clock Output
  ddr3_ck_n <= not ddr3_ck_p;

  pll_inst: Gowin_rPLL_Primer
    port map (
      clkout => clk_mem, -- ~317MHz
      clkoutp => clk_ck,
      lock => pll_locked,
      clkoutd => clk_x4, -- ~158MHz (SDIV=2)
      clkin => clk
    );
    
    -- clk_x4 <= clk_mem; -- Removed alias, now separate output

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

  u_clkdiv: CLKDIV
    generic map (
        DIV_MODE => "4"
    )
    port map (
        CLKOUT => clk_ddr,
        HCLKIN => clk_mem,
        RESETN => pll_locked,
        CALIB => '0'
    );

  -- Synchronize reset to clk_mem domain for DDR3 controller
  process(clk_mem)
  begin
    if rising_edge(clk_mem) then
      ddr3_rst_sync1 <= reset_n_s and pll_locked;
      ddr3_rst_sync2 <= ddr3_rst_sync1;
      ddr3_reset_n_sync <= ddr3_rst_sync2;
    end if;
  end process;

  -- DDR3 Controller - DISABLED FOR VIDEO TEST
  -- ddr3_controller_inst: ddr3_controller
  --   generic map (
  --     ROW_WIDTH => 14
  --   )
  --   port map (
  --     pclk => clk_ddr,
  --     fclk => clk_mem,
  --     ck => clk_ck,
  --     resetn => ddr3_reset_n_sync,
  --     rd => ddr3_rd,
  --     wr => ddr3_wr,
  --     refresh => ddr3_refresh,
  --     addr => ddr_addr_reg,
  --     din => ddr_din_reg,
  --     dout => ddr3_dout,
  --     data_ready => ddr3_data_ready,
  --     busy => ddr3_busy,
  --     DDR3_DQ => ddr3_dq,
  --     DDR3_DQS => ddr3_dqs_p,
  --     DDR3_A => ddr3_a,
  --     DDR3_BA => ddr3_ba,
  --     DDR3_nRAS => ddr3_ras_n,
  --     DDR3_nCAS => ddr3_cas_n,
  --     DDR3_nWE => ddr3_we_n,
  --     DDR3_nCS => ddr3_cs_n,
  --     DDR3_CK => ddr3_ck_p,
  --     DDR3_CKE => ddr3_cke,
  --     DDR3_nRESET => ddr3_reset_n,
  --     DDR3_DM => ddr3_dm,
  --     DDR3_ODT => ddr3_odt,
  --     write_level_done => open,
  --     wstep => open,
  --     read_calib_done => open,
  --     rclkpos => open,
  --     rclksel => open,
  --     debug => open,
  --     dout128 => open
  --   );

  -- TEST PATTERN GENERATOR
  -- Simple PAL-ish timing for 31.5MHz pixel clock
  -- Line: 2016 clocks (15.625 kHz)
  -- Frame: 625 lines (50 Hz)
  
  process(clk32)
    variable h_cnt : integer range 0 to 2047 := 0;
    variable v_cnt : integer range 0 to 1023 := 0;
  begin
    if rising_edge(clk32) then
       h_cnt := h_cnt + 1;
       if h_cnt = 2016 then
          h_cnt := 0;
          v_cnt := v_cnt + 1;
          if v_cnt = 312 then
             v_cnt := 0;
          end if;
       end if;
       
       -- Sync Generation (Active Low)
       -- HS: Start of line. Width ~150 clocks.
       if h_cnt < 150 then
          hsync <= '0';
       else
          hsync <= '1';
       end if;
       
       -- VS: Start of frame. Width ~3 lines (6048 clocks).
       if v_cnt < 3 then
          vsync <= '0';
       else
          vsync <= '1';
       end if;
       
       -- White Square
       if (h_cnt > 800 and h_cnt < 1200) and (v_cnt > 200 and v_cnt < 400) then
          r <= (others => '1');
          g <= (others => '1');
          b <= (others => '1');
       else
          r <= (others => '0');
          g <= (others => '0');
          b <= (others => '0');
       end if;
    end if;
  end process;

  video_inst: video
  port map (
    clk => clk32,
    clk_pixel_x5 => clk_x4, -- 157.5MHz
    pll_lock => pll_locked,
    audio_div => audio_div,
    ntscmode => '0', -- Force PAL for test
    vs_in_n => vsync, -- Driven by TPG
    hs_in_n => hsync, -- Driven by TPG
    r_in => r(7 downto 4), -- Driven by TPG
    g_in => g(7 downto 4),
    b_in => b(7 downto 4),
    audio_l => (others => '0'), -- Mute audio
    audio_r => (others => '0'),
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

  -- Missing assignments restored
  audio_div <= to_unsigned(327,9); -- PAL value
  leds_n(0) <= not pll_locked;
  leds_n(1) <= '1';
  uart_tx <= '1';
  
end Behavioral_top;
