LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY CpuTb IS
END ENTITY;

ARCHITECTURE sim OF CpuTb IS
    SIGNAL clk : STD_LOGIC := '0';
    SIGNAL reset : STD_LOGIC := '1';
    SIGNAL halt : STD_LOGIC;

    CONSTANT clk_period : TIME := 10 ns; -- 100 MHz
    CONSTANT timeout : TIME := 1 ms;
BEGIN
    -- Clock generation
    clk_process : PROCESS
    BEGIN
        WHILE NOW < timeout LOOP
            clk <= '0';
            WAIT FOR clk_period / 2;
            clk <= '1';
            WAIT FOR clk_period / 2;
        END LOOP;
        WAIT;
    END PROCESS;

    -- Reset logic
    reset_process : PROCESS
    BEGIN
        reset <= '1';
        WAIT FOR 30 ns;
        reset <= '0';
        WAIT;
    END PROCESS;

    -- Instantiate CPU
    uut : ENTITY work.Cpu
        PORT MAP(
            clk => clk,
            reset => reset,
            halt => halt
        );

    -- Stop simulation on halt or timeout
    monitor : PROCESS
    BEGIN
        WAIT UNTIL halt = '1' OR NOW >= timeout;
        IF halt = '1' THEN
            REPORT "CPU halted successfully." SEVERITY NOTE;
            std.env.stop;
        ELSE
            REPORT "Timeout: CPU did not halt within 1 ms." SEVERITY ERROR;
        END IF;
        WAIT;
    END PROCESS;
END ARCHITECTURE;