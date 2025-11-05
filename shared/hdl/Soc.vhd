LIBRARY ieee;
CONTEXT ieee.ieee_std_context;

USE work.RiscVPkg.ALL;

LIBRARY surf;
USE surf.AxiLitePkg.ALL;

ENTITY Soc IS
    GENERIC (
        TPD_G : TIME := 1 ns;
        RAM_FILE_PATH_G : STRING
    );
    PORT (
        clk : IN STD_LOGIC;
        reset : IN STD_LOGIC;
        halt : OUT STD_LOGIC := '0'
    );
END ENTITY Soc;

ARCHITECTURE rtl OF Soc IS
    SIGNAL axiReadMaster : AxiLiteReadMasterType;
    SIGNAL axiWriteMaster : AxiLiteWriteMasterType;
    SIGNAL axiReadSlave : AxiLiteReadSlaveType;
    SIGNAL axiWriteSlave : AxiLiteWriteSlaveType;
BEGIN
    Cpu_inst : ENTITY work.Cpu
        GENERIC MAP(
            TPD_G => TPD_G
        )
        PORT MAP(
            clk => clk,
            reset => reset,
            halt => halt,

            axiReadMaster => axiReadMaster,
            axiReadSlave => axiReadSlave,
            axiWriteMaster => axiWriteMaster,
            axiWriteSlave => axiWriteSlave
        );

    Ram_inst : ENTITY work.Ram
        GENERIC MAP(
            RAM_FILE_PATH_G => RAM_FILE_PATH_G
        )
        PORT MAP(
            clk => clk,
            reset => reset,

            axiReadMaster => axiReadMaster,
            axiReadSlave => axiReadSlave,
            axiWriteMaster => axiWriteMaster,
            axiWriteSlave => axiWriteSlave
        );

END ARCHITECTURE;