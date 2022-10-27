library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

library common;
use common.axi_pkg.all;

library sm4;
use sm4.sm4_pkg.all;

entity xor_engine is
  port(
    clk: in std_ulogic;
    resetn: in std_ulogic;
    cmd_reset: in std_ulogic;
    cmd_freeze: in std_ulogic;
    in_xor_mem_valid: in std_ulogic;
    in_xor_mem_ready: out std_ulogic;
    in_xor_mem_data: in sm4_w128_t;
    in_xor_crypt_valid: in std_ulogic;
    in_xor_crypt_ready: out std_ulogic;
    in_xor_crypt_data: in sm4_w128_t;
    out_xor_valid: out std_ulogic;
    out_xor_ready: in std_ulogic;
    out_xor_data: out sm4_w128_t
  );
end entity xor_engine;

architecture rtl of xor_engine is

  signal in_mem_ready_done: std_ulogic;
  signal in_crypt_ready_done: std_ulogic;
  signal in_xor_mem_data_stored: sm4_w128_t;
  signal in_xor_crypt_data_stored: sm4_w128_t;
  signal xor_mem_data: sm4_w128_t;
  signal xor_crypt_data: sm4_w128_t;

  begin

  out_xor_data <= xor_mem_data xor xor_crypt_data;

  xor_mem_data <= in_xor_mem_data_stored when in_mem_ready_done else in_xor_mem_data;

  xor_crypt_data <= in_xor_crypt_data_stored when in_crypt_ready_done else in_xor_crypt_data;

  in_xor_mem_ready <= out_xor_ready and not in_mem_ready_done;

  in_xor_crypt_ready <= out_xor_ready and not in_crypt_ready_done;

  out_xor_valid <= '1' when (in_xor_mem_valid = '1' or in_mem_ready_done = '1') and (in_xor_crypt_valid = '1' or in_crypt_ready_done = '1') else '0';

  process(clk)
  begin
    if rising_edge(clk) then
      if not resetn or cmd_reset then
        in_mem_ready_done <= '0';
      elsif not cmd_freeze then
        if (in_xor_crypt_valid = '1' or in_crypt_ready_done = '1') and out_xor_ready = '1' then
          in_mem_ready_done <= '0';
        elsif in_xor_mem_valid and out_xor_ready then
          in_mem_ready_done <= '1';
        end if;
      end if;
    end if;
  end process;

  process(clk)
  begin
    if rising_edge(clk) then
      if not resetn or cmd_reset then
        in_xor_mem_data_stored <= (others => '0');
      elsif not cmd_freeze then
        if not in_mem_ready_done then
          in_xor_mem_data_stored <= in_xor_mem_data;
        end if;
      end if;
    end if;
  end process;

  process(clk)
  begin
    if rising_edge(clk) then
      if not resetn or cmd_reset then
        in_crypt_ready_done <= '0';
      elsif not cmd_freeze then
        if (in_xor_mem_valid = '1' or in_mem_ready_done = '1') and out_xor_ready = '1' then
          in_crypt_ready_done <= '0';
        elsif in_xor_crypt_valid and out_xor_ready then
          in_crypt_ready_done <= '1';
        end if;
      end if;
    end if;
  end process;

  process(clk)
  begin
    if rising_edge(clk) then
      if not resetn or cmd_reset then
        in_xor_crypt_data_stored <= (others => '0');
      elsif not cmd_freeze then
        if not in_crypt_ready_done then
          in_xor_crypt_data_stored <= in_xor_crypt_data;
        end if;
      end if;
    end if;
  end process;

end architecture rtl;
