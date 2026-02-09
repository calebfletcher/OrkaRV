-- High-level CSR Entity
--
-- Handles permissions checking and delegates the actual CSR logic an
-- instantiated peakrdl-regblock register implementation.

LIBRARY ieee;
CONTEXT ieee.ieee_std_context;

USE work.RiscVPkg.ALL;
USE work.csrif_pkg.ALL;
USE work.CsrRegisters_pkg.ALL;

ENTITY Csr IS
    GENERIC (
        XLEN : INTEGER := XLEN
    );
    PORT (
        clk   : IN STD_LOGIC;
        reset : IN STD_LOGIC;

        currentPrivilege : IN Privilege;

        req     : IN STD_LOGIC;
        op      : IN csr_access_op;
        addr    : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
        wrData  : IN STD_LOGIC_VECTOR(XLEN - 1 DOWNTO 0);
        rdData  : OUT STD_LOGIC_VECTOR(XLEN - 1 DOWNTO 0);
        rdValid : OUT STD_LOGIC;
        -- set high if the access was not permitted
        illegalAccess : OUT STD_LOGIC := '0';

        hwif_in  : IN CsrRegisters_in_t;
        hwif_out : OUT CsrRegisters_out_t
    );
END ENTITY Csr;

ARCHITECTURE rtl OF Csr IS
    SUBTYPE PERMISSIONS IS STD_LOGIC_VECTOR(1 DOWNTO 0);
    CONSTANT PERM_RO_C : PERMISSIONS := "11";

    -- permissions
    SIGNAL rwPerm                 : STD_LOGIC_VECTOR(1 DOWNTO 0);
    SIGNAL lowestAllowedPrivilege : STD_LOGIC_VECTOR(1 DOWNTO 0);
    SIGNAL readPermitted          : STD_LOGIC;
    SIGNAL writePermitted         : STD_LOGIC;

    SIGNAL readRequested  : STD_LOGIC;
    SIGNAL writeRequested : STD_LOGIC;
    SIGNAL invalidRequest : STD_LOGIC;

    SIGNAL cpuif_req          : STD_LOGIC;
    SIGNAL cpuif_req_op       : csr_access_op;
    SIGNAL cpuif_addr         : STD_LOGIC_VECTOR(13 DOWNTO 0);
    SIGNAL cpuif_wr_data      : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL cpuif_wr_biten     : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL cpuif_req_stall_wr : STD_LOGIC;
    SIGNAL cpuif_req_stall_rd : STD_LOGIC;
    SIGNAL cpuif_rd_ack       : STD_LOGIC;
    SIGNAL cpuif_rd_err       : STD_LOGIC;
    SIGNAL cpuif_rd_data      : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL cpuif_wr_ack       : STD_LOGIC;
    SIGNAL cpuif_wr_err       : STD_LOGIC;
BEGIN
    -- op decode
    PROCESS (ALL)
    BEGIN
        readRequested <= '1' WHEN req = '1' AND op /= OP_WRITE ELSE
            '0';
        writeRequested <= '1' WHEN req = '1' AND op /= OP_READ ELSE
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

        -- illegal access if perms are not correct
        invalidRequest <= (writeRequested AND NOT writePermitted)
            OR (readRequested AND NOT readPermitted);

        cpuif_addr     <= addr & "00";
        cpuif_req      <= req AND NOT invalidRequest;
        cpuif_req_op   <= op;
        cpuif_wr_data  <= wrData;
        cpuif_wr_biten <= (OTHERS => '1');
        rdData         <= cpuif_rd_data;
        rdValid        <= cpuif_rd_ack;
        -- todo: probably need to register invalidRequest to align this
        illegalAccess <= invalidRequest OR cpuif_rd_err OR cpuif_wr_err;

    END PROCESS;

    CsrRegisters_inst : ENTITY work.CsrRegisters
        PORT MAP
        (
            clk                  => clk,
            rst                  => reset,
            s_cpuif_req          => cpuif_req,
            s_cpuif_req_op       => cpuif_req_op,
            s_cpuif_addr         => cpuif_addr,
            s_cpuif_wr_data      => cpuif_wr_data,
            s_cpuif_wr_biten     => cpuif_wr_biten,
            s_cpuif_req_stall_wr => cpuif_req_stall_wr,
            s_cpuif_req_stall_rd => cpuif_req_stall_rd,
            s_cpuif_rd_ack       => cpuif_rd_ack,
            s_cpuif_rd_err       => cpuif_rd_err,
            s_cpuif_rd_data      => cpuif_rd_data,
            s_cpuif_wr_ack       => cpuif_wr_ack,
            s_cpuif_wr_err       => cpuif_wr_err,
            hwif_in              => hwif_in,
            hwif_out             => hwif_out
        );
END ARCHITECTURE;