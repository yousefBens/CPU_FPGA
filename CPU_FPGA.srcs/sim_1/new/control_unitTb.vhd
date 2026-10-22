library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity control_unitTb is
end control_unitTb;

architecture DUT of control_unitTb is

    -- ================================================
    -- CLOCK
    -- ================================================

    constant CLK_PERIOD : time := 10 ns;

    -- ================================================
    -- INPUTS
    -- ================================================

    signal Clk    : std_logic := '0';
    signal rst    : std_logic := '1';

    signal opcode : std_logic_vector(3 downto 0) := "0000";
    signal flag_z : std_logic := '0';

    -- ================================================
    -- CONTROL UNIT OUTPUTS
    -- ================================================

    signal pc_enable          : std_logic;
    signal pc_load            : std_logic;

    signal ir_enable          : std_logic;

    signal reg_write_enable   : std_logic;
    signal reg_write_sel      : std_logic_vector(1 downto 0);

    signal ram_read_enable    : std_logic;
    signal ram_write_enable   : std_logic;

    signal alu_op             : std_logic_vector(2 downto 0);

    signal flags_write_enable : std_logic;
    signal halted             : std_logic;

    -- ================================================
    -- TEST DATAPATH SIGNALS
    -- ================================================

    signal alu_result     : std_logic_vector(7 downto 0) := x"0F";
    signal immediate_data : std_logic_vector(7 downto 0) := x"2A";

    signal write_data     : std_logic_vector(7 downto 0);

begin

    -- ================================================
    -- CLOCK GENERATION
    -- ================================================

    Clk <= not Clk after CLK_PERIOD / 2;


    -- ================================================
    -- CONTROL UNIT INSTANCE
    -- ================================================

    UUT : entity work.control_unit
        port map (

            Clk                => Clk,
            rst                => rst,

            opcode             => opcode,
            flag_z             => flag_z,

            pc_enable          => pc_enable,
            pc_load            => pc_load,

            ir_enable          => ir_enable,

            reg_write_enable   => reg_write_enable,
            reg_write_sel      => reg_write_sel,

            ram_read_enable    => ram_read_enable,
            ram_write_enable   => ram_write_enable,

            alu_op             => alu_op,

            flags_write_enable => flags_write_enable,
            halted             => halted
        );


    -- ================================================
    -- SIMULATED WRITEBACK MULTIPLEXER
    -- ================================================

    process(reg_write_sel, alu_result, immediate_data)
    begin

        case reg_write_sel is

            when "00" =>
                write_data <= alu_result;

            when "01" =>
                write_data <= immediate_data;

            when others =>
                write_data <= (others => '0');

        end case;

    end process;


    -- ================================================
    -- TEST PROCESS
    -- ================================================

    stimulus : process

        procedure next_cycle is
        begin
            wait until rising_edge(Clk);
            wait for 1 ns;
        end procedure;


        -- Verification d'une instruction
        -- Cette procedure commence en FETCH_ROM.

        procedure test_instruction(
            constant instruction_name : in string;
            constant test_opcode      : in std_logic_vector(3 downto 0);
            constant expected_sel     : in std_logic_vector(1 downto 0);
            constant expected_data    : in std_logic_vector(7 downto 0)
        ) is

        begin

            report "--------------------------------";
            report "TEST : " & instruction_name;
            report "--------------------------------";

            -- Appliquer l'opcode avant le prochain front
            wait until falling_edge(Clk);

            opcode <= test_opcode;

            wait for 1 ns;

            -- FETCH_ROM
            assert pc_enable = '0'
                report instruction_name & ": PC enabled in FETCH_ROM"
                severity error;

            assert reg_write_enable = '0'
                report instruction_name & ": Write enabled in FETCH_ROM"
                severity error;

            -- FETCH_ROM -> FETCH_IR
            next_cycle;

            assert ir_enable = '1'
                report instruction_name & ": FETCH_IR error"
                severity error;

            -- FETCH_IR -> DECODE
            next_cycle;

            assert ir_enable = '0'
                report instruction_name & ": DECODE error"
                severity error;

            -- DECODE -> EXECUTE
            next_cycle;

            assert reg_write_enable = '0'
                report instruction_name & ": Early register write"
                severity error;

            -- EXECUTE -> WRITEBACK
            next_cycle;

            assert reg_write_enable = '1'
                report instruction_name & ": WRITEBACK not enabled"
                severity error;

            assert reg_write_sel = expected_sel
                report instruction_name & ": Incorrect reg_write_sel"
                severity error;

            assert write_data = expected_data
                report instruction_name & ": Incorrect write_data"
                severity error;

            assert pc_enable = '1'
                report instruction_name & ": PC increment not enabled"
                severity error;

            -- WRITEBACK -> FETCH_ROM
            next_cycle;

            assert reg_write_enable = '0'
                report instruction_name & ": Write enable not cleared"
                severity error;

            assert pc_enable = '0'
                report instruction_name & ": PC enable not cleared"
                severity error;

            report instruction_name & " TEST PASSED";

        end procedure;


    begin

        report "====================================";
        report "CONTROL UNIT - STEP 3 TEST";
        report "====================================";


        -- =============================================
        -- RESET
        -- =============================================

        rst <= '1';

        next_cycle;

        assert ir_enable = '0'
            report "RESET ERROR"
            severity error;

        rst <= '0';

        report "RESET OK";


        -- =============================================
        -- NOP
        -- =============================================

        report "TEST : NOP";

        opcode <= "0000";

        -- FETCH_ROM -> FETCH_IR
        next_cycle;

        assert ir_enable = '1'
            report "NOP FETCH_IR ERROR"
            severity error;

        -- FETCH_IR -> DECODE
        next_cycle;

        -- DECODE -> EXECUTE
        next_cycle;

        assert pc_enable = '1'
            report "NOP PC ENABLE ERROR"
            severity error;

        assert reg_write_enable = '0'
            report "NOP REGISTER WRITE ERROR"
            severity error;

        -- EXECUTE -> FETCH_ROM
        next_cycle;

        report "NOP TEST PASSED";


        -- =============================================
        -- ARITHMETIC INSTRUCTIONS
        -- =============================================

        test_instruction("ADD", "0001", "00", x"0F");
        test_instruction("SUB", "0010", "00", x"0F");
        test_instruction("AND", "0011", "00", x"0F");
        test_instruction("OR",  "0100", "00", x"0F");
        test_instruction("XOR", "0101", "00", x"0F");
        test_instruction("NOT", "0110", "00", x"0F");
        test_instruction("SHL", "0111", "00", x"0F");
        test_instruction("SHR", "1000", "00", x"0F");


        -- =============================================
        -- LDI
        -- =============================================

        -- Immediate = 42 decimal = 0x2A
        immediate_data <= x"2A";

        test_instruction(
            "LDI",
            "1001",
            "01",
            x"2A"
        );


        report "====================================";
        report "ALL STEP 3 TESTS COMPLETED";
        report "====================================";

        wait;

    end process;

end DUT;