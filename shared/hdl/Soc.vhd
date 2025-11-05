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
        halt : OUT STD_LOGIC := '0'
    );
END ENTITY Soc;

ARCHITECTURE rtl OF Soc IS
    constant NUM_MASTERS_C: NATURAL := 1;
    constant NUM_SLAVES_C: NATURAL := 2;
    
    SIGNAL mAxiWriteMasters : AxiLiteWriteMasterArray(NUM_MASTERS_C-1 downto 0);
    SIGNAL mAxiWriteSlaves : AxiLiteWriteSlaveArray(NUM_MASTERS_C-1 downto 0);
    SIGNAL mAxiReadMasters : AxiLiteReadMasterArray(NUM_MASTERS_C-1 downto 0);
    SIGNAL mAxiReadSlaves : AxiLiteReadSlaveArray(NUM_MASTERS_C-1 downto 0);

    SIGNAL sAxiWriteMasters : AxiLiteWriteMasterArray(NUM_SLAVES_C-1 downto 0);
    SIGNAL sAxiWriteSlaves : AxiLiteWriteSlaveArray(NUM_SLAVES_C-1 downto 0);
    SIGNAL sAxiReadMasters : AxiLiteReadMasterArray(NUM_SLAVES_C-1 downto 0);
    SIGNAL sAxiReadSlaves : AxiLiteReadSlaveArray(NUM_SLAVES_C-1 downto 0);

    constant AXIL_XBAR_CFG_C : AxiLiteCrossbarMasterConfigArray(0 to 1) := (
      0 => (baseAddr => X"01000000",
            addrBits     => 24,
            connectivity => X"FFFF"),
      1 => (baseAddr => X"02000000",
            addrBits     => 24,
            connectivity => X"FFFF")
    );
BEGIN
    Cpu_inst : ENTITY work.Cpu
        PORT MAP(
            clk => clk,
            reset => reset,
            halt => halt,

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