library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;



entity register_fileTb is
--  Port ( );
end register_fileTb;

architecture DUT of register_fileTb is
    constant Clock_Freq     : integer  := 100_000_000;
    constant ClockPeriod    : time     := 1 sec / Clock_Freq;
    
    signal Clk        : std_logic := '0';
    signal rst        : std_logic := '1';
    
    signal read_addr_a   : std_logic_vector(2 downto 0);
    signal read_data_a   : std_logic_vector(7 downto 0);
   
    signal read_addr_b   : std_logic_vector(2 downto 0);
    signal read_data_b   : std_logic_vector(7 downto 0);
    
    signal write_enable        : std_logic := '0';
    signal write_addr   : std_logic_vector(2 downto 0);
    signal write_data   : std_logic_vector(7 downto 0);
begin
    i_register : entity work.register_file(rtl)
        port map (
            Clk        => Clk,
            rst        => rst,

            read_addr_a          => read_addr_a,
            read_data_a          => read_data_a,
            
            read_addr_b          => read_addr_b,
            read_data_b          => read_data_b,
            
            write_enable          => write_enable,
            write_addr          => write_addr,
            write_data          => write_data
        );
    
    Clk <= not Clk after ClockPeriod / 2;

    process
    begin

        -- Initialisation
        read_addr_a <= "000";
        read_addr_b <= "000";
        write_addr  <= "000";
        write_data  <= x"00";

        -- Reset
        wait for 20 ns;
        rst <= '0';

        -- Ecrire 0x15 dans R1
        write_enable <= '1';
        write_addr <= "001";
        write_data <= x"15";
        wait for 20 ns;

        -- Ecrire 0x25 dans R2
        write_addr <= "010";
        write_data <= x"25";
        wait for 20 ns;

        -- Ecrire 0x35 dans R3
        write_addr <= "011";
        write_data <= x"35";
        wait for 20 ns;

        -- Lire R1 et R2 simultanement
        write_enable <= '0';
        read_addr_a <= "001";
        read_addr_b <= "010";
        wait for 20 ns;

        -- Lire R3 et R1 simultanement
        read_addr_a <= "011";
        read_addr_b <= "001";
        wait for 20 ns;

        -- Ecrire R1 pendant sa lecture
        write_enable <= '1';
        write_addr <= "001";
        write_data <= x"50";
        read_addr_a <= "001";
        wait for 10 ns;

        -- Desactiver l'ecriture
        write_enable <= '0';
        wait for 20 ns;

        -- Reset final
        rst <= '1';
        wait for 20 ns;

        wait;

    end process;
end DUT;
