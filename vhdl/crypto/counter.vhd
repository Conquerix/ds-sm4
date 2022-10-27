library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

entity counter is
  generic(
    cmax : natural := 5
  );
  port(
    clk : in std_ulogic;
    sresetn : in std_ulogic;
    cz : in std_ulogic;
    inc : in std_ulogic;
    c: out natural range 0 to cmax
  );
end entity counter;

architecture rtl of counter is

  begin
  process(clk)
  begin
    if rising_edge(clk) then
      if not sresetn then
        c <= 0;
      elsif cz then
        c <= 0;
      elsif c /= cmax then
      	if inc then
          c <= c + 1;
        end if;
      end if;
    end if;
  end process;
end architecture rtl;
