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
    TYPE StageType IS (FETCH, DECODE, EXECUTE);
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

    SIGNAL wr_addr : RegisterIndex := 0;
    SIGNAL wr_data : STD_LOGIC_VECTOR(XLEN - 1 DOWNTO 0);
    SIGNAL wr_strobe : STD_LOGIC;

    SIGNAL ram_we : STD_LOGIC;
    SIGNAL ram_di : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL ram_do : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL ram_addr : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
BEGIN
    -- halt once we hit an ebreak
    halt <= '1' WHEN instType = EBREAK AND stage = EXECUTE ELSE
        '0';

    rs1Value <= registerFile(rs1);
    rs2Value <= registerFile(rs2);

    PROCESS (clk)
        VARIABLE nextPc : STD_LOGIC_VECTOR(31 DOWNTO 0);
    BEGIN
        IF rising_edge(clk) THEN
            -- default register write strobe to off
            wr_strobe <= '0';

            IF reset = '1' THEN
                pc <= (OTHERS => '0');
                stage <= FETCH;
            ELSE
                CASE stage IS
                    WHEN FETCH =>
                        stage <= DECODE;
                        instruction <= ram_do;
                    WHEN DECODE =>
                        stage <= EXECUTE;
                        -- todo: register decoded instruction here?

                        wr_addr <= rd;

                        CASE instType IS
                            WHEN ADDI =>
                                wr_data <= STD_LOGIC_VECTOR(unsigned(rs1Value) + unsigned(immediate));
                                wr_strobe <= '1';
                            WHEN ADD =>
                                wr_data <= STD_LOGIC_VECTOR(unsigned(rs1Value) + unsigned(rs2Value));
                                wr_strobe <= '1';
                            WHEN SUB =>
                                wr_data <= STD_LOGIC_VECTOR(unsigned(rs1Value) - unsigned(rs2Value));
                                wr_strobe <= '1';
                            WHEN OTHERS =>
                                NULL;
                        END CASE;

                        -- todo: setup ram write addr

                    WHEN EXECUTE =>
                        stage <= FETCH;

                        nextPc := STD_LOGIC_VECTOR(UNSIGNED(pc) + 4);
                        pc <= nextPc;

                        -- prepare for fetch
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
            wr_addr => wr_addr,
            wr_data => wr_data,
            wr_strobe => wr_strobe
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