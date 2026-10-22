library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity cpu_tb is
end cpu_tb;

architecture sim of cpu_tb is

    signal Clk    : std_logic := '0';
    signal rst    : std_logic := '1';
    signal halted : std_logic;

    constant CLK_PERIOD : time := 10 ns;

begin

    --------------------------------------------------
    -- Clock generation : 100 MHz
    --------------------------------------------------

    Clk <= not Clk after CLK_PERIOD / 2;

    --------------------------------------------------
    -- CPU instantiation
    --------------------------------------------------

    uut : entity work.design_1_wrapper
        port map (
            Clk    => Clk,
            rst    => rst,
            halted => halted
        );

    --------------------------------------------------
    -- Test sequence
    --------------------------------------------------

    stimulus : process
    begin

        report "====================================";
        report "CPU FPGA - FULL SYSTEM TEST";
        report "====================================";

        -- Reset
        rst <= '1';

        wait for 30 ns;

        rst <= '0';

        report "Reset released - CPU running";

        -- Wait until HALT, with timeout
        wait until halted = '1' for 1000 ns;

        assert halted = '1'
            report "ERROR: CPU did not reach HALT"
            severity failure;

        report "CPU reached HALT";

        wait for 30 ns;

        assert halted = '1'
            report "ERROR: HALT state not maintained"
            severity failure;

        report "====================================";
        report "CPU TEST COMPLETED";
        report "====================================";

        wait;

    end process;

end sim;