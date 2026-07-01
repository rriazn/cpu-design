library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity cache is
    port(
        i_clk       : in  std_logic;
        i_rst       : in  std_logic;
        i_valid     : in  std_logic;                       -- CPU request valid
        i_address   : in  std_logic_vector(31 downto 0);
        i_data      : in  std_logic_vector(31 downto 0);
        i_direction : in  std_logic;                       -- 0: read, 1: write
        o_valid     : out std_logic;                       -- response valid (data ready)
        o_ready     : out std_logic;                       -- cache can accept new request

        -- Cache <-> main memory interface
        o_mem_rd_wr : out std_logic;                       -- 0: read from mem, 1: write to mem
        o_mem_valid : out std_logic;
        o_mem_addr  : out std_logic_vector(31 downto 0);
        o_mem_data  : out std_logic_vector(31 downto 0);  -- write-back data (1 line = 1 word)
        i_mem_data  : in  std_logic_vector(31 downto 0);  -- fill data (1 line = 1 word)
        i_mem_ready : in  std_logic;

        o_data      : out std_logic_vector(31 downto 0)
    );
end cache;

architecture Behavioral of cache is

    constant C_NUM_LINES  : integer := 128;
    constant C_INDEX_BITS : integer := 7;            -- log2(128)
    constant C_TAG_BITS   : integer := 32 - C_INDEX_BITS - 2;  -- 23

    type t_cache_block is record
        valid_bit : std_logic;
        dirty_bit : std_logic;
        tag       : std_logic_vector(C_TAG_BITS-1 downto 0);
        data      : std_logic_vector(31 downto 0);
    end record;

    type t_cache is array (0 to C_NUM_LINES-1) of t_cache_block;
    signal cache_mem : t_cache := (others => (
        valid_bit => '0',
        dirty_bit => '0',
        tag       => (others => '0'),
        data      => (others => '0')
    ));

    type FSM is (Idle, Compare_Tag, Allocate, Write_Back);
    signal state_reg, state_next : FSM := Idle;

    signal s_tag    : std_logic_vector(C_TAG_BITS-1 downto 0);
    signal s_index  : integer range 0 to C_NUM_LINES-1;
    -- Reconstructed address of the dirty line to write bck
    signal s_wb_addr : std_logic_vector(31 downto 0);

begin

    s_tag    <= i_address(31 downto 9);
    s_index  <= to_integer(unsigned(i_address(8 downto 2)));
    s_wb_addr <= cache_mem(s_index).tag
                 & std_logic_vector(to_unsigned(s_index, C_INDEX_BITS))
                 & "00";

    o_mem_data <= cache_mem(s_index).data;

    -- Clocked process: state register + all cache_mem updates
    process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                state_reg <= Idle;
                for i in 0 to C_NUM_LINES-1 loop
                    cache_mem(i).valid_bit <= '0';
                    cache_mem(i).dirty_bit <= '0';
                end loop;
            else
                state_reg <= state_next;

                case state_reg is

                    when Compare_Tag =>
                        if cache_mem(s_index).valid_bit = '1' and cache_mem(s_index).tag = s_tag then
                            if i_direction = '1' then  -- write hit: update data and set dirty
                                cache_mem(s_index).data      <= i_data;
                                cache_mem(s_index).dirty_bit <= '1';
                            end if;
                        end if;

                    when Allocate =>
                        if i_mem_ready = '1' then  -- fill the line on memory response
                            cache_mem(s_index).data      <= i_mem_data;
                            cache_mem(s_index).valid_bit <= '1';
                            cache_mem(s_index).dirty_bit <= '0';
                            cache_mem(s_index).tag       <= s_tag;
                        end if;

                    when others => null;

                end case;
            end if;
        end if;
    end process;

    -- Combinatorial process: FSM next-state and output logic
    process(state_reg, i_valid, i_direction, i_mem_ready, i_mem_data,
            s_tag, s_index, s_wb_addr, i_address, cache_mem)
    begin
        state_next  <= state_reg;
        o_valid     <= '0';
        o_ready     <= '0';
        o_mem_valid <= '0';
        o_mem_rd_wr <= '0';
        o_mem_addr  <= i_address;
        o_data      <= (others => '0');  -- default prevents latch on o_data

        case state_reg is

            when Idle =>
                o_ready <= '1';
                if i_valid = '1' then
                    state_next <= Compare_Tag;
                end if;

            when Compare_Tag =>
                if cache_mem(s_index).valid_bit = '1' and cache_mem(s_index).tag = s_tag then
                    -- Hit
                    if i_direction = '0' then
                        o_data <= cache_mem(s_index).data;
                    end if;
                    o_valid    <= '1';
                    state_next <= Idle;
                elsif cache_mem(s_index).valid_bit = '1' and cache_mem(s_index).dirty_bit = '1' then
                    -- Miss: dirty line must be written back before eviction
                    state_next <= Write_Back;
                else
                    -- Miss: line is clean or invalid -> allocate directly
                    state_next <= Allocate;
                end if;

            when Write_Back =>
                o_mem_rd_wr <= '1';
                o_mem_valid <= '1';
                -- Use the evicted line's original address, NOT i_address
                o_mem_addr  <= s_wb_addr;
                if i_mem_ready = '1' then
                    state_next <= Allocate;
                end if;

            when Allocate =>
                o_mem_rd_wr <= '0';
                o_mem_valid <= '1';
                if i_mem_ready = '1' then
                    if i_direction = '0' then
                        -- Read miss: output fill data directly, skip an extra Compare_Tag cycle
                        o_data     <= i_mem_data;
                        o_valid    <= '1';
                        state_next <= Idle;
                    else
                        -- Write miss: line now filled, re-enter Compare_Tag to apply the write
                        state_next <= Compare_Tag;
                    end if;
                end if;

        end case;
    end process;

end Behavioral;
