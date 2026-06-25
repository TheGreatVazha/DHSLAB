-- Model for TI DRV8837 motor driver (Calliope)

LIBRARY IEEE;
USE IEEE.ELECTRICAL_SYSTEMS.ALL;
use IEEE.std_logic_1164.all;
use ieee.math_real.all;

ENTITY motor_driver_E IS
  PORT (
    TERMINAL Out1, Out2, GROUND, VM, VCC : ELECTRICAL;
    SIGNAL IN1, IN2, nSLEEP : in std_logic);

END motor_driver_E;

ARCHITECTURE struct OF motor_driver_E IS

  COMPONENT sw_resistor IS
    GENERIC (
      v_th : real := 2.0;
      beta : real := 150.0
    );
    PORT (
      TERMINAL a,b : ELECTRICAL;
      ctrl         : IN std_logic
    );
  END COMPONENT;

  -- Declare the diode component
  COMPONENT diode_E IS
    GENERIC (
      thermalVoltage    : real := 0.025;
      idealityFactor    : real := 1.1;
      saturationCurrent : real := 1.0e-9
    );
    PORT (
      TERMINAL anode, cathode : ELECTRICAL
    );
  END COMPONENT;
  
  -- Internal control signals for the 4 H-bridge MOSFETs
  SIGNAL ctrl_hs1, ctrl_ls1 : std_logic := '0';
  SIGNAL ctrl_hs2, ctrl_ls2 : std_logic := '0';

BEGIN

  -- Digital logic block translating inputs into MOSFET control signals
  -- Based on Table 6: Logic output definition of the motor driver
  logic_proc : PROCESS(IN1, IN2, nSLEEP)
  BEGIN
    -- Default state: Coast (High-Z, all switches open), and accounting for IN1 = 0 and IN2 = 0
    ctrl_hs1 <= '0';
    ctrl_ls1 <= '0';
    ctrl_hs2 <= '0';
    ctrl_ls2 <= '0';

    IF nSLEEP = '1' THEN
      IF IN1 = '1' AND IN2 = '0' THEN
        -- Drive Motor 1 (Forward): Out1 High, Out2 Low
        ctrl_hs1 <= '1';
        ctrl_ls2 <= '1';
      ELSIF IN1 = '0' AND IN2 = '1' THEN
        -- Drive Motor 2 (Reverse): Out1 Low, Out2 High
        ctrl_hs2 <= '1';
        ctrl_ls1 <= '1';
      ELSIF IN1 = '1' AND IN2 = '1' THEN
        -- Brake: Out1 Low, Out2 Low
        ctrl_ls1 <= '1';
        ctrl_ls2 <= '1';
      END IF;
    END IF;
  END PROCESS;

  -- Half-Bridge 1 (Out1)
  HS1_switch : sw_resistor
    PORT MAP (a => VM, b => Out1, ctrl => ctrl_hs1);

  LS1_switch : sw_resistor
    PORT MAP (a => Out1, b => GROUND, ctrl => ctrl_ls1);

  D1_hs1 : diode_E
    PORT MAP (anode => Out1, cathode => VM);

  D2_ls1 : diode_E
    PORT MAP (anode => GROUND, cathode => Out1);

  -- Half-Bridge 2 (Out2)
  HS2_switch : sw_resistor
    PORT MAP (a => VM, b => Out2, ctrl => ctrl_hs2);

  LS2_switch : sw_resistor
    PORT MAP (a => Out2, b => GROUND, ctrl => ctrl_ls2);

  D3_hs2 : diode_E
    PORT MAP (anode => Out2, cathode => VM);

  D4_ls2 : diode_E
    PORT MAP (anode => GROUND, cathode => Out2);

END struct;