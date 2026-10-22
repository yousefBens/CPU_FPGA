library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity control_unitTb is
end control_unitTb;

architecture DUT of control_unitTb is

    constant CLK_PERIOD : time := 10 ns;

    -- ==========================================
    -- CLOCK & RESET
    -- ==========================================

    signal Clk : std_logic := '0';
    signal rst : std_logic := '1';

    -- ==========================================
    -- INSTRUCTION
    -- ==========================================

    signal opcode : std_logic_vector(3 downto 0) := "0000";

    -- ==========================================
    -- CONTROL UNIT OUTPUTS
    -- ==========================================

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

    -- ==========================================
    -- PROGRAM COUNTER
    -- ==========================================

    signal pc_load_data : std_logic_vector(7 downto 0) := x"00";
    signal pc_out       : std_logic_vector(7 downto 0);

    -- ==========================================
    -- ALU
    -- ==========================================

    signal alu_a      : std_logic_vector(7 downto 0) := x"00";
    signal alu_b      : std_logic_vector(7 downto 0) := x"00";

    signal alu_result : std_logic_vector(7 downto 0);

    signal alu_z      : std_logic;
    signal alu_c      : std_logic;
    signal alu_n      : std_logic;
    signal alu_v      : std_logic;

    -- ==========================================
    -- FLAGS REGISTER
    -- ==========================================

    signal flag_z : std_logic;
    signal flag_c : std_logic;
    signal flag_n : std_logic;
    signal flag_v : std_logic;

begin

    -- ==========================================
    -- CLOCK
    -- ==========================================

    Clk <= not Clk after CLK_PERIOD / 2;

    -- ==========================================
    -- CONTROL UNIT
    -- ==========================================

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

    -- ==========================================
    -- PROGRAM COUNTER
    -- ==========================================

    U_PC : entity work.program_counter
        port map (
            Clk          => Clk,
            rst          => rst,

            pc_enable    => pc_enable,
            pc_load      => pc_load,

            pc_load_data => pc_load_data,
            pc_out       => pc_out
        );

    -- ==========================================
    -- ALU
    -- ==========================================

    U_ALU : entity work.alu
        port map (
            A       => alu_a,
            B       => alu_b,

            ALU_OP  => alu_op,

            RESULT  => alu_result,

            Z       => alu_z,
            C       => alu_c,
            N       => alu_n,
            V       => alu_v
        );

    -- ==========================================
    -- FLAGS REGISTER
    -- ==========================================

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

    -- ==========================================
    -- TEST PROCESS
    -- ==========================================

    stimulus : process

        -- Attendre un front montant
        procedure next_cycle is
        begin
            wait until rising_edge(Clk);
            wait for 1 ns;
        end procedure;

        -- Vérifier le PC
        procedure check_pc(
            constant expected : in natural;
            constant test_name : in string
        ) is
        begin
            assert unsigned(pc_out) = to_unsigned(expected, 8)
                report test_name & ": INCORRECT PC"
                severity failure;
        end procedure;

        -- Aller de FETCH_ROM à EXECUTE
        procedure go_to_execute(
            constant test_opcode : in std_logic_vector(3 downto 0)
        ) is
        begin
            -- Précondition : FSM en FETCH_ROM
            wait until falling_edge(Clk);

            opcode <= test_opcode;

            -- FETCH_ROM -> FETCH_IR
            next_cycle;

            assert ir_enable = '1'
                report "FETCH_IR ERROR"
                severity failure;

            -- FETCH_IR -> DECODE
            next_cycle;

            -- DECODE -> EXECUTE
            next_cycle;
        end procedure;

        -- Vérifier l'absence d'écritures
        procedure check_no_writes is
        begin
            assert reg_write_enable = '0'
                report "UNEXPECTED REGISTER WRITE"
                severity failure;

            assert ram_write_enable = '0'
                report "UNEXPECTED RAM WRITE"
                severity failure;
        end procedure;

        -- ==========================================
        -- PROCEDURE CMP
        -- ==========================================

        procedure test_cmp(
            constant a_value    : in natural;
            constant b_value    : in natural;
            constant expected_z : in std_logic;
            constant expected_c : in std_logic;
            constant expected_n : in std_logic;
            constant expected_v : in std_logic;
            constant test_name  : in string
        ) is
            variable old_pc : natural;
        begin

            report "TEST CMP: " & test_name;

            old_pc := to_integer(unsigned(pc_out));

            -- Préparer les opérandes
            alu_a <= std_logic_vector(to_unsigned(a_value, 8));
            alu_b <= std_logic_vector(to_unsigned(b_value, 8));

            -- Sélectionner CMP
            go_to_execute("1110");

            -- CMP doit utiliser SUB
            assert alu_op = "001"
                report test_name & ": WRONG ALU OP"
                severity failure;

            -- Vérifier le résultat ALU
            assert unsigned(alu_result) =
                   to_unsigned((a_value + 256 - b_value) mod 256, 8)
                report test_name & ": WRONG ALU RESULT"
                severity failure;

            -- Vérifier les flags combinatoires
            assert alu_z = expected_z
                report test_name & ": WRONG ALU Z"
                severity failure;

            assert alu_c = expected_c
                report test_name & ": WRONG ALU C"
                severity failure;

            assert alu_n = expected_n
                report test_name & ": WRONG ALU N"
                severity failure;

            assert alu_v = expected_v
                report test_name & ": WRONG ALU V"
                severity failure;

            -- Vérifier les commandes CMP
            assert flags_write_enable = '1'
                report test_name & ": FLAGS WRITE DISABLED"
                severity failure;

            assert pc_enable = '1'
                report test_name & ": PC ENABLE DISABLED"
                severity failure;

            assert pc_load = '0'
                report test_name & ": UNEXPECTED PC LOAD"
                severity failure;

            check_no_writes;

            -- EXECUTE -> FETCH_ROM
            -- Les flags et le PC sont enregistrés
            next_cycle;

            -- Vérifier les flags enregistrés
            assert flag_z = expected_z
                report test_name & ": REGISTERED Z ERROR"
                severity failure;

            assert flag_c = expected_c
                report test_name & ": REGISTERED C ERROR"
                severity failure;

            assert flag_n = expected_n
                report test_name & ": REGISTERED N ERROR"
                severity failure;

            assert flag_v = expected_v
                report test_name & ": REGISTERED V ERROR"
                severity failure;

            -- PC + 1
            check_pc((old_pc + 1) mod 256, test_name);

            -- Plus aucune écriture flags
            assert flags_write_enable = '0'
                report test_name & ": FLAGS WRITE STILL ENABLED"
                severity failure;

            report test_name & " PASSED";

        end procedure;

        -- ==========================================
        -- PROCEDURE JZ
        -- ==========================================

        procedure test_jz(
            constant target      : in natural;
            constant expected_pc : in natural;
            constant expected_z  : in std_logic
        ) is
        begin

            report "TEST JZ";

            assert flag_z = expected_z
                report "JZ: WRONG Z FLAG"
                severity failure;

            go_to_execute("1101");

            pc_load_data <= std_logic_vector(to_unsigned(target, 8));

            wait for 1 ns;

            if expected_z = '1' then
                assert pc_load = '1' and pc_enable = '0'
                    report "JZ SHOULD BE TAKEN"
                    severity failure;
            else
                assert pc_load = '0' and pc_enable = '1'
                    report "JZ SHOULD NOT BE TAKEN"
                    severity failure;
            end if;

            next_cycle;

            check_pc(expected_pc, "JZ");

            report "JZ TEST PASSED";

        end procedure;

    begin

        report "======================================";
        report "STEP 7 - CMP INSTRUCTION TESTBENCH";
        report "======================================";

        -- ======================================
        -- RESET
        -- ======================================

        rst <= '1';
        next_cycle;

        check_pc(0, "RESET");

        assert flag_z = '0'
            report "RESET Z ERROR"
            severity failure;

        rst <= '0';

        -- ======================================
        -- TEST 1 : CMP 10, 10
        -- ======================================

        test_cmp(
            10, 10,
            '1', '0', '0', '0',
            "CMP EQUAL"
        );

        check_pc(1, "CMP EQUAL");

        -- ======================================
        -- TEST 2 : JZ 20 (Z = 1)
        -- ======================================

        test_jz(20, 20, '1');

        -- ======================================
        -- TEST 3 : CMP 10, 5
        -- ======================================

        test_cmp(
            10, 5,
            '0', '0', '0', '0',
            "CMP GREATER"
        );

        check_pc(21, "CMP GREATER");

        -- ======================================
        -- TEST 4 : JZ 30 (Z = 0)
        -- ======================================

        test_jz(30, 22, '0');

        -- ======================================
        -- TEST 5 : CMP 5, 10
        -- ======================================

        test_cmp(
            5, 10,
            '0', '1', '1', '0',
            "CMP LESS"
        );

        check_pc(23, "CMP LESS");

        -- ======================================
        -- TEST 6 : CMP 127, -1
        -- ======================================

        -- -1 est représenté par 255 (0xFF)
        test_cmp(
            127, 255,
            '0', '1', '1', '1',
            "CMP OVERFLOW"
        );

        check_pc(24, "CMP OVERFLOW");

        -- ======================================
        -- TEST 7 : HALT
        -- ======================================

        report "TEST HALT";

        go_to_execute("1111");

        next_cycle;

        assert halted = '1'
            report "HALT FAILED"
            severity failure;

        check_pc(24, "HALT");

        for i in 1 to 5 loop
            next_cycle;

            assert halted = '1'
                report "HALTED STATE LOST"
                severity failure;

            check_pc(24, "HALTED STABILITY");
            check_no_writes;
        end loop;

        report "HALT TEST PASSED";

        -- ======================================
        -- FINAL
        -- ======================================

        report "======================================";
        report "ALL CMP TESTS PASSED";
        report "======================================";

        wait;

    end process;

end DUT;