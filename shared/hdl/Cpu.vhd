LIBRARY ieee;
CONTEXT ieee.ieee_std_context;

USE work.RiscVPkg.ALL;

ENTITY Cpu IS
    GENERIC (
        TPD_G : TIME := 1 ns;
        RAM_FILE_PATH_G : STRING := "build/program.hex"
    );
    PORT (
        clk : IN STD_LOGIC;
        reset : IN STD_LOGIC;
        halt : OUT STD_LOGIC := '0'
    );
END ENTITY Cpu;

ARCHITECTURE rtl OF Cpu IS
    TYPE StageType IS (FETCH, DECODE, EXECUTE, MEMORY, WRITEBACK);
    TYPE RegWriteSourceType IS (NONE_SRC, MEMORY_SRC, ALU_SRC, IMMEDIATE_SRC, SUCC_PC_SRC);

    TYPE RegType IS RECORD
        stage : StageType;
        -- address of the current instruction, will be updated if there
        -- are jumps
        pc : STD_LOGIC_VECTOR(XLEN - 1 DOWNTO 0);
        -- address of the instruction directly after the current one
        successivePc : STD_LOGIC_VECTOR(XLEN - 1 DOWNTO 0);

        instruction : STD_LOGIC_VECTOR(31 DOWNTO 0);
        immediate : STD_LOGIC_VECTOR(31 DOWNTO 0);
        instType : InstructionType;
        rs1 : RegisterIndex;
        rs2 : RegisterIndex;
        rd : RegisterIndex;

        -- ram write control
        ramAddr : STD_LOGIC_VECTOR(31 DOWNTO 0);
        ramDin : STD_LOGIC_VECTOR(31 DOWNTO 0);
        ramWe : STD_LOGIC;
        ramWrByteEnable : STD_LOGIC_VECTOR(3 DOWNTO 0);

        -- register write control
        regWrAddr : RegisterIndex;
        regWrData : STD_LOGIC_VECTOR(XLEN - 1 DOWNTO 0);
        regWrStrobe : STD_LOGIC;

        -- alu
        aluResult : STD_LOGIC_VECTOR(31 DOWNTO 0); -- todo: XLEN?

        -- control signals
        opMemWrite : STD_LOGIC;
        opMemWriteWidthBytes : NATURAL RANGE 1 TO 4;
        opRegWriteSource : RegWriteSourceType;
        opPcFromAlu : STD_LOGIC;

        halt : STD_LOGIC;
    END RECORD RegType;

    CONSTANT REG_INIT_C : RegType := (
        stage => FETCH,
        pc => (OTHERS => '0'),
        successivePc => (OTHERS => '0'),
        instruction => (OTHERS => '0'),
        immediate => (OTHERS => '0'),
        instType => UNKNOWN,
        rs1 => 0,
        rs2 => 0,
        rd => 0,
        ramAddr => (OTHERS => '0'),
        ramDin => (OTHERS => '0'),
        ramWe => '0',
        ramWrByteEnable => (OTHERS => '0'),
        regWrAddr => 0,
        regWrData => (OTHERS => '0'),
        regWrStrobe => '0',
        aluResult => (OTHERS => '0'),
        opMemWrite => '0',
        opMemWriteWidthBytes => 1,
        opRegWriteSource => NONE_SRC,
        opPcFromAlu => '0',
        halt => '0'
    );

    SIGNAL r : RegType := REG_INIT_C;
    SIGNAL rin : RegType;

    -- intermediate signals
    SIGNAL ramDout : STD_LOGIC_VECTOR(31 DOWNTO 0);

    SIGNAL rs1 : RegisterIndex;
    SIGNAL rs2 : RegisterIndex;
    SIGNAL rd : RegisterIndex;
    SIGNAL rs1Value : STD_LOGIC_VECTOR(XLEN - 1 DOWNTO 0);
    SIGNAL rs2Value : STD_LOGIC_VECTOR(XLEN - 1 DOWNTO 0);
    SIGNAL immediate : STD_LOGIC_VECTOR(XLEN - 1 DOWNTO 0);

    SIGNAL instType : InstructionType;
BEGIN
    PROCESS (ALL)
        VARIABLE v : regType;
    BEGIN
        -- initialise from existing state
        v := r;

        v.regWrStrobe := '0';

        CASE (r.stage) IS
            WHEN FETCH =>
                v.instruction := ramDout;
                v.immediate := immediate;
                v.instType := instType;
                v.rs1 := rs1;
                v.rs2 := rs2;
                v.rd := rd;

                v.successivePc := STD_LOGIC_VECTOR(UNSIGNED(r.pc) + 4);

                v.stage := DECODE;
            WHEN DECODE =>
                -- todo: register decoded instruction here?

                v.opRegWriteSource := NONE_SRC;
                v.opMemWrite := '0';
                v.opMemWriteWidthBytes := 1;
                v.opPcFromAlu := '0';

                CASE r.instType IS
                    WHEN LUI =>
                        v.opRegWriteSource := IMMEDIATE_SRC;
                    WHEN AUIPC =>
                        v.aluResult := STD_LOGIC_VECTOR(unsigned(r.pc) + unsigned(r.immediate));
                        v.opRegWriteSource := ALU_SRC;
                    WHEN ADDI =>
                        v.aluResult := STD_LOGIC_VECTOR(unsigned(rs1Value) + unsigned(r.immediate));
                        v.opRegWriteSource := ALU_SRC;
                    WHEN SLTI =>
                        v.aluResult := (OTHERS => '0');
                        v.aluResult(0) := '1' WHEN signed(rs1Value) < signed(r.immediate) ELSE
                        '0';
                        v.opRegWriteSource := ALU_SRC;
                    WHEN SLTIU =>
                        v.aluResult := (OTHERS => '0');
                        v.aluResult(0) := '1' WHEN unsigned(rs1Value) < unsigned(r.immediate) ELSE
                        '0';
                        v.opRegWriteSource := ALU_SRC;
                    WHEN ANDI =>
                        v.aluResult := rs1Value AND r.immediate;
                        v.opRegWriteSource := ALU_SRC;
                    WHEN ORI =>
                        v.aluResult := rs1Value OR r.immediate;
                        v.opRegWriteSource := ALU_SRC;
                    WHEN XORI =>
                        v.aluResult := rs1Value XOR r.immediate;
                        v.opRegWriteSource := ALU_SRC;
                    WHEN SLLI =>
                        v.aluResult := STD_LOGIC_VECTOR(SHIFT_LEFT(unsigned(rs1Value), to_integer(unsigned(r.immediate(4 DOWNTO 0)))));
                        v.opRegWriteSource := ALU_SRC;
                    WHEN SRLI =>
                        v.aluResult := STD_LOGIC_VECTOR(SHIFT_RIGHT(unsigned(rs1Value), to_integer(unsigned(r.immediate(4 DOWNTO 0)))));
                        v.opRegWriteSource := ALU_SRC;
                    WHEN SRAI =>
                        v.aluResult := STD_LOGIC_VECTOR(SHIFT_RIGHT(signed(rs1Value), to_integer(unsigned(r.immediate(4 DOWNTO 0)))));
                        v.opRegWriteSource := ALU_SRC;
                    WHEN ADD =>
                        v.aluResult := STD_LOGIC_VECTOR(unsigned(rs1Value) + unsigned(rs2Value));
                        v.opRegWriteSource := ALU_SRC;
                    WHEN SLT =>
                        v.aluResult := (OTHERS => '0');
                        v.aluResult(0) := '1' WHEN signed(rs1Value) < signed(rs2Value) ELSE
                        '0';
                        v.opRegWriteSource := ALU_SRC;
                    WHEN SLTU =>
                        v.aluResult := (OTHERS => '0');
                        v.aluResult(0) := '1' WHEN unsigned(rs1Value) < unsigned(rs2Value) ELSE
                        '0';
                        v.opRegWriteSource := ALU_SRC;
                    WHEN \AND\ =>
                        v.aluResult := rs1Value AND rs2Value;
                        v.opRegWriteSource := ALU_SRC;
                    WHEN \OR\ =>
                        v.aluResult := rs1Value OR rs2Value;
                        v.opRegWriteSource := ALU_SRC;
                    WHEN \XOR\ =>
                        v.aluResult := rs1Value XOR rs2Value;
                        v.opRegWriteSource := ALU_SRC;
                    WHEN \SLL\ =>
                        v.aluResult := STD_LOGIC_VECTOR(SHIFT_LEFT(unsigned(rs1Value), to_integer(unsigned(rs2Value(4 DOWNTO 0)))));
                        v.opRegWriteSource := ALU_SRC;
                    WHEN \SRL\ =>
                        v.aluResult := STD_LOGIC_VECTOR(SHIFT_RIGHT(unsigned(rs1Value), to_integer(unsigned(rs2Value(4 DOWNTO 0)))));
                        v.opRegWriteSource := ALU_SRC;
                    WHEN SUB =>
                        v.aluResult := STD_LOGIC_VECTOR(unsigned(rs1Value) - unsigned(rs2Value));
                        v.opRegWriteSource := ALU_SRC;
                    WHEN \SRA\ =>
                        v.aluResult := STD_LOGIC_VECTOR(SHIFT_RIGHT(signed(rs1Value), to_integer(unsigned(rs2Value(4 DOWNTO 0)))));
                        v.opRegWriteSource := ALU_SRC;
                    WHEN LB | LH | LW | LBU | LHU =>
                        -- todo: read strobes on ram
                        v.aluResult := STD_LOGIC_VECTOR(unsigned(rs1Value) + unsigned(r.immediate));
                        v.opRegWriteSource := MEMORY_SRC;
                    WHEN SW =>
                        v.aluResult := STD_LOGIC_VECTOR(unsigned(rs1Value) + unsigned(r.immediate));
                        v.opMemWrite := '1';
                        v.opMemWriteWidthBytes := 4;
                    WHEN SH =>
                        v.aluResult := STD_LOGIC_VECTOR(unsigned(rs1Value) + unsigned(r.immediate));
                        v.opMemWrite := '1';
                        v.opMemWriteWidthBytes := 2;
                    WHEN SB =>
                        v.aluResult := STD_LOGIC_VECTOR(unsigned(rs1Value) + unsigned(r.immediate));
                        v.opMemWrite := '1';
                        v.opMemWriteWidthBytes := 1;
                    WHEN JAL =>
                        v.aluResult := STD_LOGIC_VECTOR(unsigned(r.pc) + unsigned(r.immediate));
                        v.opRegWriteSource := SUCC_PC_SRC;
                        v.opPcFromAlu := '1';
                    WHEN JALR =>
                        v.aluResult := STD_LOGIC_VECTOR(unsigned(rs1Value) + unsigned(r.immediate));
                        v.opRegWriteSource := SUCC_PC_SRC;
                        v.opPcFromAlu := '1';
                    WHEN BEQ =>
                        v.aluResult := STD_LOGIC_VECTOR(unsigned(r.pc) + unsigned(r.immediate));
                        v.opPcFromAlu := '1' WHEN rs1Value = rs2Value ELSE
                        '0';
                    WHEN BNE =>
                        v.aluResult := STD_LOGIC_VECTOR(unsigned(r.pc) + unsigned(r.immediate));
                        v.opPcFromAlu := '1' WHEN rs1Value /= rs2Value ELSE
                        '0';
                    WHEN BLT =>
                        v.aluResult := STD_LOGIC_VECTOR(unsigned(r.pc) + unsigned(r.immediate));
                        v.opPcFromAlu := '1' WHEN SIGNED(rs1Value) < SIGNED(rs2Value) ELSE
                        '0';
                    WHEN BLTU =>
                        v.aluResult := STD_LOGIC_VECTOR(unsigned(r.pc) + unsigned(r.immediate));
                        v.opPcFromAlu := '1' WHEN UNSIGNED(rs1Value) < UNSIGNED(rs2Value) ELSE
                        '0';
                    WHEN BGE =>
                        v.aluResult := STD_LOGIC_VECTOR(unsigned(r.pc) + unsigned(r.immediate));
                        v.opPcFromAlu := '1' WHEN SIGNED(rs1Value) >= SIGNED(rs2Value) ELSE
                        '0';
                    WHEN BGEU =>
                        v.aluResult := STD_LOGIC_VECTOR(unsigned(r.pc) + unsigned(r.immediate));
                        v.opPcFromAlu := '1' WHEN UNSIGNED(rs1Value) >= UNSIGNED(rs2Value) ELSE
                        '0';
                    WHEN OTHERS =>
                        -- on unknown instruction, halt
                        v.halt := '1';
                        NULL;
                END CASE;

                v.stage := EXECUTE;
            WHEN EXECUTE =>
                --v.alu_result := ;
                v.stage := MEMORY;

                -- prepare memory ops in advance due to the memory latency
                v.ramAddr := (OTHERS => '0');
                v.ramAddr(31 DOWNTO 2) := r.aluResult(31 DOWNTO 2);
                v.ramWe := r.opMemWrite;

                v.ramWrByteEnable := "0000";
                v.ramDin := (OTHERS => '0');
                CASE r.opMemWriteWidthBytes IS
                    WHEN 1 =>
                        FOR i IN 0 TO 3 LOOP
                            IF v.aluResult(1 DOWNTO 0) = STD_LOGIC_VECTOR(to_unsigned(i, 2)) THEN
                                v.ramWrByteEnable(i) := '1';
                                v.ramDin((i + 1) * 8 - 1 DOWNTO i * 8) := rs2Value(7 DOWNTO 0);
                            END IF;
                        END LOOP;
                    WHEN 2 =>
                        IF v.aluResult(1) THEN
                            v.ramWrByteEnable := "1100";
                            v.ramDin(31 DOWNTO 16) := rs2Value(15 DOWNTO 0);
                        ELSE
                            v.ramWrByteEnable := "0011";
                            v.ramDin(15 DOWNTO 0) := rs2Value(15 DOWNTO 0);
                        END IF;
                    WHEN 3 =>
                        -- invalid (3 bytes)
                        v.ramWrByteEnable := "0000";
                    WHEN 4 =>
                        v.ramWrByteEnable := "1111";
                        v.ramDin := rs2Value;
                END CASE;
            WHEN MEMORY =>
                IF v.opPcFromAlu THEN
                    v.pc := r.aluResult(31 DOWNTO 1) & "0";
                ELSE
                    v.pc := r.successivePc;
                END IF;

                -- prepare ram read for fetch in advance due to the memory latency
                -- use v.nextPc so it takes into account jumps
                v.ramAddr := v.pc;
                v.ramWe := '0';
                v.ramWrByteEnable := (OTHERS => '0');

                v.stage := WRITEBACK;
            WHEN WRITEBACK =>
                -- write to register from alu, ram, or immediate
                v.regWrStrobe := '1' WHEN r.opRegWriteSource /= NONE_SRC ELSE
                '0';
                v.regWrAddr := r.rd;

                CASE r.opRegWriteSource IS
                    WHEN MEMORY_SRC =>
                        CASE r.instType IS
                            WHEN LB =>
                                CASE r.aluResult(1 DOWNTO 0) IS
                                    WHEN "00" =>
                                        v.regWrData := STD_LOGIC_VECTOR(resize(signed(ramDout(7 DOWNTO 0)), XLEN));
                                    WHEN "01" =>
                                        v.regWrData := STD_LOGIC_VECTOR(resize(signed(ramDout(15 DOWNTO 8)), XLEN));
                                    WHEN "10" =>
                                        v.regWrData := STD_LOGIC_VECTOR(resize(signed(ramDout(23 DOWNTO 16)), XLEN));
                                    WHEN "11" =>
                                        v.regWrData := STD_LOGIC_VECTOR(resize(signed(ramDout(31 DOWNTO 24)), XLEN));
                                    WHEN OTHERS =>
                                        v.regWrData := (OTHERS => '0');
                                END CASE;
                            WHEN LH =>
                                IF r.aluResult(1) THEN
                                    v.regWrData := STD_LOGIC_VECTOR(resize(signed(ramDout(31 DOWNTO 16)), XLEN));
                                ELSE
                                    v.regWrData := STD_LOGIC_VECTOR(resize(signed(ramDout(15 DOWNTO 0)), XLEN));
                                END IF;
                            WHEN LW =>
                                v.regWrData := ramDout;
                            WHEN LBU =>
                                CASE r.aluResult(1 DOWNTO 0) IS
                                    WHEN "00" =>
                                        v.regWrData := STD_LOGIC_VECTOR(resize(unsigned(ramDout(7 DOWNTO 0)), XLEN));
                                    WHEN "01" =>
                                        v.regWrData := STD_LOGIC_VECTOR(resize(unsigned(ramDout(15 DOWNTO 8)), XLEN));
                                    WHEN "10" =>
                                        v.regWrData := STD_LOGIC_VECTOR(resize(unsigned(ramDout(23 DOWNTO 16)), XLEN));
                                    WHEN "11" =>
                                        v.regWrData := STD_LOGIC_VECTOR(resize(unsigned(ramDout(31 DOWNTO 24)), XLEN));
                                    WHEN OTHERS =>
                                        v.regWrData := (OTHERS => '0');
                                END CASE;
                            WHEN LHU =>
                                IF r.aluResult(1) THEN
                                    v.regWrData := STD_LOGIC_VECTOR(resize(unsigned(ramDout(31 DOWNTO 16)), XLEN));
                                ELSE
                                    v.regWrData := STD_LOGIC_VECTOR(resize(unsigned(ramDout(15 DOWNTO 0)), XLEN));
                                END IF;
                            WHEN OTHERS =>
                                NULL;
                        END CASE;
                    WHEN ALU_SRC => v.regWrData := r.aluResult;
                    WHEN IMMEDIATE_SRC => v.regWrData := r.immediate;
                    WHEN SUCC_PC_SRC => v.regWrData := r.successivePc;
                    WHEN OTHERS =>
                        v.regWrData := (OTHERS => '0');
                END CASE;

                v.stage := FETCH;
        END CASE;

        IF reset THEN
            v := REG_INIT_C;
        END IF;

        -- set nextstate
        rin <= v;

        -- update outputs
        halt <= r.halt;
    END PROCESS;

    PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN
            r <= rin AFTER TPD_G;
        END IF;
    END PROCESS;

    Registers_inst : ENTITY work.Registers
        PORT MAP(
            clk => clk,
            reset => reset,
            rs1 => r.rs1,
            rs1Value => rs1Value,
            rs2 => r.rs2,
            rs2Value => rs2Value,
            wr_addr => r.regWrAddr,
            wr_data => r.regWrData,
            wr_strobe => r.regWrStrobe
        );

    Ram_inst : ENTITY work.Ram
        GENERIC MAP(
            RAM_FILE_PATH_G => RAM_FILE_PATH_G
        )
        PORT MAP(
            clk => clk,
            we => r.ramWe,
            byteWrite => r.ramWrByteEnable,
            -- word-addressed
            addr => r.ramAddr(13 DOWNTO 2),
            di => r.ramDin,
            do => ramDout
        );

    InstructionDecoder_inst : ENTITY work.InstructionDecoder
        PORT MAP(
            instructionType => instType,
            instruction => ramDout,
            immediate => immediate,
            rs1 => rs1,
            rs2 => rs2,
            rd => rd
        );

END ARCHITECTURE;