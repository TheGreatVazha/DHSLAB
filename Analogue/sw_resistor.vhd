LIBRARY IEEE;
USE IEEE.ELECTRICAL_SYSTEMS.ALL;
USE IEEE.STD_LOGIC_1164.ALL;

ENTITY sw_resistor IS
  
  GENERIC (
    v_th : real := 2.0;
    beta : real := 150.0);        -- change entity to switchable resistor

  PORT (
    TERMINAL a,b : ELECTRICAL;
    ctrl  : in std_logic);

END sw_resistor;

ARCHITECTURE behavioural OF sw_resistor IS
  QUANTITY u_ds ACROSS i_ds THROUGH a TO b;
  QUANTITY u_gs : real; -- Free quantity for gate-source voltage
  signal v_gs_target : real := 0.0; -- Discrete target voltage
BEGIN  -- simple
  v_gs_target <= 5.0 WHEN ctrl = '1' ELSE 0.0; -- Digital value to target real value V_GS
  u_gs == v_gs_target'slew(50.0e6, -50.0e6); -- Slew rate to physical V_GS
  BREAK ON u_gs'ABOVE(v_th); -- DAE restart on switch events
  IF u_gs'ABOVE(v_th) USE
    i_ds == (beta / 2.0) * 2.0 * (u_gs - v_th)**2; -- on
  ELSE
    i_ds == 0.0; -- off
  END USE;

END behavioural;