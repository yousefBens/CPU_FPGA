library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity register_file is
    port (
        Clk : in std_logic;
        rst : in std_logic;

        -- Read port A
        read_addr_a : in  std_logic_vector(2 downto 0);
        read_data_a : out std_logic_vector(7 downto 0);

        -- Read port B
        read_addr_b : in  std_logic_vector(2 downto 0);
        read_data_b : out std_logic_vector(7 downto 0);

        -- Write port
        write_enable : in std_logic;
        write_addr   : in std_logic_vector(2 downto 0);
        write_data   : in std_logic_vector(7 downto 0)
    );
end register_file;

architecture rtl of register_file is

    type register_array is array (0 to 7) of std_logic_vector(7 downto 0);

    signal registers : register_array := (others => (others => '0'));

begin

    --------------------------------------------------
    -- Asynchronous read ports
    --------------------------------------------------

    read_data_a <= registers(to_integer(unsigned(read_addr_a)));

    read_data_b <= registers(to_integer(unsigned(read_addr_b)));

    --------------------------------------------------
    -- Synchronous write port
    --------------------------------------------------

    process(Clk)
    begin
        if rising_edge(Clk) then

            if rst = '1' then
                registers <= (others => (others => '0'));

            elsif write_enable = '1' then
                registers(to_integer(unsigned(write_addr))) <= write_data;

            end if;

        end if;
    end process;

end rtl;