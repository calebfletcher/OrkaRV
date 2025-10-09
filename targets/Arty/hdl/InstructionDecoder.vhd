LIBRARY ieee;
CONTEXT ieee.ieee_std_context;

ENTITY InstructionDecoder IS
    PORT (
        clk : IN STD_LOGIC;
        reset : IN STD_LOGIC;

        instruction : IN STD_LOGIC_VECTOR(31 DOWNTO 0);

        immediate : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
    );
END ENTITY InstructionDecoder;

ARCHITECTURE rtl OF InstructionDecoder IS
    TYPE InstructionEncodingType IS (R, I, S, B, U, J);

    SIGNAL instructionEncoding : InstructionEncodingType;
BEGIN

    PROCESS (ALL)
    BEGIN
        -- extract immediate from instruction
        CASE instructionEncoding IS
            WHEN R =>
                immediate <= (OTHERS => '0');
            WHEN I =>
                immediate(31 DOWNTO 11) <= (OTHERS => instruction(31));
                immediate(10 DOWNTO 0) <= instruction(30 DOWNTO 20);
            WHEN S =>
                immediate(31 DOWNTO 11) <= (OTHERS => instruction(31));
                immediate(10 DOWNTO 5) <= instruction(30 DOWNTO 25);
                immediate(4 DOWNTO 0) <= instruction(11 DOWNTO 7);
            WHEN B =>
                immediate(31 DOWNTO 12) <= (OTHERS => instruction(31));
                immediate(11) <= instruction(7);
                immediate(10 DOWNTO 5) <= instruction(30 DOWNTO 25);
                immediate(4 DOWNTO 1) <= instruction(11 DOWNTO 8);
                immediate(0) <= '0';
            WHEN U =>
                immediate(31 DOWNTO 12) <= instruction(31 DOWNTO 12);
                immediate(11 DOWNTO 0) <= "000000000000";
            WHEN J =>
                immediate(31 DOWNTO 20) <= (OTHERS => instruction(31));
                immediate(19 DOWNTO 12) <= instruction(19 DOWNTO 12);
                immediate(11) <= instruction(20);
                immediate(10 DOWNTO 1) <= instruction(30 DOWNTO 21);
                immediate(0) <= '0';
        END CASE;
    END PROCESS;

END ARCHITECTURE;