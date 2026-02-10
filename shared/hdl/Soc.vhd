LIBRARY ieee;
CONTEXT ieee.ieee_std_context;

USE work.RiscVPkg.ALL;
USE work.AxiPkg.ALL;
USE work.AxiCrossbarPkg.ALL;

LIBRARY surf;
USE surf.AxiLitePkg.ALL;

ENTITY Soc IS
    GENERIC (
        RAM_FILE_PATH_G : STRING
    );
    PORT (
        clk   : IN STD_LOGIC;
        reset : IN STD_LOGIC;
        -- set high on ebreak
        halt : OUT STD_LOGIC := '0';
        -- set high on illegal instruction/mem error/etc.
        trap     : OUT STD_LOGIC := '0';
        gpioPins : INOUT STD_LOGIC_VECTOR(31 DOWNTO 0);

        uart_rxd_out : OUT STD_LOGIC;
        uart_txd_in  : IN STD_LOGIC;

        -- external master interface
        mAxiReadMaster  : IN AxiReadMasterType := AXI_READ_MASTER_INIT_C;
        mAxiReadSlave   : OUT AxiReadSlaveType;
        mAxiWriteMaster : IN AxiWriteMasterType := AXI_WRITE_MASTER_INIT_C;
        mAxiWriteSlave  : OUT AxiWriteSlaveType;

        -- external slave interface
        sAxilReadMaster  : OUT AxiLiteReadMasterType;
        sAxilReadSlave   : IN AxiLiteReadSlaveType := AXI_LITE_READ_SLAVE_INIT_C;
        sAxilWriteMaster : OUT AxiLiteWriteMasterType;
        sAxilWriteSlave  : IN AxiLiteWriteSlaveType := AXI_LITE_WRITE_SLAVE_INIT_C
    );
END ENTITY Soc;

ARCHITECTURE rtl OF Soc IS
    CONSTANT NUM_MASTERS_C       : NATURAL := 2;
    CONSTANT NUM_MEM_SLAVES_C    : NATURAL := 1;
    CONSTANT NUM_PERIPH_SLAVES_C : NATURAL := 3;

    SIGNAL mAxiWriteMasters : AxiWriteMasterArray(NUM_MASTERS_C - 1 DOWNTO 0) := (OTHERS => AXI_WRITE_MASTER_INIT_C);
    SIGNAL mAxiWriteSlaves  : AxiWriteSlaveArray(NUM_MASTERS_C - 1 DOWNTO 0);
    SIGNAL mAxiReadMasters  : AxiReadMasterArray(NUM_MASTERS_C - 1 DOWNTO 0) := (OTHERS => AXI_READ_MASTER_INIT_C);
    SIGNAL mAxiReadSlaves   : AxiReadSlaveArray(NUM_MASTERS_C - 1 DOWNTO 0);

    -- [mem1, mem2, ..., periph1, periph2, ...]
    SIGNAL sAxiWriteMasters : AxiWriteMasterArray(NUM_PERIPH_SLAVES_C + NUM_MEM_SLAVES_C - 1 DOWNTO 0);
    SIGNAL sAxiWriteSlaves  : AxiWriteSlaveArray(NUM_PERIPH_SLAVES_C + NUM_MEM_SLAVES_C - 1 DOWNTO 0) := (OTHERS => AXI_WRITE_SLAVE_INIT_C);
    SIGNAL sAxiReadMasters  : AxiReadMasterArray(NUM_PERIPH_SLAVES_C + NUM_MEM_SLAVES_C - 1 DOWNTO 0);
    SIGNAL sAxiReadSlaves   : AxiReadSlaveArray(NUM_PERIPH_SLAVES_C + NUM_MEM_SLAVES_C - 1 DOWNTO 0) := (OTHERS => AXI_READ_SLAVE_INIT_C);

    SIGNAL sAxiLiteWriteMasters : AxiLiteWriteMasterArray(NUM_PERIPH_SLAVES_C - 1 DOWNTO 0);
    SIGNAL sAxiLiteWriteSlaves  : AxiLiteWriteSlaveArray(NUM_PERIPH_SLAVES_C - 1 DOWNTO 0) := (OTHERS => AXI_LITE_WRITE_SLAVE_INIT_C);
    SIGNAL sAxiLiteReadMasters  : AxiLiteReadMasterArray(NUM_PERIPH_SLAVES_C - 1 DOWNTO 0);
    SIGNAL sAxiLiteReadSlaves   : AxiLiteReadSlaveArray(NUM_PERIPH_SLAVES_C - 1 DOWNTO 0) := (OTHERS => AXI_LITE_READ_SLAVE_INIT_C);

    CONSTANT AXI_XBAR_CFG_C : AxiCrossbarMasterConfigArray(0 TO NUM_PERIPH_SLAVES_C + NUM_MEM_SLAVES_C - 1) := (0 => (baseAddr => X"01000000", addrBits => 24, connectivity => X"FFFF"), 1 => (baseAddr => X"03000000", addrBits => 24, connectivity => X"FFFF"), 2 => (baseAddr => X"02000000", addrBits => 16, connectivity => X"FFFF"), 3 => (baseAddr => X"02010000", addrBits => 16, connectivity => X"FFFF"));

    SIGNAL mExtInt : STD_LOGIC;
    SIGNAL uartInt : STD_LOGIC;
BEGIN
    Cpu_inst : ENTITY work.Cpu
        PORT MAP
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

    Ram_inst : ENTITY work.Ram
        GENERIC MAP(
            RAM_FILE_PATH_G => RAM_FILE_PATH_G,
            AXI_BASE_ADDR_G => X"01000000"
        )
        PORT MAP
        (
            clk   => clk,
            reset => reset,

            axiReadMaster  => sAxiReadMasters(0),
            axiReadSlave   => sAxiReadSlaves(0),
            axiWriteMaster => sAxiWriteMasters(0),
            axiWriteSlave  => sAxiWriteSlaves(0)
        );

    Gpio_inst : ENTITY work.Gpio
        PORT MAP
        (
            clk             => clk,
            reset           => reset,
            axilReadMaster  => sAxiLiteReadMasters(0),
            axilReadSlave   => sAxiLiteReadSlaves(0),
            axilWriteMaster => sAxiLiteWriteMasters(0),
            axilWriteSlave  => sAxiLiteWriteSlaves(0),
            pins            => gpioPins
        );

    Uart_inst : ENTITY work.Uart
        PORT MAP
        (
            clk             => clk,
            reset           => reset,
            axilWriteMaster => sAxiLiteWriteMasters(1),
            axilWriteSlave  => sAxiLiteWriteSlaves(1),
            axilReadMaster  => sAxiLiteReadMasters(1),
            axilReadSlave   => sAxiLiteReadSlaves(1),
            uart_rxd_out    => uart_rxd_out,
            uart_txd_in     => uart_txd_in,
            int             => uartInt
        );

    -- interrupts
    mExtInt <= uartInt;

    -- external master interface
    mAxiWriteMasters(1) <= mAxiWriteMaster;
    mAxiWriteSlave      <= mAxiWriteSlaves(1);
    mAxiReadMasters(1)  <= mAxiReadMaster;
    mAxiReadSlave       <= mAxiReadSlaves(1);

    -- external slave interface
    sAxilWriteMaster       <= sAxiLiteWriteMasters(2);
    sAxiLiteWriteSlaves(2) <= sAxilWriteSlave;
    sAxilReadMaster        <= sAxiLiteReadMasters(2);
    sAxiLiteReadSlaves(2)  <= sAxilReadSlave;

    -- crossbar
    AxiLiteCrossbar_inst : ENTITY work.AxiCrossbar
        GENERIC MAP(
            NUM_SLAVE_SLOTS_G  => NUM_MASTERS_C,
            NUM_MASTER_SLOTS_G => NUM_PERIPH_SLAVES_C + NUM_MEM_SLAVES_C,
            MASTERS_CONFIG_G   => AXI_XBAR_CFG_C,
            DEBUG_G            => true
        )
        PORT MAP
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

    -- bridges from axi4 to axi4-lite
    axi_periph_bridges : FOR i IN 0 TO NUM_PERIPH_SLAVES_C - 1 GENERATE
        AxiToAxiLite_inst : ENTITY work.AxiToAxiLite
            PORT MAP(
                axiClk          => clk,
                axiClkRst       => reset,
                axiReadMaster   => sAxiReadMasters(NUM_MEM_SLAVES_C + i),
                axiReadSlave    => sAxiReadSlaves(NUM_MEM_SLAVES_C + i),
                axiWriteMaster  => sAxiWriteMasters(NUM_MEM_SLAVES_C + i),
                axiWriteSlave   => sAxiWriteSlaves(NUM_MEM_SLAVES_C + i),
                axilReadMaster  => sAxiLiteReadMasters(i),
                axilReadSlave   => sAxiLiteReadSlaves(i),
                axilWriteMaster => sAxiLiteWriteMasters(i),
                axilWriteSlave  => sAxiLiteWriteSlaves(i)
            );

    END GENERATE;

END ARCHITECTURE;