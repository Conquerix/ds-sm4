library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

library sm4;
use sm4.sm4_pkg.all;

entity master_axi_ctrl is

  generic(
    length_max : natural := 4096
  );

  port(
    clk:                in  std_ulogic;
    resetn:             in  std_ulogic;
    cmd_reset:          in  std_ulogic;
    cmd_freeze:         in  std_ulogic;
    working:            in  std_ulogic;
    internal_in_valid:  in  std_ulogic;
    internal_in_ready:  out std_ulogic;
    internal_in_data:   in  sm4_w128_t;
    internal_out_valid: out std_ulogic;
    internal_out_ready: in  std_ulogic;
    internal_out_data:  out sm4_w128_t;
    SBA:                in  sm4_w32_t;
    MBL:                in  sm4_w32_t;
    m0_axi_araddr:      out sm4_w32_t;
    m0_axi_arvalid:     out std_ulogic;
    m0_axi_arready:     in  std_ulogic;
    m0_axi_awaddr:      out sm4_w32_t;
    m0_axi_awvalid:     out std_ulogic;
    m0_axi_awready:     in  std_ulogic;
    m0_axi_wdata:       out sm4_w32_t;
    m0_axi_wstrb:       out std_ulogic_vector(3 downto 0);
    m0_axi_wvalid:      out std_ulogic;
    m0_axi_wready:      in  std_ulogic;
    m0_axi_rdata:       in  sm4_w32_t;
    m0_axi_rresp:       in  std_ulogic_vector(1 downto 0);
    m0_axi_rvalid:      in  std_ulogic;
    m0_axi_rready:      out std_ulogic;
    m0_axi_bresp:       in  std_ulogic_vector(1 downto 0);
    m0_axi_bvalid:      in  std_ulogic;
    m0_axi_bready:      out std_ulogic;
    err_out:            out std_ulogic_vector(2 downto 0);
    finished:           out std_ulogic;
    read_cnt:           out natural range 0 to length_max;
    write_cnt:          out natural range 0 to length_max
  );

end entity master_axi_ctrl;

architecture rtl of master_axi_ctrl is

  signal read_cz            : std_ulogic;
  --signal read_cnt           : natural range 0 to length_max;
  signal read_inc           : std_ulogic;
  signal read_reducer_cz    : std_ulogic;
  signal read_reducer_cnt   : natural range 0 to 3;
  signal read_reducer_inc   : std_ulogic;
  signal read_reducer_array : sm4_reducer_array_t;
  signal read_addr_done     : std_ulogic;
  signal read_data_done     : std_ulogic;
  signal write_cz  : std_ulogic;
  --signal write_cnt : natural range 0 to length_max;
  signal write_inc : std_ulogic;
  signal write_reducer_cz  : std_ulogic;
  signal write_reducer_cnt : natural range 0 to 3;
  signal write_reducer_inc : std_ulogic;
  signal write_reducer_array : sm4_reducer_array_t;
  signal write_data_done     : std_ulogic;
  signal write_addr_done     : std_ulogic;
  signal SBA_stored : sm4_w32_t;
  signal read_starting  : std_ulogic;
  signal write_starting : std_ulogic;
  signal out_delay : std_ulogic;
  signal internal_out_done : std_ulogic;

  signal buffer_out_ready: std_ulogic;
  signal buffer_out_valid: std_ulogic;
  signal buffer_out_data: sm4_w128_t;

  signal buffer_full: std_ulogic;



  begin

  counter_read: entity work.counter(rtl)

    generic map(cmax => length_max)

    port map(
    clk     => clk,
    sresetn => resetn,
    cz      => read_cz,
    inc     => read_inc,
    c       => read_cnt
    );

  counter_write: entity work.counter(rtl)

    generic map(cmax => length_max)

    port map(
    clk     => clk,
    sresetn => resetn,
    cz      => write_cz,
    inc     => write_inc,
    c       => write_cnt
    );

  counter_read_reducer: entity work.counter(rtl)

    generic map(cmax => 3)

    port map(
    clk     => clk,
    sresetn => resetn,
    cz      => read_reducer_cz,
    inc     => read_reducer_inc,
    c       => read_reducer_cnt
    );

  counter_write_reducer: entity work.counter(rtl)

    generic map(cmax => 3)

    port map(
    clk     => clk,
    sresetn => resetn,
    cz      => write_reducer_cz,
    inc     => write_reducer_inc,
    c       => write_reducer_cnt
    );

  read_inc <= '1' when (read_reducer_cnt = 3) and (read_cnt /= MBL(31 downto 4)-1) and (read_reducer_inc = '1') and (internal_out_ready = '1') else '0';

  read_reducer_inc <= '1' when (cmd_freeze = '0') and (working = '1') and ((m0_axi_rvalid = '1') or (read_data_done = '1')) and ((m0_axi_arready = '1') or (read_addr_done = '1')) else '0';

  read_cz <= '1' when (cmd_reset = '1') else '0';

  read_reducer_cz <= '1' when (cmd_reset = '1') or (read_inc = '1') else '0';

  m0_axi_araddr <= SBA when (read_starting = '1') else SBA + (16*read_cnt) + (4*read_reducer_cnt) + 4;

  m0_axi_arvalid <= '1' when (working = '1') and (cmd_freeze = '0') and ((read_addr_done = '0') or (read_starting = '1')) and ((read_reducer_cnt /= 3) or ((read_reducer_cnt = 3) and (internal_out_ready = '1') and (read_cnt /= MBL(31 downto 4)-1))) else '0';

  m0_axi_rready <= '1' when (working = '0') or ((working = '1') and (cmd_freeze = '0') and ((read_reducer_cnt /= 3) or ((read_reducer_cnt = 3) and ((internal_out_ready = '1') or (read_cnt = MBL(31 downto 4)-1))))) else '0';

  internal_out_data <= /* read_reducer_array(3) & read_reducer_array(2) & read_reducer_array(1) & read_reducer_array(0) when out_delay else */ m0_axi_rdata & read_reducer_array(2) & read_reducer_array(1) & read_reducer_array(0);

  internal_out_valid <= '1' when (internal_out_done = '0') and (read_reducer_cnt = 3) and (working = '1') and (cmd_freeze = '0') and ((m0_axi_rvalid = '1') or (read_data_done = '1')) else '0';


  write_inc <= '1' when (write_reducer_cnt = 3) and (write_reducer_inc = '1') and ((buffer_out_valid = '1') or (write_cnt = MBL(31 downto 4)-1)) else '0';

  write_reducer_inc <= '1' when (cmd_freeze = '0') and (working = '1') and (write_cnt < MBL(31 downto 4)) and ((m0_axi_awready = '1') or (write_addr_done = '1')) and ((m0_axi_wready = '1') or (write_data_done = '1')) else '0';

  write_cz <= '1' when (cmd_reset = '1') else '0';

  write_reducer_cz <= '1' when (cmd_reset = '1') or (write_inc = '1') else '0';

  m0_axi_awaddr <= SBA + (16*write_cnt) + (4*write_reducer_cnt);

  m0_axi_wdata <= write_reducer_array(write_reducer_cnt);

  m0_axi_awvalid <= '1' when (write_starting = '0') and (working = '1') and (cmd_freeze = '0') and (write_addr_done = '0') and (write_cnt < MBL(31 downto 4)) else '0';

  m0_axi_wvalid <= '1' when (write_starting = '0') and (working = '1') and (cmd_freeze = '0') and (write_data_done = '0') and (write_cnt < MBL(31 downto 4)) else '0';

  m0_axi_bready <= '1' when (working = '0') or ((working = '1') and (cmd_freeze = '0')) else '0';



  buffer_out_ready <= '1' when ((write_reducer_cnt = 3) and (write_cnt < MBL(31 downto 4)) and (write_reducer_inc = '1')) or (write_starting = '1') else '0';

  m0_axi_wstrb <= (others => '1');

  finished <= '1' when (write_cnt = MBL(31 downto 4)) else '0';


  process(clk)
  begin
    if rising_edge(clk) then
      if not resetn or cmd_reset then
        write_addr_done <= '0';
      elsif not cmd_freeze then
        if (write_reducer_inc = '1' and write_reducer_cnt /= 3) or (write_inc = '1' and write_reducer_cnt = 3) then
          write_addr_done <= '0';
        elsif m0_axi_awready and m0_axi_awvalid then
          write_addr_done <= '1';
        end if;
      end if;
    end if;
  end process;

  process(clk)
  begin
    if rising_edge(clk) then
      if not resetn or cmd_reset then
        write_data_done <= '0';
      elsif not cmd_freeze then
        if (write_reducer_inc = '1' and write_reducer_cnt /= 3) or (write_inc = '1' and write_reducer_cnt = 3) then
          write_data_done <= '0';
        elsif m0_axi_wready and m0_axi_wvalid then
          write_data_done <= '1';
        end if;
      end if;
    end if;
  end process;

  process(clk)
  begin
    if rising_edge(clk) then
      if not resetn or cmd_reset then
        read_addr_done <= '0';
      elsif not cmd_freeze then
        if (read_reducer_inc = '1' and read_reducer_cnt /= 3) or (read_inc = '1' and read_reducer_cnt = 3) then
          read_addr_done <= '0';
        elsif m0_axi_arready and m0_axi_arvalid and not read_starting then
          read_addr_done <= '1';
        end if;
      end if;
    end if;
  end process;

  process(clk)
  begin
    if rising_edge(clk) then
      if not resetn or cmd_reset then
        read_data_done <= '0';
      elsif not cmd_freeze then
        if (read_reducer_inc = '1' and read_reducer_cnt /= 3) or (read_inc = '1' and read_reducer_cnt = 3) then
          read_data_done <= '0';
        elsif m0_axi_rready and m0_axi_rvalid then
          read_data_done <= '1';
        end if;
      end if;
    end if;
  end process;

  process(clk)
  begin
    if rising_edge(clk) then
      if not resetn or cmd_reset then
        read_reducer_array <= (others => (others => '0'));
      elsif (working = '1') and (m0_axi_rvalid = '1') and (cmd_freeze = '0') then
        read_reducer_array(read_reducer_cnt) <= m0_axi_rdata;
      end if;
    end if;
  end process;

  process(clk)
  begin
    if rising_edge(clk) then
      if not resetn or cmd_reset then
        write_reducer_array <= (others => (others => '0'));
      elsif working and not cmd_freeze and buffer_out_ready and buffer_out_valid then
        write_reducer_array(3) <= buffer_out_data(127 downto 96);
        write_reducer_array(2) <= buffer_out_data( 95 downto 64);
        write_reducer_array(1) <= buffer_out_data( 63 downto 32);
        write_reducer_array(0) <= buffer_out_data( 31 downto  0);
      end if;
    end if;
  end process;

  process(clk)
  begin
    if rising_edge(clk) then
      if not resetn or cmd_reset then
        err_out <= (others => '0');
      elsif not cmd_freeze then
        if (m0_axi_rresp = "00") and (m0_axi_bresp = "00") then
          err_out <= (others => '0');
        elsif (m0_axi_rresp /= "00") and (m0_axi_rvalid = '1') then
          err_out <= '0' & m0_axi_rresp;
        elsif (m0_axi_bresp /= "00") and (m0_axi_bvalid = '1') then
          err_out <= '1' & m0_axi_bresp;
        end if;
      end if;
    end if;
  end process;

  process(clk)
  begin
    if rising_edge(clk) then
      if not resetn or cmd_reset then
        SBA_stored <= (others => '0');
      elsif not working and not cmd_freeze then
        SBA_stored <= SBA;
      end if;
    end if;
  end process;

  process(clk)
  begin
    if rising_edge(clk) then
      if not resetn or cmd_reset then
        read_starting <= '1';
      elsif m0_axi_arvalid then
        read_starting <= '0';
      end if;
    end if;
  end process;

  process(clk)
  begin
    if rising_edge(clk) then
      if not resetn or cmd_reset then
        write_starting <= '1';
      elsif buffer_out_valid then
        write_starting <= '0';
      end if;
    end if;
  end process;

  process(clk)
  begin
    if rising_edge(clk) then
      if not resetn or cmd_reset then
        out_delay <= '0';
      elsif (read_reducer_cnt = 3) and (read_reducer_cz = '0') then
        out_delay <= '1';
      elsif (read_reducer_cz = '1') then
        out_delay <= '0';
      end if;
    end if;
  end process;

  process(clk)
  begin
    if rising_edge(clk) then
      if not resetn or cmd_reset then
        internal_out_done <= '0';
      elsif (internal_out_ready = '1') and (internal_out_valid = '1') then
        internal_out_done <= '1';
      elsif (read_reducer_cnt /= 3) then
        internal_out_done <= '0';
      end if;
    end if;
  end process;

  process(clk)
  begin
    if rising_edge(clk) then
      if not resetn or cmd_reset then
        buffer_full <= '0';
      elsif not buffer_full then
        if internal_in_valid then
          buffer_full <= '1';
        end if;
      elsif buffer_full then
        if buffer_out_ready and not internal_in_valid then
          buffer_full <= '0';
        end if;
      end if;
    end if;
  end process;

  internal_in_ready <= '1' when not buffer_full else buffer_out_ready;

  buffer_out_valid <= buffer_full;

  process(clk)
  begin
    if rising_edge(clk) then
      if not resetn or cmd_reset then
        buffer_out_data <= (others => '0');
      elsif not buffer_full then
        if internal_in_valid then
          buffer_out_data <= internal_in_data;
        end if;
      elsif buffer_full then
        if buffer_out_ready and internal_in_valid then
          buffer_out_data <= internal_in_data;
        end if;
      end if;
    end if;
  end process;

end architecture rtl;
