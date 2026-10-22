library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity instruction_registerTb is
--  Port ( );
end instruction_registerTb;

architecture DUT of instruction_registerTb is

    constant Clock_Freq     : integer  := 100_000_000;
    constant ClockPeriod    : time     := 1 sec / Clock_Freq;
    
    signal Clk        : std_logic := '0';
    signal rst        : std_logic := '1';
    
    signal ir_enable        : std_logic := '0';
    signal Instruction_in   : std_logic_vector(15 downto 0);
    signal Instruction_out   : std_logic_vector(15 downto 0);
    
begin
    i_IR : entity work.instruction_register(rtl)
        port map (
            Clk      => Clk,
            rst     => rst,
            
            ir_enable => ir_enable,
            Instruction_in => Instruction_in,
            Instruction_out => Instruction_out
        );
        
    Clk <= not Clk after ClockPeriod / 2;
    
    process
    begin

        --------------------------------------------------
        -- TEST 1 : RESET
        --------------------------------------------------

        rst <= '1';
        ir_enable <= '0';
        Instruction_in <= x"1234";

        wait until rising_edge(Clk);
        wait for 1 ns;

        assert Instruction_out = x"0000"
            report "ERROR : RESET"
            severity error;

        --------------------------------------------------
        -- TEST 2 : LOAD 0x1234
        --------------------------------------------------

        rst <= '0';
        ir_enable <= '1';
        Instruction_in <= x"1234";

        wait until rising_edge(Clk);
        wait for 1 ns;

        assert Instruction_out = x"1234"
            report "ERROR : LOAD 0x1234"
            severity error;

        --------------------------------------------------
        -- TEST 3 : HOLD
        --------------------------------------------------

        ir_enable <= '0';
        Instruction_in <= x"5678";

        wait until rising_edge(Clk);
        wait for 1 ns;

        assert Instruction_out = x"1234"
            report "ERROR : HOLD"
            severity error;

        --------------------------------------------------
        -- TEST 4 : LOAD 0xABCD
        --------------------------------------------------

        ir_enable <= '1';
        Instruction_in <= x"ABCD";

        wait until rising_edge(Clk);
        wait for 1 ns;

        assert Instruction_out = x"ABCD"
            report "ERROR : LOAD 0xABCD"
            severity error;

        --------------------------------------------------
        -- TEST 5 : HOLD DURING MULTIPLE CLOCK CYCLES
        --------------------------------------------------

        ir_enable <= '0';
        Instruction_in <= x"F001";

        for i in 1 to 3 loop

            wait until rising_edge(Clk);
            wait for 1 ns;

            assert Instruction_out = x"ABCD"
                report "ERROR : HOLD MULTIPLE CYCLES"
                severity error;

        end loop;

        --------------------------------------------------
        -- TEST 6 : RESET PRIORITY
        --------------------------------------------------

        rst <= '1';
        ir_enable <= '1';
        Instruction_in <= x"FFFF";

        wait until rising_edge(Clk);
        wait for 1 ns;

        assert Instruction_out = x"0000"
            report "ERROR : RESET PRIORITY"
            severity error;

        --------------------------------------------------
        -- TEST 7 : INPUT CHANGE WITHOUT CLOCK EDGE
        --------------------------------------------------

        rst <= '0';
        ir_enable <= '1';
        Instruction_in <= x"AAAA";

        -- We are 1 ns after a rising edge.
        -- No new rising edge should occur in the next 2 ns.

        wait for 2 ns;

        assert Instruction_out = x"0000"
            report "ERROR : OUTPUT CHANGED WITHOUT CLOCK"
            severity error;

        --------------------------------------------------
        -- TEST 8 : LOAD AFTER NEXT RISING EDGE
        --------------------------------------------------

        wait until rising_edge(Clk);
        wait for 1 ns;

        assert Instruction_out = x"AAAA"
            report "ERROR : LOAD AFTER CLOCK"
            severity error;

        --------------------------------------------------
        -- END OF TESTS
        --------------------------------------------------

        report "ALL INSTRUCTION REGISTER TESTS PASSED"
            severity note;

        wait;

    end process;
    
end DUT;
