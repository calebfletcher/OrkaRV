LIBRARY ieee;
CONTEXT ieee.ieee_std_context;

LIBRARY surf;
USE surf.AxiLitePkg.ALL;

ENTITY CocotbSoc IS
    GENERIC (
        RAM_FILE_PATH_G : STRING
    );
    PORT (
        clk : IN STD_LOGIC;
        reset : IN STD_LOGIC;
        halt : OUT STD_LOGIC := '0';
        trap : OUT STD_LOGIC := '0';
        gpioPins : INOUT STD_LOGIC_VECTOR(31 DOWNTO 0);

        uart_rxd_out : OUT STD_LOGIC;
        uart_txd_in : IN STD_LOGIC;

        -- slave interface for cocotb master
        S_AXI_AWADDR : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        S_AXI_AWPROT : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
        S_AXI_AWVALID : IN STD_LOGIC;
        S_AXI_AWREADY : OUT STD_LOGIC;
        S_AXI_WDATA : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        S_AXI_WSTRB : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
        S_AXI_WVALID : IN STD_LOGIC;
        S_AXI_WREADY : OUT STD_LOGIC;
        S_AXI_BRESP : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
        S_AXI_BVALID : OUT STD_LOGIC;
        S_AXI_BREADY : IN STD_LOGIC;
        S_AXI_ARADDR : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        S_AXI_ARPROT : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
        S_AXI_ARVALID : IN STD_LOGIC;
        S_AXI_ARREADY : OUT STD_LOGIC;
        S_AXI_RDATA : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
        S_AXI_RRESP : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
        S_AXI_RVALID : OUT STD_LOGIC;
        S_AXI_RREADY : IN STD_LOGIC;

        -- master interface for cocotb slave
        M_AXI_AWADDR : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
        M_AXI_AWPROT : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
        M_AXI_AWVALID : OUT STD_LOGIC;
        M_AXI_AWREADY : IN STD_LOGIC;
        M_AXI_WDATA : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
        M_AXI_WSTRB : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        M_AXI_WVALID : OUT STD_LOGIC;
        M_AXI_WREADY : IN STD_LOGIC;
        M_AXI_BRESP : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        M_AXI_BVALID : IN STD_LOGIC;
        M_AXI_BREADY : OUT STD_LOGIC;
        M_AXI_ARADDR : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
        M_AXI_ARPROT : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
        M_AXI_ARVALID : OUT STD_LOGIC;
        M_AXI_ARREADY : IN STD_LOGIC;
        M_AXI_RDATA : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        M_AXI_RRESP : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        M_AXI_RVALID : IN STD_LOGIC;
        M_AXI_RREADY : OUT STD_LOGIC
    );
END ENTITY CocotbSoc;

ARCHITECTURE rtl OF CocotbSoc IS

    SIGNAL axilClk : STD_LOGIC;
    SIGNAL axilRst : STD_LOGIC;

    -- cocotb master interface
    SIGNAL mAxilReadMaster : AxiLiteReadMasterType;
    SIGNAL mAxilReadSlave : AxiLiteReadSlaveType;
    SIGNAL mAxilWriteMaster : AxiLiteWriteMasterType;
    SIGNAL mAxilWriteSlave : AxiLiteWriteSlaveType;

    -- cocotb slave interface
    SIGNAL sAxilReadMaster : AxiLiteReadMasterType;
    SIGNAL sAxilReadSlave : AxiLiteReadSlaveType;
    SIGNAL sAxilWriteMaster : AxiLiteWriteMasterType;
    SIGNAL sAxilWriteSlave : AxiLiteWriteSlaveType;
BEGIN
    Soc_inst : ENTITY work.Soc
        GENERIC MAP(
            RAM_FILE_PATH_G => RAM_FILE_PATH_G
        )
        PORT MAP(
            clk => clk,
            reset => reset,
            halt => halt,
            trap => trap,
            gpioPins => gpioPins,
            uart_rxd_out => uart_rxd_out,
            uart_txd_in => uart_txd_in
        );
    -- adapter for cocotb master
    SlaveAxiLiteIpIntegrator_inst : ENTITY surf.SlaveAxiLiteIpIntegrator
        GENERIC MAP(
            HAS_WSTRB => 1,
            ADDR_WIDTH => 32
        )
        PORT MAP(
            S_AXI_ACLK => clk,
            S_AXI_ARESETN => NOT reset,
            S_AXI_AWADDR => S_AXI_AWADDR,
            S_AXI_AWPROT => S_AXI_AWPROT,
            S_AXI_AWVALID => S_AXI_AWVALID,
            S_AXI_AWREADY => S_AXI_AWREADY,
            S_AXI_WDATA => S_AXI_WDATA,
            S_AXI_WSTRB => S_AXI_WSTRB,
            S_AXI_WVALID => S_AXI_WVALID,
            S_AXI_WREADY => S_AXI_WREADY,
            S_AXI_BRESP => S_AXI_BRESP,
            S_AXI_BVALID => S_AXI_BVALID,
            S_AXI_BREADY => S_AXI_BREADY,
            S_AXI_ARADDR => S_AXI_ARADDR,
            S_AXI_ARPROT => S_AXI_ARPROT,
            S_AXI_ARVALID => S_AXI_ARVALID,
            S_AXI_ARREADY => S_AXI_ARREADY,
            S_AXI_RDATA => S_AXI_RDATA,
            S_AXI_RRESP => S_AXI_RRESP,
            S_AXI_RVALID => S_AXI_RVALID,
            S_AXI_RREADY => S_AXI_RREADY,
            axilClk => axilClk,
            axilRst => axilRst,
            axilReadMaster => mAxilReadMaster,
            axilReadSlave => mAxilReadSlave,
            axilWriteMaster => mAxilWriteMaster,
            axilWriteSlave => mAxilWriteSlave
        );

    -- adapter for cocotb slave
    MasterAxiLiteIpIntegrator_inst : ENTITY surf.MasterAxiLiteIpIntegrator
        GENERIC MAP(
            HAS_WSTRB => 1,
            ADDR_WIDTH => 32
        )
        PORT MAP(
            M_AXI_ACLK => clk,
            M_AXI_ARESETN => NOT reset,
            M_AXI_AWADDR => M_AXI_AWADDR,
            M_AXI_AWPROT => M_AXI_AWPROT,
            M_AXI_AWVALID => M_AXI_AWVALID,
            M_AXI_AWREADY => M_AXI_AWREADY,
            M_AXI_WDATA => M_AXI_WDATA,
            M_AXI_WSTRB => M_AXI_WSTRB,
            M_AXI_WVALID => M_AXI_WVALID,
            M_AXI_WREADY => M_AXI_WREADY,
            M_AXI_BRESP => M_AXI_BRESP,
            M_AXI_BVALID => M_AXI_BVALID,
            M_AXI_BREADY => M_AXI_BREADY,
            M_AXI_ARADDR => M_AXI_ARADDR,
            M_AXI_ARPROT => M_AXI_ARPROT,
            M_AXI_ARVALID => M_AXI_ARVALID,
            M_AXI_ARREADY => M_AXI_ARREADY,
            M_AXI_RDATA => M_AXI_RDATA,
            M_AXI_RRESP => M_AXI_RRESP,
            M_AXI_RVALID => M_AXI_RVALID,
            M_AXI_RREADY => M_AXI_RREADY,
            axilClk => axilClk,
            axilRst => axilRst,
            axilReadMaster => sAxilReadMaster,
            axilReadSlave => sAxilReadSlave,
            axilWriteMaster => sAxilWriteMaster,
            axilWriteSlave => sAxilWriteSlave
        );
END ARCHITECTURE;