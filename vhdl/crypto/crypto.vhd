library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;
use ieee.numeric_std.all;

library common;
use common.axi_pkg.all;

library sm4;
use sm4.sm4_pkg.all;

entity crypto is

  generic(
    length_max : natural := 4096
  );

  port(
    aclk:           in  std_ulogic;
    aresetn:        in  std_ulogic;
    s0_axi_araddr:  in  std_ulogic_vector(11 downto 0);
    s0_axi_arvalid: in  std_ulogic;
    s0_axi_arready: out std_ulogic;
    s0_axi_awaddr:  in  std_ulogic_vector(11 downto 0);
    s0_axi_awvalid: in  std_ulogic;
    s0_axi_awready: out std_ulogic;
    s0_axi_wdata:   in  std_ulogic_vector(31 downto 0);
    s0_axi_wstrb:   in  std_ulogic_vector(3 downto 0);
    s0_axi_wvalid:  in  std_ulogic;
    s0_axi_wready:  out std_ulogic;
    s0_axi_rdata:   out std_ulogic_vector(31 downto 0);
    s0_axi_rresp:   out std_ulogic_vector(1 downto 0);
    s0_axi_rvalid:  out std_ulogic;
    s0_axi_rready:  in  std_ulogic;
    s0_axi_bresp:   out std_ulogic_vector(1 downto 0);
    s0_axi_bvalid:  out std_ulogic;
    s0_axi_bready:  in  std_ulogic;
    m0_axi_araddr:  out std_ulogic_vector(31 downto 0);
    m0_axi_arvalid: out std_ulogic;
    m0_axi_arready: in  std_ulogic;
    m0_axi_awaddr:  out std_ulogic_vector(31 downto 0);
    m0_axi_awvalid: out std_ulogic;
    m0_axi_awready: in  std_ulogic;
    m0_axi_wdata:   out std_ulogic_vector(31 downto 0);
    m0_axi_wstrb:   out std_ulogic_vector(3 downto 0);
    m0_axi_wvalid:  out std_ulogic;
    m0_axi_wready:  in  std_ulogic;
    m0_axi_rdata:   in  std_ulogic_vector(31 downto 0);
    m0_axi_rresp:   in  std_ulogic_vector(1 downto 0);
    m0_axi_rvalid:  in  std_ulogic;
    m0_axi_rready:  out std_ulogic;
    m0_axi_bresp:   in  std_ulogic_vector(1 downto 0);
    m0_axi_bvalid:  in  std_ulogic;
    m0_axi_bready:  out std_ulogic;
    irq:            out std_ulogic;
    sw:             in  std_ulogic_vector(3 downto 0);
    btn:            in  std_ulogic_vector(3 downto 0);
    led:            out std_ulogic_vector(3 downto 0)
  );
end entity crypto;

architecture rtl of crypto is

  signal SBA: sm4_w32_t;
  signal MBL: sm4_w32_t;
  signal K:   sm4_w128_t;

  signal SBA_stored: sm4_w32_t;
  signal MBL_stored: sm4_w32_t;
  signal K_stored:   sm4_w128_t;

  signal ICB: sm4_w128_t;

  signal rk:               sm4_rk_array_t;
  signal err_signal:       std_ulogic_vector(2 downto 0);
  signal rf_working:       std_ulogic;
  signal key_exp_working:  std_ulogic;
  signal m0_working:       std_ulogic;
  signal is_busy:          std_ulogic;
  signal freeze:           std_ulogic;
  signal interrupt_enable: std_ulogic;
  signal interrupt_signal: std_ulogic;
  signal resetn:           std_ulogic;
  signal soft_reset:       std_ulogic;
  signal chip_enable:      std_ulogic;
  signal start_encryption: std_ulogic;
  signal encryption_end:   std_ulogic;
  signal key_ready:        std_ulogic;
  signal ICB_retrieved:    std_ulogic;
  signal CNT_initialized:  std_ulogic;

  signal rf_handshake_valid: std_ulogic_vector(8 downto 0);
  signal rf_handshake_ready: std_ulogic_vector(8 downto 0);
  signal rf_io_array:        sm4_round_function_io_array_t;

  signal in_master_valid : std_ulogic;
  signal in_master_ready : std_ulogic;
  signal in_master_data  : sm4_w128_t;
  signal out_master_valid : std_ulogic;
  signal out_master_ready : std_ulogic;
  signal out_master_data  : sm4_w128_t;

  signal in_xor_mem_valid: std_ulogic;
  signal in_xor_mem_ready: std_ulogic;
  signal in_xor_mem_data:  sm4_w128_t;
  signal in_xor_crypt_valid: std_ulogic;
  signal in_xor_crypt_ready: std_ulogic;
  signal in_xor_crypt_data:  sm4_w128_t;
  signal out_xor_valid: std_ulogic;
  signal out_xor_ready: std_ulogic;
  signal out_xor_data:  sm4_w128_t;

  signal read_cnt: natural range 0 to length_max;
  signal read_cnt_vector: sm4_w32_t;
  signal write_cnt: natural range 0 to length_max;
  signal write_cnt_vector: sm4_w32_t;

  type crypto_state_t is (idle, starting, busy, ending);
  signal crypto_state: crypto_state_t;


  begin

  master_axi_ctrl0: entity work.master_axi_ctrl(rtl)

    generic map(length_max => length_max)

    port map(
      clk    => aclk,
      resetn => resetn,
      cmd_reset  => soft_reset,
      cmd_freeze => freeze,
      working    => m0_working,
      internal_in_valid  => in_master_valid,
      internal_in_ready  => in_master_ready,
      internal_in_data   => in_master_data,
      internal_out_valid => out_master_valid,
      internal_out_ready => out_master_ready,
      internal_out_data  => out_master_data,
      SBA => SBA_stored,
      MBL => MBL_stored,
      m0_axi_araddr  => m0_axi_araddr,
      m0_axi_arvalid => m0_axi_arvalid,
      m0_axi_arready => m0_axi_arready,
      m0_axi_awaddr  => m0_axi_awaddr,
      m0_axi_awvalid => m0_axi_awvalid,
      m0_axi_awready => m0_axi_awready,
      m0_axi_wdata   => m0_axi_wdata,
      m0_axi_wstrb   => m0_axi_wstrb,
      m0_axi_wvalid  => m0_axi_wvalid,
      m0_axi_wready  => m0_axi_wready,
      m0_axi_rdata   => m0_axi_rdata,
      m0_axi_rresp   => m0_axi_rresp,
      m0_axi_rvalid  => m0_axi_rvalid,
      m0_axi_rready  => m0_axi_rready,
      m0_axi_bresp   => m0_axi_bresp,
      m0_axi_bvalid  => m0_axi_bvalid,
      m0_axi_bready  => m0_axi_bready,
      err_out  => err_signal,
      finished => encryption_end
    );

  key_expansion0: entity work.key_expansion(rtl)

    port map(
      clk    => aclk,
      resetn => resetn,
      cmd_reset  => soft_reset,
      cmd_freeze => freeze,
      working    => key_exp_working,
      key       => K_stored,
      key_ready => key_ready,
      rk        => rk
    );

  g0: for i in 0 to 7 generate

    round_function_engine: entity work.round_function_engine(rtl)

      port map(
        clk    => aclk,
        resetn => resetn,
        cmd_reset  => soft_reset,
        cmd_freeze => freeze,
        working   => rf_working,
        input     => rf_io_array(i),
        output    => rf_io_array(i+1),
        in_valid  => rf_handshake_valid(i),
        in_ready  => rf_handshake_ready(i),
        out_valid => rf_handshake_valid(i+1),
        out_ready => rf_handshake_ready(i+1),
        rk_in_0 => rk(4*i),
        rk_in_1 => rk(4*i+1),
        rk_in_2 => rk(4*i+2),
        rk_in_3 => rk(4*i+3)
      );

  end generate;

  in_xor_crypt_data <= rf_io_array(8)(31 downto 0) & rf_io_array(8)(63 downto 32) & rf_io_array(8)(95 downto 64) & rf_io_array(8)(127 downto 96);
  rf_handshake_ready(8) <= in_xor_crypt_ready;
  in_xor_crypt_valid <= rf_handshake_valid(8);

  xor_engine0: entity work.xor_engine(rtl)

    port map(
      clk    => aclk,
      resetn => resetn,
      cmd_reset  => soft_reset,
      cmd_freeze => freeze,
      in_xor_mem_valid => in_xor_mem_valid,
      in_xor_mem_ready => in_xor_mem_ready,
      in_xor_mem_data  => in_xor_mem_data,
      in_xor_crypt_valid => in_xor_crypt_valid,
      in_xor_crypt_ready => in_xor_crypt_ready,
      in_xor_crypt_data  => in_xor_crypt_data,
      out_xor_valid => out_xor_valid,
      out_xor_ready => out_xor_ready,
      out_xor_data  => out_xor_data
    );

  slave_axi_ctrl0: entity work.slave_axi_ctrl(rtl)

    port map(
      clk     => aclk,
      aresetn => aresetn,
      s0_axi_araddr  => s0_axi_araddr,
      s0_axi_arvalid => s0_axi_arvalid,
      s0_axi_arready => s0_axi_arready,
      s0_axi_awaddr  => s0_axi_awaddr,
      s0_axi_awvalid => s0_axi_awvalid,
      s0_axi_awready => s0_axi_awready,
      s0_axi_wdata   => s0_axi_wdata,
      s0_axi_wstrb   => s0_axi_wstrb,
      s0_axi_wvalid  => s0_axi_wvalid,
      s0_axi_wready  => s0_axi_wready,
      s0_axi_rdata   => s0_axi_rdata,
      s0_axi_rresp   => s0_axi_rresp,
      s0_axi_rvalid  => s0_axi_rvalid,
      s0_axi_rready  => s0_axi_rready,
      s0_axi_bresp   => s0_axi_bresp,
      s0_axi_bvalid  => s0_axi_bvalid,
      s0_axi_bready  => s0_axi_bready,
      SBA => SBA,
      MBL => MBL,
      K   => K,
      start_encryption => start_encryption,
      -- control register
      ie   => interrupt_enable,
      ce   => chip_enable,
      rstn => resetn,
      -- status register
      cause => err_signal,
      busy  => is_busy,
      irq   => interrupt_signal
    );

  process(aclk)
  begin
    if rising_edge(aclk) then
      if not resetn then
        crypto_state <= idle;
      elsif chip_enable then
        if crypto_state = idle then
          if start_encryption then
            if (MBL = 0) or (MBL = 16) then
              crypto_state <= ending;
            else
              crypto_state <= starting;
            end if;
          end if;
        elsif crypto_state = starting then
          if key_ready and ICB_retrieved then
            crypto_state <= busy;
          end if;
        elsif crypto_state = busy then
          if (encryption_end = '1') or (err_signal /= "000") then
            crypto_state <= ending;
          end if;
        elsif crypto_state = ending then
          crypto_state <= idle;
        end if;
      end if;
    end if;
  end process;

  freeze <= not chip_enable;

  is_busy <= '0' when (crypto_state = idle) else '1';

  soft_reset <= '1' when (crypto_state = ending) else '0';

  m0_working <= '1' when (crypto_state = starting) or (crypto_state = busy) else '0';

  key_exp_working <= '1' when (crypto_state = starting) or (crypto_state = busy) else '0';

  rf_working <= '1' when (crypto_state = busy) else '0';

  interrupt_signal <= '1' when (crypto_state = ending) else '0';

  irq <= interrupt_signal when (interrupt_enable = '1') else '0';

  process(aclk)
  begin
    if rising_edge(aclk) then
      if not resetn then
        SBA_stored <= (others => '0');
        MBL_stored <= (others => '0');
        K_stored   <= (others => '0');
      elsif chip_enable and start_encryption and not is_busy then
        SBA_stored <= SBA;
        MBL_stored <= MBL;
        K_stored   <= K;
      end if;
    end if;
  end process;

  process(aclk)
  begin
    if rising_edge(aclk) then
      if not resetn or soft_reset then
        rf_io_array(0)  <= (others => '0');
        CNT_initialized <= '0';
        rf_handshake_valid(0) <= '0';
      elsif chip_enable and ICB_retrieved then
        if not CNT_initialized then
          rf_io_array(0) <= ICB(127 downto 32) & (ICB(31 downto 0) + 1);
          CNT_initialized <= '1';
          rf_handshake_valid(0) <= '1';
        elsif ((crypto_state = starting) or (crypto_state = busy)) and (rf_handshake_ready(0) = '1') then
          rf_io_array(0) <= ICB(127 downto 32) & (rf_io_array(0)(31 downto 0) + 1);
        end if;
      end if;
    end if;
  end process;

  process(aclk)
  begin
    if rising_edge(aclk) then
      if not resetn or soft_reset then
        ICB_retrieved <= '0';
        ICB <= (others => '0');
      elsif not ICB_retrieved and in_master_ready and in_master_valid then
        ICB_retrieved <= '1';
        ICB <= in_master_data;
      end if;
    end if;
  end process;

  in_master_data  <= out_xor_data  when ICB_retrieved else out_master_data;
  in_master_valid <= out_xor_valid when ICB_retrieved else out_master_valid;
  out_xor_ready <= in_master_ready;

  in_xor_mem_data <= out_master_data;
  in_xor_mem_valid <= out_master_valid when ICB_retrieved else '0';
  out_master_ready <= in_xor_mem_ready;




  read_cnt_vector <= std_ulogic_vector(to_unsigned(read_cnt, 32));
  write_cnt_vector <= std_ulogic_vector(to_unsigned(write_cnt, 32));

  process(sw, read_cnt_vector, write_cnt_vector, err_signal, is_busy)
  begin
    case sw is
    when "0000" => led <= err_signal & is_busy;
    when "0001" => led <= read_cnt_vector(3  downto 0);
    when "0010" => led <= read_cnt_vector(7  downto 4);
    when "0100" => led <= read_cnt_vector(11 downto 8);
    when "1001" => led <= write_cnt_vector(3  downto 0);
    when "1010" => led <= write_cnt_vector(7  downto 4);
    when "1100" => led <= write_cnt_vector(11 downto 8);
    when others => led <= "0000";
    end case;
  end process;

  /*

  process(aclk)
  begin
    if not aresetn then
      led <= (others => '0');
    elsif sw = "0000" then
      led <= err_signal & is_busy;
    elsif sw = "0010" then
      if btn(0) then
        led <= m0_axi_wstrb;
      elsif btn(1) then
        led <= "00" & m0_axi_bvalid & m0_axi_bready;
      elsif btn(2) and btn(3) then
        led <= m0_axi_rresp & m0_axi_bresp;
      elsif btn(2) then
        led <= m0_axi_awvalid & m0_axi_awready & m0_axi_wvalid & m0_axi_wready;
      elsif btn(3) then
        led <= m0_axi_arvalid & m0_axi_arready & m0_axi_rvalid & m0_axi_rready;
      end if;
    elsif sw = "0011" then
      if btn(0) then
        led <= s0_axi_wstrb;
      elsif btn(1) then
        led <= "00" & s0_axi_bvalid & s0_axi_bready;
      elsif btn(2) and btn(3) then
        led <= s0_axi_rresp & s0_axi_bresp;
      elsif btn(2) then
        led <= s0_axi_awvalid & s0_axi_awready & s0_axi_wvalid & s0_axi_wready;
      elsif btn(3) then
        led <= s0_axi_arvalid & s0_axi_arready & s0_axi_rvalid & s0_axi_rready;
      end if;
    elsif sw(3 downto 1) = "111" then
      if sw(0) then
        if btn(0) then
          led <= write_cnt_vector(3 downto 0);
        elsif btn(1) then
          led <= write_cnt_vector(7 downto 4);
        elsif btn(2) then
          led <= write_cnt_vector(11 downto 8);
        elsif btn(3) then
          led <= write_cnt_vector(15 downto 12);
        end if;
      else
        if btn(0) then
          led <= read_cnt_vector(3 downto 0);
        elsif btn(1) then
          led <= read_cnt_vector(7 downto 4);
        elsif btn(2) then
          led <= read_cnt_vector(11 downto 8);
        elsif btn(3) then
          led <= read_cnt_vector(15 downto 12);
        end if;
      end if;
    end if;
  end process; */

end architecture rtl;

-- vim: set tabstop=4 softtabstop=4 shiftwidth=4 expandtab textwidth=0:
