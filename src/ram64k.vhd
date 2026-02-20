library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ram64k is
    port (
        clk     : in  std_logic;
        ce      : in  std_logic;
        we      : in  std_logic;
        addr    : in  unsigned(15 downto 0);
        din     : in  unsigned(7 downto 0);
        dout    : out unsigned(7 downto 0)
    );
end entity ram64k;

architecture rtl of ram64k is
    type ram_type is array (0 to 65535) of unsigned(7 downto 0);
    signal ram : ram_type := (others => (others => '0'));
    
    -- Attribute to force Block RAM usage in Gowin
    attribute syn_ramstyle : string;
    attribute syn_ramstyle of ram : signal is "block_ram";
begin

    process(clk)
    begin
        if rising_edge(clk) then
            if ce = '1' then
                if we = '1' then
                    ram(to_integer(addr)) <= din;
                end if;
                dout <= ram(to_integer(addr));
            end if;
        end if;
    end process;

end architecture rtl;
