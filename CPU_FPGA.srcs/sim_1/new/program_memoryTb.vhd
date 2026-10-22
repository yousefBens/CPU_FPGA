library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity program_memoryTb is
end program_memoryTb;

architecture tb of program_memoryTb is

    constant CLK_PERIOD : time := 10 ns;

    signal Clk : std_logic := '0';

    signal addr : std_logic_vector(7 downto 0)
        := (others => '0');

    signal data_out : std_logic_vector(15 downto 0);

begin

    i_rom : entity work.program_memory(rtl)
        port map (
            Clk      => Clk,
            addr     => addr,
            data_out => data_out
        );
        
    Clk <= not Clk after CLK_PERIOD / 2;
    
    process
    begin

        --------------------------------------------------
        -- TEST 1 : ADDRESS 0
        --------------------------------------------------

        addr <= x"00";

        wait until rising_edge(Clk);
        wait for 1 ns;

        assert data_out = x"1234"
            report "ERROR ROM ADDRESS 0"
            severity error;

        --------------------------------------------------
        -- TEST 2 : ADDRESS 1
        --------------------------------------------------

        addr <= x"01";

        wait until rising_edge(Clk);
        wait for 1 ns;

        assert data_out = x"5678"
            report "ERROR ROM ADDRESS 1"
            severity error;

        --------------------------------------------------
        -- TEST 3 : ADDRESS 2
        --------------------------------------------------

        addr <= x"02";

        wait until rising_edge(Clk);
        wait for 1 ns;

        assert data_out = x"ABCD"
            report "ERROR ROM ADDRESS 2"
            severity error;

        --------------------------------------------------
        -- TEST 4 : ADDRESS 3
        --------------------------------------------------

        addr <= x"03";

        wait until rising_edge(Clk);
        wait for 1 ns;

        assert data_out = x"F001"
            report "ERROR ROM ADDRESS 3"
            severity error;

        --------------------------------------------------
        -- TEST 5 : UNINITIALIZED ADDRESS
        --------------------------------------------------

        addr <= x"20";

        wait until rising_edge(Clk);
        wait for 1 ns;

        assert data_out = x"0000"
            report "ERROR ROM DEFAULT VALUE"
            severity error;

        --------------------------------------------------
        -- TEST 6 : ADDRESS FF
        --------------------------------------------------

        addr <= x"FF";

        wait until rising_edge(Clk);
        wait for 1 ns;

        assert data_out = x"0000"
            report "ERROR ROM ADDRESS FF"
            severity error;

        --------------------------------------------------
        -- END
        --------------------------------------------------

        report "ALL PROGRAM MEMORY TESTS PASSED"
            severity note;

        wait;

    end process;

end tb;