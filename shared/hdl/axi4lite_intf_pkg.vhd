LIBRARY ieee;
CONTEXT ieee.ieee_std_context;

PACKAGE axi4lite_intf_pkg IS

    TYPE axi4lite_slave_in_intf IS RECORD
        AWVALID : STD_LOGIC;
        AWADDR  : STD_LOGIC_VECTOR;
        AWPROT  : STD_LOGIC_VECTOR(2 DOWNTO 0);

        WVALID : STD_LOGIC;
        WDATA  : STD_LOGIC_VECTOR;
        WSTRB  : STD_LOGIC_VECTOR;

        BREADY : STD_LOGIC;

        ARVALID : STD_LOGIC;
        ARADDR  : STD_LOGIC_VECTOR;
        ARPROT  : STD_LOGIC_VECTOR(2 DOWNTO 0);

        RREADY : STD_LOGIC;
    END RECORD axi4lite_slave_in_intf;

    TYPE axi4lite_slave_out_intf IS RECORD
        AWREADY : STD_LOGIC;

        WREADY : STD_LOGIC;

        BVALID : STD_LOGIC;
        BRESP  : STD_LOGIC_VECTOR(1 DOWNTO 0);

        ARREADY : STD_LOGIC;

        RVALID : STD_LOGIC;
        RDATA  : STD_LOGIC_VECTOR;
        RRESP  : STD_LOGIC_VECTOR(1 DOWNTO 0);
    END RECORD axi4lite_slave_out_intf;

END PACKAGE axi4lite_intf_pkg;

-- package body axi4lite_intf_pkg is
-- end package body axi4lite_intf_pkg;