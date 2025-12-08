LIBRARY ieee;
CONTEXT ieee.ieee_std_context;

USE work.RiscVPkg.ALL;
USE work.CsrPkg.ALL;

ENTITY Csr IS
    GENERIC (
        XLEN : INTEGER := XLEN
    );
    PORT (
        clk   : IN STD_LOGIC;
        reset : IN STD_LOGIC;

        currentPrivilege : IN Privilege;

        op     : IN CsrOp;
        addr   : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
        wrData : IN STD_LOGIC_VECTOR(XLEN - 1 DOWNTO 0);
        rdData : OUT STD_LOGIC_VECTOR(XLEN - 1 DOWNTO 0);
        -- set high if the access was not permitted
        illegalAccess : OUT STD_LOGIC;
    );
END ENTITY Csr;

ARCHITECTURE rtl OF Csr IS
    SUBTYPE PERMISSIONS IS STD_LOGIC_VECTOR(1 DOWNTO 0);
    CONSTANT PERM_RO_C : PERMISSIONS := "11";

    -- permissions
    SIGNAL rwPerm                 : STD_LOGIC_VECTOR(1 DOWNTO 0);
    SIGNAL lowestAllowedPrivilege : STD_LOGIC_VECTOR(1 DOWNTO 0);

    SIGNAL readPermitted  : STD_LOGIC;
    SIGNAL writePermitted : STD_LOGIC;
    SIGNAL readRequested  : STD_LOGIC;
    SIGNAL writeRequested : STD_LOGIC;

    CONSTANT CSR_TABLE_C : CsrTable(0 TO 4) := (
    0 => (addr => x"F11"), -- mvendorid
    1 => (addr => x"F12"), -- marchid
    2 => (addr => x"F13"), -- mimpid
    3 => (addr => x"F14"), -- mhartid
    4 => (addr => x"F15") -- mconfigptr
    );
    CONSTANT NUM_CSRS : INTEGER := CSR_TABLE_C'length;

    -- csr storage
    TYPE CsrStorage IS ARRAY (0 TO NUM_CSRS - 1) OF STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL csrReg : CsrStorage := (OTHERS => (OTHERS => '0'));

    -- addr demux
    SIGNAL hitVector : STD_LOGIC_VECTOR(NUM_CSRS - 1 DOWNTO 0);
    SIGNAL csrIndex  : NATURAL RANGE 0 TO NUM_CSRS - 1;
    SIGNAL csrMatch  : STD_LOGIC;
BEGIN
    -- addr demux
    FOR i IN 0 TO NUM_CSRS - 1 GENERATE
        hitVector(i) <= '1' WHEN addr = CSR_TABLE_C(i).addr ELSE
        '0';
    END GENERATE;
    csrMatch <= OR hitVector;
    csrIndex <= to_integer(unsigned(hitVector));

    -- op decode
    PROCESS (ALL)
    BEGIN
        readRequested <= '1' WHEN op = OP_READ OR op = OP_READ_WRITE OR op = OP_READ_SET OR op = OP_READ_CLEAR ELSE
            '0';
        writeRequested <= '1' WHEN op = OP_WRITE OR op = OP_READ_WRITE OR op = OP_READ_SET OR op = OP_READ_CLEAR ELSE
            '0';
    END PROCESS;

    -- permissions checks
    PROCESS (ALL)
    BEGIN
        rwPerm                 <= addr(11 DOWNTO 10);
        lowestAllowedPrivilege <= addr(9 DOWNTO 8);
        IF UNSIGNED(currentPrivilege) < unsigned(lowestAllowedPrivilege) THEN
            readPermitted  <= '0';
            writePermitted <= '0';
        ELSE
            readPermitted  <= '1';
            writePermitted <= '0' WHEN rwPerm = PERM_RO_C ELSE
                '1';
        END IF;

        -- illegal access if perms are not correct or unknown csr
        illegalAccess <= (writeRequested AND NOT writePermitted)
            OR (readRequested AND NOT readPermitted)
            OR ((readRequested OR writeRequested) AND NOT csrMatch);
    END PROCESS;

    PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF reset = '1' THEN
            ELSE
                IF readRequested AND readPermitted AND csrMatch THEN
                    rdData <= csrReg(csrIndex);
                ELSE
                    rdData <= (OTHERS => '0');
                END IF;

                IF writePermitted AND csrMatch THEN
                    CASE op IS
                        WHEN OP_WRITE =>
                            csrReg(csrIndex) <= wrData;
                        WHEN OP_READ_WRITE =>
                            csrReg(csrIndex) <= wrData;
                        WHEN OP_READ_SET =>
                            -- set bits in csr that are set in wrdata
                            csrReg(csrIndex) <= csrReg(csrIndex) OR wrData;
                        WHEN OP_READ_CLEAR =>
                            -- clear bits in csr that are set in wrdata
                            csrReg(csrIndex) <= csrReg(csrIndex) AND NOT wrData;
                        WHEN OTHERS =>
                            NULL;
                    END CASE;
                END IF;
            END IF;
        END IF;
    END PROCESS;
END ARCHITECTURE;