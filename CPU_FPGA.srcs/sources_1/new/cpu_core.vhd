library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity cpu_core is
    Port (
        Clk : in std_logic;
        rst : in std_logic;

        --------------------------------------------------
        -- PROGRAM MEMORY INTERFACE
        --------------------------------------------------
        prog_addr : out std_logic_vector(7 downto 0);
        prog_data : in  std_logic_vector(15 downto 0);

        --------------------------------------------------
        -- DATA MEMORY INTERFACE
        --------------------------------------------------
        data_addr : out std_logic_vector(7 downto 0);
        data_din  : in  std_logic_vector(7 downto 0);
        data_dout : out std_logic_vector(7 downto 0);

        data_we : out std_logic;
        data_re : out std_logic;

        --------------------------------------------------
        -- DEBUG INTERFACE
        --------------------------------------------------
        debug_pc    : out std_logic_vector(7 downto 0);
        debug_ir    : out std_logic_vector(15 downto 0);

        debug_r0    : out std_logic_vector(7 downto 0);
        debug_r1    : out std_logic_vector(7 downto 0);
        debug_r2    : out std_logic_vector(7 downto 0);
        debug_r3    : out std_logic_vector(7 downto 0);

        debug_flags : out std_logic_vector(2 downto 0);
        debug_state : out std_logic_vector(3 downto 0)
    );
end cpu_core;

architecture rtl of cpu_core is

    --------------------------------------------------
    -- OPCODES
    --------------------------------------------------

    constant OP_NOP   : std_logic_vector(3 downto 0) := "0000";
    constant OP_MOVI  : std_logic_vector(3 downto 0) := "0001";
    constant OP_MOV   : std_logic_vector(3 downto 0) := "0010";
    constant OP_ADD   : std_logic_vector(3 downto 0) := "0011";
    constant OP_SUB   : std_logic_vector(3 downto 0) := "0100";
    constant OP_AND   : std_logic_vector(3 downto 0) := "0101";
    constant OP_OR    : std_logic_vector(3 downto 0) := "0110";
    constant OP_XOR   : std_logic_vector(3 downto 0) := "0111";
    constant OP_LOAD  : std_logic_vector(3 downto 0) := "1000";
    constant OP_STORE : std_logic_vector(3 downto 0) := "1001";
    constant OP_JMP   : std_logic_vector(3 downto 0) := "1010";
    constant OP_JZ    : std_logic_vector(3 downto 0) := "1011";

    --------------------------------------------------
    -- CPU FSM
    --------------------------------------------------

    type state_type is (
        S_FETCH,
        S_FETCH_WAIT,
        S_FETCH_LATCH,
        S_DECODE,
        S_EXECUTE,
        S_LOAD_WAIT,
        S_LOAD_WRITEBACK,
        S_STORE_COMMIT
    );

    signal state : state_type := S_FETCH;

    --------------------------------------------------
    -- REGISTER FILE
    --------------------------------------------------

    type register_array is array (0 to 3)
        of std_logic_vector(7 downto 0);

    signal registers : register_array :=
        (others => (others => '0'));

    --------------------------------------------------
    -- CPU REGISTERS
    --------------------------------------------------

    signal pc : unsigned(7 downto 0) :=
        (others => '0');

    signal ir : std_logic_vector(15 downto 0) :=
        (others => '0');

    --------------------------------------------------
    -- INSTRUCTION FIELDS
    --------------------------------------------------

    signal opcode : std_logic_vector(3 downto 0);

    signal rd : integer range 0 to 3;
    signal rs : integer range 0 to 3;

    signal immediate : std_logic_vector(7 downto 0);

    --------------------------------------------------
    -- ALU SIGNALS
    --------------------------------------------------

    signal alu_a : std_logic_vector(7 downto 0);
    signal alu_b : std_logic_vector(7 downto 0);

    signal alu_result : std_logic_vector(7 downto 0);

    signal alu_zero     : std_logic;
    signal alu_carry    : std_logic;
    signal alu_negative : std_logic;

    --------------------------------------------------
    -- CPU FLAGS
    --------------------------------------------------

    signal flag_z : std_logic := '0';
    signal flag_c : std_logic := '0';
    signal flag_n : std_logic := '0';

    --------------------------------------------------
    -- MEMORY REGISTERS
    --------------------------------------------------

    signal data_addr_reg : std_logic_vector(7 downto 0) :=
        (others => '0');

    signal data_write_reg : std_logic_vector(7 downto 0) :=
        (others => '0');

    signal data_we_reg : std_logic := '0';
    signal data_re_reg : std_logic := '0';

begin

    --------------------------------------------------
    -- INSTRUCTION DECODER
    --------------------------------------------------

    opcode <= ir(15 downto 12);

    rd <= to_integer(unsigned(ir(11 downto 10)));

    rs <= to_integer(unsigned(ir(9 downto 8)));

    immediate <= ir(7 downto 0);

    --------------------------------------------------
    -- REGISTER FILE READ
    --------------------------------------------------

    alu_a <= registers(rd);
    alu_b <= registers(rs);

    --------------------------------------------------
    -- ALU
    --------------------------------------------------

    process(alu_a, alu_b, opcode)

        variable temp : unsigned(8 downto 0);

        variable result_v : std_logic_vector(7 downto 0);

        variable carry_v : std_logic;

    begin

        temp := (others => '0');
        result_v := (others => '0');
        carry_v := '0';

        case opcode is

            --------------------------------------------------
            -- ADD
            --------------------------------------------------

            when OP_ADD =>

                temp :=
                    ('0' & unsigned(alu_a)) +
                    ('0' & unsigned(alu_b));

                result_v :=
                    std_logic_vector(temp(7 downto 0));

                carry_v := temp(8);

            --------------------------------------------------
            -- SUB
            --------------------------------------------------

            when OP_SUB =>

                temp :=
                    ('0' & unsigned(alu_a)) -
                    ('0' & unsigned(alu_b));

                result_v :=
                    std_logic_vector(temp(7 downto 0));

                -- Carry represents borrow for subtraction
                if unsigned(alu_a) < unsigned(alu_b) then
                    carry_v := '1';
                else
                    carry_v := '0';
                end if;

            --------------------------------------------------
            -- AND
            --------------------------------------------------

            when OP_AND =>

                result_v := alu_a and alu_b;

            --------------------------------------------------
            -- OR
            --------------------------------------------------

            when OP_OR =>

                result_v := alu_a or alu_b;

            --------------------------------------------------
            -- XOR
            --------------------------------------------------

            when OP_XOR =>

                result_v := alu_a xor alu_b;

            --------------------------------------------------
            -- DEFAULT
            --------------------------------------------------

            when others =>

                result_v := (others => '0');

        end case;

        alu_result <= result_v;

        alu_carry <= carry_v;

        if result_v = x"00" then
            alu_zero <= '1';
        else
            alu_zero <= '0';
        end if;

        alu_negative <= result_v(7);

    end process;

    --------------------------------------------------
    -- PROGRAM MEMORY INTERFACE
    --------------------------------------------------

    prog_addr <= std_logic_vector(pc);

    --------------------------------------------------
    -- DATA MEMORY INTERFACE
    --------------------------------------------------

    data_addr <= data_addr_reg;

    data_dout <= data_write_reg;

    data_we <= data_we_reg;

    data_re <= data_re_reg;

    --------------------------------------------------
    -- CPU CONTROL UNIT
    --------------------------------------------------

    process(Clk)

    begin

        if rising_edge(Clk) then

            --------------------------------------------------
            -- RESET
            --------------------------------------------------

            if rst = '1' then

                state <= S_FETCH;

                pc <= (others => '0');

                ir <= (others => '0');

                registers <=
                    (others => (others => '0'));

                flag_z <= '0';
                flag_c <= '0';
                flag_n <= '0';

                data_addr_reg <= (others => '0');

                data_write_reg <= (others => '0');

                data_we_reg <= '0';
                data_re_reg <= '0';

            else

                --------------------------------------------------
                -- DEFAULT MEMORY CONTROL
                --------------------------------------------------

                data_we_reg <= '0';
                data_re_reg <= '0';

                --------------------------------------------------
                -- FSM
                --------------------------------------------------

                case state is

                    --------------------------------------------------
                    -- FETCH
                    --------------------------------------------------

                    when S_FETCH =>

                        -- PC already drives ROM address
                        state <= S_FETCH_WAIT;

                    --------------------------------------------------
                    -- FETCH WAIT
                    --------------------------------------------------

                    when S_FETCH_WAIT =>

                        -- Wait for synchronous ROM output
                        state <= S_FETCH_LATCH;

                    --------------------------------------------------
                    -- FETCH LATCH
                    --------------------------------------------------

                    when S_FETCH_LATCH =>

                        ir <= prog_data;

                        pc <= pc + 1;

                        state <= S_DECODE;

                    --------------------------------------------------
                    -- DECODE
                    --------------------------------------------------

                    when S_DECODE =>

                        state <= S_EXECUTE;

                    --------------------------------------------------
                    -- EXECUTE
                    --------------------------------------------------

                    when S_EXECUTE =>

                        case opcode is

                            --------------------------------------------------
                            -- NOP
                            --------------------------------------------------

                            when OP_NOP =>

                                state <= S_FETCH;

                            --------------------------------------------------
                            -- MOVI
                            --------------------------------------------------

                            when OP_MOVI =>

                                registers(rd) <= immediate;

                                state <= S_FETCH;

                            --------------------------------------------------
                            -- MOV
                            --------------------------------------------------

                            when OP_MOV =>

                                registers(rd) <= registers(rs);

                                state <= S_FETCH;

                            --------------------------------------------------
                            -- ALU OPERATIONS
                            --------------------------------------------------

                            when OP_ADD |
                                 OP_SUB |
                                 OP_AND |
                                 OP_OR  |
                                 OP_XOR =>

                                registers(rd) <= alu_result;

                                flag_z <= alu_zero;
                                flag_c <= alu_carry;
                                flag_n <= alu_negative;

                                state <= S_FETCH;

                            --------------------------------------------------
                            -- LOAD
                            --------------------------------------------------

                            when OP_LOAD =>

                                data_addr_reg <= immediate;

                                data_re_reg <= '1';

                                state <= S_LOAD_WAIT;

                            --------------------------------------------------
                            -- STORE
                            --------------------------------------------------

                            when OP_STORE =>

                                data_addr_reg <= immediate;

                                data_write_reg <= registers(rd);

                                data_we_reg <= '1';

                                state <= S_STORE_COMMIT;

                            --------------------------------------------------
                            -- JMP
                            --------------------------------------------------

                            when OP_JMP =>

                                pc <= unsigned(immediate);

                                state <= S_FETCH;

                            --------------------------------------------------
                            -- JZ
                            --------------------------------------------------

                            when OP_JZ =>

                                if flag_z = '1' then

                                    pc <= unsigned(immediate);

                                end if;

                                state <= S_FETCH;

                            --------------------------------------------------
                            -- UNKNOWN OPCODE
                            --------------------------------------------------

                            when others =>

                                state <= S_FETCH;

                        end case;

                    --------------------------------------------------
                    -- LOAD WAIT
                    --------------------------------------------------

                    when S_LOAD_WAIT =>

                        -- RAM samples read_enable on this edge
                        -- and updates read_data_reg after the edge.

                        state <= S_LOAD_WRITEBACK;

                    --------------------------------------------------
                    -- LOAD WRITEBACK
                    --------------------------------------------------

                    when S_LOAD_WRITEBACK =>

                        registers(rd) <= data_din;

                        state <= S_FETCH;

                    --------------------------------------------------
                    -- STORE COMMIT
                    --------------------------------------------------

                    when S_STORE_COMMIT =>

                        -- RAM samples write_enable on this edge

                        state <= S_FETCH;

                    --------------------------------------------------
                    -- DEFAULT
                    --------------------------------------------------

                    when others =>

                        state <= S_FETCH;

                end case;

            end if;

        end if;

    end process;

    --------------------------------------------------
    -- DEBUG OUTPUTS
    --------------------------------------------------

    debug_pc <= std_logic_vector(pc);

    debug_ir <= ir;

    debug_r0 <= registers(0);
    debug_r1 <= registers(1);
    debug_r2 <= registers(2);
    debug_r3 <= registers(3);

    -- Flags order: Z, C, N
    debug_flags <= flag_z & flag_c & flag_n;

    --------------------------------------------------
    -- DEBUG FSM STATE
    --------------------------------------------------

    with state select

        debug_state <=

            "0000" when S_FETCH,
            "0001" when S_FETCH_WAIT,
            "0010" when S_FETCH_LATCH,
            "0011" when S_DECODE,
            "0100" when S_EXECUTE,
            "0101" when S_LOAD_WAIT,
            "0110" when S_LOAD_WRITEBACK,
            "0111" when S_STORE_COMMIT,
            "1111" when others;

end rtl;