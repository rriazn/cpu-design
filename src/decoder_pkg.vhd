library ieee;
use ieee.std_logic_1164.all;

package decoder_pkg is
    subtype T_OP_TYPE is std_logic_vector(6 downto 0);
    constant R_TYPE : T_OP_TYPE := "0110011";
    constant I_TYPE : T_OP_TYPE := "0010011";
    constant S_TYPE : T_OP_TYPE := "0100011";
    constant B_TYPE : T_OP_TYPE := "1100011";
    constant LUI_TYPE : T_OP_TYPE := "0110111";
    constant AUIPC_TYPE : T_OP_TYPE := "0010111";
    constant J_TYPE : T_OP_TYPE := "1101111";
    constant JALR_TYPE : T_OP_TYPE := "1100111";
    constant L_TYPE : T_OP_TYPE := "0000011";

    type T_INSTR is (
        INSTR_ADD,
        INSTR_SUB,
        INSTR_SLL,
        INSTR_SLT,
        INSTR_SLTU,
        INSTR_XOR,
        INSTR_SRL,
        INSTR_SRA,
        INSTR_OR,
        INSTR_AND,
        INSTR_ADDI,
        INSTR_SLTI,
        INSTR_SLTIU,
        INSTR_XORI,
        INSTR_SRLI,
        INSTR_SRAI,
        INSTR_ORI,
        INSTR_ANDI,
        INSTR_LW,
        INSTR_SW,
        INSTR_BEQ,
        INSTR_BNE,
        INSTR_BLT,
        INSTR_BGE,
        INSTR_BLTU,
        INSTR_BGEU,
        INSTR_LUI,
        INSTR_AUIPC,
        INSTR_JAL,
        INSTR_JALR,
        INSTR_UK
    );

end package;

package body decoder_pkg is
end package body decoder_pkg;
