LIBRARY ieee;
CONTEXT ieee.ieee_std_context;

LIBRARY surf;
USE surf.AxiLitePkg.ALL;

USE work.axi4lite_intf_pkg.ALL;

ENTITY AxiLitePeakRdlBridge IS
    GENERIC (
        CONSTANT ADDR_BITS_G : POSITIVE := 16
    );
    PORT (
        -- surf interface
        axilWriteMaster : IN AxiLiteWriteMasterType;
        axilWriteSlave : OUT AxiLiteWriteSlaveType;
        axilReadMaster : IN AxiLiteReadMasterType;
        axilReadSlave : OUT AxiLiteReadSlaveType;

        -- peakrdl interface
        -- unconstrained address width
        s_axil_i : OUT axi4lite_slave_in_intf(
        AWADDR(ADDR_BITS_G - 1 DOWNTO 0),
        WDATA(31 DOWNTO 0),
        WSTRB(3 DOWNTO 0),
        ARADDR(ADDR_BITS_G - 1 DOWNTO 0)
        );
        s_axil_o : IN axi4lite_slave_out_intf(
        RDATA(31 DOWNTO 0)
        )
    );
END ENTITY AxiLitePeakRdlBridge;

ARCHITECTURE rtl OF AxiLitePeakRdlBridge IS

BEGIN
    s_axil_i.AWVALID <= axilWriteMaster.awvalid;
    s_axil_i.AWADDR <= axilWriteMaster.awaddr(s_axil_i.AWADDR'RANGE);
    s_axil_i.AWPROT <= axilWriteMaster.awprot;
    s_axil_i.WVALID <= axilWriteMaster.wvalid;
    s_axil_i.WDATA <= axilWriteMaster.wdata;
    s_axil_i.WSTRB <= axilWriteMaster.wstrb;
    s_axil_i.BREADY <= axilWriteMaster.bready;
    s_axil_i.ARVALID <= axilReadMaster.arvalid;
    s_axil_i.ARADDR <= axilReadMaster.araddr(s_axil_i.ARADDR'RANGE);
    s_axil_i.ARPROT <= axilReadMaster.arprot;
    s_axil_i.RREADY <= axilReadMaster.rready;

    axilReadSlave.arready <= s_axil_o.ARREADY;
    axilReadSlave.rdata <= s_axil_o.RDATA;
    axilReadSlave.rresp <= s_axil_o.RRESP;
    axilReadSlave.rvalid <= s_axil_o.RVALID;

    axilWriteSlave.awready <= s_axil_o.AWREADY;
    axilWriteSlave.wready <= s_axil_o.WREADY;
    axilWriteSlave.bresp <= s_axil_o.BRESP;
    axilWriteSlave.bvalid <= s_axil_o.BVALID;

END ARCHITECTURE;