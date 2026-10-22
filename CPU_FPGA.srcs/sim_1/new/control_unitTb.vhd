library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity control_unitTb is
end control_unitTb;

architecture DUT of control_unitTb is

    constant CLK_PERIOD : time := 10 ns;

    -- ================================================
    -- CLOCK & RESET
    -- ================================================

    signal Clk : std_logic := '0';
    signal rst : std_logic := '1';

    -- ================================================
    -- INSTRUCTION
    -- ================================================

    signal opcode : std_logic_vector(3 downto 0) := "0000";

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
    -- PROGRAM COUNTER
    -- ================================================

    signal pc_load_data : std_logic_vector(7 downto 0) := x"00";
    signal pc_out       : std_logic_vector(7 downto 0);

    -- ================================================
    -- SIMULATED ALU FLAGS
    -- ================================================

    signal alu_z : std_logic := '0';
    signal alu_c : std_logic := '0';
    signal alu_n : std_logic := '0';
    signal alu_v : std_logic := '0';

    -- ================================================
    -- REGISTERED FLAGS
    -- ================================================

    signal flag_z : std_logic;
    signal flag_c : std_logic;
    signal flag_n : std_logic;
    signal flag_v : std_logic;

begin

    -- ================================================
    -- CLOCK
    -- ================================================

    Clk <= not Clk after CLK_PERIOD / 2;


    -- ================================================
    -- CONTROL UNIT
    -- ================================================

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


    -- ================================================
    -- PROGRAM COUNTER
    -- ================================================

    U_PC : entity work.program_counter
        port map (

            Clk          => Clk,
            rst          => rst,

            pc_enable    => pc_enable,
            pc_load      => pc_load,

            pc_load_data => pc_load_data,

            pc_out       => pc_out
        );


    -- ================================================
    -- FLAGS REGISTER
    -- ================================================

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


    -- ================================================
    -- TEST PROCESS
    -- ================================================

    stimulus : process

        -- Attendre un front montant et la stabilisation
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


        -- Vérifier que les commandes sont désactivées
        procedure check_idle is
        begin

            assert pc_enable = '0'
                report "Unexpected PC increment"
                severity failure;

            assert pc_load = '0'
                report "Unexpected PC load"
                severity failure;

            assert reg_write_enable = '0'
                report "Unexpected register write"
                severity failure;

            assert ram_read_enable = '0'
                report "Unexpected RAM read"
                severity failure;

            assert ram_write_enable = '0'
                report "Unexpected RAM write"
                severity failure;

            assert flags_write_enable = '0'
                report "Unexpected flags write"
                severity failure;

        end procedure;


        -- ============================================
        -- Aller de FETCH_ROM vers EXECUTE
        -- ============================================

        procedure go_to_execute(
            constant test_opcode : in std_logic_vector(3 downto 0)
        ) is
        begin

            -- Précondition : la FSM est en FETCH_ROM
            wait until falling_edge(Clk);

            opcode <= test_opcode;

            wait for 1 ns;

            check_idle;

            -- FETCH_ROM -> FETCH_IR
            next_cycle;

            assert ir_enable = '1'
                report "FETCH_IR ERROR"
                severity failure;

            -- FETCH_IR -> DECODE
            next_cycle;

            check_idle;

            -- DECODE -> EXECUTE
            next_cycle;

        end procedure;


        -- ============================================
        -- Test d'une instruction JMP
        -- ============================================

        procedure test_jmp(
            constant target : in natural
        ) is
        begin

            report "TEST JMP";

            go_to_execute("1100");

            pc_load_data <= std_logic_vector(to_unsigned(target, 8));

            wait for 1 ns;

            assert pc_load = '1'
                report "JMP: pc_load should be 1"
                severity failure;

            assert pc_enable = '0'
                report "JMP: pc_enable should be 0"
                severity failure;

            -- EXECUTE -> FETCH_ROM
            next_cycle;

            check_pc(target, "JMP");

            check_idle;

            report "JMP TEST PASSED";

        end procedure;


        -- ============================================
        -- Test JZ
        -- ============================================

        procedure test_jz(
            constant target       : in natural;
            constant expected_pc  : in natural;
            constant expected_z   : in std_logic
        ) is
        begin

            report "TEST JZ";

            assert flag_z = expected_z
                report "JZ: Unexpected Z flag"
                severity failure;

            go_to_execute("1101");

            pc_load_data <= std_logic_vector(to_unsigned(target, 8));

            wait for 1 ns;

            if expected_z = '1' then

                assert pc_load = '1'
                    report "JZ: pc_load should be 1"
                    severity failure;

                assert pc_enable = '0'
                    report "JZ: pc_enable should be 0"
                    severity failure;

            else

                assert pc_load = '0'
                    report "JZ: pc_load should be 0"
                    severity failure;

                assert pc_enable = '1'
                    report "JZ: pc_enable should be 1"
                    severity failure;

            end if;

            -- EXECUTE -> FETCH_ROM
            next_cycle;

            check_pc(expected_pc, "JZ");

            check_idle;

            report "JZ TEST PASSED";

        end procedure;


        -- ============================================
        -- Test d'une instruction ALU
        -- ============================================

        procedure test_alu_flags(
            constant test_opcode : in std_logic_vector(3 downto 0);
            constant expected_op : in std_logic_vector(2 downto 0);
            constant expected_z  : in std_logic;
            constant expected_c  : in std_logic;
            constant expected_n  : in std_logic;
            constant expected_v  : in std_logic
        ) is
        begin

            report "TEST ALU FLAGS";

            -- Préparer les flags simulés avant EXECUTE
            alu_z <= expected_z;
            alu_c <= expected_c;
            alu_n <= expected_n;
            alu_v <= expected_v;

            go_to_execute(test_opcode);

            assert alu_op = expected_op
                report "ALU OP ERROR"
                severity failure;

            assert flags_write_enable = '1'
                report "FLAGS WRITE NOT ENABLED"
                severity failure;

            assert reg_write_enable = '0'
                report "REGISTER WRITE TOO EARLY"
                severity failure;

            -- EXECUTE -> WRITEBACK
            -- Capture des flags sur ce front
            next_cycle;

            assert flag_z = expected_z
                report "Z FLAG ERROR"
                severity failure;

            assert flag_c = expected_c
                report "C FLAG ERROR"
                severity failure;

            assert flag_n = expected_n
                report "N FLAG ERROR"
                severity failure;

            assert flag_v = expected_v
                report "V FLAG ERROR"
                severity failure;

            assert flags_write_enable = '0'
                report "FLAGS WRITE STILL ENABLED"
                severity failure;

            assert reg_write_enable = '1'
                report "WRITEBACK ERROR"
                severity failure;

            assert reg_write_sel = "00"
                report "ALU RESULT NOT SELECTED"
                severity failure;

            assert pc_enable = '1'
                report "PC NOT ENABLED"
                severity failure;

            assert alu_op = expected_op
                report "ALU OP CHANGED IN WRITEBACK"
                severity failure;

            -- WRITEBACK -> FETCH_ROM
            next_cycle;

            check_idle;

            report "ALU FLAGS TEST PASSED";

        end procedure;


    begin

        report "========================================";
        report "STEP 5: JMP / JZ / FLAGS TESTBENCH";
        report "========================================";


        -- ============================================
        -- TEST 1 : RESET
        -- ============================================

        rst <= '1';

        next_cycle;

        check_pc(0, "RESET");

        assert flag_z = '0' and
               flag_c = '0' and
               flag_n = '0' and
               flag_v = '0'
            report "RESET FLAGS ERROR"
            severity failure;

        check_idle;

        rst <= '0';

        report "RESET TEST PASSED";


        -- ============================================
        -- TEST 2 : NOP
        -- ============================================

        report "TEST NOP";

        go_to_execute("0000");

        assert pc_enable = '1'
            report "NOP: PC NOT ENABLED"
            severity failure;

        next_cycle;

        check_pc(1, "NOP");

        check_idle;

        report "NOP TEST PASSED";


        -- ============================================
        -- TEST 3 : JMP 20
        -- ============================================

        test_jmp(20);


        -- ============================================
        -- TEST 4 : JZ 30 AVEC Z = 0
        -- ============================================

        test_jz(
            30,
            21,
            '0'
        );


        -- ============================================
        -- TEST 5 : SUB -> Z = 1
        -- ============================================

        test_alu_flags(
            "0010",  -- SUB
            "001",   -- ALU SUB
            '1',     -- Z
            '0',     -- C
            '0',     -- N
            '0'      -- V
        );

        check_pc(22, "SUB");


        -- ============================================
        -- TEST 6 : JZ 40 AVEC Z = 1
        -- ============================================

        test_jz(
            40,
            40,
            '1'
        );


        -- ============================================
        -- TEST 7 : ADD -> Z = 0
        -- ============================================

        test_alu_flags(
            "0001",  -- ADD
            "000",   -- ALU ADD
            '0',     -- Z
            '1',     -- C
            '1',     -- N
            '0'      -- V
        );

        check_pc(41, "ADD");


        -- =============================================
        -- TEST 8 : JZ 50 AVEC Z = 0
        -- ============================================

        test_jz(
            50,
            42,
            '0'
        );


        -- ============================================
        -- FINAL RESULT
        -- ============================================

        report "========================================";
        report "ALL STEP 5 TESTS PASSED";
        report "========================================";

        wait;

    end process;

end DUT;