LIBRARY ieee;
CONTEXT ieee.ieee_std_context;

PACKAGE JtagPkg IS
    GENERIC (
        CONSTANT IR_LENGTH_C : NATURAL := 5
    );

    CONSTANT IR_DEFAULT_C : STD_LOGIC_VECTOR(IR_LENGTH_C - 1 DOWNTO 0) := (IR_LENGTH_C - 1 DOWNTO 1 => '0', 0 => '1');

    TYPE JtagInterface IS RECORD
        ir : STD_LOGIC_VECTOR(IR_LENGTH_C - 1 DOWNTO 0);
    END RECORD;

    TYPE Instruction IS RECORD
        instruction : STD_LOGIC_VECTOR(IR_LENGTH_C - 1 DOWNTO 0);
        reg : STD_LOGIC_VECTOR;
    END RECORD;
END PACKAGE;