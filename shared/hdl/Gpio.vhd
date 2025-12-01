-- AXI-Lite GPIO Peripheral
-- Provides a 32 pin GPIO interface, with each pin available as an input or an output.

-- Registers:
-- - 0x0 : direction (rw). 0 for input, 1 for output
-- - 0x4 : output (rw).
-- - 0x8 : input (r).

LIBRARY ieee;
CONTEXT ieee.ieee_std_context;

LIBRARY surf;
USE surf.AxiLitePkg.ALL;

ENTITY Gpio IS
    GENERIC (
        ADDR_BITS_G : POSITIVE := 16
    );
    PORT (
        clk : IN STD_LOGIC;
        reset : IN STD_LOGIC;

        axilWriteMaster : IN AxiLiteWriteMasterType;
        axilWriteSlave : OUT AxiLiteWriteSlaveType;
        axilReadMaster : IN AxiLiteReadMasterType;
        axilReadSlave : OUT AxiLiteReadSlaveType;

        pins : INOUT STD_LOGIC_VECTOR(31 DOWNTO 0)
    );
END ENTITY Gpio;

ARCHITECTURE rtl OF Gpio IS
    SIGNAL req : AxiLiteReqType;
    SIGNAL ack : AxiLiteAckType := AXI_LITE_ACK_INIT_C;

    SIGNAL dir : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    SIGNAL outputValue : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    SIGNAL inputValue : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');

BEGIN
    AxiLiteSlave_inst : ENTITY surf.AxiLiteSlave
        PORT MAP(
            axilClk => clk,
            axilRst => reset,
            req => req,
            ack => ack,
            axilWriteMaster => axilWriteMaster,
            axilWriteSlave => axilWriteSlave,
            axilReadMaster => axilReadMaster,
            axilReadSlave => axilReadSlave
        );

    SynchronizerVector_inst : ENTITY surf.SynchronizerVector
        GENERIC MAP(
            WIDTH_G => 32
        )
        PORT MAP(
            clk => clk,
            rst => reset,
            dataIn => pins,
            dataOut => inputValue
        );

    IoBufGen : FOR i IN 0 TO 31 GENERATE
        IoBufWrapper_inst : ENTITY surf.IoBufWrapper
            PORT MAP(
                O => inputValue(i),
                IO => pins(i),
                I => outputValue(i),
                T => dir(i)
            );
    END GENERATE;

    PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN
            inputValue <= pins;

            ack.done <= '0';
            IF req.request THEN
                ack.done <= '1';
                ack.resp <= AXI_RESP_OK_C;

                CASE req.address(ADDR_BITS_G - 1 DOWNTO 0) IS
                    WHEN x"0000" =>
                        IF req.rnw THEN
                            ack.rdData <= dir;
                        ELSE
                            dir <= req.wrData;
                        END IF;
                    WHEN x"0004" =>
                        -- output value (rw)
                        IF req.rnw THEN
                            ack.rdData <= outputValue;
                        ELSE
                            outputValue <= req.wrData;
                        END IF;
                    WHEN x"0008" =>
                        -- input value (r)
                        IF req.rnw THEN
                            ack.rdData <= inputValue;
                        ELSE
                            -- ignore write
                        END IF;
                    WHEN OTHERS =>
                        NULL;
                END CASE;
            END IF;
        END IF;
    END PROCESS;

END ARCHITECTURE;