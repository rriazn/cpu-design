library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity data_mem is
    generic(
        G_WORD_WIDTH : integer := 32;
        G_NUM_WORDS   : integer := 256
    );
    port(
        i_clk       : in std_logic;
        i_addr   : in std_logic_vector(31 downto 0);
        i_wr_data   : in std_logic_vector(31 downto 0);
        i_wr_en     : in std_logic;
        i_rd_en     : in std_logic;
        i_global_en : in std_logic;
        o_rd_data   : out std_logic_vector(31 downto 0)
    );
end entity;


architecture behave of data_mem is
    type t_data_mem is array (G_NUM_WORDS-1 downto 0) of std_logic_vector(G_WORD_WIDTH-1 downto 0);
    signal s_mem: t_data_mem := (others => (others => '0'));
    constant C_ADDR_WIDTH : integer := integer(ceil(log2(real(G_NUM_WORDS))));
begin
    process(i_clk)
    begin 
        if rising_edge(i_clk) then
            if i_global_en = '1' then
                if i_wr_en = '1' then
                    s_mem(to_integer(unsigned(i_addr(C_ADDR_WIDTH+1 downto 2)))) <= i_wr_data;
                end if;
                
                if i_rd_en = '1' then
                        o_rd_data <= s_mem(to_integer(unsigned(i_addr(C_ADDR_WIDTH+1 downto 2))));
                end if;
            end if;       
        end if;
    end process;
end architecture;