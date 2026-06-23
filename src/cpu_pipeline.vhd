library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.alu_pkg.all;
use work.decoder_pkg.all;

entity cpu is
    generic(
        g_rst_addr : std_logic_vector(31 downto 0) := (others => '0')
    );
    port(
        i_clk          : in  std_logic;
        i_rst          : in  std_logic;
        o_leds         : out std_logic_vector(31 downto 0);
        o_instr        : out T_INSTR;                       -- debug: decoded instr in EX
        o_line         : out std_logic_vector(31 downto 0); -- debug: raw bits in ID
        o_branch_taken : out std_logic;                     -- debug
        o_pc_decode    : out std_logic_vector(31 downto 0)  -- debug: PC in EX
    );
end entity;

architecture behave of cpu is
    -- IF stage: PC
    signal s_pc_if      : std_logic_vector(31 downto 0) := (others => '0');
    signal s_pc_next_if : std_logic_vector(31 downto 0) := (others => '0');
    signal s_pc_en_if : std_logic := '1';

    -- IF/ID pipeline register
    signal s_instr_if_id : std_logic_vector(31 downto 0) := (others => '0');
    signal s_pc_if_id    : std_logic_vector(31 downto 0) := (others => '0');

    -- IF/ID disable
    signal s_if_id_en : std_logic := '1';

    -- ID stage: decoder
    signal s_alu_op_id   : T_ALU_OP := ALU_ADD;
    signal s_instr_id    : T_INSTR  := INSTR_UK;
    signal s_rs1_id      : std_logic_vector(4 downto 0)  := (others => '0');
    signal s_rs2_id      : std_logic_vector(4 downto 0)  := (others => '0');
    signal s_rd_id       : std_logic_vector(4 downto 0)  := (others => '0');
    signal s_imm_id      : std_logic_vector(31 downto 0) := (others => '0');
    signal s_imm_flag_id : std_logic := '0';
    signal s_rs1_data_id : std_logic_vector(31 downto 0) := (others => '0');
    signal s_rs2_data_id : std_logic_vector(31 downto 0) := (others => '0');
    signal s_stall : std_logic := '1';

    -- ID/EX pipeline register
    signal s_pc_id_ex          : std_logic_vector(31 downto 0) := (others => '0');
    signal s_rs1_data_id_ex    : std_logic_vector(31 downto 0) := (others => '0');
    signal s_rs2_data_id_ex    : std_logic_vector(31 downto 0) := (others => '0');
    signal s_rd_id_ex          : std_logic_vector(4 downto 0)  := (others => '0');
    signal s_imm_id_ex         : std_logic_vector(31 downto 0) := (others => '0');
    signal s_alu_op_id_ex      : T_ALU_OP  := ALU_ADD;
    signal s_instr_id_ex       : T_INSTR   := INSTR_UK;
    signal s_imm_flag_id_ex    : std_logic := '0';
    signal s_reg_wr_en_id_ex   : std_logic := '0';
    signal s_mem_wr_en_id_ex   : std_logic := '0';
    signal s_mem_rd_en_id_ex   : std_logic := '0';
    signal s_reg_src_mem_id_ex : std_logic := '0';
    signal s_reg_src_pc_id_ex  : std_logic := '0';
    -- For forwarding:
    signal s_rs1_id_ex      : std_logic_vector(4 downto 0)  := (others => '0');
    signal s_rs2_id_ex      : std_logic_vector(4 downto 0)  := (others => '0');

    -- EX stage: ALU and branch logic
    signal s_alu_op1_ex      : std_logic_vector(31 downto 0) := (others => '0');
    signal s_alu_op2_ex      : std_logic_vector(31 downto 0) := (others => '0');
    signal s_fwd_rs2_ex      : std_logic_vector(31 downto 0) := (others => '0');
    signal s_alu_res_ex      : std_logic_vector(31 downto 0) := (others => '0');
    signal s_flag_z_ex       : std_logic := '0';
    signal s_flag_gt_ex      : std_logic := '0';
    signal s_flag_gtu_ex     : std_logic := '0';
    signal s_branch_taken_ex : std_logic := '0';
    signal s_pc_target_ex    : std_logic_vector(31 downto 0) := (others => '0');
    signal s_link_addr_ex    : std_logic_vector(31 downto 0) := (others => '0');

    -- EX/MEM pipeline register
    signal s_alu_res_ex_mem     : std_logic_vector(31 downto 0) := (others => '0');
    signal s_rs2_data_ex_mem    : std_logic_vector(31 downto 0) := (others => '0');
    signal s_rd_ex_mem          : std_logic_vector(4 downto 0)  := (others => '0');
    signal s_reg_wr_en_ex_mem   : std_logic := '0';
    signal s_mem_wr_en_ex_mem   : std_logic := '0';
    signal s_mem_rd_en_ex_mem   : std_logic := '0';
    signal s_reg_src_mem_ex_mem : std_logic := '0';
    signal s_reg_src_pc_ex_mem  : std_logic := '0';
    signal s_link_addr_ex_mem   : std_logic_vector(31 downto 0) := (others => '0');
    signal s_flag_z_ex_mem : std_logic;
    signal s_flag_gt_ex_mem : std_logic;
    signal s_flag_gtu_ex_mem : std_logic;

    -- MEM stage
    signal s_data_mem_wr_en_mem : std_logic := '0';

    -- MEM/WB pipeline register
    signal s_mem_rd_data_mem_wb : std_logic_vector(31 downto 0) := (others => '0');
    signal s_alu_res_mem_wb     : std_logic_vector(31 downto 0) := (others => '0');
    signal s_rd_mem_wb          : std_logic_vector(4 downto 0)  := (others => '0');
    signal s_reg_wr_en_mem_wb   : std_logic := '0';
    signal s_reg_src_mem_mem_wb : std_logic := '0';
    signal s_reg_src_pc_mem_wb  : std_logic := '0';
    signal s_link_addr_mem_wb   : std_logic_vector(31 downto 0) := (others => '0');

    -- WB stage
    signal s_wr_data_wb : std_logic_vector(31 downto 0) := (others => '0');
    signal s_led_reg_wb : std_logic_vector(31 downto 0) := (others => '0');

    function is_reg_write(i : T_INSTR) return std_logic is
    begin
        case i is
            when INSTR_ADD|INSTR_SUB|INSTR_SLL|INSTR_SLT|INSTR_SLTU|INSTR_XOR|
                 INSTR_SRL|INSTR_SRA|INSTR_OR|INSTR_AND|INSTR_ADDI|INSTR_SLTI|
                 INSTR_SLTIU|INSTR_XORI|INSTR_SRLI|INSTR_SRAI|INSTR_ORI|INSTR_ANDI|
                 INSTR_LW|INSTR_LUI|INSTR_AUIPC|INSTR_JAL|INSTR_JALR =>
                return '1';
            when others =>
                return '0';
        end case;
    end function;

begin

    -- IF stage
    pc_inst : entity work.pc
        generic map(g_rst_addr => g_rst_addr)
        port map(
            i_clk       => i_clk,
            i_rst       => i_rst,
            i_en        => s_pc_en_if,
            i_load      => s_branch_taken_ex,
            i_load_addr => s_pc_target_ex,
            o_pc        => s_pc_if,
            o_pc_next   => s_pc_next_if);

    instr_mem : entity work.instr_mem
        port map(i_clk => i_clk, i_addr => s_pc_if, i_global_en => s_if_id_en, o_rd_data => s_instr_if_id);

    -- IF/ID PC register: latch s_pc_if so it arrives aligned with the BRAM output
    process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                s_pc_if_id <= (others => '0');
            elsif s_if_id_en = '1' then
                s_pc_if_id <= s_pc_if;
            end if;
        end if;
    end process;

    -- ID stage
    decoder_inst : entity work.decoder
        port map(
            i_instr     => s_instr_if_id,
            o_alu_instr => s_alu_op_id,
            o_instr     => s_instr_id,
            o_rs1       => s_rs1_id,
            o_rs2       => s_rs2_id,
            o_rd        => s_rd_id,
            o_imm       => s_imm_id,
            o_imm_flag  => s_imm_flag_id);

    -- LW stall: freeze PC and IF/ID, insert bubble in ID/EX for 2 cycles
    process(s_rd_id_ex, s_mem_rd_en_id_ex, s_rs1_id, s_rs2_id, s_rd_ex_mem, s_mem_rd_en_ex_mem)
    begin
        s_pc_en_if <= '1';
        s_if_id_en <= '1';
        s_stall    <= '0';
        if s_mem_rd_en_id_ex = '1' and s_rd_id_ex /= "00000" then
            if s_rd_id_ex = s_rs1_id or s_rd_id_ex = s_rs2_id then
                s_pc_en_if <= '0';
                s_if_id_en <= '0';
                s_stall    <= '1';
            end if;
        end if;
    end process;


    reg_file : entity work.register_file
        generic map(G_DATA_WIDTH => 32, G_NUM_REGS => 32)
        port map(
            i_clk       => i_clk,
            i_rst       => i_rst,
            i_wr_en     => s_reg_wr_en_mem_wb,
            i_wr_data   => s_wr_data_wb,
            i_wr_addr   => s_rd_mem_wb,
            i_rd_addr_1 => s_rs1_id,
            i_rd_addr_2 => s_rs2_id,
            o_rd_data_1 => s_rs1_data_id,
            o_rd_data_2 => s_rs2_data_id);

    -- ID/EX register
    process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' or s_stall = '1' then
                s_pc_id_ex          <= (others => '0');
                s_rs1_data_id_ex    <= (others => '0');
                s_rs2_data_id_ex    <= (others => '0');
                s_rd_id_ex          <= (others => '0');
                s_imm_id_ex         <= (others => '0');
                s_alu_op_id_ex      <= ALU_ADD;
                s_instr_id_ex       <= INSTR_UK;
                s_imm_flag_id_ex    <= '0';
                s_reg_wr_en_id_ex   <= '0';
                s_mem_wr_en_id_ex   <= '0';
                s_mem_rd_en_id_ex   <= '0';
                s_reg_src_mem_id_ex <= '0';
                s_reg_src_pc_id_ex  <= '0';
                s_rs1_id_ex <= (others => '0');
                s_rs2_id_ex <= (others => '0');
            else
                s_pc_id_ex          <= s_pc_if_id;
                s_rs1_data_id_ex    <= s_rs1_data_id;
                s_rs2_data_id_ex    <= s_rs2_data_id;
                s_rd_id_ex          <= s_rd_id;
                s_imm_id_ex         <= s_imm_id;
                s_alu_op_id_ex      <= s_alu_op_id;
                s_instr_id_ex       <= s_instr_id;
                s_imm_flag_id_ex    <= s_imm_flag_id;
                s_reg_wr_en_id_ex   <= is_reg_write(s_instr_id);
                s_mem_wr_en_id_ex   <= '1' when s_instr_id = INSTR_SW else '0';
                s_mem_rd_en_id_ex   <= '1' when s_instr_id = INSTR_LW else '0';
                s_reg_src_mem_id_ex <= '1' when s_instr_id = INSTR_LW else '0';
                s_reg_src_pc_id_ex  <= '1' when s_instr_id = INSTR_JAL or s_instr_id = INSTR_JALR else '0';
                s_rs1_id_ex <= s_rs1_id;
                s_rs2_id_ex <= s_rs2_id;
            end if;
        end if;
    end process;

    -- EX stage
    -- Forwarding: EX/MEM takes priority over MEM/WB; LW in EX/MEM not forwarded (data not ready)
    process(s_imm_id_ex, s_alu_op_id_ex, s_rs1_data_id_ex, s_rs1_id_ex, s_imm_flag_id_ex,
            s_rs2_data_id_ex, s_rs2_id_ex,
            s_rd_ex_mem, s_alu_res_ex_mem, s_reg_wr_en_ex_mem, s_mem_rd_en_ex_mem,
            s_rd_mem_wb, s_wr_data_wb, s_reg_wr_en_mem_wb)
    begin
        -- Forwarded rs2 value (independent of the immediate mux below).
        -- Used both for the rs2 ALU operand and for the store-data path.
        if s_rs2_id_ex = s_rd_ex_mem and s_rd_ex_mem /= "00000"
              and s_reg_wr_en_ex_mem = '1' and s_mem_rd_en_ex_mem = '0' then
            s_fwd_rs2_ex <= s_alu_res_ex_mem;
        elsif s_rs2_id_ex = s_rd_mem_wb and s_rd_mem_wb /= "00000"
              and s_reg_wr_en_mem_wb = '1' then
            s_fwd_rs2_ex <= s_wr_data_wb;
        else
            s_fwd_rs2_ex <= s_rs2_data_id_ex;
        end if;

        if s_alu_op_id_ex = ALU_LUI then
            s_alu_op1_ex <= s_imm_id_ex;
        elsif s_rs1_id_ex = s_rd_ex_mem and s_rd_ex_mem /= "00000"
              and s_reg_wr_en_ex_mem = '1' and s_mem_rd_en_ex_mem = '0' then
            s_alu_op1_ex <= s_alu_res_ex_mem;
        elsif s_rs1_id_ex = s_rd_mem_wb and s_rd_mem_wb /= "00000"
              and s_reg_wr_en_mem_wb = '1' then
            s_alu_op1_ex <= s_wr_data_wb;
        else
            s_alu_op1_ex <= s_rs1_data_id_ex;
        end if;

        if s_imm_flag_id_ex = '1' then
            s_alu_op2_ex <= s_imm_id_ex;
        else
            s_alu_op2_ex <= s_fwd_rs2_ex;
        end if;
    end process;


    alu_inst : entity work.alu
        generic map(G_DATA_WIDTH => 32)
        port map(
            i_data_1   => s_alu_op1_ex,
            i_data_2   => s_alu_op2_ex,
            i_op       => s_alu_op_id_ex,
            o_res      => s_alu_res_ex,
            o_flag_z   => s_flag_z_ex,
            o_flag_gtu => s_flag_gtu_ex,
            o_flag_gt  => s_flag_gt_ex);

    -- Branch/jump decision (combinatorial, feeds PC directly)
    process(s_instr_id_ex, s_flag_z_ex, s_flag_gt_ex, s_flag_gtu_ex)
    begin
        if s_instr_id_ex = INSTR_JAL or s_instr_id_ex = INSTR_JALR then
            s_branch_taken_ex <= '1';
        elsif s_instr_id_ex = INSTR_BEQ  and s_flag_z_ex   = '1' then
            s_branch_taken_ex <= '1';
        elsif s_instr_id_ex = INSTR_BNE  and s_flag_z_ex   = '0' then
            s_branch_taken_ex <= '1';
        elsif s_instr_id_ex = INSTR_BLT  and s_flag_gt_ex  = '0' and s_flag_z_ex = '0' then
            s_branch_taken_ex <= '1';
        elsif s_instr_id_ex = INSTR_BLTU and s_flag_gtu_ex = '0' and s_flag_z_ex = '0' then
            s_branch_taken_ex <= '1';
        elsif s_instr_id_ex = INSTR_BGE  and (s_flag_gt_ex  = '1' or s_flag_z_ex = '1') then
            s_branch_taken_ex <= '1';
        elsif s_instr_id_ex = INSTR_BGEU and (s_flag_gtu_ex = '1' or s_flag_z_ex = '1') then
            s_branch_taken_ex <= '1';
        else
            s_branch_taken_ex <= '0';
        end if;
    end process;

    -- PC target
    s_pc_target_ex <= std_logic_vector(signed(s_rs1_data_id_ex) + signed(s_imm_id_ex)) and x"FFFFFFFE"
                      when s_instr_id_ex = INSTR_JALR
                      else std_logic_vector(signed(s_pc_id_ex) + signed(s_imm_id_ex));

    -- Return address for JAL/JALR: instruction after the jump
    s_link_addr_ex <= std_logic_vector(unsigned(s_pc_id_ex) + 4);

    -- EX/MEM register
    process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                s_alu_res_ex_mem     <= (others => '0');
                s_rs2_data_ex_mem    <= (others => '0');
                s_rd_ex_mem          <= (others => '0');
                s_reg_wr_en_ex_mem   <= '0';
                s_mem_wr_en_ex_mem   <= '0';
                s_mem_rd_en_ex_mem   <= '0';
                s_reg_src_mem_ex_mem <= '0';
                s_reg_src_pc_ex_mem  <= '0';
                s_link_addr_ex_mem   <= (others => '0');
                s_flag_z_ex_mem <= '0';
                s_flag_gt_ex_mem <= '0';
                s_flag_gtu_ex_mem <= '0';
            else
                s_alu_res_ex_mem     <= s_alu_res_ex;
                s_rs2_data_ex_mem    <= s_fwd_rs2_ex;
                s_rd_ex_mem          <= s_rd_id_ex;
                s_reg_wr_en_ex_mem   <= s_reg_wr_en_id_ex;
                s_mem_wr_en_ex_mem   <= s_mem_wr_en_id_ex;
                s_mem_rd_en_ex_mem   <= s_mem_rd_en_id_ex;
                s_reg_src_mem_ex_mem <= s_reg_src_mem_id_ex;
                s_reg_src_pc_ex_mem  <= s_reg_src_pc_id_ex;
                s_link_addr_ex_mem   <= s_link_addr_ex;
                s_flag_z_ex_mem <= s_flag_z_ex;
                s_flag_gt_ex_mem <= s_flag_gt_ex;
                s_flag_gtu_ex_mem <= s_flag_gtu_ex;
            end if;
        end if;
    end process;

    -- MEM stage
    s_data_mem_wr_en_mem <= '1' when s_mem_wr_en_ex_mem = '1' and s_alu_res_ex_mem /= x"00002000" else '0';

    data_mem : entity work.data_mem
        port map(
            i_clk       => i_clk,
            i_addr      => s_alu_res_ex_mem,
            i_wr_data   => s_rs2_data_ex_mem,
            i_wr_en     => s_data_mem_wr_en_mem,
            i_rd_en     => s_mem_rd_en_ex_mem,
            i_global_en => '1',
            o_rd_data   => s_mem_rd_data_mem_wb);

    -- LED register (mapped to address 0x2000)
    process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                s_led_reg_wb <= (others => '0');
            else
                if s_mem_wr_en_ex_mem = '1' and s_alu_res_ex_mem = x"00002000" then
                    s_led_reg_wb <= s_rs2_data_ex_mem;
                end if;
            end if;
        end if;
    end process;

    -- MEM/WB register
    process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                s_alu_res_mem_wb     <= (others => '0');
                s_rd_mem_wb          <= (others => '0');
                s_reg_wr_en_mem_wb   <= '0';
                s_reg_src_mem_mem_wb <= '0';
                s_reg_src_pc_mem_wb  <= '0';
                s_link_addr_mem_wb   <= (others => '0');
            else
                s_alu_res_mem_wb     <= s_alu_res_ex_mem;
                s_rd_mem_wb          <= s_rd_ex_mem;
                s_reg_wr_en_mem_wb   <= s_reg_wr_en_ex_mem;
                s_reg_src_mem_mem_wb <= s_reg_src_mem_ex_mem;
                s_reg_src_pc_mem_wb  <= s_reg_src_pc_ex_mem;
                s_link_addr_mem_wb   <= s_link_addr_ex_mem;
            end if;
        end if;
    end process;

    -- WB stage
    process(s_reg_src_mem_mem_wb, s_reg_src_pc_mem_wb,
            s_mem_rd_data_mem_wb, s_link_addr_mem_wb, s_alu_res_mem_wb)
    begin
        if s_reg_src_mem_mem_wb = '1' then
            s_wr_data_wb <= s_mem_rd_data_mem_wb;
        elsif s_reg_src_pc_mem_wb = '1' then
            s_wr_data_wb <= s_link_addr_mem_wb;
        else
            s_wr_data_wb <= s_alu_res_mem_wb;
        end if;
    end process;

    o_leds         <= s_led_reg_wb;
    o_instr        <= s_instr_id_ex;   -- instruction currently in EX
    o_line         <= s_instr_if_id;   -- raw bits currently in ID
    o_branch_taken <= s_branch_taken_ex;
    o_pc_decode    <= s_pc_id_ex;      -- PC of instruction in EX

end architecture;