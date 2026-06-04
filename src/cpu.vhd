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
        i_clk   : in  std_logic;
        i_rst   : in  std_logic;
        o_leds  : out std_logic_vector(31 downto 0);
        o_instr : out T_INSTR; -- debug
        o_line : out std_logic_vector(31 downto 0); -- debug
        o_branch_taken : out std_logic; -- debug
        o_pc_decode : out std_logic_vector(31 downto 0) -- debug
    );
end entity;

architecture behave of cpu is

    -- PC Signals
    signal s_pc       : std_logic_vector(31 downto 0) := (others => '0');
    signal s_pc_next  : std_logic_vector(31 downto 0) := (others => '0');
    signal s_pc_target : std_logic_vector(31 downto 0) := (others => '0');

    signal s_instr    : std_logic_vector(31 downto 0) := (others => '0'); -- Instruction fetched from instruction memory

    -- Decoder Signals
    signal s_dec_alu_instr : T_ALU_OP := ALU_ADD;
    signal s_dec_instr     : T_INSTR := INSTR_UK;
    signal s_dec_rs1       : std_logic_vector(4 downto 0) := (others => '0');
    signal s_dec_rs2       : std_logic_vector(4 downto 0) := (others => '0');
    signal s_dec_rd        : std_logic_vector(4 downto 0) := (others => '0');
    signal s_dec_imm       : std_logic_vector(31 downto 0) := (others => '0');
    signal s_dec_imm_flag  : std_logic := '0';
    signal s_if_instr      : std_logic_vector(31 downto 0) := (others => '0'); -- Instruction in the IF stage
    signal s_if_pc         : std_logic_vector(31 downto 0) := (others => '0'); -- PC value in the IF stage
    -- Register File Signals
    signal s_rf_rd1  : std_logic_vector(31 downto 0) := (others => '0');
    signal s_rf_rd2  : std_logic_vector(31 downto 0) := (others => '0');
    signal s_ex_reg_wr_en : std_logic := '0';

    -- ALU Signals
    signal s_alu_op1 : std_logic_vector(31 downto 0) := (others => '0');
    signal s_alu_op2 : std_logic_vector(31 downto 0) := (others => '0');
    signal s_alu_res : std_logic_vector(31 downto 0) := (others => '0');
    signal s_flag_z  : std_logic := '0';
    signal s_flag_gt : std_logic := '0';
    signal s_flag_gtu: std_logic := '0';

    signal s_ex_rd        : std_logic_vector(4 downto 0) := (others => '0'); -- Destination register
    
    signal s_ex_reg_src_mem : std_logic := '0';  -- 1 if the value to write back comes from memory, 0 if it comes from ALU
    signal s_ex_reg_src_pc  : std_logic := '0';  -- 1 if the value to write back comes from PC+4, 0 otherwise
    signal s_ex_alu_res   : std_logic_vector(31 downto 0) := (others => '0');  -- ALU result to be potentially written back to the register file
    signal s_ex_mem_addr  : std_logic_vector(31 downto 0) := (others => '0');  -- Address for memory access
    signal s_ex_mem_wr_data : std_logic_vector(31 downto 0) := (others => '0'); -- Data to be written to memory
    signal s_ex_mem_wr_en   : std_logic := '0';  -- Memory write enble
    signal s_ex_mem_rd_en   : std_logic := '0'; -- Memory read enable
    signal s_branch_taken : std_logic := '0'; -- Branch/jump decision
    signal s_fetch_pc  : std_logic_vector(31 downto 0) := (others => '0'); -- s_pc delayed 1 cycle, aligned with s_instr output

    signal s_mem_rd_data : std_logic_vector(31 downto 0) := (others => '0'); -- Data read from memory
    signal s_data_mem_wr_en : std_logic := '0'; -- 1 if want to write to memory, 0 otherwise. -> can prevent writing to memory

    signal s_led_reg : std_logic_vector(31 downto 0) := (others => '0');
    
    signal s_wr_data : std_logic_vector(31 downto 0) := (others => '0');


    function is_reg_write(i : T_INSTR) return std_logic is -- 1 if the instruction writes to a register, 0 else
    begin
        case i is
            when INSTR_ADD|INSTR_SUB|INSTR_SLL|INSTR_SLT|INSTR_SLTU|INSTR_XOR|INSTR_SRL|INSTR_SRA|INSTR_OR|INSTR_AND|
                 INSTR_ADDI|INSTR_SLTI|INSTR_SLTIU|INSTR_XORI|INSTR_SRLI|INSTR_SRAI|INSTR_ORI|INSTR_ANDI|
                 INSTR_LW|INSTR_LUI|INSTR_AUIPC|INSTR_JAL|INSTR_JALR =>
                return '1';
            when others =>
                return '0';
        end case;
    end function;

begin

    pc_inst : entity work.pc
        generic map(g_rst_addr => g_rst_addr)
        port map(i_clk => i_clk,
        i_rst => i_rst,
        i_en => '1',
        i_load => s_branch_taken,
        i_load_addr => s_pc_target,
        o_pc => s_pc,
        o_pc_next => s_pc_next);

    instr_mem : entity work.instr_mem
        port map(i_clk => i_clk, i_addr => s_pc, i_global_en => '1', o_rd_data => s_instr);

    decoder_inst : entity work.decoder
        port map(i_instr => s_if_instr,
                 o_alu_instr => s_dec_alu_instr,
                 o_instr     => s_dec_instr,
                 o_rs1       => s_dec_rs1,
                 o_rs2       => s_dec_rs2,
                 o_rd        => s_dec_rd,
                 o_imm       => s_dec_imm,
                 o_imm_flag  => s_dec_imm_flag);

    reg_file : entity work.register_file
        generic map(G_DATA_WIDTH => 32, G_NUM_REGS => 32)
        port map(i_clk => i_clk, i_rst => i_rst, i_wr_en => s_ex_reg_wr_en,
                 i_wr_data => s_wr_data, i_wr_addr => s_ex_rd,
                 i_rd_addr_1 => s_dec_rs1, i_rd_addr_2 => s_dec_rs2,
                 o_rd_data_1 => s_rf_rd1, o_rd_data_2 => s_rf_rd2);

    alu_inst : entity work.alu
        generic map(G_DATA_WIDTH => 32)
        port map(i_data_1 => s_alu_op1, i_data_2 => s_alu_op2, i_op => s_dec_alu_instr,
                 o_res => s_alu_res, o_flag_z => s_flag_z, o_flag_gtu => s_flag_gtu, o_flag_gt => s_flag_gt);

    data_mem : entity work.data_mem
        port map(i_clk => i_clk, i_addr => s_ex_mem_addr, i_wr_data => s_ex_mem_wr_data,
                 i_wr_en => s_data_mem_wr_en,
                 i_rd_en => s_ex_mem_rd_en, i_global_en => '1', o_rd_data => s_mem_rd_data);

    process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                s_if_instr <= (others => '0');
                s_if_pc    <= (others => '0');
                s_fetch_pc <= (others => '0');
            else
                -- s_fetch_pc trails s_pc by one cycle so that it is aligned
                -- with s_instr (the synchronous memory also has one cycle latency).
                -- Using s_fetch_pc for s_if_pc ensures the branch target is
                -- computed from the correct instruction address.
                s_fetch_pc <= s_pc;
                s_if_instr <= s_instr;
                s_if_pc    <= s_fetch_pc; -- use the previous fetch_pc
            end if;
        end if;
    end process;

    process(s_ex_reg_src_mem, s_ex_reg_src_pc, s_mem_rd_data, s_pc_next, s_ex_alu_res) -- Determine which data to write back to the register file
    begin
        if s_ex_reg_src_mem = '1' then
            s_wr_data <= s_mem_rd_data;
        elsif s_ex_reg_src_pc = '1' then
            s_wr_data <= s_pc_next;
        else
            s_wr_data <= s_ex_alu_res;
        end if;
    end process;

    process(s_dec_instr, s_flag_z, s_flag_gt, s_flag_gtu) -- Branch/jump taken decision
    begin
        if s_dec_instr = INSTR_JAL or s_dec_instr = INSTR_JALR then
            s_branch_taken <= '1';
        elsif s_dec_instr = INSTR_BEQ and s_flag_z = '1' then
            s_branch_taken <= '1';
        elsif s_dec_instr = INSTR_BNE and s_flag_z = '0' then
            s_branch_taken <= '1';
        elsif s_dec_instr = INSTR_BLT and s_flag_gt = '0' and s_flag_z = '0' then
            s_branch_taken <= '1';
        elsif s_dec_instr = INSTR_BLTU and s_flag_gtu = '0' and s_flag_z = '0' then
            s_branch_taken <= '1';
        elsif s_dec_instr = INSTR_BGE and (s_flag_gt = '1' or s_flag_z = '1') then
            s_branch_taken <= '1';
        elsif s_dec_instr = INSTR_BGEU and (s_flag_gtu = '1' or s_flag_z = '1') then
            s_branch_taken <= '1';
        else
            s_branch_taken <= '0';
        end if;
    end process;

    s_pc_target <= std_logic_vector(signed(s_rf_rd1) + signed(s_dec_imm)) and x"FFFFFFFE"
                   when s_dec_instr = INSTR_JALR
                   else std_logic_vector(signed(s_if_pc) + signed(s_dec_imm));
    
    -- Only write to memory if its a SW instruction and the address is not the LED address
    s_data_mem_wr_en <= '1' when (s_ex_mem_wr_en = '1' and s_ex_mem_addr /= x"00002000") else '0';

    -- Link ALU inputs
    s_alu_op1 <= s_dec_imm when s_dec_alu_instr = ALU_LUI else s_rf_rd1;
    s_alu_op2 <= s_dec_imm when s_dec_imm_flag = '1' else s_rf_rd2;

    process(i_clk) -- Set the execute signals
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                s_ex_rd <= (others => '0');
                s_ex_reg_wr_en <= '0';
                s_ex_reg_src_mem <= '0';
                s_ex_reg_src_pc <= '0';
                s_ex_alu_res <= (others => '0');
                s_ex_mem_addr <= (others => '0');
                s_ex_mem_wr_data <= (others => '0');
                s_ex_mem_wr_en <= '0';
                s_ex_mem_rd_en <= '0';
            else
                s_ex_rd <= s_dec_rd;
                s_ex_reg_wr_en <= '1' when is_reg_write(s_dec_instr) = '1' else '0';
                s_ex_reg_src_mem <= '1' when s_dec_instr = INSTR_LW else '0';
                s_ex_reg_src_pc  <= '1' when s_dec_instr = INSTR_JAL or s_dec_instr = INSTR_JALR else '0';
                s_ex_alu_res <= s_alu_res;
                s_ex_mem_addr <= s_alu_res;
                s_ex_mem_wr_data <= s_rf_rd2;
                s_ex_mem_wr_en <= '1' when s_dec_instr = INSTR_SW else '0';
                s_ex_mem_rd_en <= '1' when s_dec_instr = INSTR_LW else '0';
            end if;
        end if;
    end process;

    process(i_clk) -- Set LED output
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                s_led_reg <= (others => '0');
            else
                if s_ex_mem_wr_en = '1' and s_ex_mem_addr = x"00002000" then
                    s_led_reg <= s_ex_mem_wr_data;
                end if;
            end if;
        end if;
    end process;
    
    o_leds <= s_led_reg;
    o_instr <= s_dec_instr;
    o_line <= s_if_instr;
    o_branch_taken <= s_branch_taken;
    o_pc_decode <= s_if_pc;

end architecture;
