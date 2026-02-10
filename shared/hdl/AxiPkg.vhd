-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: AXI4 Package File
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

LIBRARY surf;
USE surf.StdRtlPkg.ALL;

PACKAGE AxiPkg IS

    CONSTANT AXI_MAX_DATA_WIDTH_C  : POSITIVE := 32; -- Units of bits
    CONSTANT AXI_MAX_WSTRB_WIDTH_C : POSITIVE := (AXI_MAX_DATA_WIDTH_C/8); -- Units of bytes

    -------------------------------------
    -- AXI bus, read master signal record
    -------------------------------------
    TYPE AxiReadMasterType IS RECORD
        -- Read Address channel
        arvalid  : sl; -- Address valid
        araddr   : slv(31 DOWNTO 0); -- Address
        arid     : slv(0 DOWNTO 0); -- Address ID
        arlen    : slv(7 DOWNTO 0); -- Transfer count
        arsize   : slv(2 DOWNTO 0); -- Bytes per transfer
        arburst  : slv(1 DOWNTO 0); -- Burst Type
        arlock   : slv(1 DOWNTO 0); -- Lock control
        arprot   : slv(2 DOWNTO 0); -- Protection control
        arcache  : slv(3 DOWNTO 0); -- Cache control
        arqos    : slv(3 DOWNTO 0); -- QoS value
        arregion : slv(3 DOWNTO 0); -- Region identifier
        -- Read data channel
        rready : sl; -- Master is ready for data
    END RECORD;
    TYPE AxiReadMasterArray IS ARRAY (NATURAL RANGE <>) OF AxiReadMasterType;
    CONSTANT AXI_READ_MASTER_INIT_C : AxiReadMasterType := (
    arvalid => '0',
    araddr => (OTHERS => '0'),
    arid => (OTHERS => '0'),
    arlen => (OTHERS => '0'),
    arsize => (OTHERS => '0'),
    arburst => (OTHERS => '0'),
    arlock => (OTHERS => '0'),
    arprot => (OTHERS => '0'),
    arcache => (OTHERS => '0'),
    arqos => (OTHERS => '0'),
    arregion => (OTHERS => '0'),
    rready  => '0');
    CONSTANT AXI_READ_MASTER_FORCE_C : AxiReadMasterType := (
    arvalid => '0',
    araddr => (OTHERS => '0'),
    arid => (OTHERS => '0'),
    arlen => (OTHERS => '0'),
    arsize => (OTHERS => '0'),
    arburst => (OTHERS => '0'),
    arlock => (OTHERS => '0'),
    arprot => (OTHERS => '0'),
    arcache => (OTHERS => '0'),
    arqos => (OTHERS => '0'),
    arregion => (OTHERS => '0'),
    rready  => '1');

    ------------------------------------
    -- AXI bus, read slave signal record
    ------------------------------------
    TYPE AxiReadSlaveType IS RECORD
        -- Read Address channel
        arready : sl; -- Slave is ready for address
        -- Read data channel
        rdata  : slv(AXI_MAX_DATA_WIDTH_C - 1 DOWNTO 0); -- Read data from slave
        rlast  : sl; -- Read data last strobe
        rvalid : sl; -- Read data is valid
        rid    : slv(0 DOWNTO 0); -- Read ID tag
        rresp  : slv(1 DOWNTO 0); -- Read data result
    END RECORD;
    TYPE AxiReadSlaveArray IS ARRAY (NATURAL RANGE <>) OF AxiReadSlaveType;
    CONSTANT AXI_READ_SLAVE_INIT_C : AxiReadSlaveType := (
    arready => '0',
    rdata => (OTHERS => '0'),
    rlast   => '0',
    rvalid  => '0',
    rid => (OTHERS => '0'),
    rresp => (OTHERS => '0'));
    CONSTANT AXI_READ_SLAVE_FORCE_C : AxiReadSlaveType := (
    arready => '1',
    rdata => (OTHERS => '0'),
    rlast   => '0',
    rvalid  => '0',
    rid => (OTHERS => '0'),
    rresp => (OTHERS => '0'));

    --------------------------------------
    -- AXI bus, write master signal record
    --------------------------------------
    TYPE AxiWriteMasterType IS RECORD
        -- Write address channel
        awvalid  : sl; -- Address valid
        awaddr   : slv(31 DOWNTO 0); -- Address
        awid     : slv(0 DOWNTO 0); -- Address ID
        awlen    : slv(7 DOWNTO 0); -- Transfer count (burst length)
        awsize   : slv(2 DOWNTO 0); -- Bytes per transfer
        awburst  : slv(1 DOWNTO 0); -- Burst Type
        awlock   : slv(1 DOWNTO 0); -- Lock control
        awprot   : slv(2 DOWNTO 0); -- Protection control
        awcache  : slv(3 DOWNTO 0); -- Cache control
        awqos    : slv(3 DOWNTO 0); -- QoS value
        awregion : slv(3 DOWNTO 0); -- Region identifier
        -- Write data channel
        wdata  : slv(AXI_MAX_DATA_WIDTH_C - 1 DOWNTO 0); -- Write data
        wlast  : sl; -- Write data is last
        wvalid : sl; -- Write data is valid
        wid    : slv(0 DOWNTO 0); -- Write ID tag
        wstrb  : slv(AXI_MAX_WSTRB_WIDTH_C - 1 DOWNTO 0); -- Write enable strobes, 1 per byte
        -- Write ack channel
        bready : sl; -- Write master is ready for status
    END RECORD;
    TYPE AxiWriteMasterArray IS ARRAY (NATURAL RANGE <>) OF AxiWriteMasterType;
    CONSTANT AXI_WRITE_MASTER_INIT_C : AxiWriteMasterType := (
    awvalid => '0',
    awaddr => (OTHERS => '0'),
    awid => (OTHERS => '0'),
    awlen => (OTHERS => '0'),
    awsize => (OTHERS => '0'),
    awburst => (OTHERS => '0'),
    awlock => (OTHERS => '0'),
    awprot => (OTHERS => '0'),
    awcache => (OTHERS => '0'),
    awqos => (OTHERS => '0'),
    awregion => (OTHERS => '0'),
    wdata => (OTHERS => '0'),
    wlast   => '0',
    wvalid  => '0',
    wid => (OTHERS => '0'),
    wstrb => (OTHERS => '0'),
    bready  => '0');
    CONSTANT AXI_WRITE_MASTER_FORCE_C : AxiWriteMasterType := (
    awvalid => '0',
    awaddr => (OTHERS => '0'),
    awid => (OTHERS => '0'),
    awlen => (OTHERS => '0'),
    awsize => (OTHERS => '0'),
    awburst => (OTHERS => '0'),
    awlock => (OTHERS => '0'),
    awprot => (OTHERS => '0'),
    awcache => (OTHERS => '0'),
    awqos => (OTHERS => '0'),
    awregion => (OTHERS => '0'),
    wdata => (OTHERS => '0'),
    wlast   => '0',
    wvalid  => '0',
    wid => (OTHERS => '0'),
    wstrb => (OTHERS => '0'),
    bready  => '1');

    -------------------------------------
    -- AXI bus, write slave signal record
    -------------------------------------
    TYPE AxiWriteSlaveType IS RECORD
        -- Write address channel
        awready : sl; -- Write slave is ready for address
        -- Write data channel
        wready : sl; -- Write slave is ready for data
        -- Write ack channel
        bresp  : slv(1 DOWNTO 0); -- Write access status
        bvalid : sl; -- Write status valid
        bid    : slv(0 DOWNTO 0); -- Channel ID
    END RECORD;
    TYPE AxiWriteSlaveArray IS ARRAY (NATURAL RANGE <>) OF AxiWriteSlaveType;
    CONSTANT AXI_WRITE_SLAVE_INIT_C : AxiWriteSlaveType := (
    awready => '0',
    wready  => '0',
    bresp => (OTHERS => '0'),
    bvalid  => '0',
    bid => (OTHERS => '0'));
    CONSTANT AXI_WRITE_SLAVE_FORCE_C : AxiWriteSlaveType := (
    awready => '1',
    wready  => '1',
    bresp => (OTHERS => '0'),
    bvalid  => '0',
    bid => (OTHERS => '0'));

    ------------------------
    -- AXI bus, fifo control
    ------------------------
    TYPE AxiCtrlType IS RECORD
        pause    : sl;
        overflow : sl;
    END RECORD AxiCtrlType;
    TYPE AxiCtrlArray IS ARRAY (NATURAL RANGE <>) OF AxiCtrlType;
    CONSTANT AXI_CTRL_INIT_C : AxiCtrlType := (
    pause    => '1',
    overflow => '0');
    CONSTANT AXI_CTRL_UNUSED_C : AxiCtrlType := (
    pause    => '0',
    overflow => '0');

    ------------------------
    -- AXI bus configuration
    ------------------------
    TYPE AxiConfigType IS RECORD
        ADDR_WIDTH_C : POSITIVE RANGE 12 TO 64;
        DATA_BYTES_C : POSITIVE RANGE 1 TO AXI_MAX_WSTRB_WIDTH_C;
        ID_BITS_C    : POSITIVE RANGE 1 TO 32;
        LEN_BITS_C   : NATURAL RANGE 0 TO 8;
    END RECORD AxiConfigType;

    FUNCTION axiConfig (
        CONSTANT ADDR_WIDTH_C : IN POSITIVE RANGE 12 TO 64                   := 32;
        CONSTANT DATA_BYTES_C : IN POSITIVE RANGE 1 TO AXI_MAX_WSTRB_WIDTH_C := 4;
        CONSTANT ID_BITS_C    : IN POSITIVE RANGE 1 TO 32                    := 12;
        CONSTANT LEN_BITS_C   : IN NATURAL RANGE 0 TO 8                      := 4
    ) RETURN AxiConfigType;

    CONSTANT AXI_CONFIG_INIT_C : AxiConfigType := axiConfig(
    ADDR_WIDTH_C => 32,
    DATA_BYTES_C => 4,
    ID_BITS_C    => 12,
    LEN_BITS_C   => 4);

    FUNCTION axiWriteMasterInit (
        CONSTANT AXI_CONFIG_C : IN AxiConfigType;
        bready                : IN sl              := '0';
        CONSTANT AXI_BURST_C  : IN slv(1 DOWNTO 0) := "01";
        CONSTANT AXI_CACHE_C  : IN slv(3 DOWNTO 0) := "1111"
    ) RETURN AxiWriteMasterType;

    FUNCTION axiReadMasterInit (
        CONSTANT AXI_CONFIG_C : IN AxiConfigType;
        CONSTANT AXI_BURST_C  : IN slv(1 DOWNTO 0) := "01";
        CONSTANT AXI_CACHE_C  : IN slv(3 DOWNTO 0) := "1111"
    ) RETURN AxiReadMasterType;

    FUNCTION ite(i : BOOLEAN; t : AxiConfigType; e : AxiConfigType) RETURN AxiConfigType;

    -- Calculate number of txns in a burst based on number of bytes and bus configuration
    -- Returned value is number of txns-1, so can be assigned to AWLEN/ARLEN
    FUNCTION getAxiLen (
        axiConfig  : AxiConfigType;
        burstBytes : INTEGER RANGE 1 TO 4096 := 4096
    ) RETURN slv;

    -- Calculate number of txns in a burst based upon burst size, total remaining bytes,
    -- current address and bus configuration.
    -- Address is used to set a transaction size aligned to 4k boundaries
    -- Returned value is number of txns-1, so can be assigned to AWLEN/ARLEN
    FUNCTION getAxiLen (
        axiConfig  : AxiConfigType;
        burstBytes : INTEGER RANGE 1 TO 4096 := 4096;
        totalBytes : slv;
        address    : slv
    ) RETURN slv;

    TYPE AxiLenType IS RECORD
        valid : slv(1 DOWNTO 0);
        max   : NATURAL; -- valid(0)
        req   : NATURAL; -- valid(0)
        value : slv(7 DOWNTO 0); -- valid(1)
    END RECORD AxiLenType;
    CONSTANT AXI_LEN_INIT_C : AxiLenType := (
    valid => "00",
    value => (OTHERS => '0'),
    max   => 1,
    req   => 1);
    PROCEDURE getAxiLenProc (
        -- Input
        axiConfig  : IN AxiConfigType;
        burstBytes : IN INTEGER RANGE 1 TO 4096 := 4096;
        totalBytes : IN slv;
        address    : IN slv;
        -- Pipelined signals
        r : IN AxiLenType;
        v : INOUT AxiLenType);

    -- Calculate the byte count for a read request
    FUNCTION getAxiReadBytes (
        axiConfig : AxiConfigType;
        axiRead   : AxiReadMasterType
    ) RETURN slv;

END PACKAGE AxiPkg;

PACKAGE BODY AxiPkg IS

    FUNCTION axiConfig (
        CONSTANT ADDR_WIDTH_C : IN POSITIVE RANGE 12 TO 64                   := 32;
        CONSTANT DATA_BYTES_C : IN POSITIVE RANGE 1 TO AXI_MAX_WSTRB_WIDTH_C := 4;
        CONSTANT ID_BITS_C    : IN POSITIVE RANGE 1 TO 32                    := 12;
        CONSTANT LEN_BITS_C   : IN NATURAL RANGE 0 TO 8                      := 4)
        RETURN AxiConfigType IS
        VARIABLE ret : AxiConfigType;
    BEGIN
        ret := (
            ADDR_WIDTH_C => ADDR_WIDTH_C,
            DATA_BYTES_C => DATA_BYTES_C,
            ID_BITS_C    => ID_BITS_C,
            LEN_BITS_C   => LEN_BITS_C);
        RETURN ret;
    END FUNCTION axiConfig;

    FUNCTION axiWriteMasterInit (
        CONSTANT AXI_CONFIG_C : IN AxiConfigType;
        bready                : IN sl              := '0';
        CONSTANT AXI_BURST_C  : IN slv(1 DOWNTO 0) := "01";
        CONSTANT AXI_CACHE_C  : IN slv(3 DOWNTO 0) := "1111")
        RETURN AxiWriteMasterType IS
        VARIABLE ret : AxiWriteMasterType;
    BEGIN
        ret         := AXI_WRITE_MASTER_INIT_C;
        ret.awsize  := toSlv(log2(AXI_CONFIG_C.DATA_BYTES_C), 3);
        ret.awlen   := getAxiLen(AXI_CONFIG_C, 4096);
        ret.bready  := bready;
        ret.awburst := AXI_BURST_C;
        ret.awcache := AXI_CACHE_C;
        RETURN ret;
    END FUNCTION axiWriteMasterInit;

    FUNCTION axiReadMasterInit (
        CONSTANT AXI_CONFIG_C : IN AxiConfigType;
        CONSTANT AXI_BURST_C  : IN slv(1 DOWNTO 0) := "01";
        CONSTANT AXI_CACHE_C  : IN slv(3 DOWNTO 0) := "1111")
        RETURN AxiReadMasterType IS
        VARIABLE ret : AxiReadMasterType;
    BEGIN
        ret         := AXI_READ_MASTER_INIT_C;
        ret.arsize  := toSlv(log2(AXI_CONFIG_C.DATA_BYTES_C), 3);
        ret.arlen   := getAxiLen(AXI_CONFIG_C, 4096);
        ret.arburst := AXI_BURST_C;
        ret.arcache := AXI_CACHE_C;
        RETURN ret;
    END FUNCTION axiReadMasterInit;

    FUNCTION ite (i : BOOLEAN; t : AxiConfigType; e : AxiConfigType) RETURN AxiConfigType IS
    BEGIN
        IF (i) THEN
            RETURN t;
        ELSE
            RETURN e;
        END IF;
    END FUNCTION ite;

    FUNCTION getAxiLen (
        axiConfig  : AxiConfigType;
        burstBytes : INTEGER RANGE 1 TO 4096 := 4096)
        RETURN slv IS
    BEGIN
        -- burstBytes / data bytes width is number of txns required.
        -- Subtract by 1 for A*LEN value for even divides.
        -- Convert to SLV and truncate to size of A*LEN port for this AXI bus
        -- This limits number of txns appropriately based on size of len port
        -- Then resize to 8 bits because our records define A*LEN as 8 bits always.
        RETURN resize(toSlv(wordCount(burstBytes, axiConfig.DATA_BYTES_C) - 1, axiConfig.LEN_BITS_C), 8);
    END FUNCTION getAxiLen;

    -- Calculate number of txns in a burst based upon burst size, total remaining bytes,
    -- current address and bus configuration.
    -- Address is used to set a transaction size aligned to 4k boundaries
    -- Returned value is number of txns-1, so can be assigned to AWLEN/ARLEN
    FUNCTION getAxiLen (
        axiConfig  : AxiConfigType;
        burstBytes : INTEGER RANGE 1 TO 4096 := 4096;
        totalBytes : slv;
        address    : slv)
        RETURN slv IS
        VARIABLE max : NATURAL;
        VARIABLE req : NATURAL;
        VARIABLE min : NATURAL;

    BEGIN

        -- Check for 4kB boundary
        max := 4096 - conv_integer(unsigned(address(11 DOWNTO 0)));

        IF (totalBytes < burstBytes) THEN
            req := conv_integer(totalBytes);
        ELSE
            req := burstBytes;
        END IF;

        min := minimum(req, max);

        -- Return the AXI Length value
        RETURN getAxiLen(axiConfig, min);

    END FUNCTION getAxiLen;

    -- getAxiLenProc is functionally the same as getAxiLen()
    -- but breaks apart the two comparator operations in getAxiLen()
    -- into two separate clock cycles (instead of one), which helps
    -- with meeting timing by breaking apart this long combinatorial chain
    PROCEDURE getAxiLenProc (
        -- Input
        axiConfig  : IN AxiConfigType;
        burstBytes : IN INTEGER RANGE 1 TO 4096 := 4096;
        totalBytes : IN slv;
        address    : IN slv;
        -- Pipelined signals
        r            : IN AxiLenType;
        v            : INOUT AxiLenType) IS
        VARIABLE min : NATURAL;
    BEGIN

        --------------------
        -- First Clock cycle
        --------------------

        -- Update valid flag for max/req
        v.valid(0) := '1';

        -- Check for 4kB boundary
        v.max := 4096 - conv_integer(unsigned(address(11 DOWNTO 0)));

        IF (totalBytes < burstBytes) THEN
            v.req := conv_integer(totalBytes);
        ELSE
            v.req := burstBytes;
        END IF;

        ---------------------
        -- Second Clock cycle
        ---------------------

        -- Update valid flag for value
        v.valid(1) := r.valid(0);

        min := minimum(r.req, r.max);

        -- Return the AXI Length value
        v.value := getAxiLen(axiConfig, min);

    END PROCEDURE;

    -- Calculate the byte count for a read request
    FUNCTION getAxiReadBytes (
        axiConfig : AxiConfigType;
        axiRead   : AxiReadMasterType)
        RETURN slv IS
        CONSTANT addrLsb : NATURAL := bitSize(AxiConfig.DATA_BYTES_C - 1);
        VARIABLE tempSlv : slv(AxiConfig.LEN_BITS_C + addrLsb DOWNTO 0);
    BEGIN
        tempSlv := (OTHERS => '0');

        IF (AxiConfig.DATA_BYTES_C > 1) THEN

            tempSlv(AxiConfig.LEN_BITS_C + addrLsb DOWNTO addrLsb)
            := axiRead.arlen(AxiConfig.LEN_BITS_C - 1 DOWNTO 0) + toSlv(1, AxiConfig.LEN_BITS_C + 1);

            tempSlv := tempSlv - axiRead.araddr(addrLsb - 1 DOWNTO 0);

        ELSE

            tempSlv(AxiConfig.LEN_BITS_C DOWNTO 0) := axiRead.arlen(AxiConfig.LEN_BITS_C - 1 DOWNTO 0) + toSlv(1, AxiConfig.LEN_BITS_C + 1);

        END IF;

        RETURN(tempSlv);
    END FUNCTION getAxiReadBytes;

END PACKAGE BODY AxiPkg;
