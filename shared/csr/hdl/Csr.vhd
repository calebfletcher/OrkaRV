-- High-level CSR Entity
--
-- Handles permissions checking and delegates the actual CSR logic an
-- instantiated peakrdl-regblock register implementation.

library ieee;
context ieee.ieee_std_context;

use work.RiscVPkg.all;
use work.CsrPkg.all;

entity Csr is
  generic (
    XLEN : integer := XLEN
  );
  port (
    clk   : in std_logic;
    reset : in std_logic;

    currentPrivilege : in Privilege;

    op     : in CsrOp;
    addr   : in std_logic_vector(11 downto 0);
    wrData : in std_logic_vector(XLEN - 1 downto 0);
    rdData : out std_logic_vector(XLEN - 1 downto 0) := (others => '0');
    -- set high if the access was not permitted
    illegalAccess : out std_logic := '0'
  );
end entity Csr;

architecture rtl of Csr is
  subtype PERMISSIONS is std_logic_vector(1 downto 0);
  constant PERM_RO_C : PERMISSIONS := "11";

  -- permissions
  signal rwPerm                 : std_logic_vector(1 downto 0);
  signal lowestAllowedPrivilege : std_logic_vector(1 downto 0);
  signal readPermitted          : std_logic;
  signal writePermitted         : std_logic;

  signal readRequested  : std_logic;
  signal writeRequested : std_logic;

  type STATE is (IDLE, READ_REQ, READ_ACK, WRITE_REQ, WRITE_ACK);

begin
  -- op decode
  process (all)
  begin
    readRequested <= '1' when op = OP_READ or op = OP_READ_WRITE or op = OP_READ_SET or op = OP_READ_CLEAR else
      '0';
    writeRequested <= '1' when op = OP_WRITE or op = OP_READ_WRITE or op = OP_READ_SET or op = OP_READ_CLEAR else
      '0';
  end process;

  -- permissions checks
  process (all)
  begin
    rwPerm                 <= addr(11 downto 10);
    lowestAllowedPrivilege <= addr(9 downto 8);
    if UNSIGNED(currentPrivilege) < unsigned(lowestAllowedPrivilege) then
      readPermitted  <= '0';
      writePermitted <= '0';
    else
      readPermitted  <= '1';
      writePermitted <= '0' when rwPerm = PERM_RO_C else
        '1';
    end if;

    -- illegal access if perms are not correct or unknown csr
    illegalAccess <= (writeRequested and not writePermitted)
      or (readRequested and not readPermitted);
    --OR ((readRequested OR writeRequested) AND NOT csrMatch);
  end process;

  -- PROCESS (clk)
  -- BEGIN
  --     IF rising_edge(clk) THEN
  --         IF reset = '1' THEN
  --             csrReg <= INIT_TABLE_C;
  --         ELSE
  --             IF readRequested AND readPermitted AND csrMatch THEN
  --                 rdData <= csrReg(csrIndex);
  --             ELSE
  --                 rdData <= (OTHERS => '0');
  --             END IF;

  --             IF writePermitted AND csrMatch THEN
  --                 CASE op IS
  --                     WHEN OP_WRITE =>
  --                         csrReg(csrIndex) <= wrData;
  --                     WHEN OP_READ_WRITE =>
  --                         csrReg(csrIndex) <= wrData;
  --                     WHEN OP_READ_SET =>
  --                         -- set bits in csr that are set in wrdata
  --                         csrReg(csrIndex) <= csrReg(csrIndex) OR wrData;
  --                     WHEN OP_READ_CLEAR =>
  --                         -- clear bits in csr that are set in wrdata
  --                         csrReg(csrIndex) <= csrReg(csrIndex) AND NOT wrData;
  --                     WHEN OTHERS =>
  --                         NULL;
  --                 END CASE;
  --             END IF;
  --         END IF;
  --     END IF;
  -- END PROCESS;
end architecture;