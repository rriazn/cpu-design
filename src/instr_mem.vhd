library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use ieee.std_logic_textio.all;
use std.textio.all;

entity instr_mem is
    generic(
        G_WORD_WIDTH : integer := 32;
        G_NUM_WORDS   : integer := 256
    );
    port(
        i_clk       : in std_logic;
        i_addr   : in std_logic_vector(31 downto 0);
        i_global_en : in std_logic;
        o_rd_data   : out std_logic_vector(31 downto 0)
    );
end entity;


architecture behave of instr_mem is
    type t_data_mem is array (G_NUM_WORDS-1 downto 0) of std_logic_vector(G_WORD_WIDTH-1 downto 0);
	
	impure function init_from_file return t_data_mem is

        file f_mem_file: text open read_mode is "fibo_hex.mem";

        variable v_file_line: line;

        variable v_tmp_ram: t_data_mem := (others => (others => '0'));
        variable v_index : integer := 0;

    begin

        while not endfile(f_mem_file) and v_index < G_NUM_WORDS loop

            readline(f_mem_file, v_file_line);
            

            hread(v_file_line, v_tmp_ram(v_index));
            v_index := v_index + 1;

        end loop;

        return v_tmp_ram;

    end function;

    signal s_mem: t_data_mem := init_from_file;
    constant C_ADDR_WIDTH : integer := integer(ceil(log2(real(G_NUM_WORDS))));
begin
    process(i_clk)
    begin 
        if rising_edge(i_clk) then
            if i_global_en = '1' then
                o_rd_data <= s_mem(to_integer(unsigned(i_addr(C_ADDR_WIDTH+1 downto 2))));
            end if;       
        end if;
    end process;
end architecture;