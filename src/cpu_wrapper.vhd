library ieee;
use ieee.std_logic_1164.all;

entity cpu_wrapper is
    port(
        i_clk  : in  std_logic;
        i_rst  : in  std_logic;
        o_leds : out std_logic_vector(7 downto 0)
    );
end entity;

architecture behave of cpu_wrapper is
    signal s_leds : std_logic_vector(31 downto 0);
begin
    cpu_inst : entity work.cpu
        generic map(g_rst_addr => (others => '0'))
        port map(i_clk => i_clk, i_rst => i_rst, o_leds => s_leds);

    o_leds <= s_leds(7 downto 0);
end architecture;
