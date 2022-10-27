library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

library sm4;
use sm4.sm4_pkg.all;

entity key_expansion is

  port(
    clk:        in  std_ulogic;
    resetn:     in  std_ulogic;
    cmd_reset:  in  std_ulogic;
    cmd_freeze: in  std_ulogic;
    working:    in  std_ulogic;
    key:        in  sm4_w128_t;
    key_ready:  out std_ulogic;
    rk:         out sm4_rk_array_t
  );

end entity key_expansion;

architecture rtl of key_expansion is

  signal cz  : std_ulogic;
  signal inc : std_ulogic;
  signal cnt : natural range 0 to 32;

  signal starting : std_ulogic;
  signal finished : std_ulogic;

  signal K : sm4_w128_t;

  signal K_in : sm4_w128_t;

  signal K_out : sm4_w128_t;

  begin

  cz <= cmd_reset;

  K <= key xor x"a3b1bac656aa3350677d9197b27022dc";

  inc <= working and not cmd_freeze;

  key_ready <= '1' when (cnt >= 4) else '0';

  counter32: entity work.counter(rtl)

    generic map(cmax => 32)

    port map(
    clk     => clk,
    sresetn => resetn,
    cz      => cz,
    inc     => inc,
    c       => cnt
    );

  K_in <= K when cnt = 0 else K_out;

  process(clk)
  begin
    if rising_edge(clk) then
      if not resetn or cmd_reset then
        K_out <= (others => '0');
      elsif (cnt /= 32) and (working = '1') and (cmd_freeze = '0') and (finished = '0') then
        K_out <= key_exp_function(K_in, ck_function(cnt));
      end if;
    end if;
  end process;


  process(clk)
  begin
    if rising_edge(clk) then
      if not resetn or cmd_reset then
        rk <= (others => (others => '0'));
      elsif (cmd_freeze = '0') and (cnt /= 0) then
        rk(cnt - 1) <= K_out(31 downto 0);
      end if;
    end if ;
  end process;

  process(clk)
  begin
    if rising_edge(clk) then
      if not resetn or cmd_reset then
        starting <= '1';
      elsif working and starting and not cmd_freeze then
        starting <= '0';
      end if;
    end if ;
  end process;

  process(clk)
  begin
    if rising_edge(clk) then
      if not resetn or cmd_reset then
        finished <= '0';
      elsif (working = '1') and (finished = '0') and (cmd_freeze = '0') and (cnt = 32) then
        finished <= '1';
      end if;
    end if ;
  end process;

end architecture rtl;
