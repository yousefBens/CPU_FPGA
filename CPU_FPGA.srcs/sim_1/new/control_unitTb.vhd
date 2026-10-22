library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity control_unitTb is
end control_unitTb;

architecture DUT of control_unitTb is

    constant CLK_PERIOD : time := 10 ns;

    -- =====================================================
    -- CLOCK & RESET
    -- =====================================================

    signal Clk : std_logic := '0';
    signal rst : std_logic := '1';

    -- =====================================================
    -- INSTRUCTION
    -- =====================================================

    signal opcode : std_logic_vector(3 downto 0) := "0000";

    -- =====================================================
    -- CONTROL UNIT OUTPUTS
    -- =====================================================

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

    -- =====================================================
    -- PROGRAM COUNTER
    -- =====================================================

    signal pc_load_data : std_logic_vector(7 downto 0) := x"00";
    signal pc_out       : std_logic_vector(7 downto 0);

    -- =====================================================
    -- SIMULATED ALU FLAGS
    -- =====================================================

    signal alu_z : std_logic := '0';
    signal alu_c : std_logic := '0';
    signal alu_n : std_logic := '0';
    signal alu_v : std_logic := '0';

    -- =====================================================
    -- REGISTERED FLAGS
    -- =====================================================

    signal flag_z : std_logic;
    signal flag_c : std_logic;
    signal flag_n : std_logic;
    signal flag_v : std_logic;

begin

    -- =====================================================
    -- CLOCK GENERATION
    -- =====================================================

    Clk <= not Clk after CLK_PERIOD / 2;


    -- =====================================================
    -- CONTROL UNIT
    -- =====================================================

    U_CONTROL : entity work.control_unit
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
    -- PROGRAM COUNTER
    -- =====================================================

    U_PC : entity work.program_counter
        port map (

            Clk          => Clk,
            rst          => rst,

            pc_enable    => pc_enable,
            pc_load      => pc_load,

            pc_load_data => pc_load_data,

            pc_out       => pc_out
        );


    -- =====================================================
    -- FLAGS REGISTER
    -- =====================================================

    U_FLAGS : entity work.flags_register
        port map (

            Clk          => Clk,
            rst          => rst,

            write_enable => flags_write_enable,

            z_in         => alu_z,
            c_in         => alu_c,
            n_in         => alu_n,
            v_in         => alu_v,

            z_out        => flag_z,
            c_out        => flag_c,
            n_out        => flag_n,
            v_out        => flag_v
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


        -- Vérifier la valeur du PC
        procedure check_pc(
            constant expected : in natural;
            constant test_name : in string
        ) is
        begin

            assert unsigned(pc_out) = to_unsigned(expected, 8)
                report test_name & ": INCORRECT PC VALUE"
                severity failure;

        end procedure;


        -- Vérifier que toutes les commandes sont désactivées
        procedure check_no_activity is
        begin

            assert pc_enable = '0'
                report "PC ENABLE ACTIVE"
                severity failure;

            assert pc_load = '0'
                report "PC LOAD ACTIVE"
                severity failure;

            assert ir_enable = '0'
                report "IR ENABLE ACTIVE"
                severity failure;

            assert reg_write_enable = '0'
                report "REGISTER WRITE ACTIVE"
                severity failure;

            assert ram_read_enable = '0'
                report "RAM READ ACTIVE"
                severity failure;

            assert ram_write_enable = '0'
                report "RAM WRITE ACTIVE"
                severity failure;

            assert flags_write_enable = '0'
                report "FLAGS WRITE ACTIVE"
                severity failure;

        end procedure;


        -- =================================================
        -- Aller de FETCH_ROM vers EXECUTE
        -- =================================================

        procedure go_to_execute(
            constant test_opcode : in std_logic_vector(3 downto 0)
        ) is
        begin

            -- Précondition : state = FETCH_ROM
            wait until falling_edge(Clk);

            opcode <= test_opcode;

            wait for 1 ns;

            -- FETCH_ROM -> FETCH_IR
            next_cycle;

            assert ir_enable = '1'
                report "FETCH_IR ERROR"
                severity failure;

            -- FETCH_IR -> DECODE
            next_cycle;

            assert ir_enable = '0'
                report "DECODE ERROR"
                severity failure;

            -- DECODE -> EXECUTE
            next_cycle;

        end procedure;


        -- =================================================
        -- TEST NOP
        -- =================================================

        procedure test_nop(
            constant expected_pc : in natural
        ) is
        begin

            report "TEST NOP";

            go_to_execute("0000");

            assert pc_enable = '1'
                report "NOP: PC NOT ENABLED"
                severity failure;

            assert pc_load = '0'
                report "NOP: PC LOAD ACTIVE"
                severity failure;

            -- EXECUTE -> FETCH_ROM
            next_cycle;

            check_pc(expected_pc, "NOP");

            report "NOP TEST PASSED";

        end procedure;


        -- =================================================
        -- TEST JMP
        -- =================================================

        procedure test_jmp(
            constant target : in natural
        ) is
        begin

            report "TEST JMP";

            go_to_execute("1100");

            pc_load_data <= std_logic_vector(to_unsigned(target, 8));

            wait for 1 ns;

            assert pc_load = '1'
                report "JMP: PC LOAD NOT ENABLED"
                severity failure;

            assert pc_enable = '0'
                report "JMP: PC ENABLE SHOULD BE 0"
                severity failure;

            -- EXECUTE -> FETCH_ROM
            next_cycle;

            check_pc(target, "JMP");

            report "JMP TEST PASSED";

        end procedure;


        -- =================================================
        -- TEST HALT
        -- =================================================

        procedure test_halt is
        begin

            report "====================================";
            report "TEST HALT";
            report "====================================";

            -- La FSM doit être en FETCH_ROM
            go_to_execute("1111");

            -- Dans EXECUTE, HALT doit bloquer le PC
            assert pc_enable = '0'
                report "HALT: PC ENABLE ACTIVE IN EXECUTE"
                severity failure;

            assert pc_load = '0'
                report "HALT: PC LOAD ACTIVE IN EXECUTE"
                severity failure;

            assert reg_write_enable = '0'
                report "HALT: REGISTER WRITE ACTIVE IN EXECUTE"
                severity failure;

            assert ram_write_enable = '0'
                report "HALT: RAM WRITE ACTIVE IN EXECUTE"
                severity failure;

            -- EXECUTE -> HALTED
            next_cycle;

            assert halted = '1'
                report "HALT: CPU DID NOT ENTER HALTED"
                severity failure;

            check_no_activity;

            check_pc(20, "HALT");

            report "CPU ENTERED HALTED STATE";

        end procedure;


    begin

        report "========================================";
        report "STEP 6: HALT TESTBENCH";
        report "========================================";


        -- =================================================
        -- TEST 1 : RESET
        -- =================================================

        rst <= '1';

        next_cycle;

        check_pc(0, "RESET");

        assert halted = '0'
            report "RESET: HALTED SHOULD BE 0"
            severity failure;

        check_no_activity;

        rst <= '0';

        report "RESET TEST PASSED";


        -- =================================================
        -- TEST 2 : NOP
        -- =================================================

        test_nop(1);


        -- =================================================
        -- TEST 3 : JMP 20
        -- =================================================

        test_jmp(20);


        -- =================================================
        -- TEST 4 : HALT
        -- =================================================

        test_halt;


        -- =================================================
        -- TEST 5 : WAIT 10 CLOCK CYCLES
        -- =================================================

        report "TEST HALTED STABILITY - 10 CYCLES";

        for i in 1 to 10 loop

            next_cycle;

            assert halted = '1'
                report "HALTED LOST DURING WAIT"
                severity failure;

            check_no_activity;

            check_pc(20, "HALTED STABILITY");

        end loop;

        report "HALTED STABILITY TEST PASSED";


        -- =================================================
        -- TEST 6 : CHANGE OPCODE TO ADD
        -- =================================================

        report "TEST OPCODE CHANGE TO ADD";

        wait until falling_edge(Clk);

        opcode <= "0001";

        alu_z <= '1';
        alu_c <= '1';
        alu_n <= '1';
        alu_v <= '1';

        wait for 1 ns;

        check_no_activity;

        for i in 1 to 3 loop

            next_cycle;

            assert halted = '1'
                report "HALTED LOST AFTER ADD OPCODE"
                severity failure;

            check_no_activity;

            check_pc(20, "HALTED ADD");

        end loop;

        assert flag_z = '0' and
               flag_c = '0' and
               flag_n = '0' and
               flag_v = '0'
            report "FLAGS CHANGED WHILE HALTED"
            severity failure;

        report "ADD OPCODE IGNORED - PASSED";


        -- =================================================
        -- TEST 7 : CHANGE OPCODE TO STORE
        -- =================================================

        report "TEST OPCODE CHANGE TO STORE";

        wait until falling_edge(Clk);

        opcode <= "1011";

        wait for 1 ns;

        for i in 1 to 3 loop

            next_cycle;

            assert halted = '1'
                report "HALTED LOST AFTER STORE OPCODE"
                severity failure;

            check_no_activity;

            check_pc(20, "HALTED STORE");

        end loop;

        report "STORE OPCODE IGNORED - PASSED";


        -- =================================================
        -- TEST 8 : CHANGE OPCODE TO JMP
        -- =================================================

        report "TEST OPCODE CHANGE TO JMP";

        wait until falling_edge(Clk);

        opcode <= "1100";

        pc_load_data <= x"64"; -- Adresse 100

        wait for 1 ns;

        for i in 1 to 3 loop

            next_cycle;

            assert halted = '1'
                report "HALTED LOST AFTER JMP OPCODE"
                severity failure;

            check_no_activity;

            check_pc(20, "HALTED JMP");

        end loop;

        report "JMP OPCODE IGNORED - PASSED";


        -- =================================================
        -- TEST 9 : RESET WHILE HALTED
        -- =================================================

        report "TEST RESET WHILE HALTED";

        wait until falling_edge(Clk);

        rst <= '1';

        wait for 1 ns;

        -- Les commandes doivent être désactivées
        check_no_activity;

        assert halted = '0'
            report "HALTED NOT CLEARED DURING RESET"
            severity failure;

        -- Reset synchrone
        next_cycle;

        check_pc(0, "RESET AFTER HALT");

        assert halted = '0'
            report "HALTED NOT CLEARED AFTER RESET"
            severity failure;

        rst <= '0';

        report "RESET AFTER HALT TEST PASSED";


        -- =================================================
        -- TEST 10 : NOP AFTER RESET
        -- =================================================

        test_nop(1);


        -- =================================================
        -- FINAL RESULT
        -- =================================================

        report "========================================";
        report "ALL STEP 6 TESTS PASSED";
        report "========================================";

        wait;

    end process;

end DUT;