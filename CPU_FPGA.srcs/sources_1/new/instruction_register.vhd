library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity instruction_register is
    port (
        Clk : in std_logic;
        rst : in std_logic;
        
        ir_enable : in std_logic;
        Instruction_in : in  std_logic_vector(15 downto 0);
        
        Instruction_out : out std_logic_vector(15 downto 0)
    );
end instruction_register;

architecture rtl of instruction_register is

    signal Instruction_reg : std_logic_vector(15 downto 0) := (others => '0');
    
begin

    Instruction_out <= Instruction_reg;

    process(Clk)
    begin
        if rising_edge(Clk) then
            if rst = '1' then
                Instruction_reg <= (others => '0');
            else
                if ir_enable = '1' then
                    Instruction_reg <= Instruction_in;
                end if;
            end if;
        end if;
    
    end process;

end rtl;
