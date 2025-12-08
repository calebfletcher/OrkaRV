LIBRARY ieee;
CONTEXT ieee.ieee_std_context;

USE work.RiscVPkg.ALL;

ENTITY InstructionDecoder IS
    PORT (
        instructionType : OUT InstructionType;

        instruction : IN STD_LOGIC_VECTOR(31 DOWNTO 0);

        immediate : OUT STD_LOGIC_VECTOR(XLEN - 1 DOWNTO 0);
        rs1 : OUT RegisterIndex;
        rs2 : OUT RegisterIndex;
        rd : OUT RegisterIndex
    );
END ENTITY InstructionDecoder;

ARCHITECTURE rtl OF InstructionDecoder IS
BEGIN

    PROCESS (ALL)
    BEGIN

        -- map opcodes
        instructionType <= decodeInstruction(instruction);

        -- extract register indexes
        rs1 <= to_integer(unsigned(instruction(19 DOWNTO 15)));
        rs2 <= to_integer(unsigned(instruction(24 DOWNTO 20)));
        rd <= to_integer(unsigned(instruction(11 DOWNTO 7)));

        -- extract immediate
        CASE instruction(6 DOWNTO 2) IS
            WHEN "11001" | "00000" | "00100" | "11100" => -- I
                immediate(31 DOWNTO 11) <= (OTHERS => instruction(31));
                immediate(10 DOWNTO 0) <= instruction(30 DOWNTO 20);
            WHEN "01000" => -- S
                immediate(31 DOWNTO 11) <= (OTHERS => instruction(31));
                immediate(10 DOWNTO 5) <= instruction(30 DOWNTO 25);
                immediate(4 DOWNTO 0) <= instruction(11 DOWNTO 7);
            WHEN "11000" => -- B
                immediate(31 DOWNTO 12) <= (OTHERS => instruction(31));
                immediate(11) <= instruction(7);
                immediate(10 DOWNTO 5) <= instruction(30 DOWNTO 25);
                immediate(4 DOWNTO 1) <= instruction(11 DOWNTO 8);
                immediate(0) <= '0';
            WHEN "01101" | "00101" => -- U
                immediate(31 DOWNTO 12) <= instruction(31 DOWNTO 12);
                immediate(11 DOWNTO 0) <= "000000000000";
            WHEN "11011" => -- J
                immediate(31 DOWNTO 20) <= (OTHERS => instruction(31));
                immediate(19 DOWNTO 12) <= instruction(19 DOWNTO 12);
                immediate(11) <= instruction(20);
                immediate(10 DOWNTO 1) <= instruction(30 DOWNTO 21);
                immediate(0) <= '0';
            WHEN OTHERS =>
                immediate <= (OTHERS => '0');
        END CASE;
    END PROCESS;

END ARCHITECTURE;