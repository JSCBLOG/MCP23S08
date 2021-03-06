-- This code interfaces with the MCP23S08 spi ic to control leds.
-- The I/O direction register is configures as an output 
-- and does not read from the o_spi_mosi line.
--
-- The i_tx_pulse is from a debounced input switch, o_spi_clk is 
-- set to 10Mhz, both from the top module.
--
-- FPGA: Nexys-4 DDR
-- Author: Jerome Samuels-Clarke
-- Website: www.jscblog.com

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity spi_MCP23S08 is
	port (
    	i_clk		: in std_logic;
        i_reset 	: in std_logic;
        
        -- mosi signal 
        i_tx_pulse	: in std_logic;
        -- spi interface
        o_spi_clk	: out std_logic;
        o_spi_mosi 	: out std_logic;
        o_cs		: out std_logic);
end entity;

architecture rtl of spi_MCP23S08 is
    type t_ctrl_path is (s_idle, s_enable, s_xmit);
    signal r_state : t_ctrl_path := s_idle;
    
    constant c_MCP23S08_ADDR_W 	: std_logic_vector(7 downto 0) := X"40"; -- address of mcp23s08 for write command
    constant c_MCP23S08_IODIR  	: std_logic_vector(7 downto 0) := X"00"; -- i/o direction register
    constant c_MCP23S08_IODIR_W	: std_logic_vector(7 downto 0) := X"00"; -- set leds as output
    constant c_MCP23S08_GPIO   	: std_logic_vector(7 downto 0) := X"09"; -- gpio register
    constant c_MCP23S08_GPIO_W 	: std_logic_vector(7 downto 0) := X"AA"; -- turn leds on
    
    signal r_tx_reg 	: std_logic_vector(23 downto 0) := (others => '0'); -- transmit register
    signal r_tmr_reg	: std_logic_vector(23 downto 0) := (others => '0'); -- shift counter  for transmission
    signal r_load_tx	: std_logic := '0'; -- signal to load mosi data
	signal r_done_tick	: std_logic := '0'; -- set after transmission is complete
    
    signal r_setup		: std_logic := '0'; -- set after the i/o direction 
begin

	fsm_proc : process (i_clk, i_reset)
	begin
        if (i_reset = '1') then
            o_cs <= '1';
        	r_load_tx <= '0';
        elsif (rising_edge(i_clk)) then
        	r_load_tx <= '0';
        	case (r_state) is
            	when s_idle =>
                	o_cs <= '1';	-- active low
                	if (i_tx_pulse = '1') then
                    	r_state <= s_enable;
                        o_cs <= '0';
                    end if;
                    
                when s_enable =>
                	r_load_tx <= '1';
                    r_state <= s_xmit;
                    
                when s_xmit =>
                	if (r_done_tick = '1') then
                    	r_state <= s_idle;
                    end if;                
             end case;            
        end if;
    end process;
    
    spi_mosi : process (i_clk, i_reset)
    begin
    	if (i_reset = '1') then
        	r_tx_reg  	<= (others => '0');
            r_tmr_reg 	<= (others => '0');
            r_setup		<= '0';
        elsif (falling_edge(i_clk)) then
        	if (r_load_tx = '1') then
            	if (r_setup = '0') then        -- check to see if the i/o has been set
            		r_tx_reg  <= c_MCP23S08_ADDR_W & c_MCP23S08_IODIR & c_MCP23S08_IODIR_W;
                    r_setup <= '1';
              	else
            		r_tx_reg  <= c_MCP23S08_ADDR_W & c_MCP23S08_GPIO & c_MCP23S08_GPIO_W;
                end if;
                r_tmr_reg <= (others => '1'); -- start o_spi_clk
          	else
            	r_tx_reg <= r_tx_reg(r_tx_reg'high-1 downto r_tx_reg'low) & '0';
            	r_tmr_reg <= r_tmr_reg(r_tmr_reg'high-1 downto r_tmr_reg'low) & '0';
            end if;
        end if;
    end process;
    
    r_done_tick <= '1' when r_tmr_reg = X"000000" else '0';
    o_spi_mosi <= r_tx_reg(r_tx_reg'high);
    o_spi_clk	<= i_clk when r_tmr_reg /= X"000000" else '0';

end rtl;
