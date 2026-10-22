library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity control_unitTb is
end control_unitTb;

architecture DUT of control_unitTb is

    constant CLK_PERIOD : time := 10 ns;  -- 100 MHz


    signal Clk    : std_logic := '0';
    signal rst    : std_logic := '1';

    signal opcode : std_logic_vector(3 downto 0) := "0000";
    signal flag_z : std_logic := '0';



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

begin

    Clk <= not Clk after CLK_PERIOD / 2;


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


    process

        -- Attendre un front montant puis stabilisation
        procedure next_cycle is
        begin
            wait until rising_edge(Clk);
            wait for 1 ns;
        end procedure;

        -- Verifier les commandes inactives
        procedure check_unused is
        begin
            assert pc_load = '0'
                report "ERROR: pc_load"
                severity error;

            assert ram_read_enable = '0'
                report "ERROR: ram_read_enable"
                severity error;

            assert ram_write_enable = '0'
                report "ERROR: ram_write_enable"
                severity error;

            assert flags_write_enable = '0'
                report "ERROR: flags_write_enable"
                severity error;

            assert halted = '0'
                report "ERROR: halted"
                severity error;
        end procedure;

    begin

        report "====================================";
        report "START CONTROL UNIT TEST";
        report "====================================";


        -- =================================================
        -- TEST 1 : RESET
        -- =================================================

        report "TEST 1 : RESET";

        rst <= '1';
        opcode <= "0000";

        next_cycle;

        assert pc_enable = '0'
            report "RESET ERROR: pc_enable"
            severity error;

        assert ir_enable = '0'
            report "RESET ERROR: ir_enable"
            severity error;

        assert reg_write_enable = '0'
            report "RESET ERROR: reg_write_enable"
            severity error;

        check_unused;

        rst <= '0';

        report "RESET OK";


        -- =================================================
        -- TEST 2 : NOP
        -- =================================================

        report "====================================";
        report "TEST 2 : NOP";
        report "====================================";

        -- FETCH_ROM
        assert pc_enable = '0'
            report "NOP FETCH_ROM: pc_enable should be 0"
            severity error;

        assert ir_enable = '0'
            report "NOP FETCH_ROM: ir_enable should be 0"
            severity error;

        next_cycle;

        -- FETCH_IR
        assert ir_enable = '1'
            report "NOP FETCH_IR: ir_enable should be 1"
            severity error;

        assert pc_enable = '0'
            report "NOP FETCH_IR: pc_enable should be 0"
            severity error;

        next_cycle;

        -- DECODE
        assert ir_enable = '0'
            report "NOP DECODE: ir_enable should be 0"
            severity error;

        assert pc_enable = '0'
            report "NOP DECODE: pc_enable should be 0"
            severity error;

        next_cycle;

        -- EXECUTE
        assert pc_enable = '1'
            report "NOP EXECUTE: pc_enable should be 1"
            severity error;

        assert reg_write_enable = '0'
            report "NOP EXECUTE: reg_write_enable should be 0"
            severity error;

        next_cycle;

        -- Retour FETCH_ROM
        assert pc_enable = '0'
            report "NOP: PC enable should return to 0"
            severity error;

        assert reg_write_enable = '0'
            report "NOP: Register File should not be written"
            severity error;

        check_unused;

        report "NOP TEST PASSED";


        -- =================================================
        -- TEST 3 : ADD
        -- =================================================

        report "====================================";
        report "TEST 3 : ADD";
        report "====================================";

        opcode <= "0001";
        wait for 1 ns;

        -- FETCH_ROM
        assert pc_enable = '0'
            report "ADD FETCH_ROM: pc_enable should be 0"
            severity error;

        next_cycle;

        -- FETCH_IR
        assert ir_enable = '1'
            report "ADD FETCH_IR: ir_enable should be 1"
            severity error;

        next_cycle;

        -- DECODE
        assert ir_enable = '0'
            report "ADD DECODE: ir_enable should be 0"
            severity error;

        assert reg_write_enable = '0'
            report "ADD DECODE: reg_write_enable should be 0"
            severity error;

        next_cycle;

        -- EXECUTE
        assert alu_op = "000"
            report "ADD EXECUTE: wrong ALU operation"
            severity error;

        assert reg_write_enable = '0'
            report "ADD EXECUTE: register write too early"
            severity error;

        assert pc_enable = '0'
            report "ADD EXECUTE: PC should not increment yet"
            severity error;

        next_cycle;

        -- WRITEBACK
        assert reg_write_enable = '1'
            report "ADD WRITEBACK: reg_write_enable should be 1"
            severity error;

        assert reg_write_sel = "00"
            report "ADD WRITEBACK: ALU result not selected"
            severity error;

        assert pc_enable = '1'
            report "ADD WRITEBACK: pc_enable should be 1"
            severity error;

        check_unused;

        next_cycle;

        -- Retour FETCH_ROM
        assert reg_write_enable = '0'
            report "ADD: reg_write_enable should return to 0"
            severity error;

        assert pc_enable = '0'
            report "ADD: pc_enable should return to 0"
            severity error;

        report "ADD TEST PASSED";


        -- =================================================
        -- TEST 4 : RESET DURING EXECUTION
        -- =================================================

        report "====================================";
        report "TEST 4 : RESET DURING EXECUTION";
        report "====================================";

        -- FETCH_ROM -> FETCH_IR
        next_cycle;

        assert ir_enable = '1'
            report "RESET TEST: expected FETCH_IR"
            severity error;

        -- Reset pendant FETCH_IR
        rst <= '1';

        next_cycle;

        -- Retour FETCH_ROM
        assert ir_enable = '0'
            report "RESET TEST: FSM did not return to FETCH_ROM"
            severity error;

        assert pc_enable = '0'
            report "RESET TEST: pc_enable should be 0"
            severity error;

        rst <= '0';

        report "RESET DURING EXECUTION PASSED";


        -- =================================================
        -- END
        -- =================================================

        report "====================================";
        report "ALL CONTROL UNIT TESTS COMPLETED";
        report "====================================";

        wait;

    end process;

end DUT;