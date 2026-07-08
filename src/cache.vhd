library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use ieee.math_real.all;

entity cache is
    generic(
        C_NUM_LINES      : integer := 128;
        CACHE_LINE_WIDTH : integer := 64
    );
    port(
        i_clk       : in  std_logic;
        i_rst       : in  std_logic;
        i_flush     : in  std_logic;                       -- invalidate all lines
        i_valid     : in  std_logic;                       -- CPU request valid
        i_address   : in  std_logic_vector(31 downto 0);
        o_valid     : out std_logic;                       -- response valid (data ready)
        o_ready     : out std_logic;                       -- cache can accept new request

        -- Cache <-> main memory interface (read-only: instruction cache)
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

    type t_cache_block is record
        valid_bit : std_logic;
        tag       : std_logic_vector(C_TAG_BITS-1 downto 0);
        data      : std_logic_vector(CACHE_LINE_WIDTH - 1 downto 0);
    end record;

    type t_cache is array (0 to C_NUM_LINES-1) of t_cache_block;
    signal cache_mem : t_cache := (others => (
        valid_bit => '0',
        tag       => (others => '0'),
        data      => (others => '0')
    ));

    type FSM is (Idle, Compare_Tag, Allocate);
    signal state_reg, state_next : FSM := Idle;

    signal s_tag    : std_logic_vector(C_TAG_BITS-1 downto 0);
    signal s_index  : integer range 0 to C_NUM_LINES-1;
    signal s_offset : std_logic_vector(C_OFFSET_BITS - 3 downto 0);

begin

    s_tag    <= i_address(31 downto 32 - C_TAG_BITS);
    s_index  <= to_integer(unsigned(i_address(32 - C_TAG_BITS - 1 downto C_OFFSET_BITS)));
    s_offset <= i_address(C_OFFSET_BITS - 1 downto 2);

    -- Clocked process: state register + cache_mem updates
    process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                state_reg <= Idle;
                for i in 0 to C_NUM_LINES-1 loop
                    cache_mem(i).valid_bit <= '0';
                end loop;
            elsif i_flush = '1' then
                -- Invalidate all lines without resetting FSM state
                for i in 0 to C_NUM_LINES-1 loop
                    cache_mem(i).valid_bit <= '0';
                end loop;
            else
                state_reg <= state_next;
                case state_reg is

                    when Allocate =>
                        if i_mem_ready = '1' then
                            cache_mem(s_index).data      <= i_mem_data;
                            cache_mem(s_index).valid_bit <= '1';
                            cache_mem(s_index).tag       <= s_tag;
                        end if;

                    when others => null;

                end case;
            end if;
        end if;
    end process;

    -- Combinatorial process: FSM next-state and output logic
    process(state_reg, i_valid, i_mem_ready, i_mem_data,
            s_tag, s_index, s_offset, i_address, cache_mem)
    begin
        state_next  <= state_reg;
        o_valid     <= '0';
        o_ready     <= '0';
        o_mem_valid <= '0';
        o_mem_addr  <= i_address;
        o_data      <= (others => '0');

        case state_reg is

            when Idle =>
                o_ready <= '1';
                if i_valid = '1' then
                    state_next <= Compare_Tag;
                end if;

            when Compare_Tag =>
                o_ready <= '1';
                if cache_mem(s_index).valid_bit = '1' and cache_mem(s_index).tag = s_tag then
                    -- Hit: serve word from cache line
                    for w in 0 to CACHE_LINE_WIDTH/32 - 1 loop
                        if to_integer(unsigned(s_offset)) = w then
                            o_data <= cache_mem(s_index).data((w+1)*32-1 downto w*32);
                        end if;
                    end loop;
                    o_valid    <= '1';
                    state_next <= Idle;
                else
                    -- Miss: assert o_mem_valid immediately so instr_mem sees the request
                    -- one cycle earlier than if we waited until the Allocate state
                    o_mem_valid <= '1';
                    state_next  <= Allocate;
                end if;

            when Allocate =>
                o_mem_valid <= '1';
                if i_mem_ready = '1' then
                    -- Serve word directly from fill data, skipping an extra Compare_Tag cycle
                    for w in 0 to CACHE_LINE_WIDTH/32 - 1 loop
                        if to_integer(unsigned(s_offset)) = w then
                            o_data <= i_mem_data((w+1)*32-1 downto w*32);
                        end if;
                    end loop;
                    o_valid    <= '1';
                    state_next <= Idle;
                end if;

        end case;
    end process;

end Behavioral;
