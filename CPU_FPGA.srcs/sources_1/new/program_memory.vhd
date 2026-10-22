library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;



entity program_memory is
    port (
        Clk          : in  std_logic;
        
        addr       : in std_logic_vector(7 downto 0);
        data_out       : out std_logic_vector(15 downto 0)
    );
end program_memory;

architecture rtl of program_memory is
    
    type rom_type is array (0 to 255) of std_logic_vector(15 downto 0);
    constant ROM : rom_type := (
        0 => x"920A",  -- LDI R1, 10
        1 => x"940A",  -- LDI R2, 10
        2 => x"E280",  -- CMP R1, R2
        3 => x"D006",  -- JZ 0x06
    
        4 => x"9663",  -- LDI R3, 99
        5 => x"F000",  -- HALT
    
        6 => x"962A",  -- LDI R3, 42
        7 => x"F000",  -- HALT
    
        others => x"0000"
    );
    
    signal data_reg : std_logic_vector(15 downto 0);

begin

    data_out <= data_reg;
    
    process(Clk)
    begin
        if rising_edge(Clk) then
                
            data_reg <= ROM(TO_INTEGER(unsigned(addr)));

    
        end if;
    
    end process;

end rtl;
