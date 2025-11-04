LIBRARY ieee;
CONTEXT ieee.ieee_std_context;

LIBRARY std;
USE std.textio.ALL;

LIBRARY surf;
USE surf.AxiLitePkg.ALL;
USE surf.StdRtlPkg.ALL;

ENTITY Ram IS
    GENERIC (
        RAM_FILE_PATH_G : STRING;
        LENGTH_WORDS_G : INTEGER := 4096
    );
    PORT (
        clk : IN STD_LOGIC;
        reset : IN STD_LOGIC;

        axiReadMaster : IN AxiLiteReadMasterType;
        axiReadSlave : OUT AxiLiteReadSlaveType;
        axiWriteMaster : IN AxiLiteWriteMasterType;
        axiWriteSlave : OUT AxiLiteWriteSlaveType
    );
END ENTITY Ram;

ARCHITECTURE rtl OF Ram IS
    TYPE RamType IS ARRAY (0 TO LENGTH_WORDS_G - 1) OF STD_LOGIC_VECTOR(31 DOWNTO 0);

    IMPURE FUNCTION InitRamFromFile (RamFileName : IN STRING) RETURN RamType IS
        FILE RamFile : text;
        VARIABLE RamFileLine : line;
        VARIABLE RamTemp : RamType := (OTHERS => (OTHERS => '0'));
        VARIABLE status : FILE_OPEN_STATUS;
        VARIABLE line_count : NATURAL := 0;
        VARIABLE extra_lines : NATURAL := 0;
    BEGIN
        FILE_OPEN(status, RamFile, RamFileName, READ_MODE);
        IF status = OPEN_OK THEN
            FOR I IN RamType'RANGE LOOP
                IF endfile(RamFile) THEN
                    EXIT;
                END IF;
                readline (RamFile, RamFileLine);
                hex_read (RamFileLine, RamTemp(I));
                line_count := line_count + 1;
            END LOOP;
            -- Check if file still has data after filling the RAM
            IF NOT endfile(RamFile) THEN
                WHILE NOT endfile(RamFile) LOOP
                    readline (RamFile, RamFileLine);
                    extra_lines := extra_lines + 1;
                END LOOP;
                REPORT "RAM initialization file '" & RamFileName & "' is too big (" &
                    INTEGER'image(line_count + extra_lines) & " lines, expected <= " &
                    INTEGER'image(RamType'length) & ")"
                    SEVERITY error;
            END IF;
            FILE_CLOSE(RamFile);
        ELSE
            REPORT "RAM initialization file '" & RamFileName & "' does not exist!" SEVERITY error;
        END IF;
        RETURN RamTemp;
    END FUNCTION;

    SIGNAL ramValue : RamType := InitRamFromFile(RAM_FILE_PATH_G);
    SIGNAL axiStatusS : AxiLiteStatusType;

BEGIN
    PROCESS (clk)
        VARIABLE read_word_address : unsigned(29 DOWNTO 0);
        VARIABLE write_word_address : unsigned(29 DOWNTO 0);
        VARIABLE axiStatus : AxiLiteStatusType := AXI_LITE_STATUS_INIT_C;
        VARIABLE vAxiReadSlave : AxiLiteReadSlaveType := AXI_LITE_READ_SLAVE_INIT_C;
        VARIABLE vAxiWriteSlave : AxiLiteWriteSlaveType := AXI_LITE_WRITE_SLAVE_INIT_C;
    BEGIN
        IF rising_edge(clk) THEN
            IF (reset) THEN
                vAxiReadSlave := AXI_LITE_READ_SLAVE_INIT_C;
                vAxiReadSlave.arready := '1';
                vAxiWriteSlave := AXI_LITE_WRITE_SLAVE_INIT_C;
                axiStatus := AXI_LITE_STATUS_INIT_C;
            ELSE
                -- defaults before checking
                vAxiReadSlave.rvalid := '0';
                axiStatus.readEnable := '0';
                axiStatus.writeEnable := '0';

                -- accept reads
                IF axiReadMaster.arvalid AND vAxiReadSlave.arready THEN
                    axiStatus.readEnable := '1';
                    vAxiReadSlave.arready := '0';

                    read_word_address := unsigned(axiReadMaster.araddr(31 DOWNTO 2));
                END IF;

                -- Write
                IF (axiStatus.writeEnable) THEN
                    write_word_address := unsigned(axiWriteMaster.awaddr(31 DOWNTO 2));
                    IF (write_word_address < LENGTH_WORDS_G) THEN
                        -- address is in range of the ram
                        FOR i IN 0 TO 3 LOOP
                            IF axiWriteMaster.wstrb(i) = '1' THEN
                                ramValue(to_integer(write_word_address))((i + 1) * 8 - 1 DOWNTO i * 8) <= axiWriteMaster.wdata((i + 1) * 8 - 1 DOWNTO i * 8);
                            END IF;
                        END LOOP;

                        axiSlaveWriteResponse(vAxiWriteSlave);
                    ELSE
                        -- out of range, return with SLVERR
                        axiSlaveWriteResponse(vAxiWriteSlave, AXI_RESP_SLVERR_C);
                    END IF;
                END IF;

                -- Read
                IF (axiStatus.readEnable AND axiReadMaster.rready) THEN
                    -- output data this clock
                    vAxiReadSlave.rvalid := '1';
                    -- ready for next tx
                    vAxiReadSlave.arready := '1';

                    IF (read_word_address < LENGTH_WORDS_G) THEN
                        -- address is in range of the ram
                        vAxiReadSlave.rdata := ramValue(to_integer(read_word_address));
                        vAxiReadSlave.rresp := AXI_RESP_OK_C;
                    ELSE
                        -- out of range, return with SLVERR
                        vAxiReadSlave.rdata := (OTHERS => '0');
                        vAxiReadSlave.rresp := AXI_RESP_SLVERR_C;
                    END IF;

                END IF;
            END IF;

            -- update output ports
            axiWriteSlave <= vAxiWriteSlave;
            axiReadSlave <= vAxiReadSlave;
            axiStatusS <= axiStatus;
        END IF;
    END PROCESS;
END ARCHITECTURE;