-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Common shim layer between IP Integrator interface and surf AXI interface
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the
-- top-level directory of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'SLAC Firmware Standard Library', including this file,
-- may be copied, modified, propagated, or distributed except according to
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.std_logic_arith.ALL;
USE ieee.std_logic_unsigned.ALL;

USE work.AxiPkg.ALL;

LIBRARY surf;
USE surf.StdRtlPkg.ALL;

ENTITY SlaveAxiIpIntegrator IS
    GENERIC (
        INTERFACENAME         : STRING                  := "S_AXI";
        EN_ERROR_RESP         : BOOLEAN                 := false;
        MAX_BURST_LENGTH      : POSITIVE RANGE 1 TO 256 := 256; -- [1, 256]
        NUM_WRITE_OUTSTANDING : NATURAL RANGE 0 TO 32   := 1; -- [0, 32]
        NUM_READ_OUTSTANDING  : NATURAL RANGE 0 TO 32   := 1; -- [0, 32]
        SUPPORTS_NARROW_BURST : NATURAL RANGE 0 TO 1    := 1;
        --      BUSER_WIDTH           : positive                  := 1;
        --      RUSER_WIDTH           : positive                  := 1;
        --      WUSER_WIDTH           : positive                  := 1;
        --      ARUSER_WIDTH          : positive                  := 1;
        --      AWUSER_WIDTH          : positive                  := 1;
        ADDR_WIDTH : POSITIVE RANGE 1 TO 64    := 32; -- [1, 64]
        ID_WIDTH   : POSITIVE                  := 1;
        DATA_WIDTH : POSITIVE RANGE 32 TO 1024 := 32; -- [32,64,128,256,512,1024]
        HAS_BURST  : NATURAL RANGE 0 TO 1      := 1;
        HAS_CACHE  : NATURAL RANGE 0 TO 1      := 1;
        HAS_LOCK   : NATURAL RANGE 0 TO 1      := 1;
        HAS_PROT   : NATURAL RANGE 0 TO 1      := 1;
        HAS_QOS    : NATURAL RANGE 0 TO 1      := 1;
        HAS_REGION : NATURAL RANGE 0 TO 1      := 1;
        HAS_WSTRB  : NATURAL RANGE 0 TO 1      := 1;
        HAS_BRESP  : NATURAL RANGE 0 TO 1      := 1;
        HAS_RRESP  : NATURAL RANGE 0 TO 1      := 1);
    PORT (
        -- IP Integrator AXI-Lite Interface
        S_AXI_ACLK     : IN STD_LOGIC;
        S_AXI_ARESETN  : IN STD_LOGIC;
        S_AXI_AWID     : IN STD_LOGIC_VECTOR(ID_WIDTH - 1 DOWNTO 0);
        S_AXI_AWADDR   : IN STD_LOGIC_VECTOR(ADDR_WIDTH - 1 DOWNTO 0);
        S_AXI_AWLEN    : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        S_AXI_AWSIZE   : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
        S_AXI_AWBURST  : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        S_AXI_AWLOCK   : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        S_AXI_AWCACHE  : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
        S_AXI_AWPROT   : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
        S_AXI_AWREGION : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
        S_AXI_AWQOS    : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
        --      S_AXI_AWUSER   : in  std_logic_vector(AWUSER_WIDTH-1 downto 0);
        S_AXI_AWVALID : IN STD_LOGIC;
        S_AXI_AWREADY : OUT STD_LOGIC;
        S_AXI_WID     : IN STD_LOGIC_VECTOR(ID_WIDTH - 1 DOWNTO 0);
        S_AXI_WDATA   : IN STD_LOGIC_VECTOR(DATA_WIDTH - 1 DOWNTO 0);
        S_AXI_WSTRB   : IN STD_LOGIC_VECTOR((DATA_WIDTH/8) - 1 DOWNTO 0);
        S_AXI_WLAST   : IN STD_LOGIC;
        --      S_AXI_WUSER    : in  std_logic_vector(WUSER_WIDTH-1 downto 0);
        S_AXI_WVALID : IN STD_LOGIC;
        S_AXI_WREADY : OUT STD_LOGIC;
        S_AXI_BID    : OUT STD_LOGIC_VECTOR(ID_WIDTH - 1 DOWNTO 0);
        S_AXI_BRESP  : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
        --      S_AXI_BUSER    : out std_logic_vector(BUSER_WIDTH downto 0);
        S_AXI_BVALID   : OUT STD_LOGIC;
        S_AXI_BREADY   : IN STD_LOGIC;
        S_AXI_ARID     : IN STD_LOGIC_VECTOR(ID_WIDTH - 1 DOWNTO 0);
        S_AXI_ARADDR   : IN STD_LOGIC_VECTOR(ADDR_WIDTH - 1 DOWNTO 0);
        S_AXI_ARLEN    : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        S_AXI_ARSIZE   : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
        S_AXI_ARBURST  : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        S_AXI_ARLOCK   : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        S_AXI_ARCACHE  : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
        S_AXI_ARPROT   : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
        S_AXI_ARREGION : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
        S_AXI_ARQOS    : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
        --      S_AXI_ARUSER   : in  std_logic_vector(ARUSER_WIDTH-1 downto 0);
        S_AXI_ARVALID : IN STD_LOGIC;
        S_AXI_ARREADY : OUT STD_LOGIC;
        S_AXI_RID     : OUT STD_LOGIC_VECTOR(ID_WIDTH - 1 DOWNTO 0);
        S_AXI_RDATA   : OUT STD_LOGIC_VECTOR(DATA_WIDTH - 1 DOWNTO 0);
        S_AXI_RRESP   : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
        S_AXI_RLAST   : OUT STD_LOGIC;
        --      S_AXI_RUSER    : out std_logic_vector(RUSER_WIDTH-1 downto 0);
        S_AXI_RVALID : OUT STD_LOGIC;
        S_AXI_RREADY : IN STD_LOGIC;
        -- SURF AXI Interface
        axiClk         : OUT sl;
        axiRst         : OUT sl;
        axiReadMaster  : OUT AxiReadMasterType;
        axiReadSlave   : IN AxiReadSlaveType;
        axiWriteMaster : OUT AxiWriteMasterType;
        axiWriteSlave  : IN AxiWriteSlaveType);
END SlaveAxiIpIntegrator;

ARCHITECTURE mapping OF SlaveAxiIpIntegrator IS

    ATTRIBUTE X_INTERFACE_INFO      : STRING;
    ATTRIBUTE X_INTERFACE_PARAMETER : STRING;

    ATTRIBUTE X_INTERFACE_INFO OF S_AXI_AWID     : SIGNAL IS "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " AWID";
    ATTRIBUTE X_INTERFACE_INFO OF S_AXI_AWADDR   : SIGNAL IS "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " AWADDR";
    ATTRIBUTE X_INTERFACE_INFO OF S_AXI_AWLEN    : SIGNAL IS "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " AWLEN";
    ATTRIBUTE X_INTERFACE_INFO OF S_AXI_AWSIZE   : SIGNAL IS "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " AWSIZE";
    ATTRIBUTE X_INTERFACE_INFO OF S_AXI_AWBURST  : SIGNAL IS "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " AWBURST";
    ATTRIBUTE X_INTERFACE_INFO OF S_AXI_AWLOCK   : SIGNAL IS "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " AWLOCK";
    ATTRIBUTE X_INTERFACE_INFO OF S_AXI_AWCACHE  : SIGNAL IS "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " AWCACHE";
    ATTRIBUTE X_INTERFACE_INFO OF S_AXI_AWPROT   : SIGNAL IS "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " AWPROT";
    ATTRIBUTE X_INTERFACE_INFO OF S_AXI_AWREGION : SIGNAL IS "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " AWREGION";
    ATTRIBUTE X_INTERFACE_INFO OF S_AXI_AWQOS    : SIGNAL IS "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " AWQOS";
    --   attribute X_INTERFACE_INFO of S_AXI_AWUSER      : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " AWUSER";
    ATTRIBUTE X_INTERFACE_INFO OF S_AXI_AWVALID : SIGNAL IS "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " AWVALID";
    ATTRIBUTE X_INTERFACE_INFO OF S_AXI_AWREADY : SIGNAL IS "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " AWREADY";
    ATTRIBUTE X_INTERFACE_INFO OF S_AXI_WID     : SIGNAL IS "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " WID";
    ATTRIBUTE X_INTERFACE_INFO OF S_AXI_WDATA   : SIGNAL IS "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " WDATA";
    ATTRIBUTE X_INTERFACE_INFO OF S_AXI_WSTRB   : SIGNAL IS "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " WSTRB";
    ATTRIBUTE X_INTERFACE_INFO OF S_AXI_WLAST   : SIGNAL IS "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " WLAST";
    --   attribute X_INTERFACE_INFO of S_AXI_WUSER       : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " WUSER";
    ATTRIBUTE X_INTERFACE_INFO OF S_AXI_WVALID : SIGNAL IS "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " WVALID";
    ATTRIBUTE X_INTERFACE_INFO OF S_AXI_WREADY : SIGNAL IS "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " WREADY";
    ATTRIBUTE X_INTERFACE_INFO OF S_AXI_BID    : SIGNAL IS "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " BID";
    ATTRIBUTE X_INTERFACE_INFO OF S_AXI_BRESP  : SIGNAL IS "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " BRESP";
    --   attribute X_INTERFACE_INFO of S_AXI_BUSER       : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " BUSER";
    ATTRIBUTE X_INTERFACE_INFO OF S_AXI_BVALID   : SIGNAL IS "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " BVALID";
    ATTRIBUTE X_INTERFACE_INFO OF S_AXI_BREADY   : SIGNAL IS "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " BREADY";
    ATTRIBUTE X_INTERFACE_INFO OF S_AXI_ARID     : SIGNAL IS "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " ARID";
    ATTRIBUTE X_INTERFACE_INFO OF S_AXI_ARADDR   : SIGNAL IS "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " ARADDR";
    ATTRIBUTE X_INTERFACE_INFO OF S_AXI_ARLEN    : SIGNAL IS "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " ARLEN";
    ATTRIBUTE X_INTERFACE_INFO OF S_AXI_ARSIZE   : SIGNAL IS "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " ARSIZE";
    ATTRIBUTE X_INTERFACE_INFO OF S_AXI_ARBURST  : SIGNAL IS "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " ARBURST";
    ATTRIBUTE X_INTERFACE_INFO OF S_AXI_ARLOCK   : SIGNAL IS "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " ARLOCK";
    ATTRIBUTE X_INTERFACE_INFO OF S_AXI_ARCACHE  : SIGNAL IS "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " ARCACHE";
    ATTRIBUTE X_INTERFACE_INFO OF S_AXI_ARPROT   : SIGNAL IS "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " ARPROT";
    ATTRIBUTE X_INTERFACE_INFO OF S_AXI_ARREGION : SIGNAL IS "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " ARREGION";
    ATTRIBUTE X_INTERFACE_INFO OF S_AXI_ARQOS    : SIGNAL IS "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " ARQOS";
    --   attribute X_INTERFACE_INFO of S_AXI_ARUSER      : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " ARUSER";
    ATTRIBUTE X_INTERFACE_INFO OF S_AXI_ARVALID : SIGNAL IS "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " ARVALID";
    ATTRIBUTE X_INTERFACE_INFO OF S_AXI_ARREADY : SIGNAL IS "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " ARREADY";
    ATTRIBUTE X_INTERFACE_INFO OF S_AXI_RID     : SIGNAL IS "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " RID";
    ATTRIBUTE X_INTERFACE_INFO OF S_AXI_RDATA   : SIGNAL IS "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " RDATA";
    ATTRIBUTE X_INTERFACE_INFO OF S_AXI_RRESP   : SIGNAL IS "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " RRESP";
    ATTRIBUTE X_INTERFACE_INFO OF S_AXI_RLAST   : SIGNAL IS "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " RLAST";
    --   attribute X_INTERFACE_INFO of S_AXI_RUSER       : signal is "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " RUSER";
    ATTRIBUTE X_INTERFACE_INFO OF S_AXI_RVALID      : SIGNAL IS "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " RVALID";
    ATTRIBUTE X_INTERFACE_INFO OF S_AXI_RREADY      : SIGNAL IS "xilinx.com:interface:aximm:1.0 " & INTERFACENAME & " RREADY";
    ATTRIBUTE X_INTERFACE_PARAMETER OF S_AXI_AWADDR : SIGNAL IS
    "XIL_INTERFACENAME " & INTERFACENAME & ", " &
    "PROTOCOL AXI4, " &
    "MAX_BURST_LENGTH " & INTEGER'image(MAX_BURST_LENGTH) & ", " &
    "NUM_WRITE_OUTSTANDING " & INTEGER'image(NUM_WRITE_OUTSTANDING) & ", " &
    "NUM_READ_OUTSTANDING " & INTEGER'image(NUM_READ_OUTSTANDING) & ", " &
    "SUPPORTS_NARROW_BURST " & INTEGER'image(SUPPORTS_NARROW_BURST) & ", " &
    --      "BUSER_WIDTH " & integer'image(BUSER_WIDTH) & ", " &
    --      "RUSER_WIDTH " & integer'image(RUSER_WIDTH) & ", " &
    --      "WUSER_WIDTH " & integer'image(WUSER_WIDTH) & ", " &
    --      "ARUSER_WIDTH " & integer'image(ARUSER_WIDTH) & ", " &
    --      "AWUSER_WIDTH " & integer'image(AWUSER_WIDTH) & ", " &
    "ADDR_WIDTH " & INTEGER'image(ADDR_WIDTH) & ", " &
    "ID_WIDTH " & INTEGER'image(ID_WIDTH) & ", " &
    "DATA_WIDTH " & INTEGER'image(DATA_WIDTH) & ", " &
    "HAS_BURST " & INTEGER'image(HAS_BURST) & ", " &
    "HAS_CACHE " & INTEGER'image(HAS_CACHE) & ", " &
    "HAS_LOCK " & INTEGER'image(HAS_LOCK) & ", " &
    "HAS_PROT " & INTEGER'image(HAS_PROT) & ", " &
    "HAS_QOS " & INTEGER'image(HAS_QOS) & ", " &
    "HAS_REGION " & INTEGER'image(HAS_REGION) & ", " &
    "HAS_WSTRB " & INTEGER'image(HAS_WSTRB) & ", " &
    "HAS_BRESP " & INTEGER'image(HAS_BRESP) & ", " &
    "HAS_RRESP " & INTEGER'image(HAS_RRESP);

    ATTRIBUTE X_INTERFACE_INFO OF S_AXI_ARESETN      : SIGNAL IS "xilinx.com:signal:reset:1.0 RST." & INTERFACENAME & "_ARESETN RST";
    ATTRIBUTE X_INTERFACE_PARAMETER OF S_AXI_ARESETN : SIGNAL IS
    "XIL_INTERFACENAME RST." & INTERFACENAME & "_ARESETN, " &
    "POLARITY ACTIVE_LOW";

    ATTRIBUTE X_INTERFACE_INFO OF S_AXI_ACLK      : SIGNAL IS "xilinx.com:signal:clock:1.0 CLK." & INTERFACENAME & "_ACLK CLK";
    ATTRIBUTE X_INTERFACE_PARAMETER OF S_AXI_ACLK : SIGNAL IS
    "XIL_INTERFACENAME CLK." & INTERFACENAME & "_ACLK, " &
    "ASSOCIATED_BUSIF " & INTERFACENAME & ", " &
    "ASSOCIATED_RESET " & INTERFACENAME & "_ARESETN";

    SIGNAL S_AXI_ReadMaster  : AxiReadMasterType  := AXI_READ_MASTER_INIT_C;
    SIGNAL S_AXI_ReadSlave   : AxiReadSlaveType   := AXI_READ_SLAVE_INIT_C;
    SIGNAL S_AXI_WriteMaster : AxiWriteMasterType := AXI_WRITE_MASTER_INIT_C;
    SIGNAL S_AXI_WriteSlave  : AxiWriteSlaveType  := AXI_WRITE_SLAVE_INIT_C;

BEGIN

    axiClk <= S_AXI_ACLK;

    axiReadMaster   <= S_AXI_ReadMaster;
    S_AXI_ReadSlave <= axiReadSlave;

    axiWriteMaster   <= S_AXI_WriteMaster;
    S_AXI_WriteSlave <= axiWriteSlave;

    U_RstSync : ENTITY surf.RstSync
        GENERIC MAP(
            IN_POLARITY_G  => '0',
            OUT_POLARITY_G => '1')
        PORT MAP(
            clk      => S_AXI_ACLK,
            asyncRst => S_AXI_ARESETN,
            syncRst  => axiRst);

    S_AXI_WriteMaster.awid(ID_WIDTH - 1 DOWNTO 0)     <= S_AXI_AWID;
    S_AXI_WriteMaster.awaddr(ADDR_WIDTH - 1 DOWNTO 0) <= S_AXI_AWADDR;
    S_AXI_WriteMaster.awlen(7 DOWNTO 0)               <= S_AXI_AWLEN;
    S_AXI_WriteMaster.awsize(2 DOWNTO 0)              <= S_AXI_AWSIZE;
    S_AXI_WriteMaster.awburst(1 DOWNTO 0)             <= S_AXI_AWBURST;
    S_AXI_WriteMaster.awlock(1 DOWNTO 0)              <= S_AXI_AWLOCK;
    S_AXI_WriteMaster.awcache(3 DOWNTO 0)             <= S_AXI_AWCACHE;
    S_AXI_WriteMaster.awprot                          <= S_AXI_AWPROT;
    S_AXI_WriteMaster.awregion(3 DOWNTO 0)            <= S_AXI_AWREGION;
    S_AXI_WriteMaster.awqos(3 DOWNTO 0)               <= S_AXI_AWQOS;
    --   S_AXI_WriteMaster.awuser(AWUSER_WIDTH-1 downto 0)  <= S_AXI_AWUSER;
    S_AXI_WriteMaster.awvalid                            <= S_AXI_AWVALID;
    S_AXI_WriteMaster.wid(ID_WIDTH - 1 DOWNTO 0)         <= S_AXI_WID;
    S_AXI_WriteMaster.wdata(DATA_WIDTH - 1 DOWNTO 0)     <= S_AXI_WDATA;
    S_AXI_WriteMaster.wstrb((DATA_WIDTH/8) - 1 DOWNTO 0) <= S_AXI_WSTRB WHEN(HAS_WSTRB /= 0) ELSE
    (OTHERS => '1');
    S_AXI_WriteMaster.wlast <= S_AXI_WLAST;
    --   S_AXI_WriteMaster.wuser(WUSER_WIDTH-1 downto 0)    <= S_AXI_WUSER;
    S_AXI_WriteMaster.wvalid <= S_AXI_WVALID;
    S_AXI_WriteMaster.bready <= S_AXI_BREADY;

    S_AXI_AWREADY <= S_AXI_WriteSlave.awready;
    S_AXI_WREADY  <= S_AXI_WriteSlave.wready;
    S_AXI_BID     <= S_AXI_WriteSlave.bid(ID_WIDTH - 1 DOWNTO 0);
    S_AXI_BRESP   <= S_AXI_WriteSlave.bresp WHEN(EN_ERROR_RESP AND (HAS_BRESP /= 0)) ELSE
        "00";
    --   S_AXI_BUSER   <= S_AXI_WriteSlave.buser(BUSER_WIDTH-1 downto 0);
    S_AXI_BVALID <= S_AXI_WriteSlave.bvalid;

    S_AXI_ReadMaster.arid(ID_WIDTH - 1 DOWNTO 0)     <= S_AXI_ARID;
    S_AXI_ReadMaster.araddr(ADDR_WIDTH - 1 DOWNTO 0) <= S_AXI_ARADDR;
    S_AXI_ReadMaster.arlen                           <= S_AXI_ARLEN;
    S_AXI_ReadMaster.arsize                          <= S_AXI_ARSIZE;
    S_AXI_ReadMaster.arburst                         <= S_AXI_ARBURST;
    S_AXI_ReadMaster.arlock                          <= S_AXI_ARLOCK;
    S_AXI_ReadMaster.arcache                         <= S_AXI_ARCACHE;
    S_AXI_ReadMaster.arprot                          <= S_AXI_ARPROT;
    S_AXI_ReadMaster.arregion(3 DOWNTO 0)            <= S_AXI_ARREGION;
    S_AXI_ReadMaster.arqos(3 DOWNTO 0)               <= S_AXI_ARQOS;
    --   S_AXI_ReadMaster.aruser(ARUSER_WIDTH-1 downto 0) <= S_AXI_ARUSER;
    S_AXI_ReadMaster.arvalid <= S_AXI_ARVALID;
    S_AXI_ReadMaster.rready  <= S_AXI_RREADY;

    S_AXI_ARREADY <= S_AXI_ReadSlave.arready;
    S_AXI_RID     <= S_AXI_ReadSlave.rid(ID_WIDTH - 1 DOWNTO 0);
    S_AXI_RDATA   <= S_AXI_ReadSlave.rdata(DATA_WIDTH - 1 DOWNTO 0);
    S_AXI_RRESP   <= S_AXI_ReadSlave.rresp WHEN(EN_ERROR_RESP AND (HAS_RRESP /= 0)) ELSE
        "00";
    S_AXI_RLAST <= S_AXI_ReadSlave.rlast;
    --   S_AXI_RUSER   <= S_AXI_ReadSlave.ruser(RUSER_WIDTH-1 downto 0);
    S_AXI_RVALID <= S_AXI_ReadSlave.rvalid;

END mapping;
