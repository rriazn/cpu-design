library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use ieee.std_logic_textio.all;
use std.textio.all;

entity instr_mem is
    generic(
        G_NUM_WORDS  : integer := 256;
        CACHE_LINE_WIDTH : integer := 64
    );
    port(
        i_clk       : in  std_logic;
        i_addr      : in  std_logic_vector(31 downto 0);
        i_wr_data   : in  std_logic_vector(CACHE_LINE_WIDTH - 1 downto 0);
        i_wr_en     : in  std_logic;   -- 1: write, 0: read
        i_valid     : in  std_logic;   -- request valid (from cache)
        o_ready     : out std_logic;   -- memory finished the request
        o_rd_data   : out std_logic_vector(CACHE_LINE_WIDTH - 1 downto 0)
    );
end entity;

architecture behave of instr_mem is
    constant C_WORDS_PER_LINE : integer := CACHE_LINE_WIDTH / 32;
    constant C_OFFSET_BITS    : integer := integer(ceil(log2(real(C_WORDS_PER_LINE)))); -- word-select bits
    constant C_INDEX_BITS     : integer := integer(ceil(log2(real(G_NUM_WORDS))));      -- line-select bits

    type t_data_mem is array (G_NUM_WORDS-1 downto 0) of std_logic_vector(CACHE_LINE_WIDTH-1 downto 0);
    impure function init_from_file return t_data_mem is
        file f_mem_file: text open read_mode is "fibo_hex.mem";
        variable v_file_line: line;
        variable v_word: std_logic_vector(31 downto 0);
        variable v_tmp_ram: t_data_mem := (others => (others => '0'));
        constant C_WORDS_PER_LINE : integer := CACHE_LINE_WIDTH / 32;
        variable v_line_idx : integer := 0;   -- which cache line (row)
        variable v_word_idx : integer := 0;   -- which word within the current line
    begin
        while not endfile(f_mem_file) and v_line_idx < G_NUM_WORDS loop
            readline(f_mem_file, v_file_line);
            hread(v_file_line, v_word);
            -- Place word v_word_idx into its slice of the current line.
            -- Word 0 -> low 32 bits, word 1 -> next 32 bits, ...
            v_tmp_ram(v_line_idx)((v_word_idx+1)*32 - 1 downto v_word_idx*32) := v_word;

            if v_word_idx = C_WORDS_PER_LINE - 1 then
                v_word_idx := 0;
                v_line_idx := v_line_idx + 1;
            else
                v_word_idx := v_word_idx + 1;
            end if;
        end loop;
        return v_tmp_ram;
    end function;
    signal s_mem: t_data_mem := init_from_file;
begin
    process(i_clk)
        variable v_idx : integer;
    begin
        if rising_edge(i_clk) then
            o_ready <= '0';
            -- skip the 2 byte-align bits AND the C_OFFSET_BITS word-select bits
            v_idx := to_integer(unsigned(
                       i_addr(C_INDEX_BITS + C_OFFSET_BITS + 1 downto C_OFFSET_BITS + 2)));
            if i_valid = '1' then
                if i_wr_en = '1' then
                    s_mem(v_idx) <= i_wr_data;
                else
                    o_rd_data <= s_mem(v_idx);
                end if;
                o_ready <= '1';
            end if;
        end if;
    end process;
end architecture;