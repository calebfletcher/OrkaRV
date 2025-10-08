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
        CASE instructionEncoding IS
            WHEN R =>
                immediate <= (OTHERS => '0');
            WHEN I =>
                immediate <= STD_LOGIC_VECTOR(resize(signed(instruction(31 DOWNTO 20)), 32));
            WHEN S =>
                immediate <= STD_LOGIC_VECTOR(resize(signed(instruction(31 DOWNTO 25) & instruction(11 DOWNTO 7)), 32));
            WHEN OTHERS =>
                NULL;
        END CASE;
    END PROCESS;

END ARCHITECTURE;