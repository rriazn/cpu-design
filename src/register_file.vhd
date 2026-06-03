library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity register_file is
    generic(
       G_DATA_WIDTH : integer := 32;
       G_NUM_REGS : integer := 32
    );
    port(
        i_clk           : in std_logic;
        i_rst           : in std_logic;
        i_wr_en         : in std_logic;
        i_wr_data       : in std_logic_vector(G_DATA_WIDTH-1 downto 0);
        i_wr_addr       : in std_logic_vector(integer(ceil(log2(real(G_NUM_REGS))))-1 downto 0);
        i_rd_addr_1     : in std_logic_vector(integer(ceil(log2(real(G_NUM_REGS))))-1 downto 0);
        i_rd_addr_2     : in std_logic_vector(integer(ceil(log2(real(G_NUM_REGS))))-1 downto 0);
        o_rd_data_1     : out std_logic_vector(G_DATA_WIDTH-1 downto 0);
        o_rd_data_2     : out std_logic_vector(G_DATA_WIDTH-1 downto 0)
    );
end entity;

architecture behave of register_file is
    type t_register_array is array (G_NUM_REGS-1 downto 0) of std_logic_vector(G_DATA_WIDTH-1 downto 0);
    signal s_register: t_register_array := (others => (others => '0'));
begin
    
    o_rd_data_1 <= (others => '0') when is_x(i_rd_addr_1) or unsigned(i_rd_addr_1) = 0 else s_register(to_integer(unsigned(i_rd_addr_1)));
    o_rd_data_2 <= (others => '0') when is_x(i_rd_addr_2) or unsigned(i_rd_addr_2) = 0 else s_register(to_integer(unsigned(i_rd_addr_2)));
    
    process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                s_register <= (others => (others => '0'));
            elsif i_wr_en = '1' then
                if unsigned(i_wr_addr) /= 0 then
                    s_register(to_integer(unsigned(i_wr_addr))) <= i_wr_data;
                end if;
            end if;
        end if;
    end process;
end architecture;