LIBRARY ieee;
CONTEXT ieee.ieee_std_context;

LIBRARY surf;
USE surf.AxiLitePkg.ALL;

USE work.axi4lite_intf_pkg.ALL;
USE work.UartRegisters_pkg.ALL;

ENTITY Uart IS
    PORT (
        clk   : IN STD_LOGIC;
        reset : IN STD_LOGIC;

        axilWriteMaster : IN AxiLiteWriteMasterType;
        axilWriteSlave  : OUT AxiLiteWriteSlaveType;
        axilReadMaster  : IN AxiLiteReadMasterType;
        axilReadSlave   : OUT AxiLiteReadSlaveType;

        uart_rxd_out : OUT STD_LOGIC;
        uart_txd_in  : IN STD_LOGIC;

        int : OUT STD_LOGIC
    );
END ENTITY Uart;

ARCHITECTURE rtl OF Uart IS
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

    SIGNAL hwif_in  : UartRegisters_in_t;
    SIGNAL hwif_out : UartRegisters_out_t;

    SIGNAL rdFifoValid : STD_LOGIC;
    SIGNAL wrDelayed   : STD_LOGIC := '0';
BEGIN
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
    UartRegisters_inst : ENTITY work.UartRegisters
        PORT MAP
        (
            clk      => clk,
            rst      => reset,
            s_axil_i => s_axil_i,
            s_axil_o => s_axil_o,
            hwif_in  => hwif_in,
            hwif_out => hwif_out
        );

    UartWrapper_inst : ENTITY surf.UartWrapper
        GENERIC MAP(
            CLK_FREQ_G  => 100.0e+6,
            BAUD_RATE_G => 1e6
        )
        PORT MAP
        (
            clk     => clk,
            rst     => reset,
            wrData  => hwif_out.tx.tx.value,
            wrValid => wrDelayed,
            wrReady => hwif_in.status.txe.next_q,
            rdData  => hwif_in.rx.rx.next_q,
            rdValid => rdFifoValid,
            -- accept data from uart on access from uart
            rdReady => hwif_out.rx.rx.swacc AND rdFifoValid,
            tx      => uart_rxd_out,
            rx      => uart_txd_in
        );

    PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF reset = '1' THEN
                wrDelayed <= '0';
            ELSE
                wrDelayed <= hwif_out.tx.tx.swacc;
            END IF;
        END IF;
    END PROCESS;

    hwif_in.status.rxr.next_q <= rdFifoValid;

    -- interrupt output
    int <= (hwif_out.ctrl.rxie.value AND hwif_out.status.rxr.value) OR (hwif_out.ctrl.txie.value AND hwif_out.status.txe.value);

END ARCHITECTURE;