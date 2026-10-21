library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity aluTb is
--  Port ( );
end aluTb;

architecture DUT of aluTb is

    signal A   : std_logic_vector(7 downto 0);
    signal B   : std_logic_vector(7 downto 0);
    signal ALU_OP   : std_logic_vector(2 downto 0);
    
    signal RESULT   : std_logic_vector(7 downto 0);
    signal Z         : std_logic := '0';
    signal C         : std_logic := '0';
    signal N         : std_logic := '0';
    signal V         : std_logic := '0';
    
begin
    i_alu : entity work.alu(rtl)
        port map (
            A          => A,
            B          => B,
            ALU_OP     => ALU_OP,

            RESULT     => RESULT,
            Z          => Z,
            C          => C,
            N          => N,
            V          => V
        );
    

    
    process
    begin

        -- Reset
        A <= x"00";
        B <= x"00";
        ALU_OP <= "000";

        wait for 20 ns;


        -- ADD : 5 + 3 = 8
        A <= x"05";
        B <= x"03";
        ALU_OP <= "000";
        wait for 20 ns;

        -- SUB : 5 - 3 = 2
        ALU_OP <= "001";
        wait for 20 ns;

        -- AND
        ALU_OP <= "010";
        wait for 20 ns;

        -- OR
        ALU_OP <= "011";
        wait for 20 ns;

        -- XOR
        ALU_OP <= "100";
        wait for 20 ns;

        -- NOT A
        ALU_OP <= "101";
        wait for 20 ns;

        -- SHIFT LEFT A
        ALU_OP <= "110";
        wait for 20 ns;

        -- SHIFT RIGHT A
        ALU_OP <= "111";
        wait for 20 ns;

        -- ADD avec Carry : 255 + 1
        A <= x"FF";
        B <= x"01";
        ALU_OP <= "000";
        wait for 20 ns;

        -- ADD avec Overflow : 127 + 1
        A <= x"7F";
        B <= x"01";
        wait for 20 ns;

        -- SUB avec emprunt : 3 - 5
        A <= x"03";
        B <= x"05";
        ALU_OP <= "001";
        wait for 20 ns;

        wait;

    end process;
end DUT;
