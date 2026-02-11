-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: AXI4-to-AXI-Lite bridge
--
-- Note: This module only supports 32-bit aligned addresses and 32-bit transactions.
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
USE ieee.std_logic_unsigned.ALL;
USE ieee.std_logic_arith.ALL;

USE work.AxiPkg.ALL;

LIBRARY surf;
USE surf.StdRtlPkg.ALL;
USE surf.AxiLitePkg.ALL;

ENTITY AxiToAxiLite IS
    GENERIC (
        TPD_G           : TIME    := 1 ns;
        RST_POLARITY_G  : sl      := '1'; -- '1' for active HIGH reset, '0' for active LOW reset
        RST_ASYNC_G     : BOOLEAN := false;
        EN_SLAVE_RESP_G : BOOLEAN := true);
    PORT (
        -- Clocks & Reset
        axiClk    : IN sl;
        axiClkRst : IN sl;
        -- AXI Slave
        axiReadMaster  : IN AxiReadMasterType;
        axiReadSlave   : OUT AxiReadSlaveType;
        axiWriteMaster : IN AxiWriteMasterType;
        axiWriteSlave  : OUT AxiWriteSlaveType;
        -- AXI Lite
        axilReadMaster  : OUT AxiLiteReadMasterType;
        axilReadSlave   : IN AxiLiteReadSlaveType;
        axilWriteMaster : OUT AxiLiteWriteMasterType;
        axilWriteSlave  : IN AxiLiteWriteSlaveType);
END AxiToAxiLite;

ARCHITECTURE mapping OF AxiToAxiLite IS

BEGIN

    axilWriteMaster.awaddr  <= axiWriteMaster.awaddr(31 DOWNTO 0);
    axilWriteMaster.awprot  <= axiWriteMaster.awprot;
    axilWriteMaster.awvalid <= axiWriteMaster.awvalid;
    axilWriteMaster.wvalid  <= axiWriteMaster.wvalid;
    axilWriteMaster.bready  <= axiWriteMaster.bready;

    axiWriteSlave.awready <= axilWriteSlave.awready;
    axiWriteSlave.bresp   <= axilWriteSlave.bresp WHEN(EN_SLAVE_RESP_G) ELSE
    AXI_RESP_OK_C;
    axiWriteSlave.bvalid <= axilWriteSlave.bvalid;
    axiWriteSlave.wready <= axilWriteSlave.wready;

    axilReadMaster.araddr  <= axiReadMaster.araddr(31 DOWNTO 0);
    axilReadMaster.arprot  <= axiReadMaster.arprot;
    axilReadMaster.arvalid <= axiReadMaster.arvalid;
    axilReadMaster.rready  <= axiReadMaster.rready;

    axiReadSlave.arready <= axilReadSlave.arready;
    axiReadSlave.rresp   <= axilReadSlave.rresp WHEN(EN_SLAVE_RESP_G) ELSE
    AXI_RESP_OK_C;
    axiReadSlave.rlast  <= '1';
    axiReadSlave.rvalid <= axilReadSlave.rvalid;

    --
    -- Collapse Axi wdata onto 32-bit AxiLite wdata
    --   Assumes only active 32 bits are asserted,
    --     otherwise could use wstrb to pick correct 32 bits
    --
    PROCESS (axiWriteMaster)
        VARIABLE i     : NATURAL;
        VARIABLE byte  : NATURAL;
        VARIABLE wdata : slv(31 DOWNTO 0);
    BEGIN
        wdata := (OTHERS => '0');
        FOR i IN 0 TO AXI_MAX_WSTRB_WIDTH_C - 1 LOOP
            byte := (8 * i) MOD 32;
            IF axiWriteMaster.wstrb(i) = '1' THEN
                wdata(byte + 7 DOWNTO byte) := wdata(byte + 7 DOWNTO byte) OR axiWriteMaster.wdata(8 * i + 7 DOWNTO 8 * i);
            END IF;
        END LOOP;
        axilWriteMaster.wdata <= wdata;
        axilWriteMaster.wstrb <= x"F";
    END PROCESS;

    PROCESS (axilReadSlave)
        VARIABLE i     : INTEGER;
        VARIABLE rdata : slv(AXI_MAX_DATA_WIDTH_C - 1 DOWNTO 0);
    BEGIN
        -- Copy the responds read bus bus to all word boundaries
        FOR i IN 0 TO (AXI_MAX_WSTRB_WIDTH_C/4) - 1 LOOP
            rdata((32 * i) + 31 DOWNTO (32 * i)) := axilReadSlave.rdata;
        END LOOP;
        -- Return the value to the output
        axiReadSlave.rdata <= rdata;
    END PROCESS;

    -- ID Tracking
    PROCESS (axiClk, axiClkRst)
    BEGIN
        IF (RST_ASYNC_G AND axiClkRst = RST_POLARITY_G) THEN
            axiReadSlave.rid  <= (OTHERS => '0') AFTER TPD_G;
            axiWriteSlave.bid <= (OTHERS => '0') AFTER TPD_G;
        ELSIF rising_edge(axiClk) THEN
            IF (RST_ASYNC_G = false AND axiClkRst = RST_POLARITY_G) THEN
                axiReadSlave.rid  <= (OTHERS => '0') AFTER TPD_G;
                axiWriteSlave.bid <= (OTHERS => '0') AFTER TPD_G;
            ELSE
                IF axiReadMaster.arvalid = '1' AND axilReadSlave.arready = '1' THEN
                    axiReadSlave.rid <= axiReadMaster.arid AFTER TPD_G;
                END IF;
                IF axiWriteMaster.awvalid = '1' AND axilWriteSlave.awready = '1' THEN
                    axiWriteSlave.bid <= axiWriteMaster.awid AFTER TPD_G;
                END IF;
            END IF;
        END IF;
    END PROCESS;

END ARCHITECTURE mapping;
