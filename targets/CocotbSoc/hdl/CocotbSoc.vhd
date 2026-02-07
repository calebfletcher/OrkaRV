library ieee;
context ieee.ieee_std_context;

library surf;
use surf.AxiLitePkg.all;

entity CocotbSoc is
  generic (
    RAM_FILE_PATH_G : string
  );
  port (
    clk      : in std_logic;
    reset    : in std_logic;
    halt     : out std_logic := '0';
    trap     : out std_logic := '0';
    gpioPins : inout std_logic_vector(31 downto 0);

    uart_rxd_out : out std_logic;
    uart_txd_in  : in std_logic;

    -- slave interface for cocotb master
    S_AXI_AWADDR  : in std_logic_vector(31 downto 0);
    S_AXI_AWPROT  : in std_logic_vector(2 downto 0);
    S_AXI_AWVALID : in std_logic;
    S_AXI_AWREADY : out std_logic;
    S_AXI_WDATA   : in std_logic_vector(31 downto 0);
    S_AXI_WSTRB   : in std_logic_vector(3 downto 0);
    S_AXI_WVALID  : in std_logic;
    S_AXI_WREADY  : out std_logic;
    S_AXI_BRESP   : out std_logic_vector(1 downto 0);
    S_AXI_BVALID  : out std_logic;
    S_AXI_BREADY  : in std_logic;
    S_AXI_ARADDR  : in std_logic_vector(31 downto 0);
    S_AXI_ARPROT  : in std_logic_vector(2 downto 0);
    S_AXI_ARVALID : in std_logic;
    S_AXI_ARREADY : out std_logic;
    S_AXI_RDATA   : out std_logic_vector(31 downto 0);
    S_AXI_RRESP   : out std_logic_vector(1 downto 0);
    S_AXI_RVALID  : out std_logic;
    S_AXI_RREADY  : in std_logic;

    -- master interface for cocotb slave
    M_AXI_AWADDR  : out std_logic_vector(31 downto 0);
    M_AXI_AWPROT  : out std_logic_vector(2 downto 0);
    M_AXI_AWVALID : out std_logic;
    M_AXI_AWREADY : in std_logic;
    M_AXI_WDATA   : out std_logic_vector(31 downto 0);
    M_AXI_WSTRB   : out std_logic_vector(3 downto 0);
    M_AXI_WVALID  : out std_logic;
    M_AXI_WREADY  : in std_logic;
    M_AXI_BRESP   : in std_logic_vector(1 downto 0);
    M_AXI_BVALID  : in std_logic;
    M_AXI_BREADY  : out std_logic;
    M_AXI_ARADDR  : out std_logic_vector(31 downto 0);
    M_AXI_ARPROT  : out std_logic_vector(2 downto 0);
    M_AXI_ARVALID : out std_logic;
    M_AXI_ARREADY : in std_logic;
    M_AXI_RDATA   : in std_logic_vector(31 downto 0);
    M_AXI_RRESP   : in std_logic_vector(1 downto 0);
    M_AXI_RVALID  : in std_logic;
    M_AXI_RREADY  : out std_logic
  );
end entity CocotbSoc;

architecture rtl of CocotbSoc is

  signal axilClk : std_logic;
  signal axilRst : std_logic;

  -- cocotb master interface
  signal mAxilReadMaster  : AxiLiteReadMasterType;
  signal mAxilReadSlave   : AxiLiteReadSlaveType;
  signal mAxilWriteMaster : AxiLiteWriteMasterType;
  signal mAxilWriteSlave  : AxiLiteWriteSlaveType;

  -- cocotb slave interface
  signal sAxilReadMaster  : AxiLiteReadMasterType;
  signal sAxilReadSlave   : AxiLiteReadSlaveType;
  signal sAxilWriteMaster : AxiLiteWriteMasterType;
  signal sAxilWriteSlave  : AxiLiteWriteSlaveType;
begin
  Soc_inst : entity work.Soc
    generic map(
      RAM_FILE_PATH_G => RAM_FILE_PATH_G
    )
    port map
    (
      clk          => clk,
      reset        => reset,
      halt         => halt,
      trap         => trap,
      gpioPins     => gpioPins,
      uart_rxd_out => uart_rxd_out,
      uart_txd_in  => uart_txd_in,

      -- cocotb master interface
      mAxilReadMaster  => mAxilReadMaster,
      mAxilReadSlave   => mAxilReadSlave,
      mAxilWriteMaster => mAxilWriteMaster,
      mAxilWriteSlave  => mAxilWriteSlave,

      -- cocotb slave interface
      sAxilReadMaster  => sAxilReadMaster,
      sAxilReadSlave   => sAxilReadSlave,
      sAxilWriteMaster => sAxilWriteMaster,
      sAxilWriteSlave  => sAxilWriteSlave
    );
  -- adapter for cocotb master
  SlaveAxiLiteIpIntegrator_inst : entity surf.SlaveAxiLiteIpIntegrator
    generic map(
      HAS_WSTRB  => 1,
      ADDR_WIDTH => 32
    )
    port map
    (
      S_AXI_ACLK      => clk,
      S_AXI_ARESETN   => not reset,
      S_AXI_AWADDR    => S_AXI_AWADDR,
      S_AXI_AWPROT    => S_AXI_AWPROT,
      S_AXI_AWVALID   => S_AXI_AWVALID,
      S_AXI_AWREADY   => S_AXI_AWREADY,
      S_AXI_WDATA     => S_AXI_WDATA,
      S_AXI_WSTRB     => S_AXI_WSTRB,
      S_AXI_WVALID    => S_AXI_WVALID,
      S_AXI_WREADY    => S_AXI_WREADY,
      S_AXI_BRESP     => S_AXI_BRESP,
      S_AXI_BVALID    => S_AXI_BVALID,
      S_AXI_BREADY    => S_AXI_BREADY,
      S_AXI_ARADDR    => S_AXI_ARADDR,
      S_AXI_ARPROT    => S_AXI_ARPROT,
      S_AXI_ARVALID   => S_AXI_ARVALID,
      S_AXI_ARREADY   => S_AXI_ARREADY,
      S_AXI_RDATA     => S_AXI_RDATA,
      S_AXI_RRESP     => S_AXI_RRESP,
      S_AXI_RVALID    => S_AXI_RVALID,
      S_AXI_RREADY    => S_AXI_RREADY,
      axilClk         => axilClk,
      axilRst         => axilRst,
      axilReadMaster  => mAxilReadMaster,
      axilReadSlave   => mAxilReadSlave,
      axilWriteMaster => mAxilWriteMaster,
      axilWriteSlave  => mAxilWriteSlave
    );

  -- adapter for cocotb slave
  MasterAxiLiteIpIntegrator_inst : entity surf.MasterAxiLiteIpIntegrator
    generic map(
      HAS_WSTRB  => 1,
      ADDR_WIDTH => 32
    )
    port map
    (
      M_AXI_ACLK      => clk,
      M_AXI_ARESETN   => not reset,
      M_AXI_AWADDR    => M_AXI_AWADDR,
      M_AXI_AWPROT    => M_AXI_AWPROT,
      M_AXI_AWVALID   => M_AXI_AWVALID,
      M_AXI_AWREADY   => M_AXI_AWREADY,
      M_AXI_WDATA     => M_AXI_WDATA,
      M_AXI_WSTRB     => M_AXI_WSTRB,
      M_AXI_WVALID    => M_AXI_WVALID,
      M_AXI_WREADY    => M_AXI_WREADY,
      M_AXI_BRESP     => M_AXI_BRESP,
      M_AXI_BVALID    => M_AXI_BVALID,
      M_AXI_BREADY    => M_AXI_BREADY,
      M_AXI_ARADDR    => M_AXI_ARADDR,
      M_AXI_ARPROT    => M_AXI_ARPROT,
      M_AXI_ARVALID   => M_AXI_ARVALID,
      M_AXI_ARREADY   => M_AXI_ARREADY,
      M_AXI_RDATA     => M_AXI_RDATA,
      M_AXI_RRESP     => M_AXI_RRESP,
      M_AXI_RVALID    => M_AXI_RVALID,
      M_AXI_RREADY    => M_AXI_RREADY,
      axilClk         => axilClk,
      axilRst         => axilRst,
      axilReadMaster  => sAxilReadMaster,
      axilReadSlave   => sAxilReadSlave,
      axilWriteMaster => sAxilWriteMaster,
      axilWriteSlave  => sAxilWriteSlave
    );
end architecture;