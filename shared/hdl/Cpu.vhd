LIBRARY ieee;
CONTEXT ieee.ieee_std_context;

USE work.RiscVPkg.ALL;

LIBRARY surf;
USE surf.AxiLitePkg.ALL;

ENTITY Cpu IS
    GENERIC (
        TPD_G : TIME := 1 ns
    );
    PORT (
        clk : IN STD_LOGIC;
        reset : IN STD_LOGIC;
        halt : OUT STD_LOGIC := '0';

        -- memory interface
        axiReadMaster : OUT AxiLiteReadMasterType := AXI_LITE_READ_MASTER_INIT_C;
        axiReadSlave : IN AxiLiteReadSlaveType := AXI_LITE_READ_SLAVE_INIT_C;
        axiWriteMaster : OUT AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
        axiWriteSlave : IN AxiLiteWriteSlaveType := AXI_LITE_WRITE_SLAVE_INIT_C
    );
END ENTITY Cpu;

ARCHITECTURE rtl OF Cpu IS
    TYPE StageType IS (INIT, FETCH, DECODE, EXECUTE, MEMORY, WRITEBACK, HALTED);
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
        axiReadMaster : AxiLiteReadMasterType;
        axiWriteMaster : AxiLiteWriteMasterType;
        memReadData : STD_LOGIC_VECTOR(31 DOWNTO 0);

        -- register write control
        regWrAddr : RegisterIndex;
        regWrData : STD_LOGIC_VECTOR(XLEN - 1 DOWNTO 0);
        regWrStrobe : STD_LOGIC;

        -- alu
        aluResult : STD_LOGIC_VECTOR(31 DOWNTO 0); -- todo: XLEN?

        -- control signal
        opMemRead : STD_LOGIC;
        opMemWrite : STD_LOGIC;
        opMemWriteWidthBytes : NATURAL RANGE 1 TO 4;
        opRegWriteSource : RegWriteSourceType;
        opPcFromAlu : STD_LOGIC;
    END RECORD RegType;

    CONSTANT REG_INIT_C : RegType := (
        stage => INIT,
        pc => x"01000000", -- reset vector
        successivePc => (OTHERS => '0'),
        instruction => (OTHERS => '0'),
        immediate => (OTHERS => '0'),
        instType => UNKNOWN,
        rs1 => 0,
        rs2 => 0,
        rd => 0,
        -- axi read master defaults to reading addr 0 for first fetch
        axiReadMaster => AXI_LITE_READ_MASTER_INIT_C,
        axiWriteMaster => AXI_LITE_WRITE_MASTER_INIT_C,
        memReadData => (OTHERS => '0'),
        regWrAddr => 0,
        regWrData => (OTHERS => '0'),
        regWrStrobe => '0',
        aluResult => (OTHERS => '0'),
        opMemRead => '0',
        opMemWrite => '0',
        opMemWriteWidthBytes => 1,
        opRegWriteSource => NONE_SRC,
        opPcFromAlu => '0'
    );

    SIGNAL r : RegType := REG_INIT_C;
    SIGNAL rin : RegType;

    -- intermediate signals
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

        -- accept axi-lite transactions
        IF (axiReadSlave.arready AND r.axiReadMaster.arvalid) THEN
            v.axiReadMaster.arvalid := '0';
            v.axiReadMaster.araddr := (OTHERS => '0');
        END IF;
        IF (axiReadSlave.rvalid AND r.axiReadMaster.rready) THEN
            v.axiReadMaster.rready := '0';
        END IF;
        IF (axiWriteSlave.awready AND r.axiWriteMaster.awvalid) THEN
            v.axiWriteMaster.awvalid := '0';
            v.axiWriteMaster.awaddr := (OTHERS => '0');
        END IF;
        IF (axiWriteSlave.wready AND r.axiWriteMaster.wvalid) THEN
            v.axiWriteMaster.wvalid := '0';
            v.axiWriteMaster.wdata := (OTHERS => '0');
        END IF;
        IF (axiWriteSlave.bvalid AND r.axiWriteMaster.bready) THEN
            v.axiWriteMaster.bready := '0';
        END IF;

        CASE (r.stage) IS
            WHEN INIT =>
                -- initial read of the pc to start the cpu running
                v.axiReadMaster.arvalid := '1';
                v.axiReadMaster.araddr := v.pc;

                v.stage := FETCH;
            WHEN FETCH =>
                IF (r.axiReadMaster.rready AND axiReadSlave.rvalid) THEN
                    IF axiReadSlave.rresp = AXI_RESP_OK_C THEN
                        v.instruction := axiReadSlave.rdata;
                        v.immediate := immediate;
                        v.instType := instType;
                        v.rs1 := rs1;
                        v.rs2 := rs2;
                        v.rd := rd;

                        v.successivePc := STD_LOGIC_VECTOR(UNSIGNED(r.pc) + 4);

                        v.stage := DECODE;
                    ELSE
                        v.stage := HALTED;
                    END IF;
                END IF;
            WHEN DECODE =>
                -- todo: register decoded instruction here?

                v.opMemRead := '0';
                v.opRegWriteSource := NONE_SRC;
                v.opMemWrite := '0';
                v.opMemWriteWidthBytes := 1;
                v.opPcFromAlu := '0';

                v.stage := EXECUTE;

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
                        v.opMemRead := '1';
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
                        v.stage := HALTED;
                        NULL;
                END CASE;
            WHEN EXECUTE =>
                -- update PC
                IF v.opPcFromAlu THEN
                    v.pc := r.aluResult(31 DOWNTO 1) & "0";
                ELSE
                    v.pc := r.successivePc;
                END IF;

                -- skip memory stage if we aren't doing any memory ops
                IF r.opMemRead OR r.opMemWrite THEN
                    v.stage := MEMORY;
                ELSE
                    v.stage := WRITEBACK;

                    -- prepare ram read for fetch in advance due to the memory latency
                    v.axiReadMaster.arvalid := '1';
                    v.axiReadMaster.araddr := v.pc;
                    v.axiReadMaster.rready := '1';
                END IF;

                -- prepare memory ops in advance due to the memory latency
                IF r.opMemRead THEN
                    v.axiReadMaster.araddr := (OTHERS => '0');
                    v.axiReadMaster.araddr(31 DOWNTO 2) := r.aluResult(31 DOWNTO 2);
                    v.axiReadMaster.arvalid := '1';

                    v.axiReadMaster.rready := '1';
                END IF;

                IF r.opMemWrite THEN
                    v.axiWriteMaster.awaddr := (OTHERS => '0');
                    v.axiWriteMaster.awaddr(31 DOWNTO 2) := r.aluResult(31 DOWNTO 2);
                    v.axiWriteMaster.awvalid := '1';

                    v.axiWriteMaster.wstrb := "0000";
                    v.axiWriteMaster.wdata := (OTHERS => '0');
                    v.axiWriteMaster.wvalid := '1';

                    v.axiWriteMaster.bready := '1';
                END IF;

                -- set wstrb and wdata for mem write
                CASE r.opMemWriteWidthBytes IS
                    WHEN 1 =>
                        FOR i IN 0 TO 3 LOOP
                            IF v.aluResult(1 DOWNTO 0) = STD_LOGIC_VECTOR(to_unsigned(i, 2)) THEN
                                v.axiWriteMaster.wstrb(i) := '1';
                                v.axiWriteMaster.wdata((i + 1) * 8 - 1 DOWNTO i * 8) := rs2Value(7 DOWNTO 0);
                            END IF;
                        END LOOP;
                    WHEN 2 =>
                        IF v.aluResult(1) THEN
                            v.axiWriteMaster.wstrb := "1100";
                            v.axiWriteMaster.wdata(31 DOWNTO 16) := rs2Value(15 DOWNTO 0);
                        ELSE
                            v.axiWriteMaster.wstrb := "0011";
                            v.axiWriteMaster.wdata(15 DOWNTO 0) := rs2Value(15 DOWNTO 0);
                        END IF;
                    WHEN 3 =>
                        -- invalid (3 bytes)
                        v.axiWriteMaster.wstrb := "0000";
                    WHEN 4 =>
                        v.axiWriteMaster.wstrb := "1111";
                        v.axiWriteMaster.wdata := rs2Value;
                END CASE;
            WHEN MEMORY =>
                -- once mem transaction completes
                IF r.opMemWrite AND r.axiWriteMaster.bready AND axiWriteSlave.bvalid THEN
                    IF axiWriteSlave.bresp = AXI_RESP_OK_C THEN
                        -- prepare ram read for fetch in advance due to the memory latency
                        v.axiReadMaster.arvalid := '1';
                        v.axiReadMaster.araddr := v.pc;
                        v.axiReadMaster.rready := '1';

                        v.stage := WRITEBACK;
                    ELSE
                        v.stage := HALTED;
                    END IF;
                END IF;
                IF r.opMemRead AND r.axiReadMaster.rready AND axiReadSlave.rvalid THEN
                    IF axiReadSlave.rresp = AXI_RESP_OK_C THEN
                        -- register read data
                        v.memReadData := axiReadSlave.rdata;

                        -- prepare ram read for fetch in advance due to the memory latency
                        v.axiReadMaster.arvalid := '1';
                        v.axiReadMaster.araddr := v.pc;
                        v.axiReadMaster.rready := '1';

                        v.stage := WRITEBACK;
                    ELSE
                        v.stage := HALTED;
                    END IF;
                END IF;
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
                                        v.regWrData := STD_LOGIC_VECTOR(resize(signed(r.memReadData(7 DOWNTO 0)), XLEN));
                                    WHEN "01" =>
                                        v.regWrData := STD_LOGIC_VECTOR(resize(signed(r.memReadData(15 DOWNTO 8)), XLEN));
                                    WHEN "10" =>
                                        v.regWrData := STD_LOGIC_VECTOR(resize(signed(r.memReadData(23 DOWNTO 16)), XLEN));
                                    WHEN "11" =>
                                        v.regWrData := STD_LOGIC_VECTOR(resize(signed(r.memReadData(31 DOWNTO 24)), XLEN));
                                    WHEN OTHERS =>
                                        v.regWrData := (OTHERS => '0');
                                END CASE;
                            WHEN LH =>
                                IF r.aluResult(1) THEN
                                    v.regWrData := STD_LOGIC_VECTOR(resize(signed(r.memReadData(31 DOWNTO 16)), XLEN));
                                ELSE
                                    v.regWrData := STD_LOGIC_VECTOR(resize(signed(r.memReadData(15 DOWNTO 0)), XLEN));
                                END IF;
                            WHEN LW =>
                                v.regWrData := r.memReadData;
                            WHEN LBU =>
                                CASE r.aluResult(1 DOWNTO 0) IS
                                    WHEN "00" =>
                                        v.regWrData := STD_LOGIC_VECTOR(resize(unsigned(r.memReadData(7 DOWNTO 0)), XLEN));
                                    WHEN "01" =>
                                        v.regWrData := STD_LOGIC_VECTOR(resize(unsigned(r.memReadData(15 DOWNTO 8)), XLEN));
                                    WHEN "10" =>
                                        v.regWrData := STD_LOGIC_VECTOR(resize(unsigned(r.memReadData(23 DOWNTO 16)), XLEN));
                                    WHEN "11" =>
                                        v.regWrData := STD_LOGIC_VECTOR(resize(unsigned(r.memReadData(31 DOWNTO 24)), XLEN));
                                    WHEN OTHERS =>
                                        v.regWrData := (OTHERS => '0');
                                END CASE;
                            WHEN LHU =>
                                IF r.aluResult(1) THEN
                                    v.regWrData := STD_LOGIC_VECTOR(resize(unsigned(r.memReadData(31 DOWNTO 16)), XLEN));
                                ELSE
                                    v.regWrData := STD_LOGIC_VECTOR(resize(unsigned(r.memReadData(15 DOWNTO 0)), XLEN));
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
            WHEN HALTED =>
                -- do nothing
        END CASE;

        IF reset THEN
            v := REG_INIT_C;
        END IF;

        -- set nextstate
        rin <= v;

        -- update outputs
        halt <= '1' WHEN r.stage = HALTED ELSE
            '0';
        axiReadMaster <= r.axiReadMaster;
        axiWriteMaster <= r.axiWriteMaster;
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

    InstructionDecoder_inst : ENTITY work.InstructionDecoder
        PORT MAP(
            instructionType => instType,
            instruction => axiReadSlave.rdata,
            immediate => immediate,
            rs1 => rs1,
            rs2 => rs2,
            rd => rd
        );

END ARCHITECTURE;