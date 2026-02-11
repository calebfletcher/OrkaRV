-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Wrapper around Xilinx generated Main AXI Crossbar for HPS Front End
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
USE surf.AxiLitePkg.ALL; -- For AXI_RESP_* constants
USE surf.ArbiterPkg.ALL;
USE surf.TextUtilPkg.ALL;

USE work.AxiPkg.ALL;

PACKAGE AxiCrossbarPkg IS
END PACKAGE AxiCrossbarPkg;

PACKAGE BODY AxiCrossbarPkg IS
END PACKAGE BODY;

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.std_logic_arith.ALL;
USE ieee.std_logic_unsigned.ALL;

LIBRARY surf;
USE surf.StdRtlPkg.ALL;
USE surf.AxiLitePkg.ALL; -- For AXI_RESP_* constants
USE surf.ArbiterPkg.ALL;
USE surf.TextUtilPkg.ALL;

USE work.AxiPkg.ALL;
USE work.AxiCrossbarPkg.ALL;

ENTITY AxiCrossbar IS
    GENERIC (
        TPD_G              : TIME                  := 1 ns;
        RST_POLARITY_G     : sl                    := '1'; -- '1' for active HIGH reset, '0' for active LOW reset
        RST_ASYNC_G        : BOOLEAN               := false;
        NUM_SLAVE_SLOTS_G  : NATURAL RANGE 1 TO 16 := 4;
        NUM_MASTER_SLOTS_G : NATURAL RANGE 1 TO 64 := 4;
        DEC_ERROR_RESP_G   : slv(1 DOWNTO 0)       := AXI_RESP_DECERR_C;
        MASTERS_CONFIG_G   : AxiLiteCrossbarMasterConfigArray;
        DEBUG_G            : BOOLEAN := false);
    PORT (
        -- Clock and Reset
        axiClk    : IN sl;
        axiClkRst : IN sl;

        -- Slave Slots (Connect to Axi Masters
        sAxiWriteMasters : IN AxiWriteMasterArray(NUM_SLAVE_SLOTS_G - 1 DOWNTO 0);
        sAxiWriteSlaves  : OUT AxiWriteSlaveArray(NUM_SLAVE_SLOTS_G - 1 DOWNTO 0);
        sAxiReadMasters  : IN AxiReadMasterArray(NUM_SLAVE_SLOTS_G - 1 DOWNTO 0);
        sAxiReadSlaves   : OUT AxiReadSlaveArray(NUM_SLAVE_SLOTS_G - 1 DOWNTO 0);

        -- Master Slots (Connect to AXI Slaves)
        mAxiWriteMasters : OUT AxiWriteMasterArray(NUM_MASTER_SLOTS_G - 1 DOWNTO 0);
        mAxiWriteSlaves  : IN AxiWriteSlaveArray(NUM_MASTER_SLOTS_G - 1 DOWNTO 0);
        mAxiReadMasters  : OUT AxiReadMasterArray(NUM_MASTER_SLOTS_G - 1 DOWNTO 0);
        mAxiReadSlaves   : IN AxiReadSlaveArray(NUM_MASTER_SLOTS_G - 1 DOWNTO 0));
END ENTITY AxiCrossbar;

ARCHITECTURE rtl OF AxiCrossbar IS

    FUNCTION getHighAddr(config : AxiLiteCrossbarMasterConfigType) RETURN slv IS
        VARIABLE result             : slv(31 DOWNTO 0);
    BEGIN
        result := config.baseAddr;
        FOR k IN 0 TO config.addrBits - 1 LOOP
            result(k) := '1';
        END LOOP;
        RETURN result;
    END FUNCTION;

    FUNCTION axiFullWriteMasterInit (CONSTANT config : AxiLiteCrossbarMasterConfigType) RETURN AxiWriteMasterType IS
        VARIABLE ret                                     : AxiWriteMasterType;
    BEGIN
        ret        := AXI_WRITE_MASTER_INIT_C;
        ret.awaddr := config.baseAddr;
        RETURN ret;
    END FUNCTION axiFullWriteMasterInit;

    FUNCTION axiFullWriteMasterInit (CONSTANT config : AxiLiteCrossbarMasterConfigArray) RETURN AxiWriteMasterArray IS
        VARIABLE ret                                     : AxiWriteMasterArray(config'RANGE);
    BEGIN
        FOR i IN config'RANGE LOOP
            ret(i) := axiFullWriteMasterInit(config(i));
        END LOOP;
        RETURN ret;
    END FUNCTION axiFullWriteMasterInit;

    FUNCTION axiFullReadMasterInit (CONSTANT config : AxiLiteCrossbarMasterConfigType) RETURN AxiReadMasterType IS
        VARIABLE ret                                    : AxiReadMasterType;
    BEGIN
        ret        := AXI_READ_MASTER_INIT_C;
        ret.araddr := config.baseAddr;
        RETURN ret;
    END FUNCTION axiFullReadMasterInit;

    FUNCTION axiFullReadMasterInit (CONSTANT config : AxiLiteCrossbarMasterConfigArray) RETURN AxiReadMasterArray IS
        VARIABLE ret                                    : AxiReadMasterArray(config'RANGE);
    BEGIN
        FOR i IN config'RANGE LOOP
            ret(i) := axiFullReadMasterInit(config(i));
        END LOOP;
        RETURN ret;
    END FUNCTION axiFullReadMasterInit;

    TYPE SlaveStateType IS (S_WAIT_AXI_TXN_S, S_DEC_ERR_S, S_ACK_S, S_TXN_S);

    CONSTANT REQ_NUM_SIZE_C : INTEGER := bitSize(NUM_MASTER_SLOTS_G - 1);
    CONSTANT ACK_NUM_SIZE_C : INTEGER := bitSize(NUM_SLAVE_SLOTS_G - 1);

    TYPE SlaveType IS RECORD
        wrState  : SlaveStateType;
        wrReqs   : slv(NUM_MASTER_SLOTS_G - 1 DOWNTO 0);
        wrReqNum : slv(REQ_NUM_SIZE_C - 1 DOWNTO 0);
        rdState  : SlaveStateType;
        rdReqs   : slv(NUM_MASTER_SLOTS_G - 1 DOWNTO 0);
        rdReqNum : slv(REQ_NUM_SIZE_C - 1 DOWNTO 0);
    END RECORD SlaveType;

    TYPE SlaveArray IS ARRAY (NATURAL RANGE <>) OF SlaveType;

    TYPE MasterStateType IS (M_WAIT_REQ_S, M_WAIT_READYS_S, M_WAIT_REQ_FALL_S);

    TYPE MasterType IS RECORD
        wrState  : MasterStateType;
        wrAcks   : slv(NUM_SLAVE_SLOTS_G - 1 DOWNTO 0);
        wrAckNum : slv(ACK_NUM_SIZE_C - 1 DOWNTO 0);
        wrValid  : sl;
        rdState  : MasterStateType;
        rdAcks   : slv(NUM_SLAVE_SLOTS_G - 1 DOWNTO 0);
        rdAckNum : slv(ACK_NUM_SIZE_C - 1 DOWNTO 0);
        rdValid  : sl;
    END RECORD MasterType;

    TYPE MasterArray IS ARRAY (NATURAL RANGE <>) OF MasterType;

    TYPE RegType IS RECORD
        slave            : SlaveArray(NUM_SLAVE_SLOTS_G - 1 DOWNTO 0);
        master           : MasterArray(NUM_MASTER_SLOTS_G - 1 DOWNTO 0);
        sAxiWriteSlaves  : AxiWriteSlaveArray(NUM_SLAVE_SLOTS_G - 1 DOWNTO 0);
        sAxiReadSlaves   : AxiReadSlaveArray(NUM_SLAVE_SLOTS_G - 1 DOWNTO 0);
        mAxiWriteMasters : AxiWriteMasterArray(NUM_MASTER_SLOTS_G - 1 DOWNTO 0);
        mAxiReadMasters  : AxiReadMasterArray(NUM_MASTER_SLOTS_G - 1 DOWNTO 0);
    END RECORD RegType;

    CONSTANT REG_INIT_C : RegType := (
    slave            => (
    OTHERS           => (
    wrState          => S_WAIT_AXI_TXN_S,
    wrReqs => (OTHERS => '0'),
    wrReqNum => (OTHERS => '0'),
    rdState          => S_WAIT_AXI_TXN_S,
    rdReqs => (OTHERS => '0'),
    rdReqNum => (OTHERS => '0'))),
    master           => (
    OTHERS           => (
    wrState          => M_WAIT_REQ_S,
    wrAcks => (OTHERS => '0'),
    wrAckNum => (OTHERS => '0'),
    wrValid          => '0',
    rdState          => M_WAIT_REQ_S,
    rdAcks => (OTHERS => '0'),
    rdAckNum => (OTHERS => '0'),
    rdValid          => '0')),
    sAxiWriteSlaves => (OTHERS => AXI_WRITE_SLAVE_INIT_C),
    sAxiReadSlaves => (OTHERS => AXI_READ_SLAVE_INIT_C),
    mAxiWriteMasters => axiFullWriteMasterInit(MASTERS_CONFIG_G),
    mAxiReadMasters  => axiFullReadMasterInit(MASTERS_CONFIG_G));

    SIGNAL r   : RegType := REG_INIT_C;
    SIGNAL rin : RegType;

    TYPE AxiStatusArray IS ARRAY (NATURAL RANGE <>) OF AxiLiteStatusType;

BEGIN

    ASSERT (NUM_MASTER_SLOTS_G = MASTERS_CONFIG_G'length)
    REPORT "Mismatch between NUM_MASTER_SLOTS_G and MASTERS_CONFIG_G'length"
        SEVERITY failure;

    noneZeroCheck : FOR i IN MASTERS_CONFIG_G'RANGE GENERATE
        ASSERT (MASTERS_CONFIG_G(i).baseAddr(MASTERS_CONFIG_G(i).addrBits - 1 DOWNTO 0) = 0)
        REPORT "AXI_LITE_CROSSBAR Configuration Error:" & LF &
            "  - Array Index       : " & INTEGER'image(i) & LF &
            "  - baseAddr          : 0x" & hstr(MASTERS_CONFIG_G(i).baseAddr) & LF &
            "  - addrBits          : " & str(MASTERS_CONFIG_G(i).addrBits) & LF &
            "  - connectivity      : 0x" & hstr(MASTERS_CONFIG_G(i).connectivity) & LF &
            "  => baseAddr must be zero within the specified addrBits range."
            SEVERITY failure;
    END GENERATE noneZeroCheck;

    gen_assert_master_config : FOR i IN 0 TO NUM_MASTER_SLOTS_G - 1 GENERATE
        gen_inner_loop : FOR j IN 0 TO NUM_MASTER_SLOTS_G - 1 GENERATE
            -- Ensure that no two master regions overlap
            ASSERT (getHighAddr(MASTERS_CONFIG_G(i)) < MASTERS_CONFIG_G(j).baseAddr) OR (getHighAddr(MASTERS_CONFIG_G(j)) < MASTERS_CONFIG_G(i).baseAddr) OR (i = j)
            REPORT "AXI_LITE_CROSSBAR Configuration Error:" & LF &
                "  - baseAddr(" & INTEGER'image(i) & "): 0x" & hstr(MASTERS_CONFIG_G(i).baseAddr) & LF &
                "  - highAddr(" & INTEGER'image(i) & "): 0x" & hstr(getHighAddr(MASTERS_CONFIG_G(i))) & LF &
                "  - baseAddr(" & INTEGER'image(j) & "): 0x" & hstr(MASTERS_CONFIG_G(j).baseAddr) & LF &
                "  - highAddr(" & INTEGER'image(j) & "): 0x" & hstr(getHighAddr(MASTERS_CONFIG_G(j))) & LF &
                "  => Address space overlap between master slot."
                SEVERITY failure;
        END GENERATE;
    END GENERATE;

    -- synopsys translate_off
    print(DEBUG_G, "AXI_LITE_CROSSBAR: " & LF &
    "NUM_SLAVE_SLOTS_G: " & INTEGER'image(NUM_SLAVE_SLOTS_G) & LF &
    "NUM_MASTER_SLOTS_G: " & INTEGER'image(NUM_MASTER_SLOTS_G) & LF &
    "DEC_ERROR_RESP_G: " & str(DEC_ERROR_RESP_G) & LF &
    "MASTERS_CONFIG_G:");

    printCfg : FOR i IN MASTERS_CONFIG_G'RANGE GENERATE
        print(DEBUG_G,
        "  baseAddr: " & hstr(MASTERS_CONFIG_G(i).baseAddr) & LF &
        "  addrBits: " & str(MASTERS_CONFIG_G(i).addrBits) & LF &
        "  connectivity: " & hstr(MASTERS_CONFIG_G(i).connectivity));
    END GENERATE printCfg;
    -- synopsys translate_on

    comb : PROCESS (axiClkRst, mAxiReadSlaves, mAxiWriteSlaves, r,
        sAxiReadMasters, sAxiWriteMasters) IS
        VARIABLE v            : RegType;
        --VARIABLE sAxiStatuses : AxiStatusArray(NUM_SLAVE_SLOTS_G - 1 DOWNTO 0);
        VARIABLE mRdReqs      : slv(NUM_SLAVE_SLOTS_G - 1 DOWNTO 0);
        VARIABLE mWrReqs      : slv(NUM_SLAVE_SLOTS_G - 1 DOWNTO 0);
    BEGIN
        v := r;

        -- Control slave side outputs
        FOR s IN NUM_SLAVE_SLOTS_G - 1 DOWNTO 0 LOOP

            v.sAxiWriteSlaves(s).awready := '0';
            v.sAxiWriteSlaves(s).wready  := '0';
            v.sAxiReadSlaves(s).arready  := '0';

            -- Reset resp valid
            IF (sAxiWriteMasters(s).bready = '1') THEN
                v.sAxiWriteSlaves(s).bvalid := '0';
            END IF;

            -- Reset rvalid upon rready
            IF (sAxiReadMasters(s).rready = '1') THEN
                v.sAxiReadSlaves(s).rvalid := '0';
            END IF;

            -- Write state machine
            CASE (r.slave(s).wrState) IS
                WHEN S_WAIT_AXI_TXN_S =>

                    -- Incoming write
                    IF (sAxiWriteMasters(s).awvalid = '1' AND sAxiWriteMasters(s).wvalid = '1') THEN

                        FOR m IN MASTERS_CONFIG_G'RANGE LOOP
                            -- Check for address match
                            IF ((MASTERS_CONFIG_G(m).addrBits = 32)
                                OR (
                                StdMatch(-- Use std_match to allow dontcares ('-')
                                sAxiWriteMasters(s).awaddr(31 DOWNTO MASTERS_CONFIG_G(m).addrBits),
                                MASTERS_CONFIG_G(m).baseAddr(31 DOWNTO MASTERS_CONFIG_G(m).addrBits))
                                AND (MASTERS_CONFIG_G(m).connectivity(s) = '1')))
                                THEN
                                v.slave(s).wrReqs(m) := '1';
                                v.slave(s).wrReqNum  := conv_std_logic_vector(m, REQ_NUM_SIZE_C);
                                --                        print("AxiLiteCrossbar: Slave  " & str(s) & " reqd Master " & str(m) & " Write addr " & hstr(sAxiWriteMasters(s).awaddr));
                            END IF;
                        END LOOP;

                        -- Respond with error if decode fails
                        IF (uOr(v.slave(s).wrReqs) = '0') THEN
                            v.sAxiWriteSlaves(s).awready := '1';
                            v.sAxiWriteSlaves(s).wready  := '1';
                            v.slave(s).wrState           := S_DEC_ERR_S;
                        ELSE
                            v.slave(s).wrState := S_ACK_S;
                        END IF;
                    END IF;

                    -- Send error
                WHEN S_DEC_ERR_S =>
                    -- Send error response
                    v.sAxiWriteSlaves(s).bresp  := DEC_ERROR_RESP_G;
                    v.sAxiWriteSlaves(s).bvalid := '1';

                    -- Clear when acked by master
                    IF (r.sAxiWriteSlaves(s).bvalid = '1' AND sAxiWriteMasters(s).bready = '1') THEN
                        v.sAxiWriteSlaves(s).bvalid := '0';
                        v.slave(s).wrState          := S_WAIT_AXI_TXN_S;
                    END IF;

                    -- Transaction is acked
                WHEN S_ACK_S =>
                    FOR m IN NUM_MASTER_SLOTS_G - 1 DOWNTO 0 LOOP
                        IF (r.slave(s).wrReqNum = m AND r.slave(s).wrReqs(m) = '1' AND r.master(m).wrAcks(s) = '1') THEN
                            v.sAxiWriteSlaves(s).awready := '1';
                            v.sAxiWriteSlaves(s).wready  := '1';
                            v.slave(s).wrState           := S_TXN_S;
                        END IF;
                    END LOOP;

                    -- Transaction in progress
                WHEN S_TXN_S =>
                    FOR m IN NUM_MASTER_SLOTS_G - 1 DOWNTO 0 LOOP
                        IF (r.slave(s).wrReqNum = m AND r.slave(s).wrReqs(m) = '1' AND r.master(m).wrAcks(s) = '1') THEN

                            -- Forward write response
                            v.sAxiWriteSlaves(s).bresp  := mAxiWriteSlaves(m).bresp;
                            v.sAxiWriteSlaves(s).bvalid := mAxiWriteSlaves(m).bvalid;

                            -- bvalid or rvalid indicates txn concluding
                            IF (r.sAxiWriteSlaves(s).bvalid = '1' AND sAxiWriteMasters(s).bready = '1') THEN
                                v.sAxiWriteSlaves(s) := AXI_WRITE_SLAVE_INIT_C;
                                v.slave(s).wrReqs    := (OTHERS => '0');
                                v.slave(s).wrState   := S_WAIT_AXI_TXN_S;
                            END IF;
                        END IF;
                    END LOOP;
            END CASE;

            -- Read state machine
            CASE (r.slave(s).rdState) IS
                WHEN S_WAIT_AXI_TXN_S =>

                    -- Incoming read
                    IF (sAxiReadMasters(s).arvalid = '1') THEN
                        FOR m IN MASTERS_CONFIG_G'RANGE LOOP
                            -- Check for address match
                            IF ((MASTERS_CONFIG_G(m).addrBits = 32)
                                OR (
                                StdMatch(-- Use std_match to allow dontcares ('-')
                                sAxiReadMasters(s).araddr(31 DOWNTO MASTERS_CONFIG_G(m).addrBits),
                                MASTERS_CONFIG_G(m).baseAddr(31 DOWNTO MASTERS_CONFIG_G(m).addrBits))
                                AND (MASTERS_CONFIG_G(m).connectivity(s) = '1')))
                                THEN
                                v.slave(s).rdReqs(m) := '1';
                                v.slave(s).rdReqNum  := conv_std_logic_vector(m, REQ_NUM_SIZE_C);
                            END IF;
                        END LOOP;

                        -- Respond with error if decode fails
                        IF (uOr(v.slave(s).rdReqs) = '0') THEN
                            v.sAxiReadSlaves(s).arready := '1';
                            v.slave(s).rdState          := S_DEC_ERR_S;
                        ELSE
                            v.slave(s).rdState := S_ACK_S;
                        END IF;
                    END IF;

                    -- Error
                WHEN S_DEC_ERR_S =>
                    v.sAxiReadSlaves(s).rresp  := DEC_ERROR_RESP_G;
                    v.sAxiReadSlaves(s).rdata  := (OTHERS => '0');
                    v.sAxiReadSlaves(s).rvalid := '1';

                    IF (r.sAxiReadSlaves(s).rvalid = '1' AND sAxiReadMasters(s).rready = '1') THEN
                        v.sAxiReadSlaves(s).rvalid := '0';
                        v.slave(s).rdState         := S_WAIT_AXI_TXN_S;
                    END IF;

                    -- Transaction is acked
                WHEN S_ACK_S =>
                    FOR m IN NUM_MASTER_SLOTS_G - 1 DOWNTO 0 LOOP
                        IF (r.slave(s).rdReqNum = m AND r.slave(s).rdReqs(m) = '1' AND r.master(m).rdAcks(s) = '1') THEN
                            v.sAxiReadSlaves(s).arready := '1';
                            v.slave(s).rdState          := S_TXN_S;
                        END IF;
                    END LOOP;

                    -- Transaction in progress
                WHEN S_TXN_S =>
                    FOR m IN NUM_MASTER_SLOTS_G - 1 DOWNTO 0 LOOP
                        IF (r.slave(s).rdReqNum = m AND r.slave(s).rdReqs(m) = '1' AND r.master(m).rdAcks(s) = '1') THEN

                            -- Forward read response
                            v.sAxiReadSlaves(s).rresp  := mAxiReadSlaves(m).rresp;
                            v.sAxiReadSlaves(s).rdata  := mAxiReadSlaves(m).rdata;
                            v.sAxiReadSlaves(s).rvalid := mAxiReadSlaves(m).rvalid;

                            -- rvalid indicates txn concluding
                            IF (r.sAxiReadSlaves(s).rvalid = '1' AND sAxiReadMasters(s).rready = '1') THEN
                                v.sAxiReadSlaves(s) := AXI_READ_SLAVE_INIT_C;
                                v.slave(s).rdReqs   := (OTHERS => '0');
                                v.slave(s).rdState  := S_WAIT_AXI_TXN_S; --S_WAIT_DONE_S;
                            END IF;
                        END IF;
                    END LOOP;
            END CASE;
        END LOOP;
        -- Control master side outputs
        FOR m IN NUM_MASTER_SLOTS_G - 1 DOWNTO 0 LOOP

            -- Group reqs by master
            mWrReqs := (OTHERS => '0');
            mRdReqs := (OTHERS => '0');
            FOR i IN mWrReqs'RANGE LOOP
                mWrReqs(i) := r.slave(i).wrReqs(m);
                mRdReqs(i) := r.slave(i).rdReqs(m);
            END LOOP;

            -- Write path processing
            CASE (r.master(m).wrState) IS
                WHEN M_WAIT_REQ_S =>

                    -- Keep these in reset state while waiting for requests
                    v.master(m).wrAcks    := (OTHERS => '0');
                    v.mAxiWriteMasters(m) := axiFullWriteMasterInit(MASTERS_CONFIG_G(m));

                    -- Wait for a request, arbitrate between simultaneous requests
                    IF (r.master(m).wrValid = '0') THEN
                        arbitrate(mWrReqs, r.master(m).wrAckNum, v.master(m).wrAckNum, v.master(m).wrValid, v.master(m).wrAcks);
                    END IF;

                    -- Upon valid request (set 1 cycle previous by arbitrate()), connect slave side
                    -- buses to this master's outputs.
                    IF (r.master(m).wrValid = '1') THEN
                        v.master(m).wrAcks    := r.master(m).wrAcks;
                        v.mAxiWriteMasters(m) := sAxiWriteMasters(conv_integer(r.master(m).wrAckNum));
                        v.master(m).wrState   := M_WAIT_READYS_S;
                    END IF;

                WHEN M_WAIT_READYS_S =>

                    -- Wait for attached slave to respond
                    -- Clear *valid signals upon *ready responses
                    IF (mAxiWriteSlaves(m).awready = '1') THEN
                        v.mAxiWriteMasters(m).awvalid := '0';
                    END IF;
                    IF (mAxiWriteSlaves(m).wready = '1') THEN
                        v.mAxiWriteMasters(m).wvalid := '0';
                    END IF;

                    -- When all *valid signals cleared, wait for slave side to clear request
                    IF (v.mAxiWriteMasters(m).awvalid = '0' AND v.mAxiWriteMasters(m).wvalid = '0') THEN
                        v.master(m).wrState := M_WAIT_REQ_FALL_S;
                    END IF;

                WHEN M_WAIT_REQ_FALL_S =>
                    -- When slave side deasserts request, clear ack and valid and start waiting for next
                    -- request
                    IF (mWrReqs(conv_integer(r.master(m).wrAckNum)) = '0') THEN
                        v.master(m).wrState := M_WAIT_REQ_S;
                        v.master(m).wrAcks  := (OTHERS => '0');
                        v.master(m).wrValid := '0';
                    END IF;

            END CASE;

            -- Don't allow baseAddr bits to be overwritten
            -- They can't be anyway based on the logic above, but Vivado can't figure that out.
            -- This helps optimization happen properly
            IF (MASTERS_CONFIG_G(m).addrBits /= 32) THEN
                v.mAxiWriteMasters(m).awaddr(31 DOWNTO MASTERS_CONFIG_G(m).addrBits) :=
                MASTERS_CONFIG_G(m).baseAddr(31 DOWNTO MASTERS_CONFIG_G(m).addrBits);
            END IF;
            -- Read path processing
            CASE (r.master(m).rdState) IS
                WHEN M_WAIT_REQ_S =>

                    -- Keep these in reset state while waiting for requests
                    v.master(m).rdAcks   := (OTHERS => '0');
                    v.mAxiReadMasters(m) := axiFullReadMasterInit(MASTERS_CONFIG_G(m));

                    -- Wait for a request, arbitrate between simultaneous requests
                    IF (r.master(m).rdValid = '0') THEN
                        arbitrate(mRdReqs, r.master(m).rdAckNum, v.master(m).rdAckNum, v.master(m).rdValid, v.master(m).rdAcks);
                    END IF;

                    -- Upon valid request (set 1 cycle previous by arbitrate()), connect slave side
                    -- buses to this master's outputs.
                    IF (r.master(m).rdValid = '1') THEN
                        v.master(m).rdAcks   := r.master(m).rdAcks;
                        v.mAxiReadMasters(m) := sAxiReadMasters(conv_integer(r.master(m).rdAckNum));
                        v.master(m).rdState  := M_WAIT_READYS_S;
                    END IF;

                WHEN M_WAIT_READYS_S =>

                    -- Wait for attached slave to respond
                    -- Clear *valid signals upon *ready responses
                    IF (mAxiReadSlaves(m).arready = '1') THEN
                        v.mAxiReadMasters(m).arvalid := '0';
                    END IF;

                    -- When all *valid signals cleared, wait for slave side to clear request
                    IF (v.mAxiReadMasters(m).arvalid = '0') THEN
                        v.master(m).rdState := M_WAIT_REQ_FALL_S;
                    END IF;

                WHEN M_WAIT_REQ_FALL_S =>
                    -- When slave side deasserts request, clear ack and valid and start waiting for next
                    -- request
                    IF (mRdReqs(conv_integer(r.master(m).rdAckNum)) = '0') THEN
                        v.master(m).rdState := M_WAIT_REQ_S;
                        v.master(m).rdAcks  := (OTHERS => '0');
                        v.master(m).rdValid := '0';
                    END IF;

            END CASE;

            -- Don't allow baseAddr bits to be overwritten
            -- They can't be anyway based on the logic above, but Vivado can't figure that out.
            -- This helps optimization happen properly
            IF (MASTERS_CONFIG_G(m).addrBits /= 32) THEN
                v.mAxiReadMasters(m).araddr(31 DOWNTO MASTERS_CONFIG_G(m).addrBits) :=
                MASTERS_CONFIG_G(m).baseAddr(31 DOWNTO MASTERS_CONFIG_G(m).addrBits);
            END IF;

        END LOOP;

        IF (RST_ASYNC_G = false AND axiClkRst = RST_POLARITY_G) THEN
            v := REG_INIT_C;
        END IF;

        rin <= v;

        sAxiReadSlaves   <= r.sAxiReadSlaves;
        sAxiWriteSlaves  <= r.sAxiWriteSlaves;
        mAxiReadMasters  <= r.mAxiReadMasters;
        mAxiWriteMasters <= r.mAxiWriteMasters;

    END PROCESS comb;

    seq : PROCESS (axiClk, axiClkRst) IS
    BEGIN
        IF (RST_ASYNC_G AND axiClkRst = RST_POLARITY_G) THEN
            r <= REG_INIT_C AFTER TPD_G;
        ELSIF rising_edge(axiClk) THEN
            r <= rin AFTER TPD_G;
        END IF;
    END PROCESS seq;

END ARCHITECTURE rtl;