library ieee;
use ieee.std_logic_1164.all;

entity PWM_driver_E is
  generic(
    pwm_bit : integer := 14
    );
  port(
    reset_n                         : in  std_logic;
    clk                             : in  std_logic;
    pwm_base_period                 : in  integer range 0 to 2**(pwm_bit)-1;
    pwm_duty_cycle                  : in  integer range 0 to 2**(pwm_bit)-1;
    pwm_control                     : in  std_logic_vector(7 downto 0);
    pwm_cycle_done                  : out std_logic;  -- new values at inputs are now used
    pwm_out1, pwm_out2, pwm_n_sleep : out std_logic);
end PWM_driver_E;

architecture rtl of PWM_driver_E is
  signal counter      : integer range 0 to 2**(pwm_bit)-1;

  -- To make sure that PWM Period, Duty Cycle, and Control Flags are not changed mid-cycle
  signal base_reg : integer range 0 to 2**(pwm_bit)-1;
  signal duty_reg : integer range 0 to 2**(pwm_bit)-1;
  signal ctrl_reg : std_logic_vector(7 downto 0);

begin
  process(clk, reset_n)
    -- A variable to check for how long the signal should remain active (Duty Cycle)
    variable is_active : boolean;
  begin
    if reset_n = '0' then
      counter        <= 0;
      base_reg       <= 0;
      duty_reg       <= 0;
      ctrl_reg       <= (others => '0');
      pwm_cycle_done <= '0';
      pwm_out1       <= '0';
      pwm_out2       <= '0';
      pwm_n_sleep    <= '0';
    elsif rising_edge(clk) then
      -- Resetting the counter, updating the registers, and flagging that the current cycle is done
      -- If period is 0, there will be one cycle with the respective output data
      if base_reg = 0 or counter + 1 >= base_reg then -- base_reg = 0 or counter >= base_reg - 1
        counter        <= 0;
        pwm_cycle_done <= '1';
        
        base_reg   <= pwm_base_period;
        duty_reg   <= pwm_duty_cycle;
        ctrl_reg   <= pwm_control;
      else
        counter        <= counter + 1;
        pwm_cycle_done <= '0';
      end if;

      -- Determining active state with Duty Cycle
      if counter < duty_reg then
        is_active := true;
      else
        is_active := false;
      end if;

      -- Control logic
      if ctrl_reg(0) = '0' then -- Enable - Pos 0
        pwm_n_sleep <= '0';
        pwm_out1    <= 'Z';
        pwm_out2    <= 'Z';
      else
        pwm_n_sleep <= '1';
        
        if ctrl_reg(2) = '1' then -- Brake - Pos 2
          -- Brake enabled
          pwm_out1 <= '1';
          pwm_out2 <= '1';
        else
          -- Normal operation with Reverse toggle
          if is_active then
            pwm_out1 <= '1';
            if ctrl_reg(1) = '1' then -- Reverse toggle - Pos 1
              pwm_out2 <= '0'; -- Reversed
            else
              pwm_out2 <= '1';
            end if;
          else
            pwm_out1 <= '0';
            if ctrl_reg(1) = '1' then
              pwm_out2 <= '1';
            else
              pwm_out2 <= '0';
            end if;
          end if;
        end if;
      end if;
    end if;
  end process;
end rtl;