LIBRARY ieee;
CONTEXT ieee.ieee_std_context;

USE work.RiscVPkg.ALL;

ENTITY Cpu IS
    PORT (
        clk : IN STD_LOGIC;
        reset : IN STD_LOGIC;
        halt : OUT STD_LOGIC := '0'
    );
END ENTITY Cpu;

ARCHITECTURE rtl OF Cpu IS
    TYPE StageType IS (FETCH, DECODE, EXECUTE, MEMORY, WRITEBACK);
    SIGNAL stage : StageType := FETCH;

    SIGNAL pc : STD_LOGIC_VECTOR(XLEN - 1 DOWNTO 0) := (OTHERS => '0');
    SIGNAL registerFile : RegistersType;

    SIGNAL rs1 : RegisterIndex;
    SIGNAL rs2 : RegisterIndex;
    SIGNAL rd : RegisterIndex;
    SIGNAL rs1Value : STD_LOGIC_VECTOR(XLEN - 1 DOWNTO 0);
    SIGNAL rs2Value : STD_LOGIC_VECTOR(XLEN - 1 DOWNTO 0);
    SIGNAL immediate : STD_LOGIC_VECTOR(XLEN - 1 DOWNTO 0);

    SIGNAL instType : InstructionType;
    SIGNAL instruction : STD_LOGIC_VECTOR(31 DOWNTO 0);

    SIGNAL reg_wr_addr : RegisterIndex := 0;
    SIGNAL reg_wr_data : STD_LOGIC_VECTOR(XLEN - 1 DOWNTO 0);
    SIGNAL reg_wr_strobe : STD_LOGIC;

    SIGNAL ram_we : STD_LOGIC;
    SIGNAL ram_di : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL ram_do : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL ram_addr : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
BEGIN
    rs1Value <= registerFile(rs1);
    rs2Value <= registerFile(rs2);

    PROCESS (clk)
        VARIABLE nextPc : STD_LOGIC_VECTOR(31 DOWNTO 0);

        VARIABLE phase_ram_we : STD_LOGIC;
        VARIABLE phase_ram_di : STD_LOGIC_VECTOR(31 DOWNTO 0);
        VARIABLE phase_ram_addr : STD_LOGIC_VECTOR(31 DOWNTO 0);

        VARIABLE phase_reg_addr : RegisterIndex;
        VARIABLE phase_reg_data : STD_LOGIC_VECTOR(XLEN - 1 DOWNTO 0);
        VARIABLE phase_reg_we : STD_LOGIC;
    BEGIN
        IF rising_edge(clk) THEN
            -- default register write strobe to off
            reg_wr_strobe <= '0';

            IF reset = '1' THEN
                pc <= (OTHERS => '0');
                stage <= FETCH;

                phase_ram_we := '0';
                phase_ram_di := (OTHERS => '0');
                phase_ram_addr := (OTHERS => '0');

                phase_reg_addr := 0;
                phase_reg_data := (OTHERS => '0');
                phase_reg_we := '0';
            ELSE
                CASE stage IS
                    WHEN FETCH =>
                        stage <= DECODE;
                        instruction <= ram_do;
                    WHEN DECODE =>
                        stage <= EXECUTE;
                        -- todo: register decoded instruction here?

                        phase_reg_addr := rd;

                        CASE instType IS
                            WHEN LUI =>
                                phase_reg_data := immediate;
                                phase_reg_we := '1';
                            WHEN ADDI =>
                                phase_reg_data := STD_LOGIC_VECTOR(unsigned(rs1Value) + unsigned(immediate));
                                phase_reg_we := '1';
                            WHEN ADD =>
                                phase_reg_data := STD_LOGIC_VECTOR(unsigned(rs1Value) + unsigned(rs2Value));
                                phase_reg_we := '1';
                            WHEN SUB =>
                                phase_reg_data := STD_LOGIC_VECTOR(unsigned(rs1Value) - unsigned(rs2Value));
                                phase_reg_we := '1';
                            WHEN OTHERS =>
                                -- on unknown instruction, halt
                                halt <= '1';
                                NULL;
                        END CASE;

                        -- todo: setup ram write addr

                    WHEN EXECUTE =>
                        stage <= MEMORY;

                        -- todo: ALU ops
                    WHEN MEMORY =>
                        stage <= WRITEBACK;
                    WHEN WRITEBACK =>
                        stage <= FETCH;

                        -- register writeback
                        reg_wr_addr <= phase_reg_addr;
                        reg_wr_data <= phase_reg_data;
                        reg_wr_strobe <= phase_reg_we;

                        -- prepare for fetch
                        nextPc := STD_LOGIC_VECTOR(UNSIGNED(pc) + 4);
                        pc <= nextPc;
                        ram_addr <= nextPc;
                END CASE;
            END IF;
        END IF;
    END PROCESS;

    Registers_inst : ENTITY work.Registers
        PORT MAP(
            clk => clk,
            reset => reset,
            --pc => pc,
            registersValue => registerFile,
            wr_addr => reg_wr_addr,
            wr_data => reg_wr_data,
            wr_strobe => reg_wr_strobe
        );

    Ram_inst : ENTITY work.Ram
        PORT MAP(
            clk => clk,
            we => ram_we,
            -- word-addressed
            addr => ram_addr(7 DOWNTO 2),
            di => ram_di,
            do => ram_do
        );

    InstructionDecoder_inst : ENTITY work.InstructionDecoder
        PORT MAP(
            instructionType => instType,
            instruction => instruction,
            immediate => immediate,
            rs1 => rs1,
            rs2 => rs2,
            rd => rd
        );
END ARCHITECTURE;