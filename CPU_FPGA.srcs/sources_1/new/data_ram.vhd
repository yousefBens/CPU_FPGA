library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- No rst port : Parce que réinitialiser tout le contenu d'une RAM à chaque reset
-- peut empêcher Vivado de l'implémenter dans une Block RAM FPGA.
entity data_ram is
    port (
        Clk          : in  std_logic;

        write_enable : in  std_logic;
        read_enable  : in  std_logic;

        addr         : in  std_logic_vector(7 downto 0);

        write_data   : in  std_logic_vector(7 downto 0);
        read_data    : out std_logic_vector(7 downto 0)
    );
end data_ram;

architecture rtl of data_ram is
    
    type ram_type is array (0 to 255) of std_logic_vector(7 downto 0);
    signal RAM : ram_type := (others => (others => '0'));
    
    signal read_data_reg : std_logic_vector(7 downto 0) := (others => '0');
    
begin
    
    read_data <= read_data_reg;
    
    process(Clk)
    begin
        if rising_edge(Clk) then
            if write_enable = '1' then
                RAM(TO_INTEGER(unsigned(addr))) <= write_data;
            elsif read_enable = '1' then
                read_data_reg <= RAM(TO_INTEGER(unsigned(addr)));

            end if;
        end if;

    
    end process;

end rtl;
