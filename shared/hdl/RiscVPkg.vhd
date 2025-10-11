LIBRARY ieee;
CONTEXT ieee.ieee_std_context;

PACKAGE RiscVPkg IS
    CONSTANT XLEN : INTEGER := 32;

    SUBTYPE RegisterIndex IS INTEGER RANGE 0 TO 31;

    TYPE RegistersType IS ARRAY (0 TO 31) OF STD_LOGIC_VECTOR(XLEN - 1 DOWNTO 0);

    TYPE InstructionEncodingType IS (R, I, S, B, U, J);
    TYPE MajorOpcode IS (
        LOAD,
        LOAD_FP,
        MISC_MEM,
        OP_IMM,
        AUIPC,
        OP_IMM_32,
        STORE,
        STORE_FP,
        AMO,
        OP,
        LUI,
        OP_32,
        MADD,
        MSUB,
        NMSUB,
        NMADD,
        OP_FP,
        OP_V,
        BRANCH,
        JALR,
        JAL,
        SYSTEM,
        OP_VE,

        UNKNOWN
    );
    TYPE InstructionType IS (
        LUI, -- LUI
        AUIPC, -- AUIPC
        JAL, -- JAL
        JALR, -- JALR
        BEQ, BNE, BLT, BGE, BLTU, BGEU, -- BRANCH
        LB, LH, LW, LBU, LHU, -- LOAD
        SB, SH, SW, -- STORE
        ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI, -- OP-IMM
        ADD, SUB, \SLL\, SLT, SLTU, \XOR\, \SRL\, \SRA\, \OR\, \AND\, -- OP
        FENCE, FENCE_TSO, PAUSE, -- MISC-MEM
        ECALL, EBREAK, -- SYSTEM

        UNKNOWN
    );

    FUNCTION decodeInstruction (
        instruction : IN STD_LOGIC_VECTOR(31 DOWNTO 0)
    ) RETURN InstructionType;
    FUNCTION instructionToEncoding(inst : IN InstructionType) RETURN InstructionEncodingType;

END PACKAGE;

PACKAGE BODY RiscVPkg IS
    FUNCTION opcodeToMajorOpcode (opcode : IN STD_LOGIC_VECTOR(6 DOWNTO 0)) RETURN MajorOpcode IS
        VARIABLE major : MajorOpcode;
    BEGIN
        CASE opcode(6 DOWNTO 2) IS
            WHEN "00000" => major := LOAD;
            WHEN "00001" => major := LOAD_FP;
            WHEN "00011" => major := MISC_MEM;
            WHEN "00100" => major := OP_IMM;
            WHEN "00101" => major := AUIPC;
            WHEN "00110" => major := OP_IMM_32;
            WHEN "01000" => major := STORE;
            WHEN "01001" => major := STORE_FP;
            WHEN "01011" => major := AMO;
            WHEN "01100" => major := OP;
            WHEN "01101" => major := LUI;
            WHEN "01110" => major := OP_32;
            WHEN "10000" => major := MADD;
            WHEN "10001" => major := MSUB;
            WHEN "10010" => major := NMSUB;
            WHEN "10011" => major := NMADD;
            WHEN "10100" => major := OP_FP;
            WHEN "10101" => major := OP_V;
            WHEN "11000" => major := BRANCH;
            WHEN "11001" => major := JALR;
            WHEN "11011" => major := JAL;
            WHEN "11100" => major := SYSTEM;
            WHEN "11101" => major := OP_VE;

            WHEN OTHERS =>
                major := UNKNOWN;
        END CASE;
        RETURN major;
    END FUNCTION;

    FUNCTION decodeInstruction (
        instruction : IN STD_LOGIC_VECTOR(31 DOWNTO 0)
    ) RETURN InstructionType IS
        VARIABLE inst : InstructionType := UNKNOWN;

        VARIABLE opcode : MajorOpcode;
        VARIABLE funct3 : STD_LOGIC_VECTOR(2 DOWNTO 0);
        VARIABLE funct7 : STD_LOGIC_VECTOR(6 DOWNTO 0);
    BEGIN
        -- extract parts
        opcode := opcodeToMajorOpcode(instruction(6 DOWNTO 0));
        funct3 := instruction(14 DOWNTO 12);
        funct7 := instruction(31 DOWNTO 25);

        -- todo: fence.tso, pause
        CASE opcode IS
            WHEN LOAD =>
                CASE funct3 IS
                    WHEN "000" =>
                        inst := LB;
                    WHEN "001" =>
                        inst := LH;
                    WHEN "010" =>
                        inst := LW;
                    WHEN "100" =>
                        inst := LBU;
                    WHEN "101" =>
                        inst := LHU;
                    WHEN OTHERS =>
                        NULL;
                END CASE;
            WHEN LOAD_FP =>
                NULL;
            WHEN MISC_MEM =>
                CASE funct3 IS
                    WHEN "000" =>
                        inst := FENCE;
                    WHEN OTHERS =>
                        NULL;
                END CASE;
            WHEN OP_IMM =>
                CASE funct3 IS
                    WHEN "000" =>
                        inst := ADDI;
                    WHEN "010" =>
                        inst := SLTI;
                    WHEN "011" =>
                        inst := SLTIU;
                    WHEN "100" =>
                        inst := XORI;
                    WHEN "110" =>
                        inst := ORI;
                    WHEN "111" =>
                        inst := ANDI;
                    WHEN "001" =>
                        CASE funct7 IS
                            WHEN "0000000" =>
                                inst := SLLI;
                            WHEN OTHERS =>
                                NULL;
                        END CASE;
                    WHEN "101" =>
                        CASE funct7 IS
                            WHEN "0000000" =>
                                inst := SRLI;
                            WHEN "0100000" =>
                                inst := SRAI;
                            WHEN OTHERS =>
                                NULL;
                        END CASE;
                    WHEN OTHERS =>
                        NULL;
                END CASE;
            WHEN AUIPC =>
                inst := AUIPC;
            WHEN OP_IMM_32 =>
                NULL;
            WHEN STORE =>
                CASE funct3 IS
                    WHEN "000" =>
                        inst := SB;
                    WHEN "001" =>
                        inst := SH;
                    WHEN "010" =>
                        inst := SW;
                    WHEN OTHERS =>
                        NULL;
                END CASE;
            WHEN STORE_FP =>
                NULL;
            WHEN AMO =>
                NULL;
            WHEN OP =>
                CASE funct3 IS
                    WHEN "000" =>
                        CASE funct7 IS
                            WHEN "0000000" =>
                                inst := ADD;
                            WHEN "0100000" =>
                                inst := SUB;
                            WHEN OTHERS =>
                                NULL;
                        END CASE;
                    WHEN "001" =>
                        CASE funct7 IS
                            WHEN "0000000" =>
                                inst := \SLL\;
                            WHEN OTHERS =>
                                NULL;
                        END CASE;
                    WHEN "010" =>
                        CASE funct7 IS
                            WHEN "0000000" =>
                                inst := SLT;
                            WHEN OTHERS =>
                                NULL;
                        END CASE;
                    WHEN "011" =>
                        CASE funct7 IS
                            WHEN "0000000" =>
                                inst := SLTU;
                            WHEN OTHERS =>
                                NULL;
                        END CASE;
                    WHEN "100" =>
                        CASE funct7 IS
                            WHEN "0000000" =>
                                inst := \XOR\;
                            WHEN OTHERS =>
                                NULL;
                        END CASE;
                    WHEN "101" =>
                        CASE funct7 IS
                            WHEN "0000000" =>
                                inst := \SRL\;
                            WHEN "0100000" =>
                                inst := \SRA\;
                            WHEN OTHERS =>
                                NULL;
                        END CASE;
                    WHEN "110" =>
                        CASE funct7 IS
                            WHEN "0000000" =>
                                inst := \OR\;
                            WHEN OTHERS =>
                                NULL;
                        END CASE;
                    WHEN "111" =>
                        CASE funct7 IS
                            WHEN "0000000" =>
                                inst := \AND\;
                            WHEN OTHERS =>
                                NULL;
                        END CASE;
                    WHEN OTHERS =>
                        NULL;
                END CASE;
            WHEN LUI =>
                inst := LUI;
            WHEN OP_32 =>
                NULL;
            WHEN MADD =>
                NULL;
            WHEN MSUB =>
                NULL;
            WHEN NMSUB =>
                NULL;
            WHEN NMADD =>
                NULL;
            WHEN OP_FP =>
                NULL;
            WHEN OP_V =>
                NULL;
            WHEN BRANCH =>
                CASE funct3 IS
                    WHEN "000" =>
                        inst := BEQ;
                    WHEN "001" =>
                        inst := BNE;
                    WHEN "100" =>
                        inst := BLT;
                    WHEN "101" =>
                        inst := BGE;
                    WHEN "110" =>
                        inst := BLTU;
                    WHEN "111" =>
                        inst := BGEU;
                    WHEN OTHERS =>
                        NULL;
                END CASE;
            WHEN JALR =>
                CASE funct3 IS
                    WHEN "000" =>
                        inst := JALR;
                    WHEN OTHERS =>
                        NULL;
                END CASE;
            WHEN JAL =>
                inst := JAL;
            WHEN SYSTEM =>
                CASE instruction IS
                    WHEN "00000000000000000000000001110011" =>
                        inst := ECALL;
                    WHEN "00000000000100000000000001110011" =>
                        inst := EBREAK;
                    WHEN OTHERS =>
                        NULL;
                END CASE;
            WHEN OP_VE =>
                NULL;

            WHEN OTHERS =>
                NULL;
        END CASE;
        RETURN inst;
    END FUNCTION;

    FUNCTION instructionToEncoding(inst : IN InstructionType) RETURN InstructionEncodingType IS
        VARIABLE encoding : InstructionEncodingType;
    BEGIN
        CASE inst IS
            WHEN LUI => encoding := U;
            WHEN AUIPC => encoding := U;
            WHEN JAL => encoding := J;
            WHEN JALR => encoding := I;

            WHEN BEQ => encoding := B;
            WHEN BNE => encoding := B;
            WHEN BLT => encoding := B;
            WHEN BGE => encoding := B;
            WHEN BLTU => encoding := B;
            WHEN BGEU => encoding := B;

            WHEN LB => encoding := I;
            WHEN LH => encoding := I;
            WHEN LW => encoding := I;
            WHEN LBU => encoding := I;
            WHEN LHU => encoding := I;

            WHEN SB => encoding := S;
            WHEN SH => encoding := S;
            WHEN SW => encoding := S;

            WHEN ADDI => encoding := I;
            WHEN SLTI => encoding := I;
            WHEN SLTIU => encoding := I;
            WHEN XORI => encoding := I;
            WHEN ORI => encoding := I;
            WHEN ANDI => encoding := I;

            WHEN SLLI => encoding := R;
            WHEN SRLI => encoding := R;
            WHEN SRAI => encoding := R;

            WHEN ADD => encoding := R;
            WHEN SUB => encoding := R;
            WHEN \SLL\ => encoding := R;
            WHEN SLT => encoding := R;
            WHEN SLTU => encoding := R;
            WHEN \XOR\ => encoding := R;
            WHEN \SRL\ => encoding := R;
            WHEN \SRA\ => encoding := R;
            WHEN \OR\ => encoding := R;
            WHEN \AND\ => encoding := R;

            WHEN FENCE => encoding := I;
            WHEN FENCE_TSO => encoding := I;
            WHEN PAUSE => encoding := I;

            WHEN OTHERS =>
                encoding := R;
        END CASE;

        RETURN encoding;
    END FUNCTION;

END PACKAGE BODY;