library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_pwm_controller is
end tb_pwm_controller;

architecture testbench of tb_pwm_controller is

  constant pwm_bit        : integer := 14;
  constant message_length : integer := 17;
  constant address_length : integer := 2;
  
  signal reset_n, clk, new_data_S, pwm_cycle_done_s : std_logic := '0';
  signal regwrite_n_S                               : std_logic;
  signal regnr_S                                    : std_logic_vector(address_length-1 downto 0);
  signal regcontent_S                               : std_logic_vector (pwm_bit-1 downto 0);
  signal pwm_base_S, pwm_duty_S                     : integer range 0 to 2**(pwm_bit)-1;
  signal pwm_control_S                              : std_logic_vector(7 downto 0);

  -- Flag to stop clock generation at the end of the test.
  signal sim_done                                   : boolean := false;

  component PWM_controller_E is
    generic(message_length : integer := 17;
            pwm_bit        : integer := 14;
            address_length : integer := 2
            );
    port(                               -- general inputs
      reset_n    : in std_logic;
      clk        : in std_logic;
      -- from SPI controller
      new_data   : in std_logic;        -- new data available
      regnr      : in std_logic_vector (address_length-1 downto 0);  -- register address
      regcontent : in std_logic_vector (pwm_bit-1 downto 0);  -- register write value
      regwrite_n : in std_logic;        -- write access?

      -- from/to pwm_driver
      pwm_cycle_done  : in  std_logic;  -- new values at inputs are now used
      pwm_control     : out std_logic_vector(7 downto 0);
      pwm_base_period : out integer range 0 to 2**(pwm_bit)-1;
      pwm_duty_cycle  : out integer range 0 to 2**(pwm_bit)-1
      );
  end component;

begin

-- ADD AN INSTANCE OF THE PWM CONTROLLER AND CONNECT ALL THE PORTS WITH THE
-- CORESSPONDING SIGNALS:
  DUT : PWM_controller_E
    generic map (
      message_length => message_length,
      pwm_bit        => pwm_bit,
      address_length => address_length
    )
    port map (
      reset_n         => reset_n,
      clk             => clk,
      new_data        => new_data_S,
      regnr           => regnr_S,
      regcontent      => regcontent_S,
      regwrite_n      => regwrite_n_S,
      pwm_cycle_done  => pwm_cycle_done_s,
      pwm_control     => pwm_control_S,
      pwm_base_period => pwm_base_S,
      pwm_duty_cycle  => pwm_duty_S
    );

-- reset generation for the PWM controller
  reset_n <= '1' after 100 ns;

-- generation of pwm_cycle_done after each PWM cycle
  ack_gen_P : process
  begin
    while not sim_done loop
      pwm_cycle_done_s <= '1';
      wait for 10 ns;
      pwm_cycle_done_s <= '0';
      wait for pwm_base_s * 10 ns;
    end loop;
    wait;
  end process;

-- ADD CLOCK GENERATION FOR THE PWM CONTROLLER
  clk <= not clk after 5 ns when not sim_done else '0';

  PWM_test : process
  begin
    -- ADD TEST CASES FOR THE PWM CONTROLLER:
    -- Initialising inputs
    new_data_S   <= '0';
    regwrite_n_S <= '1';
    regnr_S      <= "00";
    regcontent_S <= (others => '0');

    -- Test Case - 1 : Reset functioning
    
    wait until reset_n = '1';   -- Active low reset
    wait until rising_edge(clk);
    -- Asserting if the output doesn't match the reset state in pwm_controller
    assert pwm_base_S = 2 report "Reset Failed: Base period not initialized to 2. Got:" & integer'image(pwm_base_S) severity error;
    assert pwm_control_S = x"00" report "Reset Failed: Control flags not initialized to 0" severity error;

    -- Test Case - 3 : Check if new data is accepted only when regwrite_n_S is low
    wait until rising_edge(clk);
    regnr_S      <= "01";
    regcontent_S <= std_logic_vector(to_unsigned(200, 14));
    regwrite_n_S <= '1'; -- Active low
    new_data_S   <= '1';
    wait until rising_edge(clk);
    new_data_S   <= '0';

    wait until falling_edge(pwm_cycle_done_s); -- PWM cycle done and controller checks if new data available
    assert (pwm_base_S = 2) 
      report "Test Case 3 Failed: Target loaded when regwrite_n was high. And got base period:" & integer'image(pwm_base_S) severity error;

    -- Test Case 4 : Checking internal register addressing
    -- Test Case 4.1 : "00" - Unused
    wait until rising_edge(clk);
    regnr_S      <= "00";
    regcontent_S <= std_logic_vector(to_unsigned(200, 14));
    regwrite_n_S <= '0';
    new_data_S   <= '1';
    wait until rising_edge(clk); -- Makes sure the data is read
    new_data_S   <= '0';
    regwrite_n_S <= '1';

    wait until falling_edge(pwm_cycle_done_s); -- Makes sure the new values are calculated
    assert (pwm_base_S = 2 and pwm_duty_S = 0 and pwm_control_S = x"00") 
      report "Case 4 Failure: Address '00' modified outputs! Modified Base: " & integer'image(pwm_base_S) & ", Duty cycle:" & 
      integer'image(pwm_duty_S) & ", and Control flags:" & integer'image(to_integer(unsigned(pwm_control_S))) 
      severity error;

    -- Test Case 4.2 : "11" (Control Flags - direct update, no stepping)
    wait until rising_edge(clk);
    regnr_S      <= "11";
    regcontent_S <= std_logic_vector(to_unsigned(7, 14)); 
    regwrite_n_S <= '0';
    new_data_S   <= '1';
    wait until rising_edge(clk);
    new_data_S   <= '0';
    regwrite_n_S <= '1';

    wait until falling_edge(pwm_cycle_done_s);
    assert (pwm_base_S = 2 and pwm_duty_S = 0 and pwm_control_S = x"07") 
      report "Case 4 Failure: Address '11' failed or modified other registers! Got Base: " & integer'image(pwm_base_S) & ", Duty cycle:" & 
      integer'image(pwm_duty_S) & ", and Control flags:" & integer'image(to_integer(unsigned(pwm_control_S))) severity error;

    -- Test Case 4.3 : "10" (Duty Cycle - step up by 32)
    wait until rising_edge(clk);
    regnr_S      <= "10";
    regcontent_S <= std_logic_vector(to_unsigned(100, 14));
    regwrite_n_S <= '0';
    new_data_S   <= '1';
    wait until rising_edge(clk);
    new_data_S   <= '0';
    regwrite_n_S <= '1';

    wait until falling_edge(pwm_cycle_done_s);
    assert (pwm_base_S = 2 and pwm_duty_S = 32 and pwm_control_S = x"07") 
      report "Case 4 Failure: Address '10' failed or modified other registers! Got Base: " & integer'image(pwm_base_S) & ", Duty cycle:" & 
      integer'image(pwm_duty_S) & ", and Control flags:" & integer'image(to_integer(unsigned(pwm_control_S))) severity error;

    -- Test Case 4.4 : "01" (Base Period - step up by 32)
    -- & Test Case 5 : Updates only on pwm_cycle_done = '1'
    wait until rising_edge(clk);
    regnr_S      <= "01"; 
    regcontent_S <= std_logic_vector(to_unsigned(500, 14));
    regwrite_n_S <= '0';
    new_data_S   <= '1';
    wait until rising_edge(clk);
    new_data_S   <= '0';
    regwrite_n_S <= '1';

    -- Case 5 : Checking BEFORE the pwm cycle is done (Wait just 1 clock to avoid race condition with pwm_cycle_done)
    wait until rising_edge(clk);
    assert (pwm_base_S = 2 and pwm_duty_S = 32 and pwm_control_S = x"07") 
      report "Case 5 Failure: Value updated BEFORE pwm_cycle_done was high!" severity error;

    -- Case 4.4 : Checking AFTER the cycle is done
    -- Duty cycle target is 100, so it will step up again to 32 + 32 = 64. And Base period become 2 + 64 = 66
    wait until falling_edge(pwm_cycle_done_s);
    assert (pwm_base_S = 66 and pwm_duty_S = 64 and pwm_control_S = x"07") 
      report "Case 4 Failure: Address '01' failed or modified other registers! Got Base:" & integer'image(pwm_base_S) & ", Duty cycle:" & 
      integer'image(pwm_duty_S) & ", and Control flags:" & integer'image(to_integer(unsigned(pwm_control_S))) severity error;
    
    -- Test Case 6 : Verify only lower 8 bits of reg_content is used for pwm_control
    wait until rising_edge(clk);
    regnr_S      <= "11"; -- Control
    -- regcontent = 8362 = 100000 10101010, pwm_control = Lower 8 bits = 0xAA
    regcontent_S <= std_logic_vector(to_unsigned(8362, 14)); 
    regwrite_n_S <= '0';
    new_data_S   <= '1';
    wait until rising_edge(clk);
    new_data_S   <= '0';
    regwrite_n_S <= '1';

    wait until falling_edge(pwm_cycle_done_s);
    assert (pwm_control_S = x"AA" and pwm_base_S = 130 and pwm_duty_S = 96)
      report "Case 6 Failure: Lower 8 bits of reg_content not sliced properly! Expected 170 (0xAA), Got: " & 
      integer'image(to_integer(unsigned(pwm_control_S))) severity error;

    -- Test Case 7 : Verify Step-wise changes to pwm_base_period and pwm_duty_cycle
    -- Test Case 7.1 : Checking Increment of 64 for Base Period and 32 for Duty Cycle
    -- Target for Base Period: 500. Current Value: 130<500. Hence Next Value: 130 + 64 = 194
    -- Target for Duty Cycle : 100. Current Value:  96<100. Hence Next Value:  96 + 32 = 128
    wait until falling_edge(pwm_cycle_done_s);
    assert (pwm_base_S = 194 and pwm_duty_S = 128) 
      report "Case 7 Increment Failure: Expected Base Period 194, Duty Cycle 128. Got Base: " & integer'image(pwm_base_S) & 
      ", Duty: " & integer'image(pwm_duty_S) severity error;
    
    -- Test Case 7.2 : Checking Decrement of 31 for both Base Period and Duty Cycle.
    -- Duty Cycle : Current value (128) > Target value (100). So Next value: 128 - 31 = 97
    -- Base Period: Change Target to 100 so that, Current value (194) > Target (100). Next value: 194 - 31 = 163
    wait until rising_edge(clk);
    regnr_S      <= "01"; -- Base
    regcontent_S <= std_logic_vector(to_unsigned(100, 14)); -- Target 100
    regwrite_n_S <= '0';
    new_data_S   <= '1';
    wait until rising_edge(clk);
    new_data_S   <= '0';
    regwrite_n_S <= '1';

    wait until falling_edge(pwm_cycle_done_s);
    assert (pwm_base_S = 163 and pwm_duty_S = 97)
      report "Case 7 Decrement Failure: Expected Base Period 163, Duty Cycle 97. Got Base: " & integer'image(pwm_base_S) & 
      ", Duty: " & integer'image(pwm_duty_S) severity error;

    -- Test Case 8 : Checking upper and lower limit clamping of Base Period and Duty Cycle.
    -- Test Case 8.1 : Upper limit = 2^14 = 16384
    wait until rising_edge(clk);
    regnr_S      <= "01"; -- Base
    regcontent_S <= std_logic_vector(to_unsigned(16383, 14)); -- Max Target
    regwrite_n_S <= '0';
    new_data_S   <= '1';
    wait until rising_edge(clk);

    -- Write to Duty on the very next clock cycle
    regnr_S      <= "10"; -- Duty
    regcontent_S <= std_logic_vector(to_unsigned(16383, 14)); -- Max Target
    wait until rising_edge(clk);
    new_data_S   <= '0';
    regwrite_n_S <= '1';

    -- Waiting till upper limit is reached
    -- Cycles for Base: (16384 - 163)//64 = 253. for Duty: (16384-97)//32 = 508.
    -- Hence waiting for 510 cycles to be sure both are clamped to the upper limit.
    for i in 1 to 510 loop
      wait until falling_edge(pwm_cycle_done_s);
    end loop;

    assert (pwm_base_S = 16383 and pwm_duty_S = 16383)
      report "Case 8 Upper limit Failure: Upper limit clamping failed! Got Base: " & integer'image(pwm_base_S) & 
      ", Duty: " & integer'image(pwm_duty_S) severity error;
    
    -- Test Case 8.2 : Lower limit = 0
    wait until rising_edge(clk);
    regnr_S      <= "01"; -- Base
    regcontent_S <= std_logic_vector(to_unsigned(0, 14)); -- Min Target
    regwrite_n_S <= '0';
    new_data_S   <= '1';
    wait until rising_edge(clk);
    
    -- Write to Duty on the very next clock cycle
    regnr_S      <= "10"; -- Duty
    regcontent_S <= std_logic_vector(to_unsigned(0, 14)); -- Min Target
    wait until rising_edge(clk);
    new_data_S   <= '0';
    regwrite_n_S <= '1';

    -- Wait till lower limit is reached
    -- Cycles for both base and duty: (16384 - 0)//31 = 528.
    -- Hence waiting for 540 cycles
    for i in 1 to 540 loop
      wait until falling_edge(pwm_cycle_done_s);
    end loop;

    assert (pwm_base_S = 0 and pwm_duty_S = 0)
      report "Case 8 Lower limit Failure: Lower limit clamping failed! Got Base: " & integer'image(pwm_base_S) & 
      ", Duty: " & integer'image(pwm_duty_S) severity error;

    report "Simulation Finished Successfully!" severity note;
    sim_done <= true;

    wait;
  end process;
end testbench;