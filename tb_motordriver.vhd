LIBRARY IEEE;
USE IEEE.ELECTRICAL_SYSTEMS.ALL;
use IEEE.std_logic_1164.all;
use ieee.math_real.all;

ENTITY tb_motordriver IS

END ENTITY;

ARCHITECTURE testbench of tb_motordriver IS

COMPONENT motor_driver_E IS
  
  PORT (
    TERMINAL Out1, Out2, GROUND, VM, VCC : ELECTRICAL;
    SIGNAL IN1, IN2, nSLEEP : std_logic);
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

  SIGNAL in1_S, in2_S, nSleep_S : std_logic:='0';--'Z';

  
BEGIN  

  dut : motor_driver_E
  PORT MAP (Out1 => Pin1, Out2 => Pin2, GROUND => ELECTRICAL_REF, VM => VM, VCC => VCC, In1=>in1_S, In2 => in2_S, nSleep => nSleep_S);

  load1 : ENTITY work.motor_model_E(simple) 
  PORT MAP (Pin1, ELECTRICAL_REF, motor_pwm_Q1);  

  load2 : ENTITY work.motor_model_E(simple) 
  PORT MAP (Pin2, ELECTRICAL_REF, motor_pwm_Q2);  

  Volt_digital == 5.0;
  Volt_motor1 == 9.0;

  nSleep_S <= '1' after 10 us; -- activate chip

  ctrl1_P: PROCESS
  BEGIN
    -- Testcase 1: Drive Motor 1 (Forward)
    wait for 300.0 us;
    in1_S <= '1';    -- forward1, coast2
    in2_S <= '0';
    
    -- Testcase 2: Drive Motor 2 (Reverse)
    wait for 600.0 us;
    in1_S <= '0';    -- coast1, forward2
    in2_S <= '1';
    
    -- Testcase 3: Brake 
    wait for 300.0 us;
    in1_S <= '1';    
    in2_S <= '1';
    
    -- Testcase 4: Coast (Active Mode)
    wait for 300.0 us;
    in1_S <= '0';    
    in2_S <= '0';
    
    -- Testcase 5: Coast (Sleep Mode)
    wait for 300.0 us;
    nSleep_S <= '0'; -- Put chip to sleep
    in1_S <= '1';    -- Try to drive Motor 1, but sleep should force Coast
    in2_S <= '0';
    
    wait; -- Stop the process so it doesn't loop endlessly
   END PROCESS;
  
END testbench;