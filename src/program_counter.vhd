library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pc is
    generic(
        g_rst_addr : std_logic_vector(31 downto 0) := (others => '0')
    );
    port(
        i_clk       : in  std_logic;
        i_rst       : in  std_logic;
        i_en        : in  std_logic;
        i_load      : in  std_logic;
        i_load_addr : in  std_logic_vector(31 downto 0);
        o_pc        : out std_logic_vector(31 downto 0); 
        o_pc_next   : out std_logic_vector(31 downto 0)
    );
end entity;

architecture behave of pc is
    signal s_pc_state     : unsigned(31 downto 0) := unsigned(g_rst_addr);
    signal s_pc_next      : unsigned(31 downto 0);
    signal s_aligned_addr : unsigned(31 downto 0);
begin

    -- increment by 4
    s_pc_next <= s_pc_state + 4;

    -- alignment: force lowest 2 bits to 0
    s_aligned_addr <= unsigned(i_load_addr(31 downto 2) & "00");

    process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                s_pc_state <= unsigned(g_rst_addr);
            elsif i_load = '1' then
                s_pc_state <= s_aligned_addr;
            elsif i_en = '1' then
                s_pc_state <= s_pc_next;
            end if;
        end if;
    end process;

    o_pc      <= std_logic_vector(s_pc_state);
    o_pc_next <= std_logic_vector(s_pc_next);

end architecture;
