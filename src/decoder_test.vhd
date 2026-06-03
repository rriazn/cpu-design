library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.decoder_pkg.all;
use work.alu_pkg.all;

entity tb_decoder is
end entity;

architecture sim of tb_decoder is

    signal s_instr     : std_logic_vector(31 downto 0);
    signal s_alu_instr : T_ALU_OP;

begin

    -- DUT
    uut : entity work.decoder
        port map (
            i_instr     => s_instr,
            o_alu_instr => s_alu_instr
        );

    stim_proc : process
    begin

        ----------------------------------------------------------------
        -- ADD
        -- funct7=0000000 funct3=000 opcode=0110011
        ----------------------------------------------------------------
        s_instr <= "0000000" & "00000" & "00000" & "000" &
                   "00000" & "0110011";
        wait for 10 ns;

        assert s_alu_instr = ALU_ADD
            report "ADD decode failed"
            severity error;

        ----------------------------------------------------------------
        -- SUB
        ----------------------------------------------------------------
        s_instr <= "0100000" & "00000" & "00000" & "000" &
                   "00000" & "0110011";
        wait for 10 ns;

        assert s_alu_instr = ALU_SUB
            report "SUB decode failed"
            severity error;

        ----------------------------------------------------------------
        -- AND
        ----------------------------------------------------------------
        s_instr <= "0000000" & "00000" & "00000" & "111" &
                   "00000" & "0110011";
        wait for 10 ns;

        assert s_alu_instr = ALU_AND
            report "AND decode failed"
            severity error;

        ----------------------------------------------------------------
        -- OR
        ----------------------------------------------------------------
        s_instr <= "0000000" & "00000" & "00000" & "110" &
                   "00000" & "0110011";
        wait for 10 ns;

        assert s_alu_instr = ALU_OR
            report "OR decode failed"
            severity error;

        ----------------------------------------------------------------
        -- XOR
        ----------------------------------------------------------------
        s_instr <= "0000000" & "00000" & "00000" & "100" &
                   "00000" & "0110011";
        wait for 10 ns;

        assert s_alu_instr = ALU_XOR
            report "XOR decode failed"
            severity error;

        ----------------------------------------------------------------
        -- SLL
        ----------------------------------------------------------------
        s_instr <= "0000000" & "00000" & "00000" & "001" &
                   "00000" & "0110011";
        wait for 10 ns;

        assert s_alu_instr = ALU_SLL
            report "SLL decode failed"
            severity error;

        ----------------------------------------------------------------
        -- SRL
        ----------------------------------------------------------------
        s_instr <= "0000000" & "00000" & "00000" & "101" &
                   "00000" & "0110011";
        wait for 10 ns;

        assert s_alu_instr = ALU_SRL
            report "SRL decode failed"
            severity error;

        ----------------------------------------------------------------
        -- SRA
        ----------------------------------------------------------------
        s_instr <= "0100000" & "00000" & "00000" & "101" &
                   "00000" & "0110011";
        wait for 10 ns;

        assert s_alu_instr = ALU_SRA
            report "SRA decode failed"
            severity error;

        report "All decoder tests passed!"
            severity note;

        wait;

    end process;

end architecture;