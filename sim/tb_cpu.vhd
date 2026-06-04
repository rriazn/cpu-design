library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.decoder_pkg.all;
use work.alu_pkg.all;

entity tb_cpu is
end entity;

architecture tb of tb_cpu is
    signal clk : std_logic := '0';
    signal rst : std_logic := '1';
    signal leds: std_logic_vector(31 downto 0);
    signal instr: T_INSTR;
    signal line: std_logic_vector(31 downto 0);
    signal branch_taken: std_logic;
    signal pc_decode: std_logic_vector(31 downto 0);

    constant CLK_PERIOD : time := 10 ns;
begin
    uut: entity work.cpu
        generic map(g_rst_addr => (others => '0'))
        port map(
            i_clk => clk, 
            i_rst => rst, 
            o_leds => leds,
            o_instr => instr,
            o_line => line,
            o_branch_taken => branch_taken,
            o_pc_decode => pc_decode
        );

    clk_proc: process
    begin
        while now < 5 sec loop
            clk <= '0';
            wait for CLK_PERIOD/2;
            clk <= '1';
            wait for CLK_PERIOD/2;
        end loop;
        wait;
    end process;

    rst_proc: process
    begin
        rst <= '1';
        wait for 25 ns;
        rst <= '0';
        wait;
    end process;

    -- Debug output
    debug_proc: process(clk)
        variable v_instr_name : string(1 to 20);
    begin
        if rising_edge(clk) then
            if rst = '0' then
                case instr is
                    when INSTR_ADD => v_instr_name := "ADD                 ";
                    when INSTR_ADDI => v_instr_name := "ADDI                ";
                    when INSTR_SW => v_instr_name := "SW                  ";
                    when INSTR_BEQ => v_instr_name := "BEQ                 ";
                    when INSTR_BNE => v_instr_name := "BNE                 ";
                    when INSTR_LUI => v_instr_name := "LUI                 ";
                    when INSTR_JAL => v_instr_name := "JAL                 ";
                    when INSTR_JALR => v_instr_name := "JALR                ";
                    when others => v_instr_name := "OTHER               ";
                end case;
            end if;
        end if;
    end process;

end architecture;
