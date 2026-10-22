library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;



entity control_unit is
  Port (
        -- Clock & Reset
        Clk                : in  std_logic;
        rst                : in  std_logic;
        
        -- Instruction & Flags
        opcode             : in  std_logic_vector(3 downto 0);
        flag_z             : in  std_logic;
        
        -- Program Counter
        pc_enable          : out std_logic;
        pc_load            : out std_logic;
        
        -- Instruction Register
        ir_enable          : out std_logic;
        
        -- Register File
        reg_write_enable   : out std_logic;
        reg_write_sel      : out std_logic_vector(1 downto 0);
        
        -- Data RAM
        ram_read_enable    : out std_logic;
        ram_write_enable   : out std_logic;
        
        -- ALU
        alu_op             : out std_logic_vector(2 downto 0);
        
        -- Flags Register
        flags_write_enable : out std_logic;
        
        -- CPU Status
        halted             : out std_logic 
  );
end control_unit;

architecture rtl of control_unit is

    type state_type is (
        FETCH_ROM,
        FETCH_IR,
        DECODE,
        EXECUTE,
        WRITEBACK
    );

    signal state      : state_type := FETCH_ROM;
    signal next_state : state_type;
    
begin
    process(Clk)
    begin
        if rising_edge(Clk) then
            if rst = '1' then
                state <= FETCH_ROM;
            else
                state <= next_state;
            end if;
        end if;
    
    
    end process;


    process(state, opcode, flag_z)
    begin
        next_state <= state;
    
        case state is
    
            when FETCH_ROM =>
                next_state <= FETCH_IR;
    
            when FETCH_IR =>
                ir_enable <= '1';
                next_state <= DECODE;
    
            when DECODE =>
                next_state <= EXECUTE;
    
            when EXECUTE =>
    
                if opcode = "0000" then       -- NOP
                    next_state <= FETCH_ROM;
    
                elsif opcode = "0001" then    -- ADD
                    next_state <= WRITEBACK;
    
                else
                    next_state <= FETCH_ROM;
                end if;
    
            when WRITEBACK =>
                reg_write_enable <= '1';
                pc_enable <= '1';
                next_state <= FETCH_ROM;
    
        end case;
    end process;

end rtl;










