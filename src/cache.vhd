library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use ieee.math_real.all;

entity cache is
    generic(
        C_NUM_LINES      : integer := 16;
        CACHE_LINE_WIDTH : integer := 32
    );
    port(
        i_clk       : in  std_logic;
        i_rst       : in  std_logic;
        i_flush     : in  std_logic;   -- taken branch: drop a wrong-path fetch
        i_valid     : in  std_logic;
        i_address   : in  std_logic_vector(31 downto 0);
        o_valid     : out std_logic;
        o_ready     : out std_logic;

        o_mem_valid : out std_logic;
        o_mem_addr  : out std_logic_vector(31 downto 0);
        i_mem_data  : in  std_logic_vector(CACHE_LINE_WIDTH - 1 downto 0);
        i_mem_ready : in  std_logic;

        o_data      : out std_logic_vector(31 downto 0)
    );
end cache;

architecture Behavioral of cache is

    constant C_INDEX_BITS  : integer := integer(ceil(log2(real(C_NUM_LINES))));
    constant C_OFFSET_BITS : integer := integer(ceil(log2(real(CACHE_LINE_WIDTH / 8))));
    constant C_TAG_BITS    : integer := 32 - C_INDEX_BITS - C_OFFSET_BITS;

    type t_data_ram is array (0 to C_NUM_LINES-1)
        of std_logic_vector(CACHE_LINE_WIDTH - 1 downto 0);
    type t_tag_ram  is array (0 to C_NUM_LINES-1)
        of std_logic_vector(C_TAG_BITS - 1 downto 0);

    -- data array in BRAM
    signal data_ram : t_data_ram;
    attribute ram_style : string;
    attribute ram_style of data_ram : signal is "block";

    -- tag array in registers
    signal tag_ram    : t_tag_ram := (others => (others => '0'));
    signal valid_bits : std_logic_vector(C_NUM_LINES-1 downto 0) := (others => '0');

    -- address fields
    signal s_tag    : std_logic_vector(C_TAG_BITS-1 downto 0);
    signal s_index  : integer range 0 to C_NUM_LINES-1;
    signal s_offset : std_logic_vector(C_OFFSET_BITS - 3 downto 0);

    signal s_hit : std_logic;

    -- BRAM data read port
    signal data_q : std_logic_vector(CACHE_LINE_WIDTH - 1 downto 0);

    -- info handed from stage 1 to stage 2
    signal hit_reg    : std_logic := '0';
    signal miss_reg   : std_logic := '0';
    signal offset_reg : std_logic_vector(C_OFFSET_BITS - 3 downto 0);
    signal index_reg  : integer range 0 to C_NUM_LINES-1;
    signal tag_reg    : std_logic_vector(C_TAG_BITS - 1 downto 0);

    -- high while a stage 2 miss still has no data from memory
    signal s_wait : std_logic;

    -- line address of the miss that sits in stage 2
    signal s_miss_addr : std_logic_vector(31 downto 0);

begin

    -- split address into tag, index and word offset
    s_tag    <= i_address(31 downto 32 - C_TAG_BITS);
    s_index  <= to_integer(unsigned(i_address(32 - C_TAG_BITS - 1 downto C_OFFSET_BITS)));
    s_offset <= i_address(C_OFFSET_BITS - 1 downto 2);

    -- stage 1 hit check reads flop tag array so it is ready at once
    s_hit <= '1' when i_valid = '1'
                  and valid_bits(s_index) = '1'
                  and tag_ram(s_index) = s_tag
             else '0';

    -- keep waiting while the stage 2 miss has no answer yet
    s_wait <= '1' when (miss_reg = '1' and i_mem_ready = '0') else '0';

    -- rebuild the line address of the miss to fill
    s_miss_addr <= tag_reg
                 & std_logic_vector(to_unsigned(index_reg, C_INDEX_BITS))
                 & (C_OFFSET_BITS - 1 downto 0 => '0');

    -- while waiting hold the request for the stage 2 line
    -- else request for stage 1 miss
    o_mem_valid <= '1' when s_wait = '1' else (i_valid and (not s_hit));
    o_mem_addr  <= s_miss_addr when s_wait = '1' else i_address;

    -- take a new address only when not waiting
    o_ready <= not s_wait;

    -- stage 1 to stage 2 pipeline, BRAM read and line fill
    process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                valid_bits <= (others => '0');
                hit_reg    <= '0';
                miss_reg   <= '0';
            elsif i_flush = '1' and s_wait = '1' then
                -- branch: discard fetch so its not served later
                hit_reg  <= '0';
                miss_reg <= '0';
            else
                -- move stage 1 into stage 2 only when not waiting
                if s_wait = '0' then
                    hit_reg    <= s_hit;
                    miss_reg   <= i_valid and (not s_hit);
                    offset_reg <= s_offset;
                    index_reg  <= s_index;
                    tag_reg    <= s_tag;
                    data_q     <= data_ram(s_index);
                end if;

                -- store the line the moment memory answers the stage 2 miss
                if miss_reg = '1' and i_mem_ready = '1' then
                    data_ram(index_reg)   <= i_mem_data;
                    tag_ram(index_reg)    <= tag_reg;
                    valid_bits(index_reg) <= '1';
                end if;
            end if;
        end if;
    end process;

    -- stage 2 output: a hit reads BRAM, a served miss reads the fresh memory word
    process(hit_reg, miss_reg, i_mem_ready, data_q, i_mem_data, offset_reg)
    begin
        o_valid <= '0';
        o_data  <= (others => '0');

        if hit_reg = '1' then
            o_valid <= '1';
            for w in 0 to CACHE_LINE_WIDTH/32 - 1 loop
                -- single-word lines have no word-select bits, so skip the null offset
                if CACHE_LINE_WIDTH = 32 or to_integer(unsigned(offset_reg)) = w then
                    o_data <= data_q((w+1)*32-1 downto w*32);
                end if;
            end loop;
        elsif miss_reg = '1' and i_mem_ready = '1' then
            o_valid <= '1';
            for w in 0 to CACHE_LINE_WIDTH/32 - 1 loop
                -- single-word lines have no word-select bits, so skip the null offset
                if CACHE_LINE_WIDTH = 32 or to_integer(unsigned(offset_reg)) = w then
                    o_data <= i_mem_data((w+1)*32-1 downto w*32);
                end if;
            end loop;
        end if;
    end process;

end Behavioral;
