LIBRARY ieee;
CONTEXT ieee.ieee_std_context;

USE work.AxiPkg.ALL;

LIBRARY surf;
USE surf.AxiLitePkg.ALL;

ENTITY InstCache IS
    GENERIC (
        TPD_G : TIME := 1 ns
    );
    PORT (
        clk   : IN STD_LOGIC;
        reset : IN STD_LOGIC;

        axiReadMaster : OUT AxiReadMasterType := AXI_READ_MASTER_INIT_C;
        axiReadSlave  : IN AxiReadSlaveType   := AXI_READ_SLAVE_INIT_C;

        pc      : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        pcValid : IN STD_LOGIC;
        pcReady : OUT STD_LOGIC;

        instruction : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
        instValid   : OUT STD_LOGIC;
        instReady   : IN STD_LOGIC;
        -- fault if memFault is high while instValid is high
        memFault : OUT STD_LOGIC;

        flush : IN STD_LOGIC
    );
END ENTITY InstCache;

-- normal architecture
ARCHITECTURE full OF InstCache IS

    TYPE RegType IS RECORD
        -- instruction bus
        axiReadMaster : AxiReadMasterType;

        -- current state
        pc          : STD_LOGIC_VECTOR(31 DOWNTO 0);
        pcReady     : STD_LOGIC;
        instruction : STD_LOGIC_VECTOR(31 DOWNTO 0);
        instValid   : STD_LOGIC;
        instFault   : STD_LOGIC;
    END RECORD RegType;

    CONSTANT REG_INIT_C : RegType := (
    axiReadMaster => AXI_READ_MASTER_INIT_C,
    pc => (OTHERS => '0'),
    pcReady       => '1',
    instruction => (OTHERS => '0'),
    instValid     => '0',
    instFault     => '0'
    );

    SIGNAL r   : RegType := REG_INIT_C;
    SIGNAL rin : RegType;
BEGIN
    PROCESS (ALL)
        VARIABLE v : RegType;
    BEGIN
        v := r;

        -- always ready for a response
        v.axiReadMaster.rready := '1';

        IF v.instValid AND instReady THEN
            -- prep for next request
            v.pcReady     := '1';
            v.instValid   := '0';
            v.instruction := (OTHERS => '0');
        END IF;

        -- accept bus transactions
        IF (axiReadSlave.arready AND r.axiReadMaster.arvalid) THEN
            v.axiReadMaster.arvalid := '0';
            v.axiReadMaster.araddr  := (OTHERS => '0');
        END IF;
        IF (axiReadSlave.rvalid AND r.axiReadMaster.rready) THEN
            -- got instruction
            v.instValid := '1';
            v.instFault := '0' WHEN axiReadSlave.rresp = AXI_RESP_OK_C ELSE
            '1';
            v.instruction := axiReadSlave.rdata;
        END IF;

        IF pcValid AND r.pcReady THEN
            -- new pc for us
            v.pcReady := '0';

            v.axiReadMaster.araddr  := pc;
            v.axiReadMaster.arvalid := '1';
        END IF;

        IF reset THEN
            v := REG_INIT_C;
        END IF;

        rin <= v;
    END PROCESS;

    PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN
            r <= rin AFTER TPD_G;
        END IF;
    END PROCESS;

    axiReadMaster <= r.axiReadMaster;
    memFault      <= r.instFault;
    instValid     <= r.instValid;
    instruction   <= r.instruction;
    pcReady       <= r.pcReady;
END ARCHITECTURE;

-- passthrough with no caching, used to bypass the cache fully
ARCHITECTURE passthrough OF InstCache IS

BEGIN
    -- address
    axiReadMaster.araddr  <= pc;
    axiReadMaster.arvalid <= pcValid;
    pcReady               <= axiReadSlave.arready;

    -- instruction
    axiReadMaster.rready <= instReady;
    instValid            <= axiReadSlave.rvalid;
    instruction          <= axiReadSlave.rdata;
    memFault             <= '1' WHEN axiReadSlave.rresp /= AXI_RESP_OK_C ELSE
        '0';

END ARCHITECTURE;