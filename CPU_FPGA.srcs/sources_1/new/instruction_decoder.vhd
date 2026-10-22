library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;



entity instruction_decoder is
    port (
        Instruction_in : in  std_logic_vector(15 downto 0); 
        
        opcode : out  std_logic_vector(3 downto 0); 
        rd : out  std_logic_vector(2 downto 0); 
        rs : out  std_logic_vector(2 downto 0);  
        immediate : out  std_logic_vector(7 downto 0);
        jump_addr : out  std_logic_vector(7 downto 0)
    );
end instruction_decoder;

architecture rtl of instruction_decoder is

begin
    
    process(Instruction_in)
    begin
    
        opcode <= Instruction_in(15 downto 12);
       
        rd <= Instruction_in(11 downto 9);
        rs <= Instruction_in(8 downto 6);
        immediate <= Instruction_in(7 downto 0);
        jump_addr <= Instruction_in(7 downto 0);
                
    end process;

end rtl;
