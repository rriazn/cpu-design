library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_cpu is
end entity;

architecture tb of tb_cpu is
    signal clk : std_logic := '0';
    signal rst : std_logic := '1';
    signal leds: std_logic_vector(7 downto 0);

    constant CLK_PERIOD : time := 10 ns;
begin
    uut: entity work.cpu_wrapper
        port map(i_clk => clk, i_rst => rst, o_leds => leds);

    clk_proc: process
    begin
        while now < 2000 ns loop
            clk <= '0';
            wait for CLK_PERIOD/2;
            clk <= '1';
            wait for CLK_PERIOD/2;
        end loop;
        wait;
    end process;

    rst_proc: process
    begin
        rst <= '1';
        wait for 25 ns;
        rst <= '0';
        wait;
    end process;

end architecture;
