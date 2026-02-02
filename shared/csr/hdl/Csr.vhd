-- High-level CSR Entity
--
-- Handles permissions checking and delegates the actual CSR logic an
-- instantiated peakrdl-regblock register implementation.

library ieee;
context ieee.ieee_std_context;

use work.RiscVPkg.all;
use work.csrif_pkg.all;
use work.CsrRegisters_pkg.all;

entity Csr is
  generic (
    XLEN : integer := XLEN
  );
  port (
    clk   : in std_logic;
    reset : in std_logic;

    currentPrivilege : in Privilege;

    req     : in std_logic;
    op      : in csr_access_op;
    addr    : in std_logic_vector(11 downto 0);
    wrData  : in std_logic_vector(XLEN - 1 downto 0);
    rdData  : out std_logic_vector(XLEN - 1 downto 0);
    rdValid : out std_logic;
    -- set high if the access was not permitted
    illegalAccess : out std_logic := '0';

    hwif_in  : in CsrRegisters_in_t;
    hwif_out : out CsrRegisters_out_t
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
  signal invalidRequest : std_logic;

  signal cpuif_req          : std_logic;
  signal cpuif_req_op       : csr_access_op;
  signal cpuif_addr         : std_logic_vector(13 downto 0);
  signal cpuif_wr_data      : std_logic_vector(31 downto 0);
  signal cpuif_wr_biten     : std_logic_vector(31 downto 0);
  signal cpuif_req_stall_wr : std_logic;
  signal cpuif_req_stall_rd : std_logic;
  signal cpuif_rd_ack       : std_logic;
  signal cpuif_rd_err       : std_logic;
  signal cpuif_rd_data      : std_logic_vector(31 downto 0);
  signal cpuif_wr_ack       : std_logic;
  signal cpuif_wr_err       : std_logic;
begin
  -- op decode
  process (all)
  begin
    readRequested <= '1' when req = '1' and op /= OP_WRITE else
      '0';
    writeRequested <= '1' when req = '1' and op /= OP_READ else
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

    -- illegal access if perms are not correct
    invalidRequest <= (writeRequested and not writePermitted)
      or (readRequested and not readPermitted);

    cpuif_addr     <= (13 downto 2 => addr, others => '0');
    cpuif_req      <= req and not invalidRequest;
    cpuif_req_op   <= op;
    cpuif_wr_data  <= wrData;
    cpuif_wr_biten <= (others => '1');
    rdData         <= cpuif_rd_data;
    rdValid        <= cpuif_rd_ack;
    -- todo: probably need to register invalidRequest to align this
    illegalAccess <= invalidRequest or cpuif_rd_err or cpuif_wr_err;

  end process;

  CsrRegisters_inst : entity work.CsrRegisters
    port map
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
end architecture;