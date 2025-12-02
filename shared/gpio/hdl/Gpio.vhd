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

USE work.axi4lite_intf_pkg.ALL;
USE work.GpioRegisters_pkg.ALL;

ENTITY Gpio IS
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
    CONSTANT ADDR_BITS_C : POSITIVE := 4;

    SIGNAL pinsInput : STD_LOGIC_VECTOR(31 DOWNTO 0);

    SIGNAL s_axil_i : axi4lite_slave_in_intf(
    AWADDR(ADDR_BITS_C - 1 DOWNTO 0),
    WDATA(31 DOWNTO 0),
    WSTRB(3 DOWNTO 0),
    ARADDR(ADDR_BITS_C - 1 DOWNTO 0)
    );
    SIGNAL s_axil_o : axi4lite_slave_out_intf(
    RDATA(31 DOWNTO 0)
    );

    SIGNAL hwif_in : GpioRegisters_in_t;
    SIGNAL hwif_out : GpioRegisters_out_t;
BEGIN
    -- convert surf axilite to peakrdl's
    AxiLitePeakRdlBridge_inst : ENTITY work.AxiLitePeakRdlBridge
        GENERIC MAP(
            ADDR_BITS_G => ADDR_BITS_C
        )
        PORT MAP(
            axilWriteMaster => axilWriteMaster,
            axilWriteSlave => axilWriteSlave,
            axilReadMaster => axilReadMaster,
            axilReadSlave => axilReadSlave,
            s_axil_i => s_axil_i,
            s_axil_o => s_axil_o
        );

    -- register map
    GpioRegisters_inst : ENTITY work.GpioRegisters
        PORT MAP(
            clk => clk,
            rst => reset,
            s_axil_i => s_axil_i,
            s_axil_o => s_axil_o,
            hwif_in => hwif_in,
            hwif_out => hwif_out
        );

    -- synchronizer for async pin inputs
    SynchronizerVector_inst : ENTITY surf.SynchronizerVector
        GENERIC MAP(
            WIDTH_G => 32
        )
        PORT MAP(
            clk => clk,
            rst => reset,
            dataIn => pinsInput,
            dataOut => hwif_in.input.input.next_q
        );

    -- bidirectional pins to input/output/direction
    IoBufGen : FOR i IN 0 TO 31 GENERATE
        IoBufWrapper_inst : ENTITY surf.IoBufWrapper
            PORT MAP(
                O => pinsInput(i),
                IO => pins(i),
                I => hwif_out.output.output.value(i),
                T => hwif_out.direction.direction.value(i)
            );
    END GENERATE;

    -- PROCESS (clk)
    -- BEGIN
    --     IF rising_edge(clk) THEN
    --         ack.done <= '0';
    --         IF req.request THEN
    --             ack.done <= '1';
    --             ack.resp <= AXI_RESP_OK_C;

    --             CASE req.address(ADDR_BITS_G - 1 DOWNTO 0) IS
    --                 WHEN x"0000" =>
    --                     IF req.rnw THEN
    --                         ack.rdData <= dir;
    --                     ELSE
    --                         dir <= req.wrData;
    --                     END IF;
    --                 WHEN x"0004" =>
    --                     -- output value (rw)
    --                     IF req.rnw THEN
    --                         ack.rdData <= outputValue;
    --                     ELSE
    --                         outputValue <= req.wrData;
    --                     END IF;
    --                 WHEN x"0008" =>
    --                     -- input value (r)
    --                     IF req.rnw THEN
    --                         ack.rdData <= inputValue;
    --                     ELSE
    --                         -- ignore write
    --                     END IF;
    --                 WHEN OTHERS =>
    --                     NULL;
    --             END CASE;
    --         END IF;
    --     END IF;
    -- END PROCESS;

END ARCHITECTURE;