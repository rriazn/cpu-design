library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

use work.alu_pkg.all;

entity alu is
    generic(
        G_DATA_WIDTH : integer := 32
    );

    port(
        i_data_1        : in std_logic_vector(G_DATA_WIDTH-1 downto 0);
        i_data_2        : in std_logic_vector(G_DATA_WIDTH-1 downto 0);
        i_op            : in T_ALU_OP;
        o_res           : out std_logic_vector(G_DATA_WIDTH-1 downto 0);
        o_flag_z        : out std_logic;
        o_flag_gtu      : out std_logic;
        o_flag_gt       : out std_logic
    );
end entity;

architecture behave of alu is

    signal s_res_int : std_logic_vector(G_DATA_WIDTH-1 downto 0);
    signal s_ovf_int: std_logic;

begin

    process(i_data_1, i_data_2, i_op)
    begin
        
        case i_op is
            when ALU_ADD =>
                s_res_int <= std_logic_vector(signed(i_data_1) + signed(i_data_2));                
            when ALU_SUB =>
                s_res_int <= std_logic_vector(signed(i_data_1) - signed(i_data_2));                
            when ALU_AND =>
                s_res_int <= i_data_1 and i_data_2;
            when ALU_OR =>
                s_res_int <= i_data_1 or i_data_2;
            when ALU_XOR =>
                s_res_int <= i_data_1 xor i_data_2;
            when ALU_SLL =>
                s_res_int <= std_logic_vector(shift_left(unsigned(i_data_1), to_integer(unsigned(i_data_2(integer(ceil(log2(real(G_DATA_WIDTH))))-1 downto 0)))));
            when ALU_SRL =>
                s_res_int <= std_logic_vector(shift_right(unsigned(i_data_1), to_integer(unsigned(i_data_2(integer(ceil(log2(real(G_DATA_WIDTH))))-1 downto 0)))));
            when ALU_SRA =>
                s_res_int <= std_logic_vector(shift_right(signed(i_data_1), to_integer(unsigned(i_data_2(integer(ceil(log2(real(G_DATA_WIDTH))))-1 downto 0)))));
            when ALU_SLT =>
                s_res_int <= (0 => '1', others => '0') when signed(i_data_1) < signed(i_data_2) else (others => '0');
            when ALU_SLTU =>
		      s_res_int <= (0 => '1', others => '0') when unsigned(i_data_1) < unsigned(i_data_2) else (others => '0');
            when ALU_LUI =>
                s_res_int <= i_data_1; -- LUI is already handeled in the decoder
            when others =>
                s_res_int <= (others => '0');

        end case;

    end process;
    o_res <= s_res_int;

    o_flag_z <= '1' when i_data_1 = i_data_2 else '0';

    o_flag_gtu <= '1' when unsigned(i_data_1) > unsigned(i_data_2) else '0';

    o_flag_gt <= '1' when signed(i_data_1) > signed(i_data_2) else '0';
    

end architecture;