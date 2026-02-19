LIBRARY ieee;
CONTEXT ieee.ieee_std_context;

LIBRARY std;
USE std.textio.ALL;

USE work.AxiPkg.ALL;

LIBRARY surf;
USE surf.AxiLitePkg.ALL;
USE surf.StdRtlPkg.ALL;

ENTITY Ram IS
    GENERIC (
        RAM_FILE_PATH_G : STRING  := "";
        LENGTH_WORDS_G  : INTEGER := 16384;
        AXI_BASE_ADDR_G : UNSIGNED(31 DOWNTO 0)
    );
    PORT (
        clk   : IN STD_LOGIC;
        reset : IN STD_LOGIC;

        axiReadMaster  : IN AxiReadMasterType;
        axiReadSlave   : OUT AxiReadSlaveType;
        axiWriteMaster : IN AxiWriteMasterType;
        axiWriteSlave  : OUT AxiWriteSlaveType
    );
END ENTITY Ram;

ARCHITECTURE rtl OF Ram IS
    CONSTANT LENGTH_BYTES_G : INTEGER := LENGTH_WORDS_G * 4;
    TYPE RamType IS ARRAY (0 TO LENGTH_WORDS_G - 1) OF STD_LOGIC_VECTOR(31 DOWNTO 0);

    TYPE AxiLiteStatusType IS RECORD
        writeAddrEnable : sl;
        writeDataEnable : sl;
        readEnable      : sl;
    END RECORD AxiLiteStatusType;
    CONSTANT AXI_LITE_STATUS_INIT_C : AxiLiteStatusType := (writeAddrEnable => '0', writeDataEnable => '0', readEnable => '0');

    IMPURE FUNCTION InitRamFromFile (RamFileName : IN STRING) RETURN RamType IS
        FILE RamFile                                 : text;
        VARIABLE RamFileLine                         : line;
        VARIABLE RamTemp                             : RamType := (OTHERS => (OTHERS => '0'));
        VARIABLE status                              : FILE_OPEN_STATUS;
        VARIABLE line_count                          : NATURAL := 0;
        VARIABLE extra_lines                         : NATURAL := 0;
    BEGIN
        IF RamFileName'length /= 0 THEN
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
        END IF;
        RETURN RamTemp;
    END FUNCTION;

    SIGNAL ramValue   : RamType := InitRamFromFile(RAM_FILE_PATH_G);
    SIGNAL axiStatusS : AxiLiteStatusType;

BEGIN
    PROCESS (clk)
        VARIABLE readAddress      : unsigned(31 DOWNTO 0);
        VARIABLE writeAddress     : unsigned(31 DOWNTO 0);
        VARIABLE readWordAddress  : unsigned(31 DOWNTO 0);
        VARIABLE writeWordAddress : unsigned(31 DOWNTO 0);

        VARIABLE writeData      : STD_LOGIC_VECTOR(31 DOWNTO 0);
        VARIABLE writeStrb      : STD_LOGIC_VECTOR(3 DOWNTO 0);
        VARIABLE axiStatus      : AxiLiteStatusType := AXI_LITE_STATUS_INIT_C;
        VARIABLE vAxiReadSlave  : AxiReadSlaveType  := AXI_READ_SLAVE_INIT_C;
        VARIABLE vAxiWriteSlave : AxiWriteSlaveType := AXI_WRITE_SLAVE_INIT_C;
    BEGIN
        IF rising_edge(clk) THEN
            IF (reset) THEN
                vAxiReadSlave          := AXI_READ_SLAVE_INIT_C;
                vAxiReadSlave.arready  := '1';
                vAxiWriteSlave         := AXI_WRITE_SLAVE_INIT_C;
                vAxiWriteSlave.awready := '1';
                vAxiWriteSlave.wready  := '1';
                axiStatus              := AXI_LITE_STATUS_INIT_C;

                readAddress      := (OTHERS => '0');
                writeAddress     := (OTHERS => '0');
                readWordAddress  := (OTHERS => '0');
                writeWordAddress := (OTHERS => '0');
            ELSE
                -- check write complete
                IF axiWriteSlave.bvalid AND axiWriteMaster.bready THEN
                    vAxiWriteSlave.bvalid  := '0';
                    vAxiWriteSlave.awready := '1';
                    vAxiWriteSlave.wready  := '1';
                END IF;

                -- check read complete
                IF axiReadSlave.rvalid AND axiReadMaster.rready THEN
                    vAxiReadSlave.rvalid  := '0';
                    vAxiReadSlave.rlast   := '0';
                    vAxiReadSlave.arready := '1';
                END IF;

                -- accept reads
                IF axiReadMaster.arvalid AND axiReadSlave.arready THEN
                    axiStatus.readEnable  := '1';
                    vAxiReadSlave.arready := '0';

                    readAddress := unsigned(axiReadMaster.araddr);
                END IF;

                -- accept writes
                IF axiWriteMaster.awvalid AND axiWriteSlave.awready THEN
                    vAxiWriteSlave.awready := '0';

                    axiStatus.writeAddrEnable := '1';

                    writeAddress := unsigned(axiWriteMaster.awaddr);
                END IF;
                IF axiWriteMaster.wvalid AND axiWriteSlave.wready THEN
                    vAxiWriteSlave.wready := '0';

                    axiStatus.writeDataEnable := '1';

                    writeData := axiWriteMaster.wdata(31 DOWNTO 0);
                    writeStrb := axiWriteMaster.wstrb(3 DOWNTO 0);
                END IF;

                -- Write
                IF (axiStatus.writeAddrEnable AND axiStatus.writeDataEnable) THEN
                    axiStatus.writeAddrEnable := '0';
                    axiStatus.writeDataEnable := '0';

                    vAxiWriteSlave.bvalid := '1';

                    IF (writeAddress >= AXI_BASE_ADDR_G AND writeAddress < AXI_BASE_ADDR_G + LENGTH_BYTES_G) THEN
                        writeWordAddress := (writeAddress - AXI_BASE_ADDR_G) / 4;

                        -- address is in range of the ram
                        FOR i IN 0 TO 3 LOOP
                            IF writeStrb(i) = '1' THEN
                                ramValue(to_integer(writeWordAddress))((i + 1) * 8 - 1 DOWNTO i * 8) <= writeData((i + 1) * 8 - 1 DOWNTO i * 8);
                            END IF;
                        END LOOP;

                        vAxiWriteSlave.bresp := AXI_RESP_OK_C;
                    ELSE
                        -- out of range, return with SLVERR
                        vAxiWriteSlave.bresp := AXI_RESP_SLVERR_C;
                    END IF;
                END IF;

                -- Read
                IF (axiStatus.readEnable) THEN
                    axiStatus.readEnable := '0';

                    -- output data this clock
                    vAxiReadSlave.rvalid := '1';
                    -- todo: multi beats per burst
                    vAxiReadSlave.rlast := '1';

                    IF (readAddress >= AXI_BASE_ADDR_G AND readAddress < AXI_BASE_ADDR_G + LENGTH_BYTES_G) THEN
                        readWordAddress := (readAddress - AXI_BASE_ADDR_G) / 4;

                        -- address is in range of the ram
                        vAxiReadSlave.rdata(31 DOWNTO 0) := ramValue(to_integer(readWordAddress));
                        vAxiReadSlave.rresp              := AXI_RESP_OK_C;
                    ELSE
                        -- out of range, return with SLVERR
                        vAxiReadSlave.rdata := (OTHERS => '0');
                        vAxiReadSlave.rresp := AXI_RESP_SLVERR_C;
                    END IF;

                END IF;
            END IF;

            -- update output ports
            axiWriteSlave <= vAxiWriteSlave;
            axiReadSlave  <= vAxiReadSlave;
            axiStatusS    <= axiStatus;
        END IF;
    END PROCESS;
END ARCHITECTURE;