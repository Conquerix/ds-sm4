library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;
use ieee.numeric_std.all;

library common;
use common.axi_pkg.all;

library sm4;
use sm4.sm4_pkg.all;



entity slave_axi_ctrl is

  port(
        clk: in std_ulogic;
        aresetn: in std_ulogic;
        s0_axi_araddr:  in    std_ulogic_vector(11 downto 0);
        s0_axi_arvalid: in    std_ulogic;
        s0_axi_arready: out   std_ulogic;
        s0_axi_awaddr:  in    std_ulogic_vector(11 downto 0);
        s0_axi_awvalid: in    std_ulogic;
        s0_axi_awready: out   std_ulogic;
        s0_axi_wdata:   in    std_ulogic_vector(31 downto 0);
        s0_axi_wstrb:   in    std_ulogic_vector(3 downto 0);
        s0_axi_wvalid:  in    std_ulogic;
        s0_axi_wready:  out   std_ulogic;
        s0_axi_rdata:   out   std_ulogic_vector(31 downto 0);
        s0_axi_rresp:   out   std_ulogic_vector(1 downto 0);
        s0_axi_rvalid:  out   std_ulogic;
        s0_axi_rready:  in    std_ulogic;
        s0_axi_bresp:   out   std_ulogic_vector(1 downto 0);
        s0_axi_bvalid:  out   std_ulogic;
        s0_axi_bready:  in    std_ulogic;
        SBA : out sm4_w32_t;
        MBL : out sm4_w32_t;
        K : out sm4_w128_t;
        start_encryption : out std_ulogic;
        -- control register
        ie : out std_ulogic;
        ce : out std_ulogic;
        rstn : out std_ulogic;
        -- status register
        cause : in std_ulogic_vector(2 downto 0);
        busy : in std_ulogic;
        irq : in std_ulogic
    );
end entity slave_axi_ctrl;

architecture rtl of slave_axi_ctrl is

-- internal signals declaration

signal interface_registers: sm4_interface_registers_array_t;

-- timer signals

signal timer_cz: std_ulogic;
signal timer_inc: std_ulogic;
signal timer: natural range 0 to 2**16;


-- states of the FSM
type state_r_t is (idle, ackok, waitok, ackko, waitko);
signal state_r: state_r_t;

type state_w_t is (idle, readyok, wait_readyok, readyko, wait_readyko);
signal state_w: state_w_t;

begin

-- read operations
stateMachineRead: process(clk)
begin
  if rising_edge(clk) then
    if not aresetn then
        state_r <= idle;
    elsif state_r = idle then
      if s0_axi_arvalid then
        if s0_axi_araddr < 36 then
          state_r <= ackok;
        else
          state_r <= ackko;
        end if;
      end if;
    elsif (state_r = ackok) then
      if s0_axi_rready then
        state_r <= idle;
      else
        state_r <= waitok;
      end if;
    elsif state_r = waitok then
      if s0_axi_rready then
        state_r <= idle;
      end if;
    elsif state_r = ackko then
      if s0_axi_rready then
        state_r <= idle;
      else
        state_r <= waitko;
      end if;
    elsif state_r = waitko then
      if s0_axi_rready then
        state_r <= idle;
      end if;
    end if;
  end if;
end process;

s0_axi_rdata <= interface_registers(to_integer(s0_axi_araddr(5 downto 2))) when s0_axi_araddr(5 downto 2) < 9 else (others => '0');
s0_axi_arready <= '1' when (state_r = ackok) or (state_r = ackko) else '0';
s0_axi_rvalid  <= '0' when (state_r = idle) else '1';
s0_axi_rresp   <= "11" when (state_r = ackko) or (state_r = waitko) else "00";


-- write operations
stateMachineWrite : process(clk)
begin
  if rising_edge(clk) then
    if not aresetn then
      state_w <= idle;
    elsif state_w = idle then
      if (s0_axi_awvalid = '1') and (s0_axi_wvalid ='1') and (s0_axi_awaddr < 32) then
        state_w <= readyok;
      elsif (s0_axi_awvalid = '1') and (s0_axi_wvalid ='1') then
        state_w <= readyko;
      else
        state_w <= idle;
      end if;
    elsif state_w = readyok then
      if s0_axi_bready then
        state_w <= idle;
      else
        state_w <= wait_readyok;
      end if;
    elsif state_w = wait_readyok then
      if s0_axi_bready then
        state_w <= idle;
      end if;
    elsif state_w = readyko then
      if s0_axi_bready then
        state_w <= idle;
      else
        state_w <= wait_readyko;
      end if;
    elsif state_w = wait_readyko then
      if s0_axi_bready then
        state_w <= idle;
      end if;
    end if;
  end if;
end process;

s0_axi_awready <= '1' when (state_w = readyok) or (state_w = readyko) else '0';
s0_axi_wready  <= '1' when (state_w = readyok) or (state_w = readyko) else '0';
s0_axi_bvalid <= '0' when state_w = idle  else '1';
s0_axi_bresp <= "11" when (state_w = readyko) or (state_w = wait_readyko) else "00";


rstn <= '1' when (aresetn = '1') and (interface_registers(2)(0) = '0') else '0';

process(clk)
begin
  if rising_edge(clk) then
    if not aresetn then
      interface_registers <= (others => (others => '0'));
    elsif (state_w = readyok) and (s0_axi_awaddr(4 downto 2) = 2) and (s0_axi_wstrb(0) = '1') then
      interface_registers(2) <= "00000000000000000000000000000" & s0_axi_wdata(2 downto 0);
    elsif (state_w = readyok) and (s0_axi_awaddr(4 downto 2) /= 3) then
      if (s0_axi_wstrb(0) = '1') then
      	interface_registers(to_integer(s0_axi_awaddr(4 downto 2)))(7 downto 0) <= s0_axi_wdata(7 downto 0);
      end if;
      if (s0_axi_wstrb(1) = '1') then
      	interface_registers(to_integer(s0_axi_awaddr(4 downto 2)))(15 downto 8) <= s0_axi_wdata(15 downto 8);
      end if;
      if (s0_axi_wstrb(2) = '1') then
      	interface_registers(to_integer(s0_axi_awaddr(4 downto 2)))(23 downto 16) <= s0_axi_wdata(23 downto 16);
      end if;
      if (s0_axi_wstrb(3) = '1') then
      	interface_registers(to_integer(s0_axi_awaddr(4 downto 2)))(31 downto 24) <= s0_axi_wdata(31 downto 24);
      end if;
    end if;
    if timer_inc then
      interface_registers(8) <= std_ulogic_vector(to_unsigned(timer, 32));
    end if;
    if (aresetn = '1') and ((state_r = ackok) or (state_r = waitok)) and (s0_axi_araddr(4 downto 2) = 3) and (s0_axi_rready = '1') then
      interface_registers(3) <= (others => '0');
    end if;
    interface_registers(3)(5 downto 3) <= cause;
    interface_registers(3)(0) <= busy;
    if (cause /= "000") then
      interface_registers(3)(2) <= '1';
    end if;
    if irq then
      interface_registers(3)(1) <= '1';
    end if;
  end if;
end process;

SBA <= interface_registers(0);
MBL <= interface_registers(1);
K <= interface_registers(7) & interface_registers(6) & interface_registers(5) & interface_registers(4);
ce <= interface_registers(2)(1);
ie <= interface_registers(2)(2);


process(clk)
begin
  if rising_edge(clk) then
    if not aresetn then
      start_encryption <= '0';
    elsif (state_w = readyok) and (s0_axi_awaddr(4 downto 2) = 3) and (busy = '0') then
      start_encryption <= '1';
    else
      start_encryption <= '0';
    end if;
  end if;
end process;

timer_cz <= '1' when or interface_registers(3)(5 downto 1) else '0';
timer_inc <= busy;

counter_write_reducer: entity work.counter(rtl)

  generic map(cmax => 2**30)

  port map(
  clk     => clk,
  sresetn => rstn,
  cz      => timer_cz,
  inc     => timer_inc,
  c       => timer
  );

end architecture rtl;
