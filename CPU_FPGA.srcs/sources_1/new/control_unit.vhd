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
    
        next_state         <= state;
    
        pc_enable          <= '0';
        pc_load            <= '0';
        ir_enable          <= '0';
    
        reg_write_enable   <= '0';
        reg_write_sel      <= "00";
    
        ram_read_enable    <= '0';
        ram_write_enable   <= '0';
    
        flags_write_enable <= '0';
        halted             <= '0';
        
        case opcode is
        
            when "0001" => alu_op <= "000"; -- ADD
            when "0010" => alu_op <= "001"; -- SUB
            when "0011" => alu_op <= "010"; -- AND
            when "0100" => alu_op <= "011"; -- OR
            when "0101" => alu_op <= "100"; -- XOR
            when "0110" => alu_op <= "101"; -- NOT
            when "0111" => alu_op <= "110"; -- SHL
            when "1000" => alu_op <= "111"; -- SHR
            when others => alu_op <= "000";
        
        end case;
        
        case state is
    
            when FETCH_ROM =>
                next_state <= FETCH_IR;
    
            when FETCH_IR =>
                ir_enable <= '1';
                next_state <= DECODE;
    
            when DECODE =>
                next_state <= EXECUTE;
    
            when EXECUTE =>
    
                case opcode is
            
                    when "0000" =>       -- NOP
                        pc_enable <= '1';
                        next_state <= FETCH_ROM;
            
                    when "0001" =>       -- ADD
                        alu_op <= "000";
                        next_state <= WRITEBACK;
            
                    when "0010" =>       -- SUB
                        alu_op <= "001";
                        next_state <= WRITEBACK;
            
                    when "0011" =>       -- AND
                        alu_op <= "010";
                        next_state <= WRITEBACK;
            
                    when "0100" =>       -- OR
                        alu_op <= "011";
                        next_state <= WRITEBACK;
            
                    when "0101" =>       -- XOR
                        alu_op <= "100";
                        next_state <= WRITEBACK;
            
                    when "0110" =>       -- NOT
                        alu_op <= "101";
                        next_state <= WRITEBACK;
            
                    when "0111" =>       -- SHL
                        alu_op <= "110";
                        next_state <= WRITEBACK;
            
                    when "1000" =>       -- SHR
                        alu_op <= "111";
                        next_state <= WRITEBACK;
            
                    when others =>
                        next_state <= FETCH_ROM;
            
                end case;
    
            when WRITEBACK =>
                reg_write_sel    <= "00";   -- Résultat ALU
                reg_write_enable <= '1';    -- Écriture Register File
            
                pc_enable        <= '1';    -- Incrémentation PC
                next_state <= FETCH_ROM;
    
        end case;
    end process;

end rtl;










