library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity control_unitTb is
end control_unitTb;

architecture DUT of control_unitTb is

    constant CLK_PERIOD : time := 10 ns;

    -- Clock & Reset
    signal Clk : std_logic := '0';
    signal rst : std_logic := '1';

    -- Instruction & Flags
    signal opcode : std_logic_vector(3 downto 0) := "0000";
    signal flag_z : std_logic := '0';

    -- Program Counter
    signal pc_enable : std_logic;
    signal pc_load   : std_logic;

    -- Instruction Register
    signal ir_enable : std_logic;

    -- Register File
    signal reg_write_enable : std_logic;
    signal reg_write_sel    : std_logic_vector(1 downto 0);

    -- Data RAM
    signal ram_read_enable  : std_logic;
    signal ram_write_enable : std_logic;

    -- ALU
    signal alu_op : std_logic_vector(2 downto 0);

    -- Flags Register
    signal flags_write_enable : std_logic;

    -- CPU Status
    signal halted : std_logic;

begin

    -- =====================================================
    -- CLOCK
    -- =====================================================

    Clk <= not Clk after CLK_PERIOD / 2;


    -- =====================================================
    -- CONTROL UNIT
    -- =====================================================

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


    -- =====================================================
    -- TEST PROCESS
    -- =====================================================

    stimulus : process

        -- Attendre un front montant puis la stabilisation
        procedure next_cycle is
        begin
            wait until rising_edge(Clk);
            wait for 1 ns;
        end procedure;


        -- Vérifier les signaux inactifs
        procedure check_idle is
        begin
            assert ram_read_enable = '0'
                report "Unexpected RAM read"
                severity error;

            assert ram_write_enable = '0'
                report "Unexpected RAM write"
                severity error;

            assert reg_write_enable = '0'
                report "Unexpected Register File write"
                severity error;

            assert pc_enable = '0'
                report "Unexpected PC increment"
                severity error;
        end procedure;


        -- =================================================
        -- TEST ALU / LDI
        -- =================================================

        procedure test_writeback_instruction(
            constant instruction_name : in string;
            constant test_opcode      : in std_logic_vector(3 downto 0);
            constant expected_sel     : in std_logic_vector(1 downto 0);
            constant expected_alu_op  : in std_logic_vector(2 downto 0)
        ) is
        begin

            report "TEST : " & instruction_name;

            -- La FSM doit être en FETCH_ROM
            wait until falling_edge(Clk);
            opcode <= test_opcode;
            wait for 1 ns;

            check_idle;

            -- FETCH_ROM -> FETCH_IR
            next_cycle;

            assert ir_enable = '1'
                report instruction_name & ": FETCH_IR ERROR"
                severity error;

            -- FETCH_IR -> DECODE
            next_cycle;

            check_idle;

            -- DECODE -> EXECUTE
            next_cycle;

            assert alu_op = expected_alu_op
                report instruction_name & ": ALU_OP ERROR"
                severity error;

            check_idle;

            -- EXECUTE -> WRITEBACK
            next_cycle;

            assert reg_write_enable = '1'
                report instruction_name & ": WRITEBACK ERROR"
                severity error;

            assert reg_write_sel = expected_sel
                report instruction_name & ": WRITEBACK MUX ERROR"
                severity error;

            assert pc_enable = '1'
                report instruction_name & ": PC ERROR"
                severity error;

            assert alu_op = expected_alu_op
                report instruction_name & ": ALU_OP changed in WRITEBACK"
                severity error;

            assert ram_read_enable = '0' and
                   ram_write_enable = '0'
                report instruction_name & ": Unexpected RAM access"
                severity error;

            -- WRITEBACK -> FETCH_ROM
            next_cycle;

            check_idle;

            report instruction_name & " TEST PASSED";

        end procedure;


        -- =================================================
        -- TEST LOAD
        -- =================================================

        procedure test_load is
        begin

            report "================================";
            report "TEST LOAD";
            report "================================";

            wait until falling_edge(Clk);
            opcode <= "1010";
            wait for 1 ns;

            -- FETCH_ROM
            check_idle;

            -- FETCH_ROM -> FETCH_IR
            next_cycle;

            assert ir_enable = '1'
                report "LOAD: FETCH_IR ERROR"
                severity error;

            -- FETCH_IR -> DECODE
            next_cycle;

            check_idle;

            -- DECODE -> EXECUTE
            next_cycle;

            check_idle;

            -- EXECUTE -> MEMORY
            next_cycle;

            assert ram_read_enable = '1'
                report "LOAD: RAM READ NOT ENABLED"
                severity error;

            assert ram_write_enable = '0'
                report "LOAD: RAM WRITE ENABLED"
                severity error;

            assert reg_write_enable = '0'
                report "LOAD: REGISTER WRITE TOO EARLY"
                severity error;

            assert pc_enable = '0'
                report "LOAD: PC INCREMENT TOO EARLY"
                severity error;

            -- MEMORY -> WRITEBACK
            next_cycle;

            assert ram_read_enable = '0'
                report "LOAD: RAM READ STILL ENABLED"
                severity error;

            assert reg_write_enable = '1'
                report "LOAD: REGISTER WRITE NOT ENABLED"
                severity error;

            assert reg_write_sel = "10"
                report "LOAD: RAM DATA NOT SELECTED"
                severity error;

            assert pc_enable = '1'
                report "LOAD: PC NOT ENABLED"
                severity error;

            -- WRITEBACK -> FETCH_ROM
            next_cycle;

            check_idle;

            report "LOAD TEST PASSED";

        end procedure;


        -- =================================================
        -- TEST STORE
        -- =================================================

        procedure test_store is
        begin

            report "================================";
            report "TEST STORE";
            report "================================";

            wait until falling_edge(Clk);
            opcode <= "1011";
            wait for 1 ns;

            -- FETCH_ROM
            check_idle;

            -- FETCH_ROM -> FETCH_IR
            next_cycle;

            assert ir_enable = '1'
                report "STORE: FETCH_IR ERROR"
                severity error;

            -- FETCH_IR -> DECODE
            next_cycle;

            check_idle;

            -- DECODE -> EXECUTE
            next_cycle;

            check_idle;

            -- EXECUTE -> MEMORY
            next_cycle;

            assert ram_write_enable = '1'
                report "STORE: RAM WRITE NOT ENABLED"
                severity error;

            assert ram_read_enable = '0'
                report "STORE: RAM READ ENABLED"
                severity error;

            assert reg_write_enable = '0'
                report "STORE: REGISTER WRITE ENABLED"
                severity error;

            assert pc_enable = '1'
                report "STORE: PC NOT ENABLED"
                severity error;

            -- MEMORY -> FETCH_ROM
            next_cycle;

            check_idle;

            report "STORE TEST PASSED";

        end procedure;


    begin

        report "====================================";
        report "CONTROL UNIT - STEP 4 TESTBENCH";
        report "====================================";


        -- =================================================
        -- RESET
        -- =================================================

        rst <= '1';

        next_cycle;

        check_idle;

        rst <= '0';

        report "RESET TEST PASSED";


        -- =================================================
        -- NOP
        -- =================================================

        report "TEST NOP";

        opcode <= "0000";

        next_cycle; -- FETCH_IR
        assert ir_enable = '1'
            report "NOP FETCH_IR ERROR"
            severity error;

        next_cycle; -- DECODE
        check_idle;

        next_cycle; -- EXECUTE

        assert pc_enable = '1'
            report "NOP PC ERROR"
            severity error;

        assert reg_write_enable = '0'
            report "NOP REGISTER WRITE ERROR"
            severity error;

        next_cycle; -- FETCH_ROM
        check_idle;

        report "NOP TEST PASSED";


        -- =================================================
        -- ALU INSTRUCTIONS
        -- =================================================

        test_writeback_instruction("ADD", "0001", "00", "000");
        test_writeback_instruction("SUB", "0010", "00", "001");
        test_writeback_instruction("AND", "0011", "00", "010");
        test_writeback_instruction("OR",  "0100", "00", "011");
        test_writeback_instruction("XOR", "0101", "00", "100");
        test_writeback_instruction("NOT", "0110", "00", "101");
        test_writeback_instruction("SHL", "0111", "00", "110");
        test_writeback_instruction("SHR", "1000", "00", "111");


        -- =================================================
        -- LDI
        -- =================================================

        test_writeback_instruction("LDI", "1001", "01", "000");


        -- =================================================
        -- LOAD
        -- =================================================

        test_load;


        -- =================================================
        -- STORE
        -- =================================================

        test_store;


        report "====================================";
        report "ALL STEP 4 TESTS COMPLETED";
        report "====================================";

        wait;

    end process;

end DUT;