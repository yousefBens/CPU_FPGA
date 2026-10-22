library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity data_ramTb is
--  Port ( );
end data_ramTb;

architecture DUT of data_ramTb is

    constant Clock_Freq   : integer := 100_000_000;
    constant ClockPeriod  : time := 1 sec / Clock_Freq;

    signal Clk : std_logic := '0';

    signal write_enable : std_logic := '0';
    signal read_enable  : std_logic := '0';

    signal addr       : std_logic_vector(7 downto 0) := (others => '0');
    signal write_data : std_logic_vector(7 downto 0) := (others => '0');
    signal read_data  : std_logic_vector(7 downto 0);

begin


    Clk <= not Clk after ClockPeriod / 2;


    i_data_ram : entity work.data_ram(rtl)
        port map (
            Clk          => Clk,
            write_enable => write_enable,
            read_enable  => read_enable,
            addr         => addr,
            write_data   => write_data,
            read_data    => read_data
        );



    process
    begin

        --------------------------------------------------
        -- TEST 1 : Write 0xAB at address 0x10
        --------------------------------------------------
        wait until falling_edge(Clk);

        addr         <= x"10";
        write_data   <= x"AB";
        write_enable <= '1';
        read_enable  <= '0';

        wait until rising_edge(Clk);
        wait for 1 ns;

        assert read_data = x"00"
            report "TEST 1 FAILED: read_data changed during write"
            severity error;


        --------------------------------------------------
        -- TEST 2 : Read address 0x10
        --------------------------------------------------
        wait until falling_edge(Clk);

        write_enable <= '0';
        read_enable  <= '1';
        addr         <= x"10";

        wait until rising_edge(Clk);
        wait for 1 ns;

        assert read_data = x"AB"
            report "TEST 2 FAILED: Expected 0xAB"
            severity error;


        --------------------------------------------------
        -- TEST 3 : Write 0x55 at address 0x20
        --------------------------------------------------
        wait until falling_edge(Clk);

        addr         <= x"20";
        write_data   <= x"55";
        write_enable <= '1';
        read_enable  <= '0';

        wait until rising_edge(Clk);
        wait for 1 ns;

        assert read_data = x"AB"
            report "TEST 3 FAILED: read_data should hold 0xAB"
            severity error;


        --------------------------------------------------
        -- TEST 4 : Read address 0x20
        --------------------------------------------------
        wait until falling_edge(Clk);

        write_enable <= '0';
        read_enable  <= '1';
        addr         <= x"20";

        wait until rising_edge(Clk);
        wait for 1 ns;

        assert read_data = x"55"
            report "TEST 4 FAILED: Expected 0x55"
            severity error;


        --------------------------------------------------
        -- TEST 5 : Verify address 0x10 is unchanged
        --------------------------------------------------
        wait until falling_edge(Clk);

        addr <= x"10";

        wait until rising_edge(Clk);
        wait for 1 ns;

        assert read_data = x"AB"
            report "TEST 5 FAILED: RAM[0x10] was modified"
            severity error;


        --------------------------------------------------
        -- TEST 6 : Read disabled
        -- Output must hold previous value
        --------------------------------------------------
        wait until falling_edge(Clk);

        read_enable  <= '0';
        write_enable <= '0';
        addr         <= x"20";

        wait until rising_edge(Clk);
        wait for 1 ns;

        assert read_data = x"AB"
            report "TEST 6 FAILED: read_data should hold"
            severity error;


        --------------------------------------------------
        -- TEST 7 : Simultaneous read and write
        -- Write has priority
        --------------------------------------------------
        wait until falling_edge(Clk);

        addr         <= x"10";
        write_data   <= x"FF";
        write_enable <= '1';
        read_enable  <= '1';

        wait until rising_edge(Clk);
        wait for 1 ns;

        assert read_data = x"AB"
            report "TEST 7 FAILED: Write priority not respected"
            severity error;


        --------------------------------------------------
        -- TEST 8 : Read updated address 0x10
        --------------------------------------------------
        wait until falling_edge(Clk);

        write_enable <= '0';
        read_enable  <= '1';

        wait until rising_edge(Clk);
        wait for 1 ns;

        assert read_data = x"FF"
            report "TEST 8 FAILED: Expected updated value 0xFF"
            severity error;


        --------------------------------------------------
        -- TEST 9 : Write at address 0x00
        --------------------------------------------------
        wait until falling_edge(Clk);

        addr         <= x"00";
        write_data   <= x"12";
        write_enable <= '1';
        read_enable  <= '0';

        wait until rising_edge(Clk);
        wait for 1 ns;


        --------------------------------------------------
        -- TEST 10 : Read address 0x00
        --------------------------------------------------
        wait until falling_edge(Clk);

        write_enable <= '0';
        read_enable  <= '1';

        wait until rising_edge(Clk);
        wait for 1 ns;

        assert read_data = x"12"
            report "TEST 10 FAILED: Address 0x00"
            severity error;


        --------------------------------------------------
        -- TEST 11 : Write at address 0xFF
        --------------------------------------------------
        wait until falling_edge(Clk);

        addr         <= x"FF";
        write_data   <= x"EE";
        write_enable <= '1';
        read_enable  <= '0';

        wait until rising_edge(Clk);
        wait for 1 ns;


        --------------------------------------------------
        -- TEST 12 : Read address 0xFF
        --------------------------------------------------
        wait until falling_edge(Clk);

        write_enable <= '0';
        read_enable  <= '1';

        wait until rising_edge(Clk);
        wait for 1 ns;

        assert read_data = x"EE"
            report "TEST 12 FAILED: Address 0xFF"
            severity error;


        --------------------------------------------------
        -- TEST 13 : Verify synchronous read
        -- Changing address must not immediately
        -- change read_data
        --------------------------------------------------
        wait until falling_edge(Clk);

        addr <= x"10";

        wait for 1 ns;

        assert read_data = x"EE"
            report "TEST 13 FAILED: Asynchronous read detected"
            severity error;

        wait until rising_edge(Clk);
        wait for 1 ns;

        assert read_data = x"FF"
            report "TEST 13 FAILED: Synchronous read incorrect"
            severity error;


        --------------------------------------------------
        -- END OF TESTS
        --------------------------------------------------
        report "====================================";
        report "ALL DATA RAM TESTS PASSED";
        report "====================================";

        wait;

    end process;

end DUT;