library ieee;
use ieee.std_logic_1164.all;

package alu_pkg is

    type T_ALU_OP is (
        ALU_ADD,
        ALU_SUB,
        ALU_AND,
        ALU_OR,
        ALU_XOR,
        ALU_SLL,
        ALU_SRL,
        ALU_SRA,
        ALU_SLT,
        ALU_SLTU,
        ALU_LUI
    );

end package alu_pkg;

package body alu_pkg is
end package body alu_pkg;