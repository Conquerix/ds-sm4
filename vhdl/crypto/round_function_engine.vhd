library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

library sm4;
use sm4.sm4_pkg.all;

entity round_function_engine is

  port(
    clk       : in  std_ulogic;
    resetn    : in  std_ulogic;
    cmd_reset : in  std_ulogic;
    cmd_freeze: in  std_ulogic;
    working   : in  std_ulogic;
    input     : in  sm4_w128_t;
    output    : out sm4_w128_t;
    in_valid  : in  std_ulogic;
    in_ready  : out std_ulogic;
    out_valid : out std_ulogic;
    out_ready : in  std_ulogic;
    rk_in_0   : in  sm4_w32_t;
    rk_in_1   : in  sm4_w32_t;
    rk_in_2   : in  sm4_w32_t;
    rk_in_3   : in  sm4_w32_t
  );

end entity round_function_engine;

architecture rtl of round_function_engine is

  type engine_state_t  is (round_1, round_2, round_3, round_4, reset);

  signal engine_state : engine_state_t;

  signal round_function_input  : sm4_w128_t;
  signal round_function_output : sm4_w128_t;
  signal round_function_rk     : sm4_w32_t;

  signal freeze : std_ulogic;

  begin

  in_ready  <= '1' when ((engine_state = round_4) and (in_valid = '1') and (out_ready = '1')) or (engine_state = reset) else '0';
  out_valid <= '1' when (engine_state = round_4) else '0';

  freeze <= '1' when (((engine_state = round_4) or (engine_state = reset)) and ((in_valid = '0') or (out_ready = '0'))) or (working = '0') else '0';

  round_function_input <= input when (engine_state = round_4) or (engine_state = reset) else output;

  process(engine_state, rk_in_0, rk_in_1, rk_in_2, rk_in_3)
  begin
    case engine_state is
      when round_1 => round_function_rk <= rk_in_1;
      when round_2 => round_function_rk <= rk_in_2;
      when round_3 => round_function_rk <= rk_in_3;
      when round_4 => round_function_rk <= rk_in_0;
      when reset   => round_function_rk <= rk_in_0;
    end case;
  end process;

  round_function_output <= round_function(round_function_input, round_function_rk);

  process(clk)
  begin
    if rising_edge(clk) then
      if not resetn or cmd_reset then
        output <= (others => '0');
      elsif not freeze and not cmd_freeze then
        output <= round_function_output;
      end if;
    end if;
  end process;

  process(clk)
  begin
    if rising_edge(clk) then
      if not resetn or cmd_reset then
        engine_state <= reset;
      elsif working and not cmd_freeze then
        case engine_state is
          when round_1 => engine_state <= round_2;
          when round_2 => engine_state <= round_3;
          when round_3 => engine_state <= round_4;
          when round_4 => if out_ready and in_valid then engine_state <= round_1; end if;
          when reset   => if out_ready and in_valid then engine_state <= round_1; end if;
        end case;
      end if;
    end if;
  end process;


end architecture rtl;
