library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity alu is
    port (
        A      : in  std_logic_vector(7 downto 0);
        B      : in  std_logic_vector(7 downto 0);
        ALU_OP : in  std_logic_vector(2 downto 0);

        RESULT : out std_logic_vector(7 downto 0);

        Z      : out std_logic;
        C      : out std_logic;
        N      : out std_logic;
        V      : out std_logic
    );
end alu;

architecture rtl of alu is

begin

    process(A, B, ALU_OP)

        variable temp_result : std_logic_vector(7 downto 0);
        variable temp_add    : unsigned(8 downto 0);

        variable temp_c : std_logic;
        variable temp_v : std_logic;

    begin

        temp_result := (others => '0');
        temp_add    := (others => '0');

        temp_c := '0';
        temp_v := '0';

        case ALU_OP is

            --------------------------------------------------
            -- ADD
            --------------------------------------------------
            when "000" =>

                temp_add :=
                    ('0' & unsigned(A)) +
                    ('0' & unsigned(B));

                temp_result := std_logic_vector(temp_add(7 downto 0));

                temp_c := temp_add(8);

                temp_v := (not (A(7) xor B(7))) and
                          (A(7) xor temp_result(7));

            --------------------------------------------------
            -- SUB
            --------------------------------------------------
            when "001" =>

                temp_result :=
                    std_logic_vector(unsigned(A) - unsigned(B));

                if unsigned(A) < unsigned(B) then
                    temp_c := '1';
                end if;

                temp_v := (A(7) xor B(7)) and
                          (A(7) xor temp_result(7));

            --------------------------------------------------
            -- AND
            --------------------------------------------------
            when "010" =>

                temp_result := A and B;

            --------------------------------------------------
            -- OR
            --------------------------------------------------
            when "011" =>

                temp_result := A or B;

            --------------------------------------------------
            -- XOR
            --------------------------------------------------
            when "100" =>

                temp_result := A xor B;

            --------------------------------------------------
            -- NOT A
            --------------------------------------------------
            when "101" =>

                temp_result := not A;

            --------------------------------------------------
            -- SHIFT LEFT
            --------------------------------------------------
            when "110" =>

                temp_result := A(6 downto 0) & '0';

            --------------------------------------------------
            -- SHIFT RIGHT
            --------------------------------------------------
            when "111" =>

                temp_result := '0' & A(7 downto 1);

            when others =>

                temp_result := (others => '0');

        end case;

        --------------------------------------------------
        -- Outputs
        --------------------------------------------------

        RESULT <= temp_result;

        C <= temp_c;
        V <= temp_v;

        if temp_result = x"00" then
            Z <= '1';
        else
            Z <= '0';
        end if;

        N <= temp_result(7);

    end process;

end rtl;