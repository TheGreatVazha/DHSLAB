-----------------------------------------------------------------------------------------------------
--  Student1 full name and matriculation number:
--  Student2 full name and matriculation number:
-----------------------------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.ELECTRICAL_SYSTEMS.ALL;
use IEEE.std_logic_1164.all;
use ieee.math_real.all;

ENTITY tb_motorcontroller IS
END tb_motorcontroller;

architecture testbench of tb_motorcontroller is

  constant message_length : integer   := 17;
  constant pwm_bit        : integer   := 14;
  constant address_length : integer   := 2;

  COMPONENT motorcontroller IS
    generic(message_length : integer   := 17;
            pwm_bit        : integer   := 14;
            address_length : integer   := 2);
    port (                 
      -- general signals
      reset_n                         : in  std_logic;
      clk                             : in  std_logic;
      -- SPI interface
      sclk                            : in  std_logic;
      cs_n                            : in  std_logic;
      din                             : in  std_logic;
      -- Analog connections
      TERMINAL Out1, Out2, GROUND, VM, VCC : ELECTRICAL);
  END COMPONENT;

  COMPONENT motor_model_E IS
  PORT (
    TERMINAL Pin1, Pin2 : ELECTRICAL;
    Quantity motor_rpm: out real);
  END COMPONENT;

  TERMINAL Pin1, Pin2, VM, VCC : ELECTRICAL;
  QUANTITY motor_pwm_Q1, motor_pwm_Q2 : real;
  QUANTITY Volt_motor1 ACROSS I_motor1 THROUGH VM;
  Quantity Volt_digital ACROSS I_digital THROUGH VCC;

  signal reset_n, clk, SPIclk_enable, start, send : std_logic := '0';
  signal cs_n_S, din_S, sclk_S, SPIclk                              : std_logic := '1';
  signal message                                                    : std_logic_vector(message_length-1 downto 0);
  signal debug_counter                                              : integer;

BEGIN
-----------------------------------------------------------------------------------------------------
--  device under test
-----------------------------------------------------------------------------------------------------
  dut : motorcontroller 
    generic map(message_length, pwm_bit, address_length)
    port map (
       	reset_n => reset_n,
       	clk     => clk,
       	sclk    => SPIclk,
       	cs_n    => cs_n_S,
       	din     => din_S,
       	Out1	=> Pin1, 
	Out2 	=> Pin2, 
	GROUND 	=> ELECTRICAL_REF, 
	VM 	=> VM, 
	VCC 	=> VCC);
-----------------------------------------------------------------------------------------------------
-- Analog part of testbench
-----------------------------------------------------------------------------------------------------
-- two motors as load
  load1 : ENTITY work.motor_model_E(simple)
  PORT MAP (Pin1, ELECTRICAL_REF, motor_pwm_Q1);  

  load2 : ENTITY work.motor_model_E(simple)
  PORT MAP (Pin2, ELECTRICAL_REF, motor_pwm_Q2);  

-- define voltage sources
  Volt_digital == 5.0;
  Volt_motor1 == 9.0;

-----------------------------------------------------------------------------------------------------
-- Digital part of testbench
-----------------------------------------------------------------------------------------------------

-- clocks and reset
  reset_n <= '1' after 100 ns;
  clk     <= not clk after 5 ns;        -- clk rate 100 MHz

  SPIclk <= sclk_S when SPIclk_enable = '1' else '1';

  SPIclk_P : process
  begin
    sclk_S <= '0'; -- 50 MHz clock
    wait for 100 ns;
    sclk_S <= '1';
    wait for 100 ns;
  end process;

-- general data generation for SPI transmission
  Data_P : process
  begin
    message                                           <= (others => '0');
    wait for 500 ns;
    message(message_length-1 downto message_length-2) <= "01";  -- write to base register 
    message(12)                                        <= '1';  -- set base value to 6144
    message(11)                                        <= '1';
    message(1 downto 0)                               <= "00";  
    start                                             <= '1';
    wait until send = '1';
    start                                             <= '0';
    wait until send = '0';
    message(message_length-1 downto message_length-2) <= "10";  -- write to duty register 
    message(12 downto 11)                               <= "10";  -- set duty value to 4096
    message(1 downto 0)                               <= "00";  
    start                                             <= '1';
    wait until send = '1';
    start                                             <= '0';
    wait until send = '0';
    message(message_length-1 downto message_length-2) <= "11";  -- write to control register 
    message(8 downto 7)                               <= "00";
    message(1 downto 0)                               <= "11";  -- invert& enable
    start                                             <= '1';
    wait until send = '1';
    start                                             <= '0';
    wait until send = '0';

    wait for 20 ms;

    -- have a look at your two matriculation numbers. Consider only the lower 4 digits (should be a number 0-9999). 
    -- Now send the higher value as base period and the lower value as duty cycle to the Motor Controller.
    -- (If you work alone use 234567 as second matriculation number.)
    -- Check in the simulation window how the rpms of the motors change.

    -- Matriculation 1: 922816 -> lower 4: 2816
    -- Matriculation 2 (Partner): 234567 -> lower 4: 4567
    -- Higher: 4567 (Base period)  -> 01000111010111 in binary
    -- Lower:  2816 (Duty cycle)   -> 00101100000000 in binary

    message <= (others => '0');
    message(message_length-1 downto message_length-2) <= "01";  -- write to base register 
    message(13 downto 0)                              <= "01000111010111"; -- 4567
    start                                             <= '1';
    wait until send = '1';
    start                                             <= '0';
    wait until send = '0';
    
    message <= (others => '0');
    message(message_length-1 downto message_length-2) <= "10";  -- write to duty register 
    message(13 downto 0)                              <= "00101100000000"; -- 2816
    start                                             <= '1';
    wait until send = '1';
    start                                             <= '0';
    wait until send = '0';
    
    wait;
  end process;

-- SPI sending process
  Send_P : process
  begin
    debug_counter <= -1;
    din_S         <= message(message_length-1);
    if start = '0' then
      wait until start = '1';
    end if;
    din_S         <= message(message_length-1);
    send          <= '1';
    SPIclk_enable <= '1';
    cs_n_S        <= '0';
    wait until rising_edge(sclk_S);
    for I in message_length-2 downto 0 loop
      debug_counter <= I;
      din_S         <= message(I);
      wait until rising_edge(sclk_S);
    end loop;
    debug_counter <= -3;
    cs_n_S        <= '1';
    send          <= '0';
    SPIclk_enable <= '0';
    wait until rising_edge(sclk_S);

  end process;



END testbench;