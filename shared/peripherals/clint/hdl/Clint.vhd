LIBRARY ieee;
CONTEXT ieee.ieee_std_context;

LIBRARY surf;
USE surf.AxiLitePkg.ALL;

USE work.axi4lite_intf_pkg.ALL;
USE work.ClintRegisters_pkg.ALL;

ENTITY Clint IS
    PORT (
        clk   : IN STD_LOGIC;
        reset : IN STD_LOGIC;

        axilWriteMaster : IN AxiLiteWriteMasterType;
        axilWriteSlave  : OUT AxiLiteWriteSlaveType;
        axilReadMaster  : IN AxiLiteReadMasterType;
        axilReadSlave   : OUT AxiLiteReadSlaveType;

        mTimInt  : OUT STD_LOGIC;
        mSoftInt : OUT STD_LOGIC
    );
END ENTITY Clint;

ARCHITECTURE rtl OF Clint IS
    CONSTANT ADDR_BITS_C : POSITIVE := 4;

    SIGNAL s_axil_i : axi4lite_slave_in_intf(
    AWADDR(ADDR_BITS_C - 1 DOWNTO 0),
    WDATA(31 DOWNTO 0),
    WSTRB(3 DOWNTO 0),
    ARADDR(ADDR_BITS_C - 1 DOWNTO 0)
    );
    SIGNAL s_axil_o : axi4lite_slave_out_intf(
    RDATA(31 DOWNTO 0)
    );

    SIGNAL hwif_in  : ClintRegisters_in_t;
    SIGNAL hwif_out : ClintRegisters_out_t;

    SIGNAL mtime    : UNSIGNED(63 DOWNTO 0) := (OTHERS => '0');
    SIGNAL mtimecmp : STD_LOGIC_VECTOR(63 DOWNTO 0);
BEGIN
    PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF reset THEN
                mtime <= (OTHERS => '0');
            ELSE
                mtime <= mtime + 1;
            END IF;
        END IF;
    END PROCESS;

    mtimecmp <= hwif_out.mtimecmph.mtimecmph.value & hwif_out.mtimecmp.mtimecmp.value;

    -- timer interrupt when mtime >= mtimecmp
    mTimInt <= '1' WHEN mtime >= UNSIGNED(mtimecmp) ELSE
        '0';
    -- software interrupt when reg value set
    mSoftInt <= hwif_out.msip.msip.value;

    -- convert surf axilite to peakrdl's
    AxiLitePeakRdlBridge_inst : ENTITY work.AxiLitePeakRdlBridge
        GENERIC MAP(
            ADDR_BITS_G => ADDR_BITS_C
        )
        PORT MAP
        (
            axilWriteMaster => axilWriteMaster,
            axilWriteSlave  => axilWriteSlave,
            axilReadMaster  => axilReadMaster,
            axilReadSlave   => axilReadSlave,
            s_axil_i        => s_axil_i,
            s_axil_o        => s_axil_o
        );

    -- register map
    ClintRegisters_inst : ENTITY work.ClintRegisters
        PORT MAP
        (
            clk      => clk,
            rst      => reset,
            s_axil_i => s_axil_i,
            s_axil_o => s_axil_o,
            hwif_in  => hwif_in,
            hwif_out => hwif_out
        );

END ARCHITECTURE;