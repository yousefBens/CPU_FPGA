library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- to hold flags modifie after after rising edge because alu combinatoire

entity flags_register is
    port (
        Clk          : in  std_logic;
        rst          : in  std_logic;
        write_enable : in  std_logic;

        -- Flags provenant de l'ALU
        z_in         : in  std_logic;
        c_in         : in  std_logic;
        n_in         : in  std_logic;
        v_in         : in  std_logic;

        -- Flags enregistrés
        z_out        : out std_logic;
        c_out        : out std_logic;
        n_out        : out std_logic;
        v_out        : out std_logic
    );
end flags_register;

architecture rtl of flags_register is

    signal z_reg : std_logic := '0';
    signal c_reg : std_logic := '0';
    signal n_reg : std_logic := '0';
    signal v_reg : std_logic := '0';

begin

    process(Clk)
    begin
        if rising_edge(Clk) then

            if rst = '1' then

                z_reg <= '0';
                c_reg <= '0';
                n_reg <= '0';
                v_reg <= '0';

            elsif write_enable = '1' then

                z_reg <= z_in;
                c_reg <= c_in;
                n_reg <= n_in;
                v_reg <= v_in;

            end if;

        end if;
    end process;

    z_out <= z_reg;
    c_out <= c_reg;
    n_out <= n_reg;
    v_out <= v_reg;

end rtl;