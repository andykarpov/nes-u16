library IEEE; 
use IEEE.std_logic_1164.all; 
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;

entity ldr is
port (
	RESET		: in std_logic;
	CLK		: in std_logic;
	CLK_CPU		: in std_logic;
	KEYSCAN		: in std_logic_vector(7 downto 0);
	SPI_MISO	: in std_logic;
	SPI1_MISO	: in std_logic;
	-- out
	SPI_CLK		: out std_logic;
	SPI1_CLK	: out std_logic;
	SPI_MOSI	: out std_logic;
	SPI1_MOSI	: out std_logic;

	UART_TXD	: out std_logic;
	SPI_CS_N	: out std_logic;	-- SPI FLASH
	SPI1_CS_N	: out std_logic;	-- SD Card
	SPI2_CS_N	: out std_logic;	-- data_io
	SPI3_CS_N	: out std_logic;	-- OSD
	SPI4_CS_N	: out std_logic);	-- SPI_SS for user_io
end ldr;

architecture rtl of ldr is

signal spi_busy		: std_logic;
signal spi_do		: std_logic_vector(7 downto 0);
signal spi_wr		: std_logic;
signal spi1_busy	: std_logic;
signal spi1_do		: std_logic_vector(7 downto 0);
signal spi1_wr		: std_logic;

signal cpu_di		: std_logic_vector(7 downto 0);
signal cpu_do		: std_logic_vector(7 downto 0);
signal cpu_addr		: std_logic_vector(15 downto 0);
signal cpu_mreq		: std_logic;
signal cpu_iorq		: std_logic;
signal cpu_wr		: std_logic;

signal ram_wr		: std_logic;
signal ram_do		: std_logic_vector(7 downto 0);

signal reg_0		: std_logic_vector(7 downto 0) := "11111111";

signal uart_wr		: std_logic;
signal uart_tx_busy	: std_logic;

begin

u0: entity work.spi
port map(
	RESET		=> RESET,
	CLK		=> CLK,
	SCK		=> CLK,
	DI		=> cpu_do,
	DO		=> spi_do,
	WR		=> spi_wr,
	BUSY		=> spi_busy,
	SCLK		=> SPI_CLK,
	MOSI		=> SPI_MOSI,
	MISO		=> SPI_MISO);

u1: entity work.nz80cpu
port map(
	CLK		=> CLK_CPU,
	CLKEN		=> '1',
	RESET		=> RESET,
	NMI		=> '0',
	INT		=> '0',
	DI		=> cpu_di,
	DO		=> cpu_do,
	ADDR		=> cpu_addr,
	WR		=> cpu_wr,
	MREQ		=> cpu_mreq,
	IORQ		=> cpu_iorq,
	HALT		=> open,
	M1		=> open);
	
u2: entity work.ram
port map(
	address	 	=> cpu_addr(14 downto 0),
	clock	 	=> CLK,
	data	 	=> cpu_do,
	wren	 	=> ram_wr,
	q	 	=> ram_do);

-- UART
u3: entity work.uart
generic map (
	divisor		=> 745)			-- divisor = 100MHz / 115200 Baud = 868
port map (
	CLK		=> CLK,
	RESET		=> RESET,
	WR		=> uart_wr,
--	RD		=> uart_rd,
	DI		=> cpu_do,
--	DO		=> uart_do,
	TXBUSY		=> uart_tx_busy,
--	RXAVAIL		=> uart_rx_avail,
--	RXERROR		=> uart_rx_error,
--	RXD		=> RXD,
	TXD		=> UART_TXD);

u4: entity work.spi
port map(
	RESET		=> RESET,
	CLK		=> CLK,
	SCK		=> CLK,
	DI		=> cpu_do,
	DO		=> spi1_do,
	WR		=> spi1_wr,
	BUSY		=> spi1_busy,
	SCLK		=> SPI1_CLK,
	MOSI		=> SPI1_MOSI,
	MISO		=> SPI1_MISO);
	
-------------------------------------------------------------------------------
process (CLK, RESET, cpu_addr, cpu_iorq, cpu_wr)
begin
	if RESET = '1' then
		reg_0 <= (others => '1');
	elsif CLK'event and CLK = '1' then
		if cpu_addr(7 downto 0) = X"00" and cpu_iorq = '1' and cpu_wr = '1' then reg_0 <= cpu_do; end if;
	end if;
end process;

SPI_CS_N  <= reg_0(0);
SPI1_CS_N <= reg_0(1);
SPI2_CS_N <= reg_0(2);
SPI3_CS_N <= reg_0(3);
SPI4_CS_N <= reg_0(4);
	
cpu_di <= 	ram_do when cpu_addr(15) = '0' and cpu_mreq = '1' and cpu_wr = '0' else
		reg_0 when cpu_addr(7 downto 0) = X"00" and cpu_iorq = '1' and cpu_wr = '0' else
		spi_do when cpu_addr(7 downto 0) = X"01" and cpu_iorq = '1' and cpu_wr = '0' else
		spi_busy & "000000" & uart_tx_busy when cpu_addr(7 downto 0) = X"02" and cpu_iorq = '1' and cpu_wr = '0' else
		KEYSCAN when cpu_addr(7 downto 0) = X"04" and cpu_iorq = '1' and cpu_wr = '0' else
		spi1_do when cpu_addr(7 downto 0) = X"05" and cpu_iorq = '1' and cpu_wr = '0' else
		spi1_busy & "0000000" when cpu_addr(7 downto 0) = X"06" and cpu_iorq = '1' and cpu_wr = '0' else
		X"FF";

ram_wr  <= '1' when cpu_addr(15) = '0' and cpu_mreq = '1' and cpu_wr = '1' else '0';
spi_wr  <= '1' when cpu_addr(7 downto 0) = X"01" and cpu_iorq = '1' and cpu_wr = '1' else '0';
spi1_wr <= '1' when cpu_addr(7 downto 0) = X"05" and cpu_iorq = '1' and cpu_wr = '1' else '0';
uart_wr <= '1' when cpu_addr(7 downto 0) = X"03" and cpu_iorq = '1' and cpu_wr = '1' else '0';


end rtl;