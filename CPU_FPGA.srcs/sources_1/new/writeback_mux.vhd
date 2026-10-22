library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity writeback_mux is
    port (
        -- Sources de données
        alu_result : in std_logic_vector(7 downto 0);
        immediate  : in std_logic_vector(7 downto 0);
        ram_data   : in std_logic_vector(7 downto 0);

        -- Sélection provenant de la Control Unit
        sel        : in std_logic_vector(1 downto 0);

        -- Donnée envoyée au Register File
        data_out   : out std_logic_vector(7 downto 0)
    );
end writeback_mux;

architecture rtl of writeback_mux is

begin

    process(alu_result, immediate, ram_data, sel)
    begin
        case sel is

            when "00" =>
                data_out <= alu_result;

            when "01" =>
                data_out <= immediate;

            when "10" =>
                data_out <= ram_data;

            when others =>
                data_out <= (others => '0');

        end case;
    end process;

end rtl;