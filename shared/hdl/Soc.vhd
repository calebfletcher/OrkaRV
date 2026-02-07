library ieee;
context ieee.ieee_std_context;

use work.RiscVPkg.all;

library surf;
use surf.AxiLitePkg.all;

entity Soc is
  generic (
    RAM_FILE_PATH_G : string
  );
  port (
    clk   : in std_logic;
    reset : in std_logic;
    -- set high on ebreak
    halt : out std_logic := '0';
    -- set high on illegal instruction/mem error/etc.
    trap     : out std_logic := '0';
    gpioPins : inout std_logic_vector(31 downto 0);

    uart_rxd_out : out std_logic;
    uart_txd_in  : in std_logic;

    -- external master interface
    mAxilReadMaster  : in AxiLiteReadMasterType := AXI_LITE_READ_MASTER_INIT_C;
    mAxilReadSlave   : out AxiLiteReadSlaveType;
    mAxilWriteMaster : in AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
    mAxilWriteSlave  : out AxiLiteWriteSlaveType;

    -- external slave interface
    sAxilReadMaster  : out AxiLiteReadMasterType;
    sAxilReadSlave   : in AxiLiteReadSlaveType := AXI_LITE_READ_SLAVE_INIT_C;
    sAxilWriteMaster : out AxiLiteWriteMasterType;
    sAxilWriteSlave  : in AxiLiteWriteSlaveType := AXI_LITE_WRITE_SLAVE_INIT_C
  );
end entity Soc;

architecture rtl of Soc is
  constant NUM_MASTERS_C : natural := 2;
  constant NUM_SLAVES_C  : natural := 4;

  signal mAxiWriteMasters : AxiLiteWriteMasterArray(NUM_MASTERS_C - 1 downto 0) := (others => AXI_LITE_WRITE_MASTER_INIT_C);
  signal mAxiWriteSlaves  : AxiLiteWriteSlaveArray(NUM_MASTERS_C - 1 downto 0);
  signal mAxiReadMasters  : AxiLiteReadMasterArray(NUM_MASTERS_C - 1 downto 0) := (others => AXI_LITE_READ_MASTER_INIT_C);
  signal mAxiReadSlaves   : AxiLiteReadSlaveArray(NUM_MASTERS_C - 1 downto 0);

  signal sAxiWriteMasters : AxiLiteWriteMasterArray(NUM_SLAVES_C - 1 downto 0);
  signal sAxiWriteSlaves  : AxiLiteWriteSlaveArray(NUM_SLAVES_C - 1 downto 0) := (others => AXI_LITE_WRITE_SLAVE_INIT_C);
  signal sAxiReadMasters  : AxiLiteReadMasterArray(NUM_SLAVES_C - 1 downto 0);
  signal sAxiReadSlaves   : AxiLiteReadSlaveArray(NUM_SLAVES_C - 1 downto 0) := (others => AXI_LITE_READ_SLAVE_INIT_C);

  constant AXIL_XBAR_CFG_C : AxiLiteCrossbarMasterConfigArray(0 to NUM_SLAVES_C - 1) := (0 => (baseAddr => X"01000000", addrBits => 24, connectivity => X"FFFF"), 1 => (baseAddr => X"03000000", addrBits => 24, connectivity => X"FFFF"), 2 => (baseAddr => X"02000000", addrBits => 16, connectivity => X"FFFF"), 3 => (baseAddr => X"02010000", addrBits => 16, connectivity => X"FFFF"));

  signal mExtInt : std_logic;
  signal uartInt : std_logic;
begin
  Cpu_inst : entity work.Cpu
    port map
    (
      clk   => clk,
      reset => reset,
      halt  => halt,
      trap  => trap,

      axiReadMaster  => mAxiReadMasters(0),
      axiReadSlave   => mAxiReadSlaves(0),
      axiWriteMaster => mAxiWriteMasters(0),
      axiWriteSlave  => mAxiWriteSlaves(0),

      mExtInt => mExtInt
    );

  Ram_inst : entity work.Ram
    generic map(
      RAM_FILE_PATH_G => RAM_FILE_PATH_G,
      AXI_BASE_ADDR_G => X"01000000"
    )
    port map
    (
      clk   => clk,
      reset => reset,

      axiReadMaster  => sAxiReadMasters(0),
      axiReadSlave   => sAxiReadSlaves(0),
      axiWriteMaster => sAxiWriteMasters(0),
      axiWriteSlave  => sAxiWriteSlaves(0)
    );

  Gpio_inst : entity work.Gpio
    port map
    (
      clk             => clk,
      reset           => reset,
      axilReadMaster  => sAxiReadMasters(2),
      axilReadSlave   => sAxiReadSlaves(2),
      axilWriteMaster => sAxiWriteMasters(2),
      axilWriteSlave  => sAxiWriteSlaves(2),
      pins            => gpioPins
    );

  Uart_inst : entity work.Uart
    port map
    (
      clk             => clk,
      reset           => reset,
      axilWriteMaster => sAxiWriteMasters(3),
      axilWriteSlave  => sAxiWriteSlaves(3),
      axilReadMaster  => sAxiReadMasters(3),
      axilReadSlave   => sAxiReadSlaves(3),
      uart_rxd_out    => uart_rxd_out,
      uart_txd_in     => uart_txd_in,
      int             => uartInt
    );

  -- interrupts
  mExtInt <= uartInt;

  -- external master interface
  mAxiWriteMasters(1) <= mAxilWriteMaster;
  mAxilWriteSlave     <= mAxiWriteSlaves(1);
  mAxiReadMasters(1)  <= mAxilReadMaster;
  mAxilReadSlave      <= mAxiReadSlaves(1);

  -- external slave interface
  sAxilWriteMaster   <= sAxiWriteMasters(1);
  sAxiWriteSlaves(1) <= sAxilWriteSlave;
  sAxilReadMaster    <= sAxiReadMasters(1);
  sAxiReadSlaves(1)  <= sAxilReadSlave;

  -- crossbar
  AxiLiteCrossbar_inst : entity surf.AxiLiteCrossbar
    generic map(
      NUM_SLAVE_SLOTS_G  => NUM_MASTERS_C,
      NUM_MASTER_SLOTS_G => NUM_SLAVES_C,
      MASTERS_CONFIG_G   => AXIL_XBAR_CFG_C,
      DEBUG_G            => true
    )
    port map
    (
      axiClk    => clk,
      axiClkRst => reset,
      -- master/slave swapped due to the crossbar being opposite to how we think of them
      sAxiWriteMasters => mAxiWriteMasters,
      sAxiWriteSlaves  => mAxiWriteSlaves,
      sAxiReadMasters  => mAxiReadMasters,
      sAxiReadSlaves   => mAxiReadSlaves,
      mAxiWriteMasters => sAxiWriteMasters,
      mAxiWriteSlaves  => sAxiWriteSlaves,
      mAxiReadMasters  => sAxiReadMasters,
      mAxiReadSlaves   => sAxiReadSlaves
    );

end architecture;