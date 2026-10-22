library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity instruction_decoderTb is
end instruction_decoderTb;

architecture DUT of instruction_decoderTb is

    signal Instruction_in : std_logic_vector(15 downto 0) := (others => '0');

    signal opcode    : std_logic_vector(3 downto 0);
    signal rd        : std_logic_vector(2 downto 0);
    signal rs        : std_logic_vector(2 downto 0);
    signal immediate : std_logic_vector(7 downto 0);
    signal jump_addr : std_logic_vector(7 downto 0);

begin

    i_decoder : entity work.instruction_decoder(rtl)
        port map (
            Instruction_in => Instruction_in,
            opcode         => opcode,
            rd             => rd,
            rs             => rs,
            immediate      => immediate,
            jump_addr      => jump_addr
        );


    process
    begin

        --------------------------------------------------
        -- TEST 1 : NOP
        -- Opcode = 0000
        --------------------------------------------------
        Instruction_in <= x"0000";
        wait for 10 ns;

        assert opcode = "0000"
            report "TEST 1 FAILED: NOP opcode"
            severity error;

        --------------------------------------------------
        -- TEST 2 : ADD R1, R2
        -- Format R
        -- Opcode = 0001
        -- Rd = 001
        -- Rs = 010
        --------------------------------------------------
        Instruction_in <= x"1280";
        wait for 10 ns;

        assert opcode = "0001"
            report "TEST 2 FAILED: ADD opcode"
            severity error;

        assert rd = "001"
            report "TEST 2 FAILED: ADD rd"
            severity error;

        assert rs = "010"
            report "TEST 2 FAILED: ADD rs"
            severity error;

        --------------------------------------------------
        -- TEST 3 : SUB R3, R4
        -- Format R
        -- Opcode = 0010
        -- Rd = 011
        -- Rs = 100
        --------------------------------------------------
        Instruction_in <= x"2700";
        wait for 10 ns;

        assert opcode = "0010"
            report "TEST 3 FAILED: SUB opcode"
            severity error;

        assert rd = "011"
            report "TEST 3 FAILED: SUB rd"
            severity error;

        assert rs = "100"
            report "TEST 3 FAILED: SUB rs"
            severity error;

        --------------------------------------------------
        -- TEST 4 : LDI R2, 42
        -- Format I
        -- Opcode = 1001
        -- Rd = 010
        -- Immediate = 00101010
        --------------------------------------------------
        Instruction_in <= x"942A";
        wait for 10 ns;

        assert opcode = "1001"
            report "TEST 4 FAILED: LDI opcode"
            severity error;

        assert rd = "010"
            report "TEST 4 FAILED: LDI rd"
            severity error;

        assert immediate = x"2A"
            report "TEST 4 FAILED: LDI immediate"
            severity error;

        --------------------------------------------------
        -- TEST 5 : JMP 0x80
        -- Format J
        -- Opcode = 1010
        -- Address = 10000000
        --------------------------------------------------
        Instruction_in <= x"A080";
        wait for 10 ns;

        assert opcode = "1010"
            report "TEST 5 FAILED: JMP opcode"
            severity error;

        assert jump_addr = x"80"
            report "TEST 5 FAILED: JMP address"
            severity error;

        --------------------------------------------------
        -- TEST 6 : JZ 0x40
        -- Format J
        -- Opcode = 1011
        --------------------------------------------------
        Instruction_in <= x"B040";
        wait for 10 ns;

        assert opcode = "1011"
            report "TEST 6 FAILED: JZ opcode"
            severity error;

        assert jump_addr = x"40"
            report "TEST 6 FAILED: JZ address"
            severity error;

        --------------------------------------------------
        -- TEST 7 : HALT
        -- Format S
        -- Opcode = 1111
        --------------------------------------------------
        Instruction_in <= x"F000";
        wait for 10 ns;

        assert opcode = "1111"
            report "TEST 7 FAILED: HALT opcode"
            severity error;

        --------------------------------------------------
        -- FIN
        --------------------------------------------------
        report "ALL INSTRUCTION DECODER TESTS PASSED"
            severity note;

        wait;

    end process;

end DUT;