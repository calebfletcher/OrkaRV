LIBRARY ieee;
CONTEXT ieee.ieee_std_context;

USE work.RiscVPkg.ALL;

ENTITY Registers IS
    GENERIC (
        XLEN : INTEGER := XLEN
    );
    PORT (
        -- common signals
        clk : IN STD_LOGIC;
        reset : IN STD_LOGIC;

        -- registers
        registersValue : OUT RegistersType := (OTHERS => (OTHERS => '0'));

        -- register writes
        wr_addr : IN RegisterIndex;
        wr_data : IN STD_LOGIC_VECTOR(XLEN - 1 DOWNTO 0);
        wr_strobe : IN STD_LOGIC
    );
END ENTITY Registers;

ARCHITECTURE rtl OF Registers IS
    SIGNAL registerFile : RegistersType := (OTHERS => (OTHERS => '0'));
BEGIN

    PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF reset = '1' THEN
                registerFile <= (OTHERS => (OTHERS => '0'));
            ELSE
                IF wr_strobe = '1' AND wr_addr /= 0 THEN
                    registerFile(wr_addr) <= wr_data;
                END IF;
            END IF;
        END IF;
    END PROCESS;

    registersValue <= registerFile;
END ARCHITECTURE;