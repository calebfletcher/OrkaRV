LIBRARY ieee;
CONTEXT ieee.ieee_std_context;

USE work.RiscVPkg.ALL;
USE work.csrif_pkg.ALL;
USE work.CsrRegisters_pkg.ALL;

LIBRARY surf;
USE surf.AxiLitePkg.ALL;

ENTITY Cpu IS
    GENERIC (
        TPD_G : TIME := 1 ns
    );
    PORT (
        clk   : IN STD_LOGIC;
        reset : IN STD_LOGIC;
        halt  : OUT STD_LOGIC := '0';
        trap  : OUT STD_LOGIC := '0';

        -- memory interface
        axiReadMaster  : OUT AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
        axiReadSlave   : IN AxiLiteReadSlaveType    := AXI_LITE_READ_SLAVE_INIT_C;
        axiWriteMaster : OUT AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
        axiWriteSlave  : IN AxiLiteWriteSlaveType   := AXI_LITE_WRITE_SLAVE_INIT_C;

        -- interrupts
        mExtInt : IN STD_LOGIC
    );
END ENTITY Cpu;

ARCHITECTURE rtl OF Cpu IS
    TYPE StageType IS (INIT, FETCH, DECODE, EXECUTE, MEMORY, WRITEBACK, HALTED, TRAPPED);
    TYPE RegWriteSourceType IS (NONE_SRC, MEMORY_SRC, ALU_SRC, IMMEDIATE_SRC, SUCC_PC_SRC, CSR_SRC);

    TYPE RegType IS RECORD
        stage : StageType;
        -- address of the current instruction, will be updated if there
        -- are jumps
        pc : STD_LOGIC_VECTOR(XLEN - 1 DOWNTO 0);
        -- address of the instruction directly after the current one
        successivePc : STD_LOGIC_VECTOR(XLEN - 1 DOWNTO 0);

        instruction : STD_LOGIC_VECTOR(31 DOWNTO 0);
        immediate   : STD_LOGIC_VECTOR(31 DOWNTO 0);
        instType    : InstructionType;
        rs1         : RegisterIndex;
        rs2         : RegisterIndex;
        rd          : RegisterIndex;

        -- ram write control
        axiReadMaster  : AxiLiteReadMasterType;
        axiWriteMaster : AxiLiteWriteMasterType;
        memReadData    : STD_LOGIC_VECTOR(31 DOWNTO 0);

        -- register write control
        regWrAddr   : RegisterIndex;
        regWrData   : STD_LOGIC_VECTOR(XLEN - 1 DOWNTO 0);
        regWrStrobe : STD_LOGIC;

        -- csr write control
        currentPrivilege : Privilege;
        csrReq           : STD_LOGIC;
        csrOp            : csr_access_op;
        csrAddr          : STD_LOGIC_VECTOR(11 DOWNTO 0);
        csrWrData        : STD_LOGIC_VECTOR(XLEN - 1 DOWNTO 0);
        csrRdData        : STD_LOGIC_VECTOR(XLEN - 1 DOWNTO 0);

        -- csr hardware inputs
        csrHwIn : CsrRegisters_in_t;

        -- alu
        aluResult : STD_LOGIC_VECTOR(31 DOWNTO 0); -- todo: XLEN?

        -- control signal
        opMemRead            : STD_LOGIC;
        opMemWrite           : STD_LOGIC;
        opMemWriteWidthBytes : NATURAL RANGE 1 TO 4;
        opRegWriteSource     : RegWriteSourceType;
        opPcFromAlu          : STD_LOGIC;
        opPcFromMepcCsr      : STD_LOGIC;
    END RECORD RegType;

    CONSTANT CSR_IN_INIT_C : CsrRegisters_in_t := (
    mstatus => (
    mie     => (
    next_q  => '0',
    we      => '0'
    ),
    mpie   => (
    next_q => '0',
    we     => '0'
    ),
    mpp    => (
    next_q => PRIV_MACHINE_C,
    we     => '0'
    )
    ),
    mepc => (
    mepc => (
    next_q => (OTHERS => '0'),
    we   => '0'
    )
    ),
    mcause => (
    code   => (
    next_q => (OTHERS => '0'),
    we     => '0'
    ),
    interrupt => (
    next_q    => '0',
    we        => '0'
    )
    ),
    mtval => (
    mtval => (
    next_q => (OTHERS => '0'),
    we    => '0'
    )
    ),
    mip    => (
    meip   => (
    next_q => '0'
    )
    )
    );

    CONSTANT REG_INIT_C : RegType := (
    stage    => INIT,
    pc       => x"01000000", -- reset vector
    successivePc => (OTHERS => '0'),
    instruction => (OTHERS => '0'),
    immediate => (OTHERS => '0'),
    instType => UNKNOWN,
    rs1      => 0,
    rs2      => 0,
    rd       => 0,
    -- axi read master defaults to reading addr 0 for first fetch
    axiReadMaster  => AXI_LITE_READ_MASTER_INIT_C,
    axiWriteMaster => AXI_LITE_WRITE_MASTER_INIT_C,
    memReadData => (OTHERS => '0'),
    regWrAddr      => 0,
    regWrData => (OTHERS => '0'),
    regWrStrobe    => '0',

    currentPrivilege => PRIV_MACHINE_C,
    csrReq           => '0',
    csrOp            => OP_READ,
    csrAddr => (OTHERS => '0'),
    csrWrData => (OTHERS => '0'),
    csrRdData => (OTHERS => '0'),

    csrHwIn => CSR_IN_INIT_C,

    aluResult => (OTHERS => '0'),
    opMemRead            => '0',
    opMemWrite           => '0',
    opMemWriteWidthBytes => 1,
    opRegWriteSource     => NONE_SRC,
    opPcFromAlu          => '0',
    opPcFromMepcCsr      => '0'
    );

    SIGNAL r   : RegType := REG_INIT_C;
    SIGNAL rin : RegType;

    -- intermediate signals
    SIGNAL rs1       : RegisterIndex;
    SIGNAL rs2       : RegisterIndex;
    SIGNAL rd        : RegisterIndex;
    SIGNAL rs1Value  : STD_LOGIC_VECTOR(XLEN - 1 DOWNTO 0);
    SIGNAL rs2Value  : STD_LOGIC_VECTOR(XLEN - 1 DOWNTO 0);
    SIGNAL immediate : STD_LOGIC_VECTOR(XLEN - 1 DOWNTO 0);

    SIGNAL csrRdData        : STD_LOGIC_VECTOR(XLEN - 1 DOWNTO 0);
    SIGNAL csrIllegalAccess : STD_LOGIC;

    SIGNAL instType : InstructionType;

    SIGNAL csrHwOut : CsrRegisters_out_t;

    -- take interrupt
    PROCEDURE interrupt (
        VARIABLE v     : INOUT RegType;
        CONSTANT cause : IN InterruptCause
    ) IS
    BEGIN
        -- ensure this instruction does nothing
        v.opMemRead        := '0';
        v.opMemWrite       := '0';
        v.opRegWriteSource := NONE_SRC;

        -- set mcause
        v.csrHwIn.mcause.interrupt.next_q := '1';
        v.csrHwIn.mcause.interrupt.we     := '1';
        v.csrHwIn.mcause.code.next_q      := STD_LOGIC_VECTOR(to_unsigned(cause, 31));
        v.csrHwIn.mcause.code.we          := '1';

        -- set mepc to current instruction for a normal interrupt, so
        -- execution continues there afterwards. if this is a WFI, set it to
        -- the next instruction so we don't wait again
        v.csrHwIn.mepc.mepc.next_q := r.pc;
        v.csrHwIn.mepc.mepc.we     := '1';

        -- set mpie to mie
        v.csrHwIn.mstatus.mpie.we     := '1';
        v.csrHwIn.mstatus.mpie.next_q := csrHwOut.mstatus.mie.value;
        -- set mie to 0
        v.csrHwIn.mstatus.mie.we     := '1';
        v.csrHwIn.mstatus.mie.next_q := '0';
        -- set mpp to M-mode
        v.csrHwIn.mstatus.mpp.we     := '1';
        v.csrHwIn.mstatus.mpp.next_q := PRIV_MACHINE_C;

        -- update pc
        IF csrHwOut.mtvec.mode.value /= "00" THEN
            -- invalid mode
            v.stage := TRAPPED;
        ELSE
            -- go to mtvec address
            v.pc    := csrHwOut.mtvec.base.value & "00";
            v.stage := FETCH;
        END IF;
        -- todo: check for msip
        -- todo: check for mtip

        -- prep instruction fetch
        v.axiReadMaster.arvalid := '1';
        v.axiReadMaster.araddr  := v.pc;
        v.axiReadMaster.rready  := '1';
    END PROCEDURE;
BEGIN
    PROCESS (ALL)
        VARIABLE v : regType;
    BEGIN
        -- initialise from existing state
        v := r;

        -- reset all csr inputs (not very efficient)
        v.csrHwIn := CSR_IN_INIT_C;

        -- read interrupts
        -- todo: cdc?
        v.csrHwIn.mip.meip.next_q := mExtInt;

        v.regWrStrobe := '0';

        -- accept axi-lite transactions
        IF (axiReadSlave.arready AND r.axiReadMaster.arvalid) THEN
            v.axiReadMaster.arvalid := '0';
            v.axiReadMaster.araddr  := (OTHERS => '0');
        END IF;
        IF (axiReadSlave.rvalid AND r.axiReadMaster.rready) THEN
            v.axiReadMaster.rready := '0';
        END IF;
        IF (axiWriteSlave.awready AND r.axiWriteMaster.awvalid) THEN
            v.axiWriteMaster.awvalid := '0';
            v.axiWriteMaster.awaddr  := (OTHERS => '0');
        END IF;
        IF (axiWriteSlave.wready AND r.axiWriteMaster.wvalid) THEN
            v.axiWriteMaster.wvalid := '0';
            v.axiWriteMaster.wdata  := (OTHERS => '0');
        END IF;
        IF (axiWriteSlave.bvalid AND r.axiWriteMaster.bready) THEN
            v.axiWriteMaster.bready := '0';
        END IF;

        CASE (r.stage) IS
            WHEN INIT =>
                -- initial read of the pc to start the cpu running
                v.axiReadMaster.arvalid := '1';
                v.axiReadMaster.araddr  := v.pc;

                v.stage := FETCH;
            WHEN FETCH =>
                IF (r.axiReadMaster.rready AND axiReadSlave.rvalid) THEN
                    IF axiReadSlave.rresp = AXI_RESP_OK_C THEN
                        v.instruction := axiReadSlave.rdata;
                        v.immediate   := immediate;
                        v.instType    := instType;
                        v.rs1         := rs1;
                        v.rs2         := rs2;
                        v.rd          := rd;

                        v.successivePc := STD_LOGIC_VECTOR(UNSIGNED(r.pc) + 4);

                        v.stage := DECODE;

                        -- check for interrupts
                        IF csrHwOut.mstatus.mie.value AND csrHwOut.mip.meip.value AND csrHwOut.mie.meie.value THEN
                            interrupt(v, INTERRUPT_M_EXT_C);
                        END IF;
                    ELSE
                        v.stage := TRAPPED;
                    END IF;
                END IF;
            WHEN DECODE =>
                -- todo: register decoded instruction here?

                v.opMemRead            := '0';
                v.opRegWriteSource     := NONE_SRC;
                v.opMemWrite           := '0';
                v.opMemWriteWidthBytes := 1;
                v.opPcFromAlu          := '0';
                v.opPcFromMepcCsr      := '0';
                v.csrReq               := '0';

                v.stage := EXECUTE;

                CASE r.instType IS
                    WHEN LUI =>
                        v.opRegWriteSource := IMMEDIATE_SRC;
                    WHEN AUIPC =>
                        v.aluResult        := STD_LOGIC_VECTOR(unsigned(r.pc) + unsigned(r.immediate));
                        v.opRegWriteSource := ALU_SRC;
                    WHEN ADDI =>
                        v.aluResult        := STD_LOGIC_VECTOR(unsigned(rs1Value) + unsigned(r.immediate));
                        v.opRegWriteSource := ALU_SRC;
                    WHEN SLTI                 =>
                        v.aluResult    := (OTHERS => '0');
                        v.aluResult(0) := '1' WHEN signed(rs1Value) < signed(r.immediate) ELSE
                        '0';
                        v.opRegWriteSource := ALU_SRC;
                    WHEN SLTIU                =>
                        v.aluResult    := (OTHERS => '0');
                        v.aluResult(0) := '1' WHEN unsigned(rs1Value) < unsigned(r.immediate) ELSE
                        '0';
                        v.opRegWriteSource := ALU_SRC;
                    WHEN ANDI =>
                        v.aluResult        := rs1Value AND r.immediate;
                        v.opRegWriteSource := ALU_SRC;
                    WHEN ORI =>
                        v.aluResult        := rs1Value OR r.immediate;
                        v.opRegWriteSource := ALU_SRC;
                    WHEN XORI =>
                        v.aluResult        := rs1Value XOR r.immediate;
                        v.opRegWriteSource := ALU_SRC;
                    WHEN SLLI =>
                        v.aluResult        := STD_LOGIC_VECTOR(SHIFT_LEFT(unsigned(rs1Value), to_integer(unsigned(r.immediate(4 DOWNTO 0)))));
                        v.opRegWriteSource := ALU_SRC;
                    WHEN SRLI =>
                        v.aluResult        := STD_LOGIC_VECTOR(SHIFT_RIGHT(unsigned(rs1Value), to_integer(unsigned(r.immediate(4 DOWNTO 0)))));
                        v.opRegWriteSource := ALU_SRC;
                    WHEN SRAI =>
                        v.aluResult        := STD_LOGIC_VECTOR(SHIFT_RIGHT(signed(rs1Value), to_integer(unsigned(r.immediate(4 DOWNTO 0)))));
                        v.opRegWriteSource := ALU_SRC;
                    WHEN ADD =>
                        v.aluResult        := STD_LOGIC_VECTOR(unsigned(rs1Value) + unsigned(rs2Value));
                        v.opRegWriteSource := ALU_SRC;
                    WHEN SLT                  =>
                        v.aluResult    := (OTHERS => '0');
                        v.aluResult(0) := '1' WHEN signed(rs1Value) < signed(rs2Value) ELSE
                        '0';
                        v.opRegWriteSource := ALU_SRC;
                    WHEN SLTU                 =>
                        v.aluResult    := (OTHERS => '0');
                        v.aluResult(0) := '1' WHEN unsigned(rs1Value) < unsigned(rs2Value) ELSE
                        '0';
                        v.opRegWriteSource := ALU_SRC;
                    WHEN \AND\ =>
                        v.aluResult        := rs1Value AND rs2Value;
                        v.opRegWriteSource := ALU_SRC;
                    WHEN \OR\ =>
                        v.aluResult        := rs1Value OR rs2Value;
                        v.opRegWriteSource := ALU_SRC;
                    WHEN \XOR\ =>
                        v.aluResult        := rs1Value XOR rs2Value;
                        v.opRegWriteSource := ALU_SRC;
                    WHEN \SLL\ =>
                        v.aluResult        := STD_LOGIC_VECTOR(SHIFT_LEFT(unsigned(rs1Value), to_integer(unsigned(rs2Value(4 DOWNTO 0)))));
                        v.opRegWriteSource := ALU_SRC;
                    WHEN \SRL\ =>
                        v.aluResult        := STD_LOGIC_VECTOR(SHIFT_RIGHT(unsigned(rs1Value), to_integer(unsigned(rs2Value(4 DOWNTO 0)))));
                        v.opRegWriteSource := ALU_SRC;
                    WHEN SUB =>
                        v.aluResult        := STD_LOGIC_VECTOR(unsigned(rs1Value) - unsigned(rs2Value));
                        v.opRegWriteSource := ALU_SRC;
                    WHEN \SRA\ =>
                        v.aluResult        := STD_LOGIC_VECTOR(SHIFT_RIGHT(signed(rs1Value), to_integer(unsigned(rs2Value(4 DOWNTO 0)))));
                        v.opRegWriteSource := ALU_SRC;
                    WHEN LB | LH | LW | LBU | LHU =>
                        v.aluResult        := STD_LOGIC_VECTOR(unsigned(rs1Value) + unsigned(r.immediate));
                        v.opMemRead        := '1';
                        v.opRegWriteSource := MEMORY_SRC;
                    WHEN SW =>
                        v.aluResult            := STD_LOGIC_VECTOR(unsigned(rs1Value) + unsigned(r.immediate));
                        v.opMemWrite           := '1';
                        v.opMemWriteWidthBytes := 4;
                    WHEN SH =>
                        v.aluResult            := STD_LOGIC_VECTOR(unsigned(rs1Value) + unsigned(r.immediate));
                        v.opMemWrite           := '1';
                        v.opMemWriteWidthBytes := 2;
                    WHEN SB =>
                        v.aluResult            := STD_LOGIC_VECTOR(unsigned(rs1Value) + unsigned(r.immediate));
                        v.opMemWrite           := '1';
                        v.opMemWriteWidthBytes := 1;
                    WHEN JAL =>
                        v.aluResult        := STD_LOGIC_VECTOR(unsigned(r.pc) + unsigned(r.immediate));
                        v.opRegWriteSource := SUCC_PC_SRC;
                        v.opPcFromAlu      := '1';
                    WHEN JALR =>
                        v.aluResult        := STD_LOGIC_VECTOR(unsigned(rs1Value) + unsigned(r.immediate));
                        v.opRegWriteSource := SUCC_PC_SRC;
                        v.opPcFromAlu      := '1';
                    WHEN BEQ =>
                        v.aluResult   := STD_LOGIC_VECTOR(unsigned(r.pc) + unsigned(r.immediate));
                        v.opPcFromAlu := '1' WHEN rs1Value = rs2Value ELSE
                        '0';
                    WHEN BNE =>
                        v.aluResult   := STD_LOGIC_VECTOR(unsigned(r.pc) + unsigned(r.immediate));
                        v.opPcFromAlu := '1' WHEN rs1Value /= rs2Value ELSE
                        '0';
                    WHEN BLT =>
                        v.aluResult   := STD_LOGIC_VECTOR(unsigned(r.pc) + unsigned(r.immediate));
                        v.opPcFromAlu := '1' WHEN SIGNED(rs1Value) < SIGNED(rs2Value) ELSE
                        '0';
                    WHEN BLTU =>
                        v.aluResult   := STD_LOGIC_VECTOR(unsigned(r.pc) + unsigned(r.immediate));
                        v.opPcFromAlu := '1' WHEN UNSIGNED(rs1Value) < UNSIGNED(rs2Value) ELSE
                        '0';
                    WHEN BGE =>
                        v.aluResult   := STD_LOGIC_VECTOR(unsigned(r.pc) + unsigned(r.immediate));
                        v.opPcFromAlu := '1' WHEN SIGNED(rs1Value) >= SIGNED(rs2Value) ELSE
                        '0';
                    WHEN BGEU =>
                        v.aluResult   := STD_LOGIC_VECTOR(unsigned(r.pc) + unsigned(r.immediate));
                        v.opPcFromAlu := '1' WHEN UNSIGNED(rs1Value) >= UNSIGNED(rs2Value) ELSE
                        '0';
                    WHEN CSRRW | CSRRWI =>
                        v.csrReq := '1';
                        v.csrOp  := OP_WRITE WHEN r.rd = 0 ELSE
                        OP_READ_WRITE;
                        v.csrAddr   := r.immediate(11 DOWNTO 0);
                        v.csrWrData := rs1Value WHEN r.instType = CSRRW ELSE
                        STD_LOGIC_VECTOR(to_unsigned(r.rs1, rs1Value'length));
                        v.opRegWriteSource := NONE_SRC WHEN r.rd = 0 ELSE
                        CSR_SRC;
                    WHEN CSRRS | CSRRSI =>
                        v.csrReq := '1';
                        v.csrOp  := OP_READ WHEN r.rs1 = 0 ELSE
                        OP_READ_SET;
                        v.csrAddr   := r.immediate(11 DOWNTO 0);
                        v.csrWrData := rs1Value WHEN r.instType = CSRRS ELSE
                        STD_LOGIC_VECTOR(to_unsigned(r.rs1, rs1Value'length));
                        v.opRegWriteSource := CSR_SRC;
                    WHEN CSRRC | CSRRCI =>
                        v.csrReq := '1';
                        v.csrOp  := OP_READ WHEN r.rs1 = 0 ELSE
                        OP_READ_CLEAR;
                        v.csrAddr   := r.immediate(11 DOWNTO 0);
                        v.csrWrData := rs1Value WHEN r.instType = CSRRC ELSE
                        STD_LOGIC_VECTOR(to_unsigned(r.rs1, rs1Value'length));
                        v.opRegWriteSource := CSR_SRC;
                    WHEN EBREAK =>
                        v.stage := HALTED;
                    WHEN WFI =>
                        -- stay in decode until an interrupt arrives
                        -- purposefully ignoring mstatus.mie per priv spec
                        IF csrHwOut.mip.meip.value AND csrHwOut.mie.meie.value THEN
                            -- continue on to execute stage
                        ELSE
                            v.stage := DECODE;
                        END IF;
                    WHEN MRET =>
                        -- return pc to mepc
                        v.opPcFromMepcCsr := '1';

                        -- set mie to mpie
                        v.csrHwIn.mstatus.mie.we     := '1';
                        v.csrHwIn.mstatus.mie.next_q := csrHwOut.mstatus.mpie.value;
                        -- set mpie to 0
                        v.csrHwIn.mstatus.mpie.we     := '1';
                        v.csrHwIn.mstatus.mpie.next_q := '1';
                        -- set mpp to M-mode
                        v.csrHwIn.mstatus.mpp.we     := '1';
                        v.csrHwIn.mstatus.mpp.next_q := PRIV_MACHINE_C;

                    WHEN OTHERS =>
                        -- on unknown instruction, halt
                        -- todo: raise illegal instruction exception
                        v.stage := TRAPPED;
                END CASE;
            WHEN EXECUTE =>
                -- update PC
                IF v.opPcFromAlu THEN
                    v.pc := r.aluResult(31 DOWNTO 1) & "0";
                ELSIF v.opPcFromMepcCsr THEN
                    v.pc := csrHwOut.mepc.mepc.value;
                ELSE
                    v.pc := r.successivePc;
                END IF;

                -- handle potential csr read and reset
                v.csrRdData := csrRdData;
                v.csrReq    := '0';
                v.csrAddr   := (OTHERS => '0');
                v.csrWrData := (OTHERS => '0');

                IF v.opMemRead OR v.opMemWrite THEN
                    -- only use memory stage if we are doing memory ops
                    v.stage := MEMORY;
                ELSIF csrIllegalAccess THEN
                    -- handle illegal csr access
                    v.stage := TRAPPED;
                ELSE
                    v.stage := WRITEBACK;

                    -- prepare ram read for fetch in advance due to the memory latency
                    v.axiReadMaster.arvalid := '1';
                    v.axiReadMaster.araddr  := v.pc;
                    v.axiReadMaster.rready  := '1';
                END IF;

                -- prepare memory ops in advance due to the memory latency
                IF r.opMemRead THEN
                    v.axiReadMaster.araddr              := (OTHERS => '0');
                    v.axiReadMaster.araddr(31 DOWNTO 2) := r.aluResult(31 DOWNTO 2);
                    v.axiReadMaster.arvalid             := '1';

                    v.axiReadMaster.rready := '1';
                END IF;

                IF r.opMemWrite THEN
                    v.axiWriteMaster.awaddr              := (OTHERS => '0');
                    v.axiWriteMaster.awaddr(31 DOWNTO 2) := r.aluResult(31 DOWNTO 2);
                    v.axiWriteMaster.awvalid             := '1';

                    v.axiWriteMaster.wstrb  := "0000";
                    v.axiWriteMaster.wdata  := (OTHERS => '0');
                    v.axiWriteMaster.wvalid := '1';

                    v.axiWriteMaster.bready := '1';
                END IF;

                -- set wstrb and wdata for mem write
                CASE r.opMemWriteWidthBytes IS
                    WHEN 1 =>
                        FOR i IN 0 TO 3 LOOP
                            IF v.aluResult(1 DOWNTO 0) = STD_LOGIC_VECTOR(to_unsigned(i, 2)) THEN
                                v.axiWriteMaster.wstrb(i)                            := '1';
                                v.axiWriteMaster.wdata((i + 1) * 8 - 1 DOWNTO i * 8) := rs2Value(7 DOWNTO 0);
                            END IF;
                        END LOOP;
                    WHEN 2 =>
                        IF v.aluResult(1) THEN
                            v.axiWriteMaster.wstrb               := "1100";
                            v.axiWriteMaster.wdata(31 DOWNTO 16) := rs2Value(15 DOWNTO 0);
                        ELSE
                            v.axiWriteMaster.wstrb              := "0011";
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
                        v.axiReadMaster.araddr  := v.pc;
                        v.axiReadMaster.rready  := '1';

                        v.stage := WRITEBACK;
                    ELSE
                        v.stage := TRAPPED;
                    END IF;
                END IF;
                IF r.opMemRead AND r.axiReadMaster.rready AND axiReadSlave.rvalid THEN
                    IF axiReadSlave.rresp = AXI_RESP_OK_C THEN
                        -- register read data
                        v.memReadData := axiReadSlave.rdata;

                        -- prepare ram read for fetch in advance due to the memory latency
                        v.axiReadMaster.arvalid := '1';
                        v.axiReadMaster.araddr  := v.pc;
                        v.axiReadMaster.rready  := '1';

                        v.stage := WRITEBACK;
                    ELSE
                        v.stage := TRAPPED;
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
                                    WHEN OTHERS            =>
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
                                    WHEN OTHERS            =>
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
                    WHEN ALU_SRC           => v.regWrData       := r.aluResult;
                    WHEN IMMEDIATE_SRC     => v.regWrData := r.immediate;
                    WHEN SUCC_PC_SRC       => v.regWrData   := r.successivePc;
                    WHEN CSR_SRC           => v.regWrData       := r.csrRdData;
                    WHEN OTHERS            =>
                        v.regWrData := (OTHERS => '0');
                END CASE;

                v.stage := FETCH;
            WHEN HALTED =>
                -- do nothing
            WHEN TRAPPED =>
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
        trap <= '1' WHEN r.stage = TRAPPED ELSE
            '0';
        axiReadMaster  <= r.axiReadMaster;
        axiWriteMaster <= r.axiWriteMaster;
    END PROCESS;

    PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN
            r <= rin AFTER TPD_G;
        END IF;
    END PROCESS;

    Registers_inst : ENTITY work.Registers
        PORT MAP
        (
            clk       => clk,
            reset     => reset,
            rs1       => r.rs1,
            rs1Value  => rs1Value,
            rs2       => r.rs2,
            rs2Value  => rs2Value,
            wr_addr   => r.regWrAddr,
            wr_data   => r.regWrData,
            wr_strobe => r.regWrStrobe
        );

    InstructionDecoder_inst : ENTITY work.InstructionDecoder
        PORT MAP
        (
            instructionType => instType,
            instruction     => axiReadSlave.rdata,
            immediate       => immediate,
            rs1             => rs1,
            rs2             => rs2,
            rd              => rd
        );

    Csr_inst : ENTITY work.Csr
        PORT MAP
        (
            clk              => clk,
            reset            => reset,
            currentPrivilege => r.currentPrivilege,
            req              => r.csrReq,
            op               => r.csrOp,
            addr             => r.csrAddr,
            wrData           => r.csrWrData,
            rdData           => csrRdData,
            illegalAccess    => csrIllegalAccess,
            hwif_in          => r.csrHwIn,
            hwif_out         => csrHwOut
        );

END ARCHITECTURE;