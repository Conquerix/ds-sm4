use std.env.all;
use std.textio.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

library common;
use common.rnd_pkg.all;
use common.utils_pkg.all;

library sm4;
use sm4.sm4_pkg.all;

entity crypto_sim is
    generic(
        f_mhz:    positive := 100
    );
    port(
        s0_axi_arready: out std_ulogic;
        s0_axi_awready: out std_ulogic;
        s0_axi_wready:  out std_ulogic;
        s0_axi_rdata:   out std_ulogic_vector(31 downto 0);
        s0_axi_rresp:   out std_ulogic_vector(1 downto 0);
        s0_axi_rvalid:  out std_ulogic;
        s0_axi_bresp:   out std_ulogic_vector(1 downto 0);
        s0_axi_bvalid:  out std_ulogic;
        m0_axi_araddr:  out std_ulogic_vector(31 downto 0);
        m0_axi_arvalid: out std_ulogic;
        m0_axi_awaddr:  out std_ulogic_vector(31 downto 0);
        m0_axi_awvalid: out std_ulogic;
        m0_axi_wdata:   out std_ulogic_vector(31 downto 0);
        m0_axi_wstrb:   out std_ulogic_vector(3 downto 0);
        m0_axi_wvalid:  out std_ulogic;
        m0_axi_rready:  out std_ulogic;
        m0_axi_bready:  out std_ulogic;
        irq:            out std_ulogic;
        led:            out std_ulogic_vector(3 downto 0)
    );
end entity crypto_sim;

architecture sim of crypto_sim is

  type key_t is protected
      procedure init(name: string);
      impure function part(nb: natural range 0 to 3) return sm4_w32_t;
  end protected key_t;

  type key_t is protected body

    variable key: std_ulogic_vector(127 downto 0);

    procedure init(name: string) is
      file f: text;
      variable l: line;
    begin
      file_open(f, name, read_mode);
      readline(f, l);
      hread(l, key);
      file_close(f);
    end procedure init;

    impure function part(nb: natural range 0 to 3) return sm4_w32_t is
    begin
        return key((nb+1)*32-1 downto nb*32);
    end function part;

  end protected body key_t;

    constant na: positive := 11;
    constant nb: positive := 2;
    constant fin: string := "axi_memory_in.txt";
    constant fout: string := "axi_memory_out.txt";
    constant fout2: string := "axi_memory_inb.txt";

    constant period:   time := (1.0e3 * 1 ns) / real(f_mhz);
    constant max_time: time := (1.0e5 * 1 ns);


    signal aclk:            std_ulogic;
    signal aresetn:         std_ulogic;
    signal dump:            std_ulogic;
    signal dump2:           std_ulogic;

    signal s0_axi_araddr:   std_ulogic_vector(11 downto 0);
    signal s0_axi_arvalid:  std_ulogic;
    signal s0_axi_rready:   std_ulogic;
    signal s0_axi_awaddr:   std_ulogic_vector(11 downto 0);
    signal s0_axi_awvalid:  std_ulogic;
    signal s0_axi_wdata:    std_ulogic_vector(31 downto 0);
    signal s0_axi_wstrb:    std_ulogic_vector(3 downto 0);
    signal s0_axi_wvalid:   std_ulogic;
    signal s0_axi_bready:   std_ulogic;

    signal m0_axi_arready:  std_ulogic;
    signal m0_axi_awready:  std_ulogic;
    signal m0_axi_wready:   std_ulogic;
    signal m0_axi_rdata:    std_ulogic_vector(31 downto 0);
    signal m0_axi_rresp:    std_ulogic_vector(1 downto 0);
    signal m0_axi_rvalid:   std_ulogic;
    signal m0_axi_bresp:    std_ulogic_vector(1 downto 0);
    signal m0_axi_bvalid:   std_ulogic;

    signal sw:  std_ulogic_vector(3 downto 0);
    signal btn: std_ulogic_vector(3 downto 0);

    shared variable key: key_t;

begin

    process
    begin
        aclk <= '0';
        wait for period / 2;
        aclk <= '1';
        wait for period / 2;
    end process;


    crypto0: entity work.crypto(rtl)

        port map(
            aclk => aclk,
            aresetn => aresetn,
            s0_axi_araddr => s0_axi_araddr,
            s0_axi_arvalid => s0_axi_arvalid,
            s0_axi_arready => s0_axi_arready,
            s0_axi_awaddr => s0_axi_awaddr,
            s0_axi_awvalid => s0_axi_awvalid,
            s0_axi_awready => s0_axi_awready,
            s0_axi_wdata => s0_axi_wdata,
            s0_axi_wstrb => s0_axi_wstrb,
            s0_axi_wvalid => s0_axi_wvalid,
            s0_axi_wready => s0_axi_wready,
            s0_axi_rdata => s0_axi_rdata,
            s0_axi_rresp => s0_axi_rresp,
            s0_axi_rvalid => s0_axi_rvalid,
            s0_axi_rready => s0_axi_rready,
            s0_axi_bresp => s0_axi_bresp,
            s0_axi_bvalid => s0_axi_bvalid,
            s0_axi_bready => s0_axi_bready,

            m0_axi_araddr => m0_axi_araddr,
            m0_axi_arvalid => m0_axi_arvalid,
            m0_axi_arready => m0_axi_arready,
            m0_axi_awaddr => m0_axi_awaddr,
            m0_axi_awvalid => m0_axi_awvalid,
            m0_axi_awready => m0_axi_awready,
            m0_axi_wdata => m0_axi_wdata,
            m0_axi_wstrb => m0_axi_wstrb,
            m0_axi_wvalid => m0_axi_wvalid,
            m0_axi_wready => m0_axi_wready,
            m0_axi_rdata => m0_axi_rdata,
            m0_axi_rresp => m0_axi_rresp,
            m0_axi_rvalid => m0_axi_rvalid,
            m0_axi_rready => m0_axi_rready,
            m0_axi_bresp => m0_axi_bresp,
            m0_axi_bvalid => m0_axi_bvalid,
            m0_axi_bready => m0_axi_bready,
            irq => irq,
            sw => sw,
            btn => btn,
            led => led
        );

    u0: entity common.axi_memory_optimized(rtl)
    generic map(
        na   => na,
        nb   => nb,
        fin  => fin,
        fout => fout,
        fout2 => fout2
    )
    port map(
        aclk           => aclk,
        aresetn        => aresetn,
        dump           => dump,
        dump2           => dump2,
        s0_axi_araddr  => m0_axi_araddr(10 downto 0),
        s0_axi_arvalid => m0_axi_arvalid,
        s0_axi_arready => m0_axi_arready,
        s0_axi_awaddr  => m0_axi_awaddr(10 downto 0),
        s0_axi_awvalid => m0_axi_awvalid,
        s0_axi_awready => m0_axi_awready,
        s0_axi_wdata   => m0_axi_wdata,
        s0_axi_wstrb   => m0_axi_wstrb,
        s0_axi_wvalid  => m0_axi_wvalid,
        s0_axi_wready  => m0_axi_wready,
        s0_axi_rdata   => m0_axi_rdata,
        s0_axi_rresp   => m0_axi_rresp,
        s0_axi_rvalid  => m0_axi_rvalid,
        s0_axi_rready  => m0_axi_rready,
        s0_axi_bresp   => m0_axi_bresp,
        s0_axi_bvalid  => m0_axi_bvalid,
        s0_axi_bready  => m0_axi_bready
    );


    process
        variable rg: rnd_generator;
    begin
        key.init("key.txt");

        aresetn        <= '0';
        s0_axi_araddr  <= (others => '0');
        s0_axi_arvalid <= '0';
        s0_axi_rready  <= '0';
        s0_axi_awaddr  <= (others => '0');
        s0_axi_awvalid <= '0';
        s0_axi_wdata   <= (others => '0');
        s0_axi_wstrb   <= (others => '0');
        s0_axi_wvalid  <= '0';
        s0_axi_bready  <= '0';
        for i in 1 to 10 loop
            wait until rising_edge(aclk);
        end loop;
        aresetn <= '1';
        for i in 1 to 2 loop
            wait until rising_edge(aclk);
        end loop;
        s0_axi_wstrb <= "1111";

        -- WRITING SBA
        print("WRITING SBA : x00000010");

        s0_axi_awaddr <= (others => '0');
        s0_axi_awvalid <= '1';
        s0_axi_wdata <= x"00000000";
        s0_axi_wvalid <= '1';
        wait until rising_edge(aclk) and (s0_axi_awready = '1') and (s0_axi_wready = '1');
        s0_axi_awvalid <= '0';
        s0_axi_wvalid <= '0';
        s0_axi_bready <= '1';
        wait until rising_edge(aclk) and (s0_axi_bvalid = '1');
        s0_axi_bready <= '0';
        if (s0_axi_bresp /= "00") then
          print("ERROR : write resp =" & ds_to_string(s0_axi_bresp) & "for write addr =" & ds_to_string(s0_axi_awaddr));
          finish;
        end if;

        -- WRITING MBL
        print("WRITING MBL: x00000010");

        s0_axi_awaddr <= x"004";
        s0_axi_awvalid <= '1';
        s0_axi_wdata <= x"00000800";
        s0_axi_wvalid <= '1';
        wait until rising_edge(aclk) and (s0_axi_awready = '1') and (s0_axi_wready = '1');
        s0_axi_awvalid <= '0';
        s0_axi_wvalid <= '0';
        s0_axi_bready <= '1';
        wait until rising_edge(aclk) and (s0_axi_bvalid = '1');
        s0_axi_bready <= '0';
        if (s0_axi_bresp /= "00") then
          print("ERROR : write resp =" & ds_to_string(s0_axi_bresp) & "for write addr =" & ds_to_string(s0_axi_awaddr));
          finish;
        end if;

        -- WRITING CTRL
        print("WRITING CTRL : x00000017");

        s0_axi_awaddr <= x"008";
        s0_axi_awvalid <= '1';
        s0_axi_wdata <= x"00000016";
        s0_axi_wvalid <= '1';
        wait until rising_edge(aclk) and (s0_axi_awready = '1') and (s0_axi_wready = '1');
        s0_axi_awvalid <= '0';
        s0_axi_wvalid <= '0';
        s0_axi_bready <= '1';
        wait until rising_edge(aclk) and (s0_axi_bvalid = '1');
        s0_axi_bready <= '0';
        if (s0_axi_bresp /= "00") then
          print("ERROR : write resp =" & ds_to_string(s0_axi_bresp) & "for write addr =" & ds_to_string(s0_axi_awaddr));
          finish;
        end if;

        -- WRITING KEY 1
        print("WRITING KEY 1 : " & ds_to_string(key.part(0)));

        s0_axi_awaddr <= x"010";
        s0_axi_awvalid <= '1';
        s0_axi_wdata <= key.part(0);
        s0_axi_wvalid <= '1';
        wait until rising_edge(aclk) and (s0_axi_awready = '1') and (s0_axi_wready = '1');
        s0_axi_awvalid <= '0';
        s0_axi_wvalid <= '0';
        s0_axi_bready <= '1';
        wait until rising_edge(aclk) and (s0_axi_bvalid = '1');
        s0_axi_bready <= '0';
        if (s0_axi_bresp /= "00") then
          print("ERROR : write resp =" & ds_to_string(s0_axi_bresp) & "for write addr =" & ds_to_string(s0_axi_awaddr));
          finish;
        end if;

        -- WRITING KEY 2
        print("WRITING KEY 2 : " & ds_to_string(key.part(1)));

        s0_axi_awaddr <= x"014";
        s0_axi_awvalid <= '1';
        s0_axi_wdata <= key.part(1);
        s0_axi_wvalid <= '1';
        wait until rising_edge(aclk) and (s0_axi_awready = '1') and (s0_axi_wready = '1');
        s0_axi_awvalid <= '0';
        s0_axi_wvalid <= '0';
        s0_axi_bready <= '1';
        wait until rising_edge(aclk) and (s0_axi_bvalid = '1');
        s0_axi_bready <= '0';
        if (s0_axi_bresp /= "00") then
          print("ERROR : write resp =" & ds_to_string(s0_axi_bresp) & "for write addr =" & ds_to_string(s0_axi_awaddr));
          finish;
        end if;

        -- WRITING KEY 3
        print("WRITING KEY 3 : " & ds_to_string(key.part(2)));

        s0_axi_awaddr <= x"018";
        s0_axi_awvalid <= '1';
        s0_axi_wdata <= key.part(2);
        s0_axi_wvalid <= '1';
        wait until rising_edge(aclk) and (s0_axi_awready = '1') and (s0_axi_wready = '1');
        s0_axi_awvalid <= '0';
        s0_axi_wvalid <= '0';
        s0_axi_bready <= '1';
        wait until rising_edge(aclk) and (s0_axi_bvalid = '1');
        s0_axi_bready <= '0';
        if (s0_axi_bresp /= "00") then
          print("ERROR : write resp =" & ds_to_string(s0_axi_bresp) & "for write addr =" & ds_to_string(s0_axi_awaddr));
          finish;
        end if;

        -- WRITING KEY 4
        print("WRITING KEY 4 : " & ds_to_string(key.part(3)));

        s0_axi_awaddr <= x"01C";
        s0_axi_awvalid <= '1';
        s0_axi_wdata <= key.part(3);
        s0_axi_wvalid <= '1';
        wait until rising_edge(aclk) and (s0_axi_awready = '1') and (s0_axi_wready = '1');
        s0_axi_awvalid <= '0';
        s0_axi_wvalid <= '0';
        s0_axi_bready <= '1';
        wait until rising_edge(aclk) and (s0_axi_bvalid = '1');
        s0_axi_bready <= '0';
        if (s0_axi_bresp /= "00") then
          print("ERROR : write resp =" & ds_to_string(s0_axi_bresp) & "for write addr =" & ds_to_string(s0_axi_awaddr));
          finish;
        end if;

        -- READING SBA
        print("READING SBA");

        s0_axi_araddr <= x"000";
        s0_axi_arvalid <= '1';
        wait until rising_edge(aclk) and (s0_axi_arready = '1');
        s0_axi_arvalid <= '0';
        s0_axi_rready <= '1';
        wait until rising_edge(aclk) and (s0_axi_rvalid ='1');
        print("SBA : " & ds_to_string(s0_axi_rdata));
        s0_axi_rready <= '0';
        if (s0_axi_bresp /= "00") then
          print("ERROR : read resp =" & ds_to_string(s0_axi_bresp) & "for read addr =" & ds_to_string(s0_axi_awaddr));
          finish;
        end if;

        -- READING MBL
        print("READING MBL");

        s0_axi_araddr <= x"004";
        s0_axi_arvalid <= '1';
        wait until rising_edge(aclk) and (s0_axi_arready = '1');
        s0_axi_arvalid <= '0';
        s0_axi_rready <= '1';
        wait until rising_edge(aclk) and (s0_axi_rvalid ='1');
        print("MBL : " & ds_to_string(s0_axi_rdata));
        s0_axi_rready <= '0';
        if (s0_axi_bresp /= "00") then
          print("ERROR : read resp =" & ds_to_string(s0_axi_bresp) & "for read addr =" & ds_to_string(s0_axi_awaddr));
          finish;
        end if;

        -- READING CTRL
        print("READING CTRL");

        s0_axi_araddr <= x"008";
        s0_axi_arvalid <= '1';
        wait until rising_edge(aclk) and (s0_axi_arready = '1');
        s0_axi_arvalid <= '0';
        s0_axi_rready <= '1';
        wait until rising_edge(aclk) and (s0_axi_rvalid ='1');
        print("CTRL : " & ds_to_string(s0_axi_rdata));
        s0_axi_rready <= '0';
        if (s0_axi_bresp /= "00") then
          print("ERROR : read resp =" & ds_to_string(s0_axi_bresp) & "for read addr =" & ds_to_string(s0_axi_awaddr));
          finish;
        end if;

        -- READING STATUS
        print("READING STATUS");

        s0_axi_araddr <= x"00C";
        s0_axi_arvalid <= '1';
        wait until rising_edge(aclk) and (s0_axi_arready = '1');
        s0_axi_arvalid <= '0';
        s0_axi_rready <= '1';
        wait until rising_edge(aclk) and (s0_axi_rvalid ='1');
        print("STATUS : " & ds_to_string(s0_axi_rdata));
        s0_axi_rready <= '0';
        if (s0_axi_bresp /= "00") then
          print("ERROR : read resp =" & ds_to_string(s0_axi_bresp) & "for read addr =" & ds_to_string(s0_axi_awaddr));
          finish;
        end if;

        -- READING KEY 1
        print("READING KEY 1");

        s0_axi_araddr <= x"010";
        s0_axi_arvalid <= '1';
        wait until rising_edge(aclk) and (s0_axi_arready = '1');
        s0_axi_arvalid <= '0';
        s0_axi_rready <= '1';
        wait until rising_edge(aclk) and (s0_axi_rvalid ='1');
        print("KEY 1 : " & ds_to_string(s0_axi_rdata));
        s0_axi_rready <= '0';
        if (s0_axi_bresp /= "00") then
          print("ERROR : read resp =" & ds_to_string(s0_axi_bresp) & "for read addr =" & ds_to_string(s0_axi_awaddr));
          finish;
        end if;

        -- READING KEY 2
        print("READING KEY 2");

        s0_axi_araddr <= x"014";
        s0_axi_arvalid <= '1';
        wait until rising_edge(aclk) and (s0_axi_arready = '1');
        s0_axi_arvalid <= '0';
        s0_axi_rready <= '1';
        wait until rising_edge(aclk) and (s0_axi_rvalid ='1');
        print("KEY 2 : " & ds_to_string(s0_axi_rdata));
        s0_axi_rready <= '0';
        if (s0_axi_bresp /= "00") then
          print("ERROR : read resp =" & ds_to_string(s0_axi_bresp) & "for read addr =" & ds_to_string(s0_axi_awaddr));
          finish;
        end if;

        -- READING KEY 3
        print("READING KEY 3");

        s0_axi_araddr <= x"018";
        s0_axi_arvalid <= '1';
        wait until rising_edge(aclk) and (s0_axi_arready = '1');
        s0_axi_arvalid <= '0';
        s0_axi_rready <= '1';
        wait until rising_edge(aclk) and (s0_axi_rvalid ='1');
        print("KEY 3 : " & ds_to_string(s0_axi_rdata));
        s0_axi_rready <= '0';
        if (s0_axi_bresp /= "00") then
          print("ERROR : read resp =" & ds_to_string(s0_axi_bresp) & "for read addr =" & ds_to_string(s0_axi_awaddr));
          finish;
        end if;

        -- READING KEY 4
        print("READING KEY 4");

        s0_axi_araddr <= x"01C";
        s0_axi_arvalid <= '1';
        wait until rising_edge(aclk) and (s0_axi_arready = '1');
        s0_axi_arvalid <= '0';
        s0_axi_rready <= '1';
        wait until rising_edge(aclk) and (s0_axi_rvalid ='1');
        print("KEY 4 : " & ds_to_string(s0_axi_rdata));
        s0_axi_rready <= '0';
        if (s0_axi_bresp /= "00") then
          print("ERROR : read resp =" & ds_to_string(s0_axi_bresp) & "for read addr =" & ds_to_string(s0_axi_awaddr));
          finish;
        end if;

        -- WRITING STATUS
        print("WRITING STATUS : Starting encryption!");

        s0_axi_awaddr <= x"00C";
        s0_axi_awvalid <= '1';
        s0_axi_wdata <= x"12345678";
        s0_axi_wvalid <= '1';
        wait until rising_edge(aclk) and (s0_axi_awready = '1') and (s0_axi_wready = '1');
        s0_axi_awvalid <= '0';
        s0_axi_wvalid <= '0';
        s0_axi_bready <= '1';
        wait until rising_edge(aclk) and (s0_axi_bvalid = '1');
        s0_axi_bready <= '0';
        if (s0_axi_bresp /= "00") then
          print("ERROR : write resp =" & ds_to_string(s0_axi_bresp) & "for write addr =" & ds_to_string(s0_axi_awaddr));
          finish;
        end if;

        -- READING STATUS
        print("READING STATUS : Just to be sure!");

        s0_axi_araddr <= x"00C";
        s0_axi_arvalid <= '1';
        wait until rising_edge(aclk) and (s0_axi_arready = '1');
        s0_axi_arvalid <= '0';
        s0_axi_rready <= '1';
        wait until rising_edge(aclk) and (s0_axi_rvalid ='1');
        print("STATUS : " & ds_to_string(s0_axi_rdata));
        s0_axi_rready <= '0';
        if (s0_axi_bresp /= "00") then
          print("ERROR : read resp =" & ds_to_string(s0_axi_bresp) & "for read addr =" & ds_to_string(s0_axi_awaddr));
          finish;
        end if;

        wait until rising_edge(aclk) and (irq = '1');

        -- READING STATUS
        print("READING STATUS : finished encryption ! (might be an error ?)");

        s0_axi_araddr <= x"00C";
        s0_axi_arvalid <= '1';
        wait until rising_edge(aclk) and (s0_axi_arready = '1');
        s0_axi_arvalid <= '0';
        s0_axi_rready <= '1';
        wait until rising_edge(aclk) and (s0_axi_rvalid ='1');
        print("STATUS : " & ds_to_string(s0_axi_rdata));
        s0_axi_rready <= '0';
        if (s0_axi_bresp /= "00") then
          print("ERROR : read resp =" & ds_to_string(s0_axi_bresp) & "for read addr =" & ds_to_string(s0_axi_awaddr));
          finish;
        end if;

        wait until rising_edge(aclk);
        dump <= '1';
        for i in 1 to 10 loop
            wait until rising_edge(aclk);
        end loop;
        dump <= '0';

        -- WRITING STATUS
        print("WRITING STATUS : Starting decryption!");

        s0_axi_awaddr <= x"00C";
        s0_axi_awvalid <= '1';
        s0_axi_wdata <= x"12345678";
        s0_axi_wvalid <= '1';
        wait until rising_edge(aclk) and (s0_axi_awready = '1') and (s0_axi_wready = '1');
        s0_axi_awvalid <= '0';
        s0_axi_wvalid <= '0';
        s0_axi_bready <= '1';
        wait until rising_edge(aclk) and (s0_axi_bvalid = '1');
        s0_axi_bready <= '0';
        if (s0_axi_bresp /= "00") then
          print("ERROR : write resp =" & ds_to_string(s0_axi_bresp) & "for write addr =" & ds_to_string(s0_axi_awaddr));
          finish;
        end if;

        -- READING STATUS
        print("READING STATUS : Just to be sure!");

        s0_axi_araddr <= x"00C";
        s0_axi_arvalid <= '1';
        wait until rising_edge(aclk) and (s0_axi_arready = '1');
        s0_axi_arvalid <= '0';
        s0_axi_rready <= '1';
        wait until rising_edge(aclk) and (s0_axi_rvalid ='1');
        print("STATUS : " & ds_to_string(s0_axi_rdata));
        s0_axi_rready <= '0';
        if (s0_axi_bresp /= "00") then
          print("ERROR : read resp =" & ds_to_string(s0_axi_bresp) & "for read addr =" & ds_to_string(s0_axi_awaddr));
          finish;
        end if;

        wait until rising_edge(aclk) and (irq = '1');

        -- READING STATUS
        print("READING STATUS : finished decryption ! (might be an error ?)");

        s0_axi_araddr <= x"00C";
        s0_axi_arvalid <= '1';
        wait until rising_edge(aclk) and (s0_axi_arready = '1');
        s0_axi_arvalid <= '0';
        s0_axi_rready <= '1';
        wait until rising_edge(aclk) and (s0_axi_rvalid ='1');
        print("STATUS : " & ds_to_string(s0_axi_rdata));
        s0_axi_rready <= '0';
        if (s0_axi_bresp /= "00") then
          print("ERROR : read resp =" & ds_to_string(s0_axi_bresp) & "for read addr =" & ds_to_string(s0_axi_awaddr));
          finish;
        end if;

        wait until rising_edge(aclk);
        dump2 <= '1';
        for i in 1 to 10 loop
            wait until rising_edge(aclk);
        end loop;
        dump2 <= '0';

        print("Time to check if everything went well!");
        finish;

    end process;


    process
    begin
      wait for max_time;
      finish;
    end process;


    -- Check unknowns
    process
    begin
        wait until rising_edge(aclk) and aresetn = '0';
        loop
            wait until rising_edge(aclk);
            check_unknowns(s0_axi_araddr, "S0_AXI_ARADDR");
            check_unknowns(s0_axi_arvalid, "S0_AXI_ARVALID");
            check_unknowns(s0_axi_arready, "S0_AXI_ARREADY");
            check_unknowns(s0_axi_awaddr, "S0_AXI_AWADDR");
            check_unknowns(s0_axi_awvalid, "S0_AXI_AWVALID");
            check_unknowns(s0_axi_awready, "S0_AXI_AWREADY");
            check_unknowns(s0_axi_wdata, "S0_AXI_WDATA");
            check_unknowns(s0_axi_wstrb, "S0_AXI_WSTRB");
            check_unknowns(s0_axi_wvalid, "S0_AXI_WVALID");
            check_unknowns(s0_axi_wready, "S0_AXI_WREADY");
            check_unknowns(s0_axi_rdata, "S0_AXI_RDATA");
            check_unknowns(s0_axi_rresp, "S0_AXI_RRESP");
            check_unknowns(s0_axi_rvalid, "S0_AXI_RVALID");
            check_unknowns(s0_axi_rready, "S0_AXI_RREADY");
            check_unknowns(s0_axi_bresp, "S0_AXI_BRESP");
            check_unknowns(s0_axi_bvalid, "S0_AXI_BVALID");
            check_unknowns(s0_axi_bready, "S0_AXI_BREADY");

            check_unknowns(m0_axi_araddr, "M0_AXI_ARADDR");
            check_unknowns(m0_axi_arvalid, "M0_AXI_ARVALID");
            check_unknowns(m0_axi_arready, "M0_AXI_ARREADY");
            check_unknowns(m0_axi_awaddr, "M0_AXI_AWADDR");
            check_unknowns(m0_axi_awvalid, "M0_AXI_AWVALID");
            check_unknowns(m0_axi_awready, "M0_AXI_AWREADY");
            check_unknowns(m0_axi_wdata, "M0_AXI_WDATA");
            check_unknowns(m0_axi_wstrb, "M0_AXI_WSTRB");
            check_unknowns(m0_axi_wvalid, "M0_AXI_WVALID");
            check_unknowns(m0_axi_wready, "M0_AXI_WREADY");
            check_unknowns(m0_axi_rdata, "M0_AXI_RDATA");
            check_unknowns(m0_axi_rresp, "M0_AXI_RRESP");
            check_unknowns(m0_axi_rvalid, "M0_AXI_RVALID");
            check_unknowns(m0_axi_rready, "M0_AXI_RREADY");
            check_unknowns(m0_axi_bresp, "M0_AXI_BRESP");
            check_unknowns(m0_axi_bvalid, "M0_AXI_BVALID");
            check_unknowns(m0_axi_bready, "M0_AXI_BREADY");
        end loop;
    end process;


end architecture sim;
