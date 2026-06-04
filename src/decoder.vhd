library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.alu_pkg.all;
use work.decoder_pkg.all;

entity decoder is
    port(
        i_instr      : in  std_logic_vector(31 downto 0);
        o_alu_instr  : out T_ALU_OP;
        o_instr      : out T_INSTR;
        o_rs1        : out std_logic_vector(4 downto 0);
        o_rs2        : out std_logic_vector(4 downto 0);
        o_rd         : out std_logic_vector(4 downto 0);
        o_imm        : out std_logic_vector(31 downto 0);
        o_imm_flag   : out std_logic
    );
end entity;

architecture behave of decoder is
begin
    decode: process(i_instr) is
        variable v_opcode : T_OP_TYPE;
        variable v_funct_3 : std_logic_vector(2 downto 0);
        variable v_funct_7 : std_logic_vector(6 downto 0);
        variable v_imm_i  : std_logic_vector(31 downto 0);
        variable v_imm_s  : std_logic_vector(31 downto 0);
        variable v_imm_b  : std_logic_vector(31 downto 0);
        variable v_imm_j  : std_logic_vector(31 downto 0);
        variable v_imm_u  : std_logic_vector(31 downto 0);
    begin
        v_opcode := i_instr(6 downto 0);
        v_funct_3 := i_instr(14 downto 12);
        v_funct_7 := i_instr(31 downto 25);

        v_imm_i := std_logic_vector(resize(signed(i_instr(31 downto 20)), 32));
        v_imm_s := std_logic_vector(resize(signed(i_instr(31 downto 25) & i_instr(11 downto 7)), 32));
        v_imm_b := std_logic_vector(resize(signed(i_instr(31) & i_instr(7) & i_instr(30 downto 25) & i_instr(11 downto 8) & '0'), 32));
        v_imm_j := std_logic_vector(resize(signed(i_instr(31) & i_instr(19 downto 12) & i_instr(20) & i_instr(30 downto 21) & '0'), 32));
        v_imm_u := i_instr(31 downto 12) & (11 downto 0 => '0');

        o_alu_instr <= ALU_ADD;
        o_instr     <= INSTR_UK;
        o_rs1       <= i_instr(19 downto 15);
        o_rs2       <= i_instr(24 downto 20);
        o_rd        <= i_instr(11 downto 7);
        o_imm       <= (others => '0');
        o_imm_flag  <= '0';

        case v_opcode is
            when R_TYPE =>
                o_imm_flag <= '0';
                case v_funct_3 is
                    when "000" =>
                        if v_funct_7 = "0000000" then
                            o_alu_instr <= ALU_ADD;
                            o_instr <= INSTR_ADD;
                        elsif v_funct_7 = "0100000" then
                            o_alu_instr <= ALU_SUB;
                            o_instr <= INSTR_SUB;
                        end if;
                    when "001" =>
                        o_alu_instr <= ALU_SLL;
                        o_instr <= INSTR_SLL;
                    when "010" =>
                        o_alu_instr <= ALU_SLT;
                        o_instr <= INSTR_SLT;
                    when "011" =>
                        o_alu_instr <= ALU_SLTU;
                        o_instr <= INSTR_SLTU;
                    when "100" =>
                        o_alu_instr <= ALU_XOR;
                        o_instr <= INSTR_XOR;
                    when "101" =>
                        if v_funct_7 = "0000000" then
                            o_alu_instr <= ALU_SRL;
                            o_instr <= INSTR_SRL;
                        elsif v_funct_7 = "0100000" then
                            o_alu_instr <= ALU_SRA;
                            o_instr <= INSTR_SRA;
                        end if;
                    when "110" =>
                        o_alu_instr <= ALU_OR;
                        o_instr <= INSTR_OR;
                    when "111" =>
                        o_alu_instr <= ALU_AND;
                        o_instr <= INSTR_AND;
                    when others =>
                        null;
                end case;
            when I_TYPE =>
                o_imm_flag <= '1';
                o_imm <= v_imm_i;
                o_rs2 <= (others => '0');
                case v_funct_3 is
                    when "000" =>
                        o_alu_instr <= ALU_ADD;
                        o_instr <= INSTR_ADDI;
                    when "001" =>
                        if v_funct_7 = "0000000" then
                            o_alu_instr <= ALU_SLL;
                            o_instr <= INSTR_SLL;
                        end if;
                    when "010" =>
                        o_alu_instr <= ALU_SLT;
                        o_instr <= INSTR_SLTI;
                    when "011" =>
                        o_alu_instr <= ALU_SLTU;
                        o_instr <= INSTR_SLTIU;
                    when "100" =>
                        o_alu_instr <= ALU_XOR;
                        o_instr <= INSTR_XORI;
                    when "101" =>
                        if v_funct_7 = "0000000" then
                            o_alu_instr <= ALU_SRL;
                            o_instr <= INSTR_SRLI;
                        elsif v_funct_7 = "0100000" then
                            o_alu_instr <= ALU_SRA;
                            o_instr <= INSTR_SRAI;
                        end if;
                    when "110" =>
                        o_alu_instr <= ALU_OR;
                        o_instr <= INSTR_ORI;
                    when "111" =>
                        o_alu_instr <= ALU_AND;
                        o_instr <= INSTR_ANDI;
                    when others =>
                        null;
                end case;
            when L_TYPE =>
                o_imm_flag <= '1';
                o_imm <= v_imm_i;
                o_alu_instr <= ALU_ADD;
                o_rs2 <= (others => '0');
                if v_funct_3 = "010" then
                    o_instr <= INSTR_LW;
                else
                    o_instr <= INSTR_UK;
                end if;
            when S_TYPE =>
                o_imm_flag <= '1';
                o_imm <= v_imm_s;
                o_alu_instr <= ALU_ADD;
                if v_funct_3 = "010" then
                    o_instr <= INSTR_SW;
                else
                    o_instr <= INSTR_UK;
                end if;
            when B_TYPE =>
                o_imm_flag <= '0';
                o_imm <= v_imm_b;
                o_alu_instr <= ALU_SUB;
                case v_funct_3 is
                    when "000" =>
                        o_instr <= INSTR_BEQ;
                    when "001" =>
                        o_instr <= INSTR_BNE;
                    when "100" =>
                        o_instr <= INSTR_BLT;
                    when "101" =>
                        o_instr <= INSTR_BGE;
                    when "110" =>
                        o_instr <= INSTR_BLTU;
                    when "111" =>
                        o_instr <= INSTR_BGEU;
                    when others =>
                        o_instr <= INSTR_UK;
                end case;
            when LUI_TYPE =>
                o_imm_flag <= '1';
                o_imm <= v_imm_u;
                o_rs1 <= (others => '0');
                o_rs2 <= (others => '0');
                o_alu_instr <= ALU_LUI;
                o_instr <= INSTR_LUI;
            when AUIPC_TYPE =>
                o_imm_flag <= '1';
                o_imm <= v_imm_u;
                o_rs1 <= (others => '0');
                o_rs2 <= (others => '0');
                o_alu_instr <= ALU_ADD;
                o_instr <= INSTR_AUIPC;
            when J_TYPE =>
                o_imm_flag <= '1';
                o_imm <= v_imm_j;
                o_rs1 <= (others => '0');
                o_rs2 <= (others => '0');
                o_instr <= INSTR_JAL;
            when JALR_TYPE =>
                o_imm_flag <= '1';
                o_imm <= v_imm_i;
                o_rs2 <= (others => '0');
                o_alu_instr <= ALU_ADD;
                o_instr <= INSTR_JALR;
            when others =>
                null;
        end case;
    end process;
end architecture;
