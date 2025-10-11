LIBRARY ieee;
CONTEXT ieee.ieee_std_context;

LIBRARY std;
USE std.textio.ALL;

ENTITY Ram IS
    PORT (
        clk : IN STD_LOGIC;
        we : IN STD_LOGIC;
        addr : IN STD_LOGIC_VECTOR(5 DOWNTO 0);
        di : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        do : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
    );
END ENTITY Ram;

ARCHITECTURE rtl OF Ram IS
    TYPE RamType IS ARRAY (0 TO 63) OF STD_LOGIC_VECTOR(31 DOWNTO 0);
    -- SIGNAL ramValue : RamType := (
    --     0 => X"00000000",
    --     1 => X"00000000",
    --     2 => X"00000000",
    --     3 => X"00000000",
    --     4 => X"00000000",
    --     OTHERS => X"00000000"
    -- );

    IMPURE FUNCTION InitRamFromFile (RamFileName : IN STRING) RETURN RamType IS
        FILE RamFile : text;
        VARIABLE RamFileLine : line;
        VARIABLE RamTemp : RamType := (OTHERS => (OTHERS => '0'));
        VARIABLE status : FILE_OPEN_STATUS;
    BEGIN
        FILE_OPEN(status, RamFile, RamFileName, READ_MODE);
        IF status = OPEN_OK THEN
            FOR I IN RamType'RANGE LOOP
                IF endfile(RamFile) THEN
                    EXIT;
                END IF;
                readline (RamFile, RamFileLine);
                hex_read (RamFileLine, RamTemp(I));
            END LOOP;
            FILE_CLOSE(RamFile);
        ELSE
            REPORT "RAM initialization file '" & RamFileName & "' does not exist!" SEVERITY error;
        END IF;
        RETURN RamTemp;
    END FUNCTION;

    SIGNAL ramValue : RamType := InitRamFromFile("build/program.hex");
BEGIN
    PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF we = '1' THEN
                ramValue(to_integer(unsigned(addr))) <= di;
            END IF;
            do <= ramValue(to_integer(unsigned(addr)));
        END IF;
    END PROCESS;
END ARCHITECTURE;