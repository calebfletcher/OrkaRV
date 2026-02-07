library ieee;
context ieee.ieee_std_context;

library surf;
use surf.AxiLitePkg.all;

use work.axi4lite_intf_pkg.all;
use work.UartRegisters_pkg.all;

entity Uart is
  port (
    clk   : in std_logic;
    reset : in std_logic;

    axilWriteMaster : in AxiLiteWriteMasterType;
    axilWriteSlave  : out AxiLiteWriteSlaveType;
    axilReadMaster  : in AxiLiteReadMasterType;
    axilReadSlave   : out AxiLiteReadSlaveType;

    uart_rxd_out : out std_logic;
    uart_txd_in  : in std_logic;

    int : out std_logic
  );
end entity Uart;

architecture rtl of Uart is
  constant ADDR_BITS_C : positive := 4;

  signal s_axil_i : axi4lite_slave_in_intf(
  AWADDR(ADDR_BITS_C - 1 downto 0),
  WDATA(31 downto 0),
  WSTRB(3 downto 0),
  ARADDR(ADDR_BITS_C - 1 downto 0)
  );
  signal s_axil_o : axi4lite_slave_out_intf(
  RDATA(31 downto 0)
  );

  signal hwif_in  : UartRegisters_in_t;
  signal hwif_out : UartRegisters_out_t;

  signal rdFifoValid : std_logic;
  signal wrDelayed   : std_logic := '0';
begin
  -- convert surf axilite to peakrdl's
  AxiLitePeakRdlBridge_inst : entity work.AxiLitePeakRdlBridge
    generic map(
      ADDR_BITS_G => ADDR_BITS_C
    )
    port map
    (
      axilWriteMaster => axilWriteMaster,
      axilWriteSlave  => axilWriteSlave,
      axilReadMaster  => axilReadMaster,
      axilReadSlave   => axilReadSlave,
      s_axil_i        => s_axil_i,
      s_axil_o        => s_axil_o
    );

  -- register map
  UartRegisters_inst : entity work.UartRegisters
    port map
    (
      clk      => clk,
      rst      => reset,
      s_axil_i => s_axil_i,
      s_axil_o => s_axil_o,
      hwif_in  => hwif_in,
      hwif_out => hwif_out
    );

  UartWrapper_inst : entity surf.UartWrapper
    generic map(
      CLK_FREQ_G  => 100.0e+6,
      BAUD_RATE_G => 1e6
    )
    port map
    (
      clk     => clk,
      rst     => reset,
      wrData  => hwif_out.tx.tx.value,
      wrValid => wrDelayed,
      wrReady => hwif_in.status.txe.next_q,
      rdData  => hwif_in.rx.rx.next_q,
      rdValid => rdFifoValid,
      -- ready for new data when currently empty
      rdReady => not hwif_in.status.rxr.next_q,
      tx      => uart_rxd_out,
      rx      => uart_txd_in
    );

  process (clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        wrDelayed                 <= '0';
        hwif_in.status.rxr.next_q <= '0';
      else
        wrDelayed <= hwif_out.tx.tx.swacc;

        if rdFifoValid and (hwif_out.rx.rx.swacc or not hwif_out.status.rxr.value) then
          -- sw read data from rx buffer or was empty
          hwif_in.status.rxr.next_q <= '1';
        elsif hwif_out.rx.rx.swacc then
          -- sw read data from rx buffer while already full
          hwif_in.status.rxr.next_q <= '0';
        else
          -- preserve current value
          hwif_in.status.rxr.next_q <= hwif_in.status.rxr.next_q;
        end if;
      end if;
    end if;
  end process;

  -- interrupt output
  int <= (hwif_out.ctrl.rxie.value and hwif_out.status.rxr.value) or (hwif_out.ctrl.txie.value and hwif_out.status.txe.value);

end architecture;