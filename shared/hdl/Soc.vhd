LIBRARY ieee;
CONTEXT ieee.ieee_std_context;

USE work.RiscVPkg.ALL;

LIBRARY surf;
USE surf.AxiLitePkg.ALL;

ENTITY Soc IS
    GENERIC (
        RAM_FILE_PATH_G : STRING
    );
    PORT (
        clk : IN STD_LOGIC;
        reset : IN STD_LOGIC;
        -- set high on ebreak
        halt : OUT STD_LOGIC := '0';
        -- set high on illegal instruction/mem error/etc.
        trap : OUT STD_LOGIC := '0';
        gpioPins : INOUT STD_LOGIC_VECTOR(31 DOWNTO 0);

        uart_rxd_out : OUT STD_LOGIC;
        uart_txd_in : IN STD_LOGIC;

        -- external master interface
        mAxilReadMaster : IN AxiLiteReadMasterType := AXI_LITE_READ_MASTER_INIT_C;
        mAxilReadSlave : OUT AxiLiteReadSlaveType;
        mAxilWriteMaster : IN AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
        mAxilWriteSlave : OUT AxiLiteWriteSlaveType;

        -- external slave interface
        sAxilReadMaster : OUT AxiLiteReadMasterType;
        sAxilReadSlave : IN AxiLiteReadSlaveType := AXI_LITE_READ_SLAVE_INIT_C;
        sAxilWriteMaster : OUT AxiLiteWriteMasterType;
        sAxilWriteSlave : IN AxiLiteWriteSlaveType := AXI_LITE_WRITE_SLAVE_INIT_C
    );
END ENTITY Soc;

ARCHITECTURE rtl OF Soc IS
    CONSTANT NUM_MASTERS_C : NATURAL := 2;
    CONSTANT NUM_SLAVES_C : NATURAL := 4;

    SIGNAL mAxiWriteMasters : AxiLiteWriteMasterArray(NUM_MASTERS_C - 1 DOWNTO 0) := (OTHERS => AXI_LITE_WRITE_MASTER_INIT_C);
    SIGNAL mAxiWriteSlaves : AxiLiteWriteSlaveArray(NUM_MASTERS_C - 1 DOWNTO 0);
    SIGNAL mAxiReadMasters : AxiLiteReadMasterArray(NUM_MASTERS_C - 1 DOWNTO 0) := (OTHERS => AXI_LITE_READ_MASTER_INIT_C);
    SIGNAL mAxiReadSlaves : AxiLiteReadSlaveArray(NUM_MASTERS_C - 1 DOWNTO 0);

    SIGNAL sAxiWriteMasters : AxiLiteWriteMasterArray(NUM_SLAVES_C - 1 DOWNTO 0);
    SIGNAL sAxiWriteSlaves : AxiLiteWriteSlaveArray(NUM_SLAVES_C - 1 DOWNTO 0) := (OTHERS => AXI_LITE_WRITE_SLAVE_INIT_C);
    SIGNAL sAxiReadMasters : AxiLiteReadMasterArray(NUM_SLAVES_C - 1 DOWNTO 0);
    SIGNAL sAxiReadSlaves : AxiLiteReadSlaveArray(NUM_SLAVES_C - 1 DOWNTO 0) := (OTHERS => AXI_LITE_READ_SLAVE_INIT_C);

    CONSTANT AXIL_XBAR_CFG_C : AxiLiteCrossbarMasterConfigArray(0 TO NUM_SLAVES_C - 1) := (0 => (baseAddr => X"01000000", addrBits => 24, connectivity => X"FFFF"), 1 => (baseAddr => X"03000000", addrBits => 24, connectivity => X"FFFF"), 2 => (baseAddr => X"02000000", addrBits => 16, connectivity => X"FFFF"), 3 => (baseAddr => X"02010000", addrBits => 16, connectivity => X"FFFF"));
BEGIN
    Cpu_inst : ENTITY work.Cpu
        PORT MAP(
            clk => clk,
            reset => reset,
            halt => halt,
            trap => trap,

            axiReadMaster => mAxiReadMasters(0),
            axiReadSlave => mAxiReadSlaves(0),
            axiWriteMaster => mAxiWriteMasters(0),
            axiWriteSlave => mAxiWriteSlaves(0)
        );

    Ram_inst : ENTITY work.Ram
        GENERIC MAP(
            RAM_FILE_PATH_G => RAM_FILE_PATH_G,
            AXI_BASE_ADDR_G => X"01000000"
        )
        PORT MAP(
            clk => clk,
            reset => reset,

            axiReadMaster => sAxiReadMasters(0),
            axiReadSlave => sAxiReadSlaves(0),
            axiWriteMaster => sAxiWriteMasters(0),
            axiWriteSlave => sAxiWriteSlaves(0)
        );

    Gpio_inst : ENTITY work.Gpio
        PORT MAP(
            clk => clk,
            reset => reset,
            axilReadMaster => sAxiReadMasters(2),
            axilReadSlave => sAxiReadSlaves(2),
            axilWriteMaster => sAxiWriteMasters(2),
            axilWriteSlave => sAxiWriteSlaves(2),
            pins => gpioPins
        );

    Uart_inst : ENTITY work.Uart
        PORT MAP(
            clk => clk,
            reset => reset,
            axilWriteMaster => sAxiWriteMasters(3),
            axilWriteSlave => sAxiWriteSlaves(3),
            axilReadMaster => sAxiReadMasters(3),
            axilReadSlave => sAxiReadSlaves(3),
            uart_rxd_out => uart_rxd_out,
            uart_txd_in => uart_txd_in
        );

    -- external master interface
    mAxiWriteMasters(1) <= mAxilWriteMaster;
    mAxilWriteSlave <= mAxiWriteSlaves(1);
    mAxiReadMasters(1) <= mAxilReadMaster;
    mAxilReadSlave <= mAxiReadSlaves(1);

    -- external slave interface
    sAxilWriteMaster <= sAxiWriteMasters(1);
    sAxiWriteSlaves(1) <= sAxilWriteSlave;
    sAxilReadMaster <= sAxiReadMasters(1);
    sAxiReadSlaves(1) <= sAxilReadSlave;

    -- crossbar
    AxiLiteCrossbar_inst : ENTITY surf.AxiLiteCrossbar
        GENERIC MAP(
            NUM_SLAVE_SLOTS_G => NUM_MASTERS_C,
            NUM_MASTER_SLOTS_G => NUM_SLAVES_C,
            MASTERS_CONFIG_G => AXIL_XBAR_CFG_C,
            DEBUG_G => true
        )
        PORT MAP(
            axiClk => clk,
            axiClkRst => reset,
            -- master/slave swapped due to the crossbar being opposite to how we think of them
            sAxiWriteMasters => mAxiWriteMasters,
            sAxiWriteSlaves => mAxiWriteSlaves,
            sAxiReadMasters => mAxiReadMasters,
            sAxiReadSlaves => mAxiReadSlaves,
            mAxiWriteMasters => sAxiWriteMasters,
            mAxiWriteSlaves => sAxiWriteSlaves,
            mAxiReadMasters => sAxiReadMasters,
            mAxiReadSlaves => sAxiReadSlaves
        );

END ARCHITECTURE;