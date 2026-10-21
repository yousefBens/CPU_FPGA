library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity program_counter is
    port (
        Clk          : in  std_logic;
        rst          : in  std_logic;

        pc_enable    : in  std_logic;
        pc_load      : in  std_logic;
        pc_load_data : in  std_logic_vector(7 downto 0);

        pc_out       : out std_logic_vector(7 downto 0)
    );
end program_counter;

architecture rtl of program_counter is

    signal pc_reg : unsigned(7 downto 0) := (others => '0');

begin

    pc_out <= std_logic_vector(pc_reg);

    process(Clk)
    begin
        if rising_edge(Clk) then

            if rst = '1' then
                pc_reg <= (others => '0');

            elsif pc_enable = '1' then

                if pc_load = '1' then
                    pc_reg <= unsigned(pc_load_data);
                else
                    pc_reg <= pc_reg + 1;
                end if;

            end if;

        end if;
    end process;

    

end rtl;