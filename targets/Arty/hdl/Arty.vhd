LIBRARY ieee;
CONTEXT ieee.ieee_std_context;

ENTITY Arty IS
    PORT (
        CLK100MHZ : IN STD_LOGIC;
        ck_rstn : IN STD_LOGIC;

        sw : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
        btn : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
        led : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);

        uart_rxd_out : OUT STD_LOGIC;
        uart_txd_in : IN STD_LOGIC
    );
END ENTITY Arty;

ARCHITECTURE rtl OF Arty IS

BEGIN

    Soc_inst : ENTITY work.Soc
        GENERIC MAP(
            RAM_FILE_PATH_G => "../../software/build/program.hex"
        )
        PORT MAP(
            clk => CLK100MHZ,
            reset => NOT ck_rstn,
            halt => led(0)
        );

END ARCHITECTURE;