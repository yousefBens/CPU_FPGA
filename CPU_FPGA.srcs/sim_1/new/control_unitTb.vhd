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

    -- Control Unit Inputs
    signal opcode : std_logic_vector(3 downto 0) := "0000";
    signal flag_z : std_logic := '0';

    -- Control Unit Outputs
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

    -- ALU Signals
    signal A      : std_logic_vector(7 downto 0) := x"00";
    signal B      : std_logic_vector(7 downto 0) := x"00";
    signal RESULT : std_logic_vector(7 downto 0);

    signal Z : std_logic;
    signal C : std_logic;
    signal N : std_logic;
    signal V : std_logic;

begin

    -- =====================================================
    -- CLOCK GENERATION
    -- =====================================================

    Clk <= not Clk after CLK_PERIOD / 2;


    -- =====================================================
    -- CONTROL UNIT
    -- =====================================================

    UUT_CONTROL : entity work.control_unit
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
    -- ALU
    -- =====================================================

    UUT_ALU : entity work.alu
        port map (
            A      => A,
            B      => B,
            ALU_OP => alu_op,

            RESULT => RESULT,

            Z => Z,
            C => C,
            N => N,
            V => V
        );


    -- =====================================================
    -- TEST PROCESS
    -- =====================================================

    stimulus : process

        procedure next_cycle is
        begin
            wait until rising_edge(Clk);
            wait for 1 ns;
        end procedure;


        -- Test d'une instruction arithmetique
        procedure test_instruction(
            constant instruction_name : in string;
            constant test_opcode      : in std_logic_vector(3 downto 0);
            constant expected_alu_op  : in std_logic_vector(2 downto 0);
            constant input_a          : in std_logic_vector(7 downto 0);
            constant input_b          : in std_logic_vector(7 downto 0);
            constant expected_result  : in std_logic_vector(7 downto 0)
        ) is
        begin

            report "------------------------------------";
            report "TEST : " & instruction_name;
            report "------------------------------------";

            -- La procedure commence en FETCH_ROM.
            -- Changer les entrees avant le prochain front.
            wait until falling_edge(Clk);

            opcode <= test_opcode;
            A <= input_a;
            B <= input_b;

            wait for 1 ns;

            -- FETCH_ROM
            assert pc_enable = '0'
                report instruction_name & ": PC enabled during FETCH_ROM"
                severity error;

            assert reg_write_enable = '0'
                report instruction_name & ": Register write during FETCH_ROM"
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

            -- Verification du decodage
            assert alu_op = expected_alu_op
                report instruction_name & ": Incorrect ALU_OP"
                severity error;

            -- Verification du calcul ALU
            assert RESULT = expected_result
                report instruction_name & ": Incorrect ALU RESULT"
                severity error;

            assert reg_write_enable = '0'
                report instruction_name & ": Register write too early"
                severity error;

            assert pc_enable = '0'
                report instruction_name & ": PC increment too early"
                severity error;

            -- EXECUTE -> WRITEBACK
            next_cycle;

            assert reg_write_enable = '1'
                report instruction_name & ": WRITEBACK not enabled"
                severity error;

            assert reg_write_sel = "00"
                report instruction_name & ": ALU result not selected"
                severity error;

            assert pc_enable = '1'
                report instruction_name & ": PC increment not enabled"
                severity error;

            -- WRITEBACK -> FETCH_ROM
            next_cycle;

            assert reg_write_enable = '0'
                report instruction_name & ": Register write remains enabled"
                severity error;

            assert pc_enable = '0'
                report instruction_name & ": PC enable remains active"
                severity error;

            report instruction_name & " TEST PASSED";

        end procedure;


    begin

        report "====================================";
        report "CONTROL UNIT + ALU TESTBENCH";
        report "====================================";


        -- =================================================
        -- RESET
        -- =================================================

        rst <= '1';

        next_cycle;

        rst <= '0';

        report "RESET COMPLETED";


        -- =================================================
        -- ADD
        -- 10 + 5 = 15
        -- =================================================

        test_instruction(
            "ADD",
            "0001",
            "000",
            x"0A",
            x"05",
            x"0F"
        );


        -- =================================================
        -- SUB
        -- 10 - 5 = 5
        -- =================================================

        test_instruction(
            "SUB",
            "0010",
            "001",
            x"0A",
            x"05",
            x"05"
        );


        -- =================================================
        -- AND
        -- 0xAA AND 0x0F = 0x0A
        -- =================================================

        test_instruction(
            "AND",
            "0011",
            "010",
            x"AA",
            x"0F",
            x"0A"
        );


        -- =================================================
        -- OR
        -- 0xA0 OR 0x0F = 0xAF
        -- =================================================

        test_instruction(
            "OR",
            "0100",
            "011",
            x"A0",
            x"0F",
            x"AF"
        );


        -- =================================================
        -- XOR
        -- 0xAA XOR 0xFF = 0x55
        -- =================================================

        test_instruction(
            "XOR",
            "0101",
            "100",
            x"AA",
            x"FF",
            x"55"
        );


        -- =================================================
        -- NOT
        -- NOT 0xAA = 0x55
        -- =================================================

        test_instruction(
            "NOT",
            "0110",
            "101",
            x"AA",
            x"00",
            x"55"
        );


        -- =================================================
        -- SHL
        -- 0x05 << 1 = 0x0A
        -- =================================================

        test_instruction(
            "SHL",
            "0111",
            "110",
            x"05",
            x"00",
            x"0A"
        );


        -- =================================================
        -- SHR
        -- 0x0A >> 1 = 0x05
        -- =================================================

        test_instruction(
            "SHR",
            "1000",
            "111",
            x"0A",
            x"00",
            x"05"
        );


        report "====================================";
        report "ALL ARITHMETIC TESTS COMPLETED";
        report "====================================";

        wait;

    end process;

end DUT;