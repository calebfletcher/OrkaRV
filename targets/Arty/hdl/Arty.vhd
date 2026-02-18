LIBRARY ieee;
CONTEXT ieee.ieee_std_context;

ENTITY Arty IS
    PORT (
        CLK100MHZ : IN STD_LOGIC;
        ck_rstn   : IN STD_LOGIC;

        sw  : INOUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        btn : INOUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        led : INOUT STD_LOGIC_VECTOR(3 DOWNTO 0);

        uart_rxd_out : OUT STD_LOGIC;
        uart_txd_in  : IN STD_LOGIC
    );
END ENTITY Arty;

ARCHITECTURE rtl OF Arty IS

BEGIN

    Soc_inst : ENTITY work.Soc
        GENERIC MAP(
            RAM_FILE_PATH_G => "../../firmware/build/program.hex",
            NUM_GPIO        => 3
        )
        PORT MAP(
            clk                  => CLK100MHZ,
            reset                => NOT ck_rstn,
            halt                 => led(0),
            gpioPins(2 DOWNTO 0) => led(3 DOWNTO 1),
            -- gpioPins(3 DOWNTO 0)  => sw,
            -- gpioPins(7 DOWNTO 4)  => btn,
            -- gpioPins(10 DOWNTO 8) => led(3 DOWNTO 1),
            uart_rxd_out => uart_rxd_out,
            uart_txd_in  => uart_txd_in
        );

END ARCHITECTURE;