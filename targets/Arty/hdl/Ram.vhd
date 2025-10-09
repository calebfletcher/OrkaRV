LIBRARY ieee;
CONTEXT ieee.ieee_std_context;

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
    TYPE ram_type IS ARRAY (0 TO 63) OF STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL RAM : ram_type := (
        0 => X"00000000",
        1 => X"00000000",
        2 => X"00000000",
        3 => X"00000000",
        4 => X"00000000",
        OTHERS => X"00000000"
    );
BEGIN
    PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF we = '1' THEN
                RAM(to_integer(unsigned(addr))) <= di;
            END IF;
            do <= RAM(to_integer(unsigned(addr)));
        END IF;
    END PROCESS;
END ARCHITECTURE;