library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity alu is
  Port (
    Clk    : in std_logic;
    rst    : in std_logic;

    A      : in std_logic_vector(7 downto 0);
    B      : in std_logic_vector(7 downto 0);
    ALU_OP : in std_logic_vector(2 downto 0);

    RESULT : out std_logic_vector(7 downto 0);
    Z      : out std_logic;
    C      : out std_logic;
    N      : out std_logic;
    V      : out std_logic
  );
end alu;

architecture rtl of alu is

    signal RESULT_reg : std_logic_vector(7 downto 0) := (others => '0');

begin

    RESULT <= RESULT_reg;

    process(Clk)
        variable temp_result : std_logic_vector(7 downto 0);
        variable temp_add    : unsigned(8 downto 0);
    begin
        if rising_edge(Clk) then
            if rst = '1' then
                RESULT_reg <= (others => '0');
                Z <= '0';
                C <= '0';
                N <= '0';
                V <= '0';

            else
                
                C <= '0';
                V <= '0';

                case ALU_OP is

                    when "000" => -- ADD
                        temp_add := ('0' & unsigned(A)) + ('0' & unsigned(B));
                        temp_result := std_logic_vector(temp_add(7 downto 0));
                        RESULT_reg <= temp_result;

                        C <= temp_add(8);
                        V <= (not (A(7) xor B(7))) and
                             (A(7) xor temp_result(7));

                    when "001" => -- SUB
                        temp_result := std_logic_vector(unsigned(A) - unsigned(B));
                        RESULT_reg <= temp_result;

                        if unsigned(A) < unsigned(B) then
                            C <= '1';
                        end if;

                        V <= (A(7) xor B(7)) and
                             (A(7) xor temp_result(7));

                    when "010" => -- AND
                        temp_result := A and B;
                        RESULT_reg <= temp_result;

                    when "011" => -- OR
                        temp_result := A or B;
                        RESULT_reg <= temp_result;

                    when "100" => -- XOR
                        temp_result := A xor B;
                        RESULT_reg <= temp_result;

                    when "101" => -- NOT A
                        temp_result := not A;
                        RESULT_reg <= temp_result;

                    when "110" => -- SHIFT LEFT A
                        temp_result := A(6 downto 0) & '0';
                        RESULT_reg <= temp_result;

                    when "111" => -- SHIFT RIGHT A
                        temp_result := '0' & A(7 downto 1);
                        RESULT_reg <= temp_result;

                    when others =>
                        temp_result := (others => '0');
                        RESULT_reg <= temp_result;

                end case;

                -- Zero Flag
                if temp_result = x"00" then
                    Z <= '1';
                else
                    Z <= '0';
                end if;

                -- Negative Flag
                N <= temp_result(7);

            end if;
        end if;
    end process;

end rtl;