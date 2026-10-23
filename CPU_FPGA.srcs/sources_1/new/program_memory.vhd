library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_TEXTIO.ALL;

use STD.TEXTIO.ALL;



entity program_memory is
    generic (
        MEM_FILE : string := "/home/yousef/Vivado_workspace/CPU_FPGA/CPU_FPGA.srcs/sources_1/new/program.mem"
    );
    port (
        Clk          : in  std_logic;
        
        addr       : in std_logic_vector(7 downto 0);
        data_out       : out std_logic_vector(15 downto 0)
    );
end program_memory;

architecture rtl of program_memory is
    
    type rom_type is array (0 to 255) of std_logic_vector(15 downto 0);
    
    ----------------------------------------------------------------------
    impure function init_rom(filename : string) return rom_type is

        file rom_file : text open read_mode is filename;

        variable line_content : line;
        variable rom_data : rom_type := (others => x"0000");

        variable instruction : std_logic_vector(15 downto 0);
        variable index : integer := 0;

    begin

        while not endfile(rom_file) loop

            readline(rom_file, line_content);

            if index < 256 then
                hread(line_content, instruction);
                rom_data(index) := instruction;
                index := index + 1;
            end if;

        end loop;

        return rom_data;

    end function;
    -------------------------------------------------------------
    signal ROM : rom_type := init_rom(MEM_FILE);

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
