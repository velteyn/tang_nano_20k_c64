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
  signal clk_ck : std_logic;
  signal clk32 : std_logic;
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

  pll_inst: Gowin_rPLL
    port map (
      clkout => clk_x4,
      clkoutp => clk_ck,
      lock => pll_locked,
      clkoutd => clk32,
      clkin => clk
    );

  u_clkdiv: CLKDIV
    generic map (
        DIV_MODE => "4"
    )
    port map (
        CLKOUT => clk_ddr,
        HCLKIN => clk_x4,
        RESETN => pll_locked,
        CALIB => '0'
    );

  -- Synchronize reset to clk_x4 domain for DDR3 controller
  process(clk_x4)
  begin
    if rising_edge(clk_x4) then
      ddr3_rst_sync1 <= reset_n_s and pll_locked;
      ddr3_rst_sync2 <= ddr3_rst_sync1;
      ddr3_reset_n_sync <= ddr3_rst_sync2;
    end if;
  end process;

  ddr3_controller_inst: ddr3_controller
    generic map (
      ROW_WIDTH => 14
    )
    port map (
      pclk => clk_ddr,
      fclk => clk_x4,
      ck => clk_ck,
      resetn => ddr3_reset_n_sync,
      rd => ddr3_rd,
      wr => ddr3_wr,
      refresh => ddr3_refresh,
      addr => ddr_addr_reg,
      din => ddr_din_reg,
      dout => ddr3_dout,
      data_ready => ddr3_data_ready,
      busy => ddr3_busy,
      DDR3_DQ => ddr3_dq,
      DDR3_DQS => ddr3_dqs_p,
      DDR3_A => ddr3_a,
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

  -- Memory interface bridge (CDC)
  
  -- Master Process (clk32 domain)
  process(clk32)
  begin
    if rising_edge(clk32) then
       -- Internal Reset Generation
       if reset_cnt < "11111111111111111111" then
          reset_cnt <= reset_cnt + 1;
          reset_n_s <= '0';
       else
          reset_n_s <= '1';
       end if;

      -- Sync ack from DDR domain
      ack_sync1 <= ack_toggle;
      ack_sync2 <= ack_sync1;

      if mem_busy = '0' then
        if ram_ce = '1' then
          -- Start transaction
          mem_busy <= '1';
          ddr_addr_reg <= std_logic_vector(c64_addr);
          ddr_din_reg <= std_logic_vector(c64_data_out) & std_logic_vector(c64_data_out);
          if ram_we = '1' then
             ddr_cmd_reg <= '1'; -- Write
          else
             ddr_cmd_reg <= '0'; -- Read
          end if;
          req_toggle <= not req_toggle;
        end if;
      else
        -- Wait for ack
        if ack_sync2 = req_toggle then
          mem_busy <= '0';
          if ddr_cmd_reg = '0' then -- Read
             sdram_data <= unsigned(ddr_dout_reg(7 downto 0));
          end if;
        end if;
      end if;
    end if;
  end process;

  -- Slave Process (clk_ddr domain)
  process(clk_ddr)
  begin
    if rising_edge(clk_ddr) then
      -- Sync req from Master domain
      req_sync1 <= req_toggle;
      req_sync2 <= req_sync1;
      
      ddr3_rd <= '0';
      ddr3_wr <= '0';
      
      case cdc_state is
        when S_IDLE =>
          if req_sync2 /= req_prev then
             cdc_state <= S_ISSUE;
          end if;
          
        when S_ISSUE =>
          if ddr3_busy = '0' then
             if ddr_cmd_reg = '1' then
                ddr3_wr <= '1';
                -- Write: Ack immediately (fire and forget)
                ack_toggle <= not ack_toggle;
                req_prev <= req_sync2;
                cdc_state <= S_IDLE;
             else
                ddr3_rd <= '1';
                cdc_state <= S_WAIT_READ;
             end if;
          end if;
          
        when S_WAIT_READ =>
          if ddr3_data_ready = '1' then
             ddr_dout_reg <= ddr3_dout;
             ack_toggle <= not ack_toggle;
             req_prev <= req_sync2;
             cdc_state <= S_IDLE;
          end if;
          
        when S_WAIT_WRITE =>
           cdc_state <= S_IDLE;
      end case;
    end if;
  end process;

  -- Instantiate the C64 core
  -- UART driver
  uart_tx <= '1';
  
  -- Drive unused upper address bits
  c64_addr(26 downto 16) <= (others => '0');
  
  -- Default values for unused inputs
  ntscMode <= '0'; -- PAL
  joyA <= (others => '1'); -- Released (Active Low)
  joyB <= (others => '1');
  pot1 <= (others => '0');
  pot2 <= (others => '0');
  pot3 <= (others => '0');
  pot4 <= (others => '0');
  
  -- Unused ports
  m0s <= (others => 'Z');
  sd_clk <= '0';
  sd_cmd <= 'Z';
  sd_dat <= (others => 'Z');

  audio_div  <= to_unsigned(342,9) when ntscMode = '1' else to_unsigned(327,9);
  leds_n(0) <= not pll_locked; -- LED on when PLL is locked (if active low)
  leds_n(1) <= '1'; -- Off

  fpga64_sid_iec_inst: entity work.fpga64_sid_iec
  port map
  (
    clk32        => clk32,
    reset_n      => reset_n_s,
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
    
    -- audio_data   => audio_data_l(17 downto 2),
    -- audio_data   => open,
    
    -- USER
    pb_i => (others => '0'),
    pb_o => open,
    pa2_i => '0',
    pa2_o => open,
    pc2_n_o => open,
    flag2_n_i => '0',
    sp2_i => '0',
    sp2_o => open,
    sp1_i => '0',
    sp1_o => open,
    cnt2_i => '0',
    cnt2_o => open,
    cnt1_i => '0',
    cnt1_o => open,

    -- IEC
    iec_data_o => open,
    iec_data_i => '0',
    iec_clk_o => open,
    iec_clk_i => '0',
    iec_atn_o => open,

    c64rom_addr => (others => '0'),
    c64rom_data => (others => '0'),
    c64rom_wr => '0',

    cass_motor => open,
    cass_write => open,
    cass_sense => '0',
    cass_read => '0',

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
    dma_req      => '0',
    dma_cycle    => open,
    dma_addr     => dma_addr_s,
    dma_dout     => dma_dout_s,
    dma_din      => dma_din_s,
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
    debugX       => open,
    debugY       => open
  );

  video_inst: video
  port map (
    clk => clk32,
    clk_pixel_x5 => clk_x4, -- 160MHz
    pll_lock => pll_locked,
    audio_div => audio_div,
    ntscmode => ntscMode,
    vs_in_n => vsync, -- Check polarity
    hs_in_n => hsync, -- Check polarity
    r_in => r_in_s,
    g_in => g_in_s,
    b_in => b_in_s,
    audio_l => audio_data_l,
    audio_r => audio_data_r,
    osd_status => osd_status,
    mcu_start => '0',
    mcu_osd_strobe => '0',
    mcu_data => (others => '0'),
    system_scanlines => "00", -- Default no scanlines? Or "01"?
    system_volume => "01", -- Enable volume to prevent audio logic sweeping
    system_wide_screen => '0',
    tmds_clk_n => tmds_clk_n,
    tmds_clk_p => tmds_clk_p,
    tmds_d_n => tmds_d_n,
    tmds_d_p => tmds_d_p
  );

end Behavioral_top;
