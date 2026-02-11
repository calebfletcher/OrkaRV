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

        pc    : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        flush : IN STD_LOGIC;

        instruction : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
        instValid   : OUT STD_LOGIC;
        -- fault if memFault is high while instValid is high
        memFault : OUT STD_LOGIC;
    );
END ENTITY InstCache;

ARCHITECTURE rtl OF InstCache IS

    TYPE RegType IS RECORD
        -- instruction bus
        axiReadMaster : AxiReadMasterType;

        -- current state
        pc        : STD_LOGIC_VECTOR(31 DOWNTO 0);
        pcValid   : STD_LOGIC;
        inst      : STD_LOGIC_VECTOR(31 DOWNTO 0);
        instValid : STD_LOGIC;
        instFault : STD_LOGIC;
    END RECORD RegType;

    CONSTANT REG_INIT_C : RegType := (
    axiReadMaster => AXI_READ_MASTER_INIT_C,
    pc => (OTHERS => '0'),
    pcValid       => '0',
    inst => (OTHERS => '0'),
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

        -- accept instruction bus transactions
        IF (axiReadSlave.arready AND r.axiReadMaster.arvalid) THEN
            v.axiReadMaster.arvalid := '0';
            v.axiReadMaster.araddr  := (OTHERS => '0');
        END IF;
        IF (axiReadSlave.rvalid AND r.axiReadMaster.rready) THEN
            v.axiReadMaster.rready := '0';
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

    --memFault <= axiReadSlave.rresp;
END ARCHITECTURE;