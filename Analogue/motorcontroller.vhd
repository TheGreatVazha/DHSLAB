LIBRARY IEEE;
USE IEEE.ELECTRICAL_SYSTEMS.ALL;
use IEEE.std_logic_1164.all;
use ieee.math_real.all;

ENTITY motorcontroller IS
    generic(message_length : integer   := 24;
            pwm_bit        : integer   := 21;
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
END motorcontroller;

ARCHITECTURE struct OF motorcontroller IS

  -- Digital PWM Generator Top Level
  COMPONENT PWM_digital_top_E IS
    generic(message_length : integer;
            pwm_bit        : integer;
            address_length : integer);
    port (                               
      reset_n                         : in  std_logic;
      clk                             : in  std_logic;
      sclk                            : in  std_logic;
      cs_n                            : in  std_logic;
      din                             : in  std_logic;
      pwm_out1, pwm_out2, pwm_n_sleep : out std_logic
    );
  END COMPONENT;

  -- Analog Motor Driver (H-Bridge)
  COMPONENT motor_driver_E IS
    PORT (
      TERMINAL Out1, Out2, GROUND, VM, VCC : ELECTRICAL;
      SIGNAL IN1, IN2, nSLEEP : in std_logic
    );
  END COMPONENT;

  SIGNAL sig_pwm_out1    : std_logic;
  SIGNAL sig_pwm_out2    : std_logic;
  SIGNAL sig_pwm_n_sleep : std_logic;


BEGIN
  -- Digital Subsystem
  inst_digital_top: PWM_digital_top_E
    GENERIC MAP (
      message_length => message_length,
      pwm_bit        => pwm_bit,
      address_length => address_length
    )
    PORT MAP (
      reset_n     => reset_n,
      clk         => clk,
      sclk        => sclk,
      cs_n        => cs_n,
      din         => din,
      pwm_out1    => sig_pwm_out1,
      pwm_out2    => sig_pwm_out2,
      pwm_n_sleep => sig_pwm_n_sleep
    );

  -- Analog Subsystem
  inst_analog_driver: motor_driver_E
    PORT MAP (
      Out1   => Out1,
      Out2   => Out2,
      GROUND => GROUND,
      VM     => VM,
      VCC    => VCC,
      IN1    => sig_pwm_out1,
      IN2    => sig_pwm_out2,
      nSLEEP => sig_pwm_n_sleep
    );

END struct;