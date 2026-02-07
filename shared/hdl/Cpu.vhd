library ieee;
context ieee.ieee_std_context;

use work.RiscVPkg.all;
use work.csrif_pkg.all;
use work.CsrRegisters_pkg.all;

library surf;
use surf.AxiLitePkg.all;

entity Cpu is
  generic (
    TPD_G : time := 1 ns
  );
  port (
    clk   : in std_logic;
    reset : in std_logic;
    halt  : out std_logic := '0';
    trap  : out std_logic := '0';

    -- memory interface
    axiReadMaster  : out AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
    axiReadSlave   : in AxiLiteReadSlaveType    := AXI_LITE_READ_SLAVE_INIT_C;
    axiWriteMaster : out AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
    axiWriteSlave  : in AxiLiteWriteSlaveType   := AXI_LITE_WRITE_SLAVE_INIT_C;

    -- interrupts
    mExtInt : in std_logic
  );
end entity Cpu;

architecture rtl of Cpu is
  type StageType is (INIT, FETCH, DECODE, EXECUTE, MEMORY, WRITEBACK, HALTED, TRAPPED);
  type RegWriteSourceType is (NONE_SRC, MEMORY_SRC, ALU_SRC, IMMEDIATE_SRC, SUCC_PC_SRC, CSR_SRC);

  type RegType is record
    stage : StageType;
    -- address of the current instruction, will be updated if there
    -- are jumps
    pc : std_logic_vector(XLEN - 1 downto 0);
    -- address of the instruction directly after the current one
    successivePc : std_logic_vector(XLEN - 1 downto 0);

    instruction : std_logic_vector(31 downto 0);
    immediate   : std_logic_vector(31 downto 0);
    instType    : InstructionType;
    rs1         : RegisterIndex;
    rs2         : RegisterIndex;
    rd          : RegisterIndex;

    -- ram write control
    axiReadMaster  : AxiLiteReadMasterType;
    axiWriteMaster : AxiLiteWriteMasterType;
    memReadData    : std_logic_vector(31 downto 0);

    -- register write control
    regWrAddr   : RegisterIndex;
    regWrData   : std_logic_vector(XLEN - 1 downto 0);
    regWrStrobe : std_logic;

    -- csr write control
    currentPrivilege : Privilege;
    csrReq           : std_logic;
    csrOp            : csr_access_op;
    csrAddr          : std_logic_vector(11 downto 0);
    csrWrData        : std_logic_vector(XLEN - 1 downto 0);
    csrRdData        : std_logic_vector(XLEN - 1 downto 0);

    -- csr hardware inputs
    csrHwIn : CsrRegisters_in_t;

    -- alu
    aluResult : std_logic_vector(31 downto 0); -- todo: XLEN?

    -- control signal
    opMemRead            : std_logic;
    opMemWrite           : std_logic;
    opMemWriteWidthBytes : natural range 1 to 4;
    opRegWriteSource     : RegWriteSourceType;
    opPcFromAlu          : std_logic;
    opPcFromMepcCsr      : std_logic;
  end record RegType;

  constant CSR_IN_INIT_C : CsrRegisters_in_t := (
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
  next_q => (others => '0'),
  we   => '0'
  )
  ),
  mcause => (
  code   => (
  next_q => (others => '0'),
  we     => '0'
  ),
  interrupt => (
  next_q    => '0',
  we        => '0'
  )
  ),
  mtval => (
  mtval => (
  next_q => (others => '0'),
  we    => '0'
  )
  ),
  mip    => (
  meip   => (
  next_q => '0'
  )
  )
  );

  constant REG_INIT_C : RegType := (
  stage    => INIT,
  pc       => x"01000000", -- reset vector
  successivePc => (others => '0'),
  instruction => (others => '0'),
  immediate => (others => '0'),
  instType => UNKNOWN,
  rs1      => 0,
  rs2      => 0,
  rd       => 0,
  -- axi read master defaults to reading addr 0 for first fetch
  axiReadMaster  => AXI_LITE_READ_MASTER_INIT_C,
  axiWriteMaster => AXI_LITE_WRITE_MASTER_INIT_C,
  memReadData => (others => '0'),
  regWrAddr      => 0,
  regWrData => (others => '0'),
  regWrStrobe    => '0',

  currentPrivilege => PRIV_MACHINE_C,
  csrReq           => '0',
  csrOp            => OP_READ,
  csrAddr => (others => '0'),
  csrWrData => (others => '0'),
  csrRdData => (others => '0'),

  csrHwIn => CSR_IN_INIT_C,

  aluResult => (others => '0'),
  opMemRead            => '0',
  opMemWrite           => '0',
  opMemWriteWidthBytes => 1,
  opRegWriteSource     => NONE_SRC,
  opPcFromAlu          => '0',
  opPcFromMepcCsr      => '0'
  );

  signal r   : RegType := REG_INIT_C;
  signal rin : RegType;

  -- intermediate signals
  signal rs1       : RegisterIndex;
  signal rs2       : RegisterIndex;
  signal rd        : RegisterIndex;
  signal rs1Value  : std_logic_vector(XLEN - 1 downto 0);
  signal rs2Value  : std_logic_vector(XLEN - 1 downto 0);
  signal immediate : std_logic_vector(XLEN - 1 downto 0);

  signal csrRdData        : std_logic_vector(XLEN - 1 downto 0);
  signal csrIllegalAccess : std_logic;

  signal instType : InstructionType;

  signal csrHwOut : CsrRegisters_out_t;
begin
  process (all)
    variable v : regType;
  begin
    -- initialise from existing state
    v := r;

    -- reset all csr inputs (not very efficient)
    v.csrHwIn := CSR_IN_INIT_C;

    -- read interrupts
    -- todo: cdc?
    v.csrHwIn.mip.meip.next_q := mExtInt;

    v.regWrStrobe := '0';

    -- accept axi-lite transactions
    if (axiReadSlave.arready and r.axiReadMaster.arvalid) then
      v.axiReadMaster.arvalid := '0';
      v.axiReadMaster.araddr  := (others => '0');
    end if;
    if (axiReadSlave.rvalid and r.axiReadMaster.rready) then
      v.axiReadMaster.rready := '0';
    end if;
    if (axiWriteSlave.awready and r.axiWriteMaster.awvalid) then
      v.axiWriteMaster.awvalid := '0';
      v.axiWriteMaster.awaddr  := (others => '0');
    end if;
    if (axiWriteSlave.wready and r.axiWriteMaster.wvalid) then
      v.axiWriteMaster.wvalid := '0';
      v.axiWriteMaster.wdata  := (others => '0');
    end if;
    if (axiWriteSlave.bvalid and r.axiWriteMaster.bready) then
      v.axiWriteMaster.bready := '0';
    end if;

    case (r.stage) is
      when INIT =>
        -- initial read of the pc to start the cpu running
        v.axiReadMaster.arvalid := '1';
        v.axiReadMaster.araddr  := v.pc;

        v.stage := FETCH;
      when FETCH =>
        if (r.axiReadMaster.rready and axiReadSlave.rvalid) then
          if axiReadSlave.rresp = AXI_RESP_OK_C then
            v.instruction := axiReadSlave.rdata;
            v.immediate   := immediate;
            v.instType    := instType;
            v.rs1         := rs1;
            v.rs2         := rs2;
            v.rd          := rd;

            v.successivePc := std_logic_vector(UNSIGNED(r.pc) + 4);

            v.stage := DECODE;

            -- check for interrupts
            if csrHwOut.mstatus.mie.value and csrHwOut.mie.meie.value and csrHwOut.mip.meip.value then
              -- take interrupt

              -- ensure this instruction does nothing
              v.opMemRead        := '0';
              v.opMemWrite       := '0';
              v.opRegWriteSource := NONE_SRC;
              v.csrReq           := '0';

              -- set mcause
              v.csrHwIn.mcause.interrupt.next_q := '1';
              v.csrHwIn.mcause.interrupt.we     := '1';
              v.csrHwIn.mcause.code.next_q      := std_logic_vector(to_unsigned(11, 31));
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
              if csrHwOut.mtvec.mode.value /= "00" then
                -- invalid mode
                v.stage := TRAPPED;
              else
                -- go to mtvec address
                v.pc    := csrHwOut.mtvec.base.value & "00";
                v.stage := FETCH;
              end if;
              -- todo: check for msip
              -- todo: check for mtip

              -- prep instruction fetch
              v.axiReadMaster.arvalid := '1';
              v.axiReadMaster.araddr  := v.pc;
              v.axiReadMaster.rready  := '1';
            end if;
          else
            v.stage := TRAPPED;
          end if;
        end if;
      when DECODE =>
        -- todo: register decoded instruction here?

        v.opMemRead            := '0';
        v.opRegWriteSource     := NONE_SRC;
        v.opMemWrite           := '0';
        v.opMemWriteWidthBytes := 1;
        v.opPcFromAlu          := '0';
        v.opPcFromMepcCsr      := '0';
        v.csrReq               := '0';

        v.stage := EXECUTE;

        case r.instType is
          when LUI =>
            v.opRegWriteSource := IMMEDIATE_SRC;
          when AUIPC =>
            v.aluResult        := std_logic_vector(unsigned(r.pc) + unsigned(r.immediate));
            v.opRegWriteSource := ALU_SRC;
          when ADDI =>
            v.aluResult        := std_logic_vector(unsigned(rs1Value) + unsigned(r.immediate));
            v.opRegWriteSource := ALU_SRC;
          when SLTI                 =>
            v.aluResult    := (others => '0');
            v.aluResult(0) := '1' when signed(rs1Value) < signed(r.immediate) else
            '0';
            v.opRegWriteSource := ALU_SRC;
          when SLTIU                =>
            v.aluResult    := (others => '0');
            v.aluResult(0) := '1' when unsigned(rs1Value) < unsigned(r.immediate) else
            '0';
            v.opRegWriteSource := ALU_SRC;
          when ANDI =>
            v.aluResult        := rs1Value and r.immediate;
            v.opRegWriteSource := ALU_SRC;
          when ORI =>
            v.aluResult        := rs1Value or r.immediate;
            v.opRegWriteSource := ALU_SRC;
          when XORI =>
            v.aluResult        := rs1Value xor r.immediate;
            v.opRegWriteSource := ALU_SRC;
          when SLLI =>
            v.aluResult        := std_logic_vector(SHIFT_LEFT(unsigned(rs1Value), to_integer(unsigned(r.immediate(4 downto 0)))));
            v.opRegWriteSource := ALU_SRC;
          when SRLI =>
            v.aluResult        := std_logic_vector(SHIFT_RIGHT(unsigned(rs1Value), to_integer(unsigned(r.immediate(4 downto 0)))));
            v.opRegWriteSource := ALU_SRC;
          when SRAI =>
            v.aluResult        := std_logic_vector(SHIFT_RIGHT(signed(rs1Value), to_integer(unsigned(r.immediate(4 downto 0)))));
            v.opRegWriteSource := ALU_SRC;
          when ADD =>
            v.aluResult        := std_logic_vector(unsigned(rs1Value) + unsigned(rs2Value));
            v.opRegWriteSource := ALU_SRC;
          when SLT                  =>
            v.aluResult    := (others => '0');
            v.aluResult(0) := '1' when signed(rs1Value) < signed(rs2Value) else
            '0';
            v.opRegWriteSource := ALU_SRC;
          when SLTU                 =>
            v.aluResult    := (others => '0');
            v.aluResult(0) := '1' when unsigned(rs1Value) < unsigned(rs2Value) else
            '0';
            v.opRegWriteSource := ALU_SRC;
          when \AND\ =>
            v.aluResult        := rs1Value and rs2Value;
            v.opRegWriteSource := ALU_SRC;
          when \OR\ =>
            v.aluResult        := rs1Value or rs2Value;
            v.opRegWriteSource := ALU_SRC;
          when \XOR\ =>
            v.aluResult        := rs1Value xor rs2Value;
            v.opRegWriteSource := ALU_SRC;
          when \SLL\ =>
            v.aluResult        := std_logic_vector(SHIFT_LEFT(unsigned(rs1Value), to_integer(unsigned(rs2Value(4 downto 0)))));
            v.opRegWriteSource := ALU_SRC;
          when \SRL\ =>
            v.aluResult        := std_logic_vector(SHIFT_RIGHT(unsigned(rs1Value), to_integer(unsigned(rs2Value(4 downto 0)))));
            v.opRegWriteSource := ALU_SRC;
          when SUB =>
            v.aluResult        := std_logic_vector(unsigned(rs1Value) - unsigned(rs2Value));
            v.opRegWriteSource := ALU_SRC;
          when \SRA\ =>
            v.aluResult        := std_logic_vector(SHIFT_RIGHT(signed(rs1Value), to_integer(unsigned(rs2Value(4 downto 0)))));
            v.opRegWriteSource := ALU_SRC;
          when LB | LH | LW | LBU | LHU =>
            v.aluResult        := std_logic_vector(unsigned(rs1Value) + unsigned(r.immediate));
            v.opMemRead        := '1';
            v.opRegWriteSource := MEMORY_SRC;
          when SW =>
            v.aluResult            := std_logic_vector(unsigned(rs1Value) + unsigned(r.immediate));
            v.opMemWrite           := '1';
            v.opMemWriteWidthBytes := 4;
          when SH =>
            v.aluResult            := std_logic_vector(unsigned(rs1Value) + unsigned(r.immediate));
            v.opMemWrite           := '1';
            v.opMemWriteWidthBytes := 2;
          when SB =>
            v.aluResult            := std_logic_vector(unsigned(rs1Value) + unsigned(r.immediate));
            v.opMemWrite           := '1';
            v.opMemWriteWidthBytes := 1;
          when JAL =>
            v.aluResult        := std_logic_vector(unsigned(r.pc) + unsigned(r.immediate));
            v.opRegWriteSource := SUCC_PC_SRC;
            v.opPcFromAlu      := '1';
          when JALR =>
            v.aluResult        := std_logic_vector(unsigned(rs1Value) + unsigned(r.immediate));
            v.opRegWriteSource := SUCC_PC_SRC;
            v.opPcFromAlu      := '1';
          when BEQ =>
            v.aluResult   := std_logic_vector(unsigned(r.pc) + unsigned(r.immediate));
            v.opPcFromAlu := '1' when rs1Value = rs2Value else
            '0';
          when BNE =>
            v.aluResult   := std_logic_vector(unsigned(r.pc) + unsigned(r.immediate));
            v.opPcFromAlu := '1' when rs1Value /= rs2Value else
            '0';
          when BLT =>
            v.aluResult   := std_logic_vector(unsigned(r.pc) + unsigned(r.immediate));
            v.opPcFromAlu := '1' when SIGNED(rs1Value) < SIGNED(rs2Value) else
            '0';
          when BLTU =>
            v.aluResult   := std_logic_vector(unsigned(r.pc) + unsigned(r.immediate));
            v.opPcFromAlu := '1' when UNSIGNED(rs1Value) < UNSIGNED(rs2Value) else
            '0';
          when BGE =>
            v.aluResult   := std_logic_vector(unsigned(r.pc) + unsigned(r.immediate));
            v.opPcFromAlu := '1' when SIGNED(rs1Value) >= SIGNED(rs2Value) else
            '0';
          when BGEU =>
            v.aluResult   := std_logic_vector(unsigned(r.pc) + unsigned(r.immediate));
            v.opPcFromAlu := '1' when UNSIGNED(rs1Value) >= UNSIGNED(rs2Value) else
            '0';
          when CSRRW | CSRRWI =>
            v.csrReq := '1';
            v.csrOp  := OP_WRITE when r.rd = 0 else
            OP_READ_WRITE;
            v.csrAddr   := r.immediate(11 downto 0);
            v.csrWrData := rs1Value when r.instType = CSRRW else
            std_logic_vector(to_unsigned(r.rs1, rs1Value'length));
            v.opRegWriteSource := NONE_SRC when r.rd = 0 else
            CSR_SRC;
          when CSRRS | CSRRSI =>
            v.csrReq := '1';
            v.csrOp  := OP_READ when r.rs1 = 0 else
            OP_READ_SET;
            v.csrAddr   := r.immediate(11 downto 0);
            v.csrWrData := rs1Value when r.instType = CSRRS else
            std_logic_vector(to_unsigned(r.rs1, rs1Value'length));
            v.opRegWriteSource := CSR_SRC;
          when CSRRC | CSRRCI =>
            v.csrReq := '1';
            v.csrOp  := OP_READ when r.rs1 = 0 else
            OP_READ_CLEAR;
            v.csrAddr   := r.immediate(11 downto 0);
            v.csrWrData := rs1Value when r.instType = CSRRC else
            std_logic_vector(to_unsigned(r.rs1, rs1Value'length));
            v.opRegWriteSource := CSR_SRC;
          when EBREAK =>
            v.stage := HALTED;
          when WFI =>
            -- stay in decode until an interrupt arrives
            -- purposefully ignoring mstatus.mie per priv spec
            if csrHwOut.mip.meip.value and csrHwOut.mie.meie.value then
              -- continue on to execute stage
            else
              v.stage := DECODE;
            end if;
          when MRET =>
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

          when others =>
            -- on unknown instruction, halt
            -- todo: raise illegal instruction exception
            v.stage := TRAPPED;
        end case;
      when EXECUTE =>
        -- update PC
        if v.opPcFromAlu then
          v.pc := r.aluResult(31 downto 1) & "0";
        elsif v.opPcFromMepcCsr then
          v.pc := csrHwOut.mepc.mepc.value;
        else
          v.pc := r.successivePc;
        end if;

        -- handle potential csr read and reset
        v.csrRdData := csrRdData;
        v.csrReq    := '0';
        v.csrAddr   := (others => '0');
        v.csrWrData := (others => '0');

        if v.opMemRead or v.opMemWrite then
          -- only use memory stage if we are doing memory ops
          v.stage := MEMORY;
        elsif csrIllegalAccess then
          -- handle illegal csr access
          v.stage := TRAPPED;
        else
          v.stage := WRITEBACK;

          -- prepare ram read for fetch in advance due to the memory latency
          v.axiReadMaster.arvalid := '1';
          v.axiReadMaster.araddr  := v.pc;
          v.axiReadMaster.rready  := '1';
        end if;

        -- prepare memory ops in advance due to the memory latency
        if r.opMemRead then
          v.axiReadMaster.araddr              := (others => '0');
          v.axiReadMaster.araddr(31 downto 2) := r.aluResult(31 downto 2);
          v.axiReadMaster.arvalid             := '1';

          v.axiReadMaster.rready := '1';
        end if;

        if r.opMemWrite then
          v.axiWriteMaster.awaddr              := (others => '0');
          v.axiWriteMaster.awaddr(31 downto 2) := r.aluResult(31 downto 2);
          v.axiWriteMaster.awvalid             := '1';

          v.axiWriteMaster.wstrb  := "0000";
          v.axiWriteMaster.wdata  := (others => '0');
          v.axiWriteMaster.wvalid := '1';

          v.axiWriteMaster.bready := '1';
        end if;

        -- set wstrb and wdata for mem write
        case r.opMemWriteWidthBytes is
          when 1 =>
            for i in 0 to 3 loop
              if v.aluResult(1 downto 0) = std_logic_vector(to_unsigned(i, 2)) then
                v.axiWriteMaster.wstrb(i)                            := '1';
                v.axiWriteMaster.wdata((i + 1) * 8 - 1 downto i * 8) := rs2Value(7 downto 0);
              end if;
            end loop;
          when 2 =>
            if v.aluResult(1) then
              v.axiWriteMaster.wstrb               := "1100";
              v.axiWriteMaster.wdata(31 downto 16) := rs2Value(15 downto 0);
            else
              v.axiWriteMaster.wstrb              := "0011";
              v.axiWriteMaster.wdata(15 downto 0) := rs2Value(15 downto 0);
            end if;
          when 3 =>
            -- invalid (3 bytes)
            v.axiWriteMaster.wstrb := "0000";
          when 4 =>
            v.axiWriteMaster.wstrb := "1111";
            v.axiWriteMaster.wdata := rs2Value;
        end case;
      when MEMORY =>
        -- once mem transaction completes
        if r.opMemWrite and r.axiWriteMaster.bready and axiWriteSlave.bvalid then
          if axiWriteSlave.bresp = AXI_RESP_OK_C then
            -- prepare ram read for fetch in advance due to the memory latency
            v.axiReadMaster.arvalid := '1';
            v.axiReadMaster.araddr  := v.pc;
            v.axiReadMaster.rready  := '1';

            v.stage := WRITEBACK;
          else
            v.stage := TRAPPED;
          end if;
        end if;
        if r.opMemRead and r.axiReadMaster.rready and axiReadSlave.rvalid then
          if axiReadSlave.rresp = AXI_RESP_OK_C then
            -- register read data
            v.memReadData := axiReadSlave.rdata;

            -- prepare ram read for fetch in advance due to the memory latency
            v.axiReadMaster.arvalid := '1';
            v.axiReadMaster.araddr  := v.pc;
            v.axiReadMaster.rready  := '1';

            v.stage := WRITEBACK;
          else
            v.stage := TRAPPED;
          end if;
        end if;
      when WRITEBACK =>
        -- write to register from alu, ram, or immediate
        v.regWrStrobe := '1' when r.opRegWriteSource /= NONE_SRC else
        '0';
        v.regWrAddr := r.rd;

        case r.opRegWriteSource is
          when MEMORY_SRC =>
            case r.instType is
              when LB =>
                case r.aluResult(1 downto 0) is
                  when "00" =>
                    v.regWrData := std_logic_vector(resize(signed(r.memReadData(7 downto 0)), XLEN));
                  when "01" =>
                    v.regWrData := std_logic_vector(resize(signed(r.memReadData(15 downto 8)), XLEN));
                  when "10" =>
                    v.regWrData := std_logic_vector(resize(signed(r.memReadData(23 downto 16)), XLEN));
                  when "11" =>
                    v.regWrData := std_logic_vector(resize(signed(r.memReadData(31 downto 24)), XLEN));
                  when others            =>
                    v.regWrData := (others => '0');
                end case;
              when LH =>
                if r.aluResult(1) then
                  v.regWrData := std_logic_vector(resize(signed(r.memReadData(31 downto 16)), XLEN));
                else
                  v.regWrData := std_logic_vector(resize(signed(r.memReadData(15 downto 0)), XLEN));
                end if;
              when LW =>
                v.regWrData := r.memReadData;
              when LBU =>
                case r.aluResult(1 downto 0) is
                  when "00" =>
                    v.regWrData := std_logic_vector(resize(unsigned(r.memReadData(7 downto 0)), XLEN));
                  when "01" =>
                    v.regWrData := std_logic_vector(resize(unsigned(r.memReadData(15 downto 8)), XLEN));
                  when "10" =>
                    v.regWrData := std_logic_vector(resize(unsigned(r.memReadData(23 downto 16)), XLEN));
                  when "11" =>
                    v.regWrData := std_logic_vector(resize(unsigned(r.memReadData(31 downto 24)), XLEN));
                  when others            =>
                    v.regWrData := (others => '0');
                end case;
              when LHU =>
                if r.aluResult(1) then
                  v.regWrData := std_logic_vector(resize(unsigned(r.memReadData(31 downto 16)), XLEN));
                else
                  v.regWrData := std_logic_vector(resize(unsigned(r.memReadData(15 downto 0)), XLEN));
                end if;
              when others =>
                null;
            end case;
          when ALU_SRC           => v.regWrData       := r.aluResult;
          when IMMEDIATE_SRC     => v.regWrData := r.immediate;
          when SUCC_PC_SRC       => v.regWrData   := r.successivePc;
          when CSR_SRC           => v.regWrData       := r.csrRdData;
          when others            =>
            v.regWrData := (others => '0');
        end case;

        v.stage := FETCH;
      when HALTED =>
        -- do nothing
      when TRAPPED =>
        -- do nothing
    end case;

    if reset then
      v := REG_INIT_C;
    end if;

    -- set nextstate
    rin <= v;

    -- update outputs
    halt <= '1' when r.stage = HALTED else
      '0';
    trap <= '1' when r.stage = TRAPPED else
      '0';
    axiReadMaster  <= r.axiReadMaster;
    axiWriteMaster <= r.axiWriteMaster;
  end process;

  process (clk)
  begin
    if rising_edge(clk) then
      r <= rin after TPD_G;
    end if;
  end process;

  Registers_inst : entity work.Registers
    port map
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

  InstructionDecoder_inst : entity work.InstructionDecoder
    port map
    (
      instructionType => instType,
      instruction     => axiReadSlave.rdata,
      immediate       => immediate,
      rs1             => rs1,
      rs2             => rs2,
      rd              => rd
    );

  Csr_inst : entity work.Csr
    port map
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

end architecture;