library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;



entity program_counter is
    generic (
        PC_WIDTH : positive := 8
    );
    port (
        clk          : in  std_logic;
        rst          : in  std_logic;

        pc_enable    : in  std_logic;
        pc_load      : in  std_logic;

        pc_load_data : in  std_logic_vector(PC_WIDTH-1 downto 0);

        pc_out       : out std_logic_vector(PC_WIDTH-1 downto 0)
    );
end program_counter;

architecture rtl of program_counter is

begin


end rtl;
