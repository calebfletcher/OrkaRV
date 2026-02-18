LIBRARY ieee;
CONTEXT ieee.ieee_std_context;

USE work.RiscVPkg.ALL;
USE work.AxiPkg.ALL;
USE work.AxiCrossbarPkg.ALL;

LIBRARY surf;
USE surf.AxiLitePkg.ALL;

ENTITY Soc IS
    GENERIC (
        RAM_FILE_PATH_G : STRING;
        NUM_GPIO        : NATURAL RANGE 1 TO 32 := 32;
    );
    PORT (
        clk   : IN STD_LOGIC;
        reset : IN STD_LOGIC;
        -- set high on ebreak
        halt : OUT STD_LOGIC := '0';
        -- set high on illegal instruction/mem error/etc.
        trap     : OUT STD_LOGIC := '0';
        gpioPins : INOUT STD_LOGIC_VECTOR(NUM_GPIO - 1 DOWNTO 0);

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
    CONSTANT NUM_MASTERS_C       : NATURAL := 3;
    CONSTANT NUM_MEM_SLAVES_C    : NATURAL := 1;
    CONSTANT NUM_PERIPH_SLAVES_C : NATURAL := 4;

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

    CONSTANT AXI_XBAR_CFG_C : AxiLiteCrossbarMasterConfigArray(0 TO NUM_PERIPH_SLAVES_C + NUM_MEM_SLAVES_C - 1) := (
    0 => (baseAddr => X"01000000", addrBits => 24, connectivity => X"FFFF"), -- ram
    1 => (baseAddr => X"03000000", addrBits => 24, connectivity => X"FFFF"), -- debug
    2 => (baseAddr => X"02020000", addrBits => 16, connectivity => X"FFFF"), -- clint
    3 => (baseAddr => X"02000000", addrBits => 16, connectivity => X"FFFF"), -- gpio
    4 => (baseAddr => X"02010000", addrBits => 16, connectivity => X"FFFF") -- uart
    );

    SIGNAL mExtInt  : STD_LOGIC;
    SIGNAL mTimInt  : STD_LOGIC;
    SIGNAL mSoftInt : STD_LOGIC;
    SIGNAL uartInt  : STD_LOGIC;

    SIGNAL mtime : STD_LOGIC_VECTOR(63 DOWNTO 0);
BEGIN
    Cpu_inst : ENTITY work.Cpu
        PORT MAP
        (
            clk   => clk,
            reset => reset,
            halt  => halt,
            trap  => trap,

            instAxiReadMaster  => mAxiReadMasters(0),
            instAxiReadSlave   => mAxiReadSlaves(0),
            dataAxiReadMaster  => mAxiReadMasters(1),
            dataAxiReadSlave   => mAxiReadSlaves(1),
            dataAxiWriteMaster => mAxiWriteMasters(1),
            dataAxiWriteSlave  => mAxiWriteSlaves(1),

            mExtInt  => mExtInt,
            mSoftInt => mSoftInt,
            mTimInt  => mTimInt,

            mtime => mtime
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

    Clint_inst : ENTITY work.Clint
        PORT MAP(
            clk             => clk,
            reset           => reset,
            axilWriteMaster => sAxiLiteWriteMasters(1),
            axilWriteSlave  => sAxiLiteWriteSlaves(1),
            axilReadMaster  => sAxiLiteReadMasters(1),
            axilReadSlave   => sAxiLiteReadSlaves(1),
            mTimInt         => mTimInt,
            mSoftInt        => mSoftInt,
            mtime           => mtime
        );

    Gpio_inst : ENTITY work.Gpio
        GENERIC MAP(
            NUM_GPIO => NUM_GPIO
        )
        PORT MAP
        (
            clk             => clk,
            reset           => reset,
            axilReadMaster  => sAxiLiteReadMasters(2),
            axilReadSlave   => sAxiLiteReadSlaves(2),
            axilWriteMaster => sAxiLiteWriteMasters(2),
            axilWriteSlave  => sAxiLiteWriteSlaves(2),
            pins            => gpioPins
        );

    Uart_inst : ENTITY work.Uart
        PORT MAP
        (
            clk             => clk,
            reset           => reset,
            axilWriteMaster => sAxiLiteWriteMasters(3),
            axilWriteSlave  => sAxiLiteWriteSlaves(3),
            axilReadMaster  => sAxiLiteReadMasters(3),
            axilReadSlave   => sAxiLiteReadSlaves(3),
            uart_rxd_out    => uart_rxd_out,
            uart_txd_in     => uart_txd_in,
            int             => uartInt
        );

    -- interrupts
    mExtInt <= uartInt;

    -- external master interface
    mAxiWriteMasters(2) <= mAxiWriteMaster;
    mAxiWriteSlave      <= mAxiWriteSlaves(2);
    mAxiReadMasters(2)  <= mAxiReadMaster;
    mAxiReadSlave       <= mAxiReadSlaves(2);

    -- external slave interface
    sAxilWriteMaster       <= sAxiLiteWriteMasters(0);
    sAxiLiteWriteSlaves(0) <= sAxilWriteSlave;
    sAxilReadMaster        <= sAxiLiteReadMasters(0);
    sAxiLiteReadSlaves(0)  <= sAxilReadSlave;

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