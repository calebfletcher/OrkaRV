LIBRARY ieee;
CONTEXT ieee.ieee_std_context;

LIBRARY surf;
USE surf.AxiLitePkg.ALL;

ENTITY AxiLiteTimeout IS
    PORT (
        clk   : IN STD_LOGIC;
        reset : IN STD_LOGIC;

        -- slave (upstream-facing) interface
        sAxiWriteMaster : IN AxiLiteWriteMasterType;
        sAxiWriteSlave  : OUT AxiLiteWriteSlaveType;
        sAxiReadMaster  : IN AxiLiteReadMasterType;
        sAxiReadSlave   : OUT AxiLiteReadSlaveType;

        -- master (downstream-facing) interface
        mAxiWriteMaster : OUT AxiLiteWriteMasterType;
        mAxiWriteSlave  : IN AxiLiteWriteSlaveType;
        mAxiReadMaster  : OUT AxiLiteReadMasterType;
        mAxiReadSlave   : IN AxiLiteReadSlaveType

    );
END ENTITY AxiLiteTimeout;

ARCHITECTURE rtl OF AxiLiteTimeout IS
    CONSTANT TIMEOUT_COUNT_C : INTEGER := 100;
    TYPE counter_array IS ARRAY (0 TO 4) OF INTEGER RANGE 0 TO TIMEOUT_COUNT_C;
    SIGNAL timeout_counters : counter_array := (OTHERS => 0);
    SIGNAL channel_blocked  : STD_LOGIC_VECTOR(4 DOWNTO 0);
    SIGNAL timeout          : STD_LOGIC_VECTOR(4 DOWNTO 0);
BEGIN

    -- Channel order: 0=AW, 1=W, 2=B, 3=AR, 4=R
    channel_blocked(0) <= sAxiWriteMaster.awvalid AND NOT mAxiWriteSlave.awready; -- AW
    channel_blocked(1) <= sAxiWriteMaster.wvalid AND NOT mAxiWriteSlave.wready; -- W
    channel_blocked(2) <= sAxiWriteMaster.bready AND NOT mAxiWriteSlave.bvalid; -- B
    channel_blocked(3) <= sAxiReadMaster.arvalid AND NOT sAxiReadSlave.arready; -- AR
    channel_blocked(4) <= sAxiReadMaster.rready AND NOT sAxiReadSlave.rvalid; -- R

    -- Passthroughs
    mAxiWriteMaster <= sAxiWriteMaster;
    mAxiReadMaster  <= sAxiReadMaster;

    -- Combinatorial passthrough for slave response, overridden on timeout
    -- Write address ready
    sAxiWriteSlave.awready <= sAxiWriteMaster.awvalid WHEN timeout(0) ELSE
    mAxiWriteSlave.awready;
    -- Write data ready
    sAxiWriteSlave.wready <= sAxiWriteMaster.wvalid WHEN timeout(1) ELSE
    mAxiWriteSlave.wready;
    -- Write response channel (B)
    sAxiWriteSlave.bvalid <= '1' WHEN timeout(2) ELSE
    mAxiWriteSlave.bvalid;
    sAxiWriteSlave.bresp <= AXI_RESP_SLVERR_C WHEN timeout(2) ELSE
    mAxiWriteSlave.bresp;

    -- Read address ready
    sAxiReadSlave.arready <= sAxiReadMaster.arvalid WHEN timeout(3) ELSE
    mAxiReadSlave.arready;
    -- Read response channel (R)
    sAxiReadSlave.rvalid <= sAxiReadMaster.rready WHEN timeout(4) ELSE
    mAxiReadSlave.rvalid;
    sAxiReadSlave.rdata <= (OTHERS => '0') WHEN timeout(4) ELSE
    mAxiReadSlave.rdata;
    sAxiReadSlave.rresp <= AXI_RESP_SLVERR_C WHEN timeout(4) ELSE
    mAxiReadSlave.rresp;

    -- Timeout process
    PROCESS (clk, reset)
    BEGIN
        IF reset THEN
            timeout_counters <= (OTHERS => 0);
            timeout          <= (OTHERS => '0');
        ELSIF rising_edge(clk) THEN
            FOR i IN channel_blocked'RANGE LOOP
                IF NOT timeout(i) THEN
                    IF channel_blocked(i) THEN
                        IF timeout_counters(i) < TIMEOUT_COUNT_C THEN
                            timeout_counters(i) <= timeout_counters(i) + 1;
                        END IF;
                    ELSE
                        timeout_counters(i) <= 0;
                    END IF;
                    IF timeout_counters(i) = TIMEOUT_COUNT_C THEN
                        timeout(i) <= '1';
                    ELSE
                        timeout(i) <= '0';
                    END IF;
                END IF;
            END LOOP;
        END IF;
    END PROCESS;
END ARCHITECTURE;