library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity SPI is
  generic(message_length : integer   := 17;
          pwm_bit        : integer   := 14;
          address_length : integer   := 2);
         
  port (                                -- general signals
    reset_n    : in  std_logic;
    clk        : in  std_logic;
    -- SPI interface
    sclk       : in  std_logic;
    cs_n       : in  std_logic;
    din        : in  std_logic;
    -- internal interface
    new_data   : out std_logic;         -- new data available
    regnr      : out std_logic_vector (address_length-1 downto 0);  -- register address
    regcontent : out std_logic_vector (pwm_bit-1 downto 0);  -- register write value
    regwrite_n : out std_logic          -- write access?
    );
end entity SPI;

architecture RTL of SPI is
  --ADD TYPE FOR STATE MACHINE
  type state_type is (IDLE, RECEIVE);
  signal state: state_type;

  --ADD SIGNALS
  signal din_prev_flag, din_curr_flag : std_logic; -- Flag to let the FSM know that data is collected from Master
  signal shift_reg   : std_logic_vector(message_length-1 downto 0); -- Data from SPI Master
  signal bit_counter : integer range 0 to message_length; -- Counter to count the bitwidth of the data from Master

begin

---------- Process - 1: SPI DIN Shift Register and counter that is Synchronous to falling edge of SPI Clock ----------

  spi_proc : process(reset_n, sclk, cs_n)
  begin
    -- Asynchronous reset on SPI interface
    if reset_n = '0' then
      shift_reg <= (others => '0');
      bit_counter   <= 0;
      din_curr_flag <= '0';
    elsif cs_n = '1' then
      bit_counter   <= 0;
      din_curr_flag <= '0';
    elsif falling_edge(sclk) then
      shift_reg <= shift_reg(message_length-2 downto 0) & din; -- First bit from DIN is MSB and last is LSB
      -- Counter logic
      if bit_counter = message_length - 1 then
        din_curr_flag   <= '1';
        bit_counter     <= 0;
      else
        din_curr_flag   <= '0';
        bit_counter     <= bit_counter + 1;
      end if;
    end if;
  end process;

---------------- Process - 2: FSM State Register and data output process synchronised to System Clock ----------------
  fsm_proc : process(reset_n, clk)
  begin
    -- Asynchronous reset on FSM
    if reset_n = '0' then
      state <= IDLE;
      new_data      <= '0';
      regnr         <= (others => '0');
      regcontent    <= (others => '0');
      regwrite_n    <= '1';
      
      din_prev_flag <= '1';
    elsif rising_edge(clk) then
      -- Using two flags to compare and make sure there's no duplication of data
      din_prev_flag <= din_curr_flag;

      new_data <= '0';
      case state is
        when IDLE =>
          if cs_n = '0' then
            state <= RECEIVE;
          end if;
        
        when RECEIVE =>
          if cs_n = '1' then
            state <= IDLE; -- Stoping transaction if master pulls CS high early
          elsif din_prev_flag = '0' and din_curr_flag = '1' then
            new_data   <= '1';
            regnr      <= shift_reg(message_length-1 downto message_length-address_length); -- 16 to 15
            regwrite_n <= shift_reg(message_length-address_length-1); -- 14
            regcontent <= shift_reg(pwm_bit-1 downto 0); -- 13 to 0

            -- Next state is updated too
            state <= IDLE;
          end if;
      end case;
    end if;
  end process;
end architecture RTL;