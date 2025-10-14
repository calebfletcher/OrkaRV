LIBRARY ieee;
CONTEXT ieee.ieee_std_context;

USE work.RiscVPkg.ALL;

ENTITY Cpu IS
    GENERIC (
        TPD_G : TIME := 1 ns
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

        -- ram write control
        ramAddr : STD_LOGIC_VECTOR(31 DOWNTO 0);
        ramDin : STD_LOGIC_VECTOR(31 DOWNTO 0);
        ramWe : STD_LOGIC;

        -- register write control
        regWrAddr : RegisterIndex;
        regWrData : STD_LOGIC_VECTOR(XLEN - 1 DOWNTO 0);
        regWrStrobe : STD_LOGIC;

        -- alu
        aluResult : STD_LOGIC_VECTOR(31 DOWNTO 0); -- todo: XLEN?

        -- control signals
        opMemWrite : STD_LOGIC;
        opRegWriteSource : RegWriteSourceType;
        opPcFromAlu : STD_LOGIC;

        halt : STD_LOGIC;
    END RECORD RegType;

    CONSTANT REG_INIT_C : RegType := (
        stage => FETCH,
        pc => (OTHERS => '0'),
        successivePc => (OTHERS => '0'),
        instruction => (OTHERS => '0'),
        ramAddr => (OTHERS => '0'),
        ramDin => (OTHERS => '0'),
        ramWe => '0',
        regWrAddr => 0,
        regWrData => (OTHERS => '0'),
        regWrStrobe => '0',
        aluResult => (OTHERS => '0'),
        opMemWrite => '0',
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

                v.successivePc := STD_LOGIC_VECTOR(UNSIGNED(r.pc) + 4);

                v.stage := DECODE;
            WHEN DECODE =>
                -- todo: register decoded instruction here?

                v.opRegWriteSource := NONE_SRC;
                v.opMemWrite := '0';
                v.opPcFromAlu := '0';

                CASE instType IS
                    WHEN LUI =>
                        v.opRegWriteSource := IMMEDIATE_SRC;
                    WHEN ADDI =>
                        v.aluResult := STD_LOGIC_VECTOR(unsigned(rs1Value) + unsigned(immediate));
                        v.opRegWriteSource := ALU_SRC;
                    WHEN ADD =>
                        v.aluResult := STD_LOGIC_VECTOR(unsigned(rs1Value) + unsigned(rs2Value));
                        v.opRegWriteSource := ALU_SRC;
                    WHEN SUB =>
                        v.aluResult := STD_LOGIC_VECTOR(unsigned(rs1Value) - unsigned(rs2Value));
                        v.opRegWriteSource := ALU_SRC;
                    WHEN LW =>
                        v.aluResult := STD_LOGIC_VECTOR(unsigned(rs1Value) + unsigned(immediate));
                        v.opRegWriteSource := MEMORY_SRC;
                    WHEN SW =>
                        v.aluResult := STD_LOGIC_VECTOR(unsigned(rs1Value) + unsigned(immediate));
                        v.opMemWrite := '1';
                    WHEN JAL =>
                        v.aluResult := STD_LOGIC_VECTOR(unsigned(r.pc) + unsigned(immediate));
                        v.opRegWriteSource := SUCC_PC_SRC;
                        v.opPcFromAlu := '1';
                    WHEN JALR =>
                        v.aluResult := STD_LOGIC_VECTOR(unsigned(rs1Value) + unsigned(immediate));
                        v.opRegWriteSource := SUCC_PC_SRC;
                        v.opPcFromAlu := '1';
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
                v.ramAddr := r.aluResult;
                v.ramWe := r.opMemWrite;
                v.ramDin := rs2Value;
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

                v.stage := WRITEBACK;
            WHEN WRITEBACK =>
                -- write to register from alu, ram, or immediate
                v.regWrStrobe := '1' WHEN r.opRegWriteSource /= NONE_SRC ELSE
                '0';
                v.regWrAddr := rd;

                CASE r.opRegWriteSource IS
                    WHEN MEMORY_SRC => v.regWrData := ramDout;
                    WHEN ALU_SRC => v.regWrData := r.aluResult;
                    WHEN IMMEDIATE_SRC => v.regWrData := immediate;
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
            rs1 => rs1,
            rs1Value => rs1Value,
            rs2 => rs2,
            rs2Value => rs2Value,
            wr_addr => r.regWrAddr,
            wr_data => r.regWrData,
            wr_strobe => r.regWrStrobe
        );

    Ram_inst : ENTITY work.Ram
        PORT MAP(
            clk => clk,
            we => r.ramWe,
            -- word-addressed
            addr => r.ramAddr(7 DOWNTO 2),
            di => r.ramDin,
            do => ramDout
        );

    InstructionDecoder_inst : ENTITY work.InstructionDecoder
        PORT MAP(
            instructionType => instType,
            instruction => r.instruction,
            immediate => immediate,
            rs1 => rs1,
            rs2 => rs2,
            rd => rd
        );

END ARCHITECTURE;