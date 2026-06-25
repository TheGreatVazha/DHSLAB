LIBRARY IEEE;
USE IEEE.ELECTRICAL_SYSTEMS.ALL;
USE IEEE.MATH_REAL.ALL;

ENTITY diode_E IS
  GENERIC (
    thermalVoltage    : real := 0.025; -- 25 mV
    idealityFactor    : real := 1.1;
    saturationCurrent : real := 1.0e-9 -- 1 nA
  );
  PORT (
    TERMINAL anode, cathode : ELECTRICAL);

END diode_E;

ARCHITECTURE behav OF diode_E IS
  QUANTITY u_d ACROSS i_d THROUGH anode TO cathode;
BEGIN
  i_d == saturationCurrent * (exp(u_d / (idealityFactor * thermalVoltage)) - 1.0);
END behav;