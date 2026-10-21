library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;



entity program_counterTb is
--  Port ( );
end program_counterTb;

architecture DUT of program_counterTb is

    constant Clock_Freq     : integer  := 100_000_000;
    constant ClockPeriod    : time     := 1 sec / Clock_Freq;
    
    signal Clk        : std_logic := '0';
    signal rst        : std_logic := '1';

    signal pc_enable        : std_logic := '0';
    signal pc_load        : std_logic := '0';
    signal pc_load_data   : std_logic_vector(7 downto 0);
    
    signal pc_out   : std_logic_vector(7 downto 0);
   
begin
    i_pc : entity work.program_counter(rtl)
        port map (
            Clk        => Clk,
            rst        => rst,

            pc_enable          => pc_enable,
            pc_load          => pc_load,
            
            pc_load_data          => pc_load_data,
            pc_out          => pc_out
        );
        
     Clk <= not Clk after ClockPeriod / 2;
     
    process
    begin

        -- RESET
        wait until rising_edge(Clk);
        wait for 1 ns;

        assert pc_out = x"00"
            report "ERROR RESET"
            severity error;

        rst <= '0';

        -- INCREMENT
        pc_enable <= '1';

        wait until rising_edge(Clk);
        wait for 1 ns;

        assert pc_out = x"01"
            report "ERROR INCREMENT 1"
            severity error;

        wait until rising_edge(Clk);
        wait for 1 ns;

        assert pc_out = x"02"
            report "ERROR INCREMENT 2"
            severity error;

        -- HOLD
        pc_enable <= '0';

        wait until rising_edge(Clk);
        wait for 1 ns;

        assert pc_out = x"02"
            report "ERROR HOLD"
            severity error;

        -- LOAD
        pc_enable <= '1';
        pc_load <= '1';
        pc_load_data <= x"20";

        wait until rising_edge(Clk);
        wait for 1 ns;

        assert pc_out = x"20"
            report "ERROR LOAD"
            severity error;

        -- OVERFLOW
        pc_load_data <= x"FF";

        wait until rising_edge(Clk);
        wait for 1 ns;

        assert pc_out = x"FF"
            report "ERROR LOAD FF"
            severity error;

        pc_load <= '0';

        wait until rising_edge(Clk);
        wait for 1 ns;

        assert pc_out = x"00"
            report "ERROR OVERFLOW"
            severity error;

        -- RESET PRIORITY
        rst <= '1';
        pc_load <= '1';
        pc_load_data <= x"55";

        wait until rising_edge(Clk);
        wait for 1 ns;

        assert pc_out = x"00"
            report "ERROR RESET PRIORITY"
            severity error;

        report "ALL PC TESTS PASSED"
            severity note;

        wait;

    end process;     

end DUT;
