LIBRARY ieee;
CONTEXT ieee.ieee_std_context;

ENTITY Jtag IS
    GENERIC (
        CONSTANT IR_LENGTH_C : NATURAL := 5;
        PACKAGE JtagPkg IS NEW work.JtagPkg
            GENERIC MAP(IR_LENGTH_C => IR_LENGTH_C)
            );
            PORT (
                clk : IN STD_LOGIC;
                reset : IN STD_LOGIC;

                tck : IN STD_LOGIC;
                tms : IN STD_LOGIC;
                tdi : IN STD_LOGIC;
                tdo : OUT STD_LOGIC;

                ir_out : OUT JtagPkg.JtagInterface
            );
        END ENTITY Jtag;

    ARCHITECTURE rtl OF Jtag IS

        TYPE StateType IS (TestLogicReset, RunTestIdle, SelectDrScan, CaptureDr, ShiftDr, Exit1Dr, PauseDr, Exit2Dr, UpdateDr, SelectIrScan, CaptureIr, ShiftIr, Exit1Ir, PauseIr, Exit2Ir, UpdateIr);

        SIGNAL state : StateType := TestLogicReset;

        SIGNAL ir : STD_LOGIC_VECTOR(IR_LENGTH_C - 1 DOWNTO 0) := JtagPkg.IR_DEFAULT_C;
    BEGIN

        PROCESS (clk)
            VARIABLE lastTck : STD_LOGIC := '1';
        BEGIN
            IF rising_edge(clk) THEN
                IF reset THEN
                    ir <= JtagPkg.IR_DEFAULT_C;
                    state <= TestLogicReset;
                    lastTck := '1';
                ELSE
                    IF tck AND NOT lastTck THEN
                        -- rising edge
                        CASE state IS
                            WHEN TestLogicReset =>
                                state <= TestLogicReset WHEN tms ELSE
                                    RunTestIdle;
                            WHEN RunTestIdle =>
                                state <= SelectDrScan WHEN tms ELSE
                                    RunTestIdle;
                            WHEN SelectDrScan =>
                                state <= SelectIrScan WHEN tms ELSE
                                    CaptureDr;
                            WHEN CaptureDr =>
                                state <= Exit1Dr WHEN tms ELSE
                                    ShiftDr;
                            WHEN ShiftDr =>
                                state <= Exit1Dr WHEN tms ELSE
                                    ShiftDr;
                            WHEN Exit1Dr =>
                                state <= UpdateDr WHEN tms ELSE
                                    PauseDr;
                            WHEN PauseDr =>
                                state <= Exit2Dr WHEN tms ELSE
                                    PauseDr;
                            WHEN Exit2Dr =>
                                state <= UpdateDr WHEN tms ELSE
                                    ShiftDr;
                            WHEN UpdateDr =>
                                state <= SelectDrScan WHEN tms ELSE
                                    RunTestIdle;
                            WHEN SelectIrScan =>
                                state <= TestLogicReset WHEN tms ELSE
                                    CaptureIr;
                            WHEN CaptureIr =>
                                state <= Exit1Ir WHEN tms ELSE
                                    ShiftIr;
                            WHEN ShiftIr =>
                                state <= Exit1Ir WHEN tms ELSE
                                    ShiftIr;
                            WHEN Exit1Ir =>
                                state <= UpdateIr WHEN tms ELSE
                                    PauseIr;
                            WHEN PauseIr =>
                                state <= Exit2Ir WHEN tms ELSE
                                    PauseIr;
                            WHEN Exit2Ir =>
                                state <= UpdateIr WHEN tms ELSE
                                    ShiftIr;
                            WHEN UpdateIr =>
                                state <= SelectDrScan WHEN tms ELSE
                                    RunTestIdle;
                        END CASE;
                    ELSE
                        -- falling edge (or initial)
                    END IF;
                    lastTck := tck;

                    -- register selection
                    -- CASE ir IS
                    --     WHEN "00000" =>
                    --         -- BYPASS
                    --     WHEN "00001" =>
                    --         -- IDCODE
                    --     WHEN "11111" =>
                    --         -- BYPASS
                    --     WHEN OTHERS =>
                    --         -- reserved or undefined
                    --         NULL;
                    -- END CASE;
                END IF;
            END IF;
        END PROCESS;

    END ARCHITECTURE;