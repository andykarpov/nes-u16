-------------------------------------------------------------------[09.02.2016]
-- OSD
-------------------------------------------------------------------------------
-- Engineer: 	MVV
--
-- 14.11.2015	Initial release
-------------------------------------------------------------------------------

library IEEE; 
use IEEE.std_logic_1164.all; 
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;

entity osd is
port (
	I_RESET		: in std_logic;
	I_CLK		: in std_logic;
	I_CLK_CPU	: in std_logic;
	I_KEY0		: in std_logic_vector(7 downto 0);
	I_KEY1		: in std_logic_vector(7 downto 0);
	I_KEY2		: in std_logic_vector(7 downto 0);
	I_KEY3		: in std_logic_vector(7 downto 0);
	I_KEY4		: in std_logic_vector(7 downto 0);
	I_KEY5		: in std_logic_vector(7 downto 0);
	I_KEY6		: in std_logic_vector(7 downto 0);
	I_SPI_MISO	: in std_logic;
	I_SPI1_MISO	: in std_logic;
	I_RED		: in std_logic_vector(4 downto 0);
	I_GREEN		: in std_logic_vector(4 downto 0);
	I_BLUE		: in std_logic_vector(4 downto 0);
	I_HCNT		: in std_logic_vector(9 downto 0);
	I_VCNT		: in std_logic_vector(9 downto 0);
	I_DOWNLOAD_OK	: in std_logic;
	O_RED		: out std_logic_vector(7 downto 0);
	O_GREEN		: out std_logic_vector(7 downto 0);
	O_BLUE		: out std_logic_vector(7 downto 0);
	O_BUTTONS	: out std_logic_vector(1 downto 0);
	O_SWITCHES	: out std_logic_vector(2 downto 0);
	O_JOYPAD_KEYS	: out std_logic_vector(15 downto 0);
	
	O_SPI_CLK	: out std_logic;
	O_SPI_MOSI	: out std_logic;
	O_SPI_CS_N	: out std_logic;	-- SPI FLASH
	O_SPI1_CS_N	: out std_logic;	-- SD Card
	
	O_DOWNLOAD_DO	: out std_logic_vector(7 downto 0);
	O_DOWNLOAD_WR	: out std_logic;
	O_DOWNLOAD_ON	: out std_logic);
end osd;

architecture rtl of osd is

signal spi_busy		: std_logic;
signal spi_do		: std_logic_vector(7 downto 0);
signal spi_wr		: std_logic;
signal cpu_di		: std_logic_vector(7 downto 0);
signal cpu_do		: std_logic_vector(7 downto 0);
signal cpu_addr		: std_logic_vector(15 downto 0);
signal cpu_mreq		: std_logic;
signal cpu_iorq		: std_logic;
signal cpu_wr		: std_logic;
signal m1		: std_logic;
signal ram_wr		: std_logic;
signal ram_do		: std_logic_vector(7 downto 0);
signal reg_0		: std_logic_vector(7 downto 0) := "11111111";
signal buttons		: std_logic_vector(1 downto 0) := "00";
signal switches		: std_logic_vector(2 downto 0) := "000";
signal osd_byte		: std_logic_vector(7 downto 0);
signal osd_pixel	: std_logic;
signal osd_de		: std_logic;
signal osd_vcnt		: std_logic_vector(9 downto 0);
signal osd_hcnt		: std_logic_vector(9 downto 0);
signal osd_h_active	: std_logic;
signal osd_v_active	: std_logic;
signal djoy1		: std_logic_vector(7 downto 0);
signal djoy2		: std_logic_vector(7 downto 0);
signal int		: std_logic;

constant OSD_INK	: std_logic_vector(2 downto 0) := "111";	-- RGB
constant OSD_PAPER	: std_logic_vector(2 downto 0) := "011";	-- RGB
constant OSD_H_ON	: std_logic_vector(9 downto 0) := "0010000000";	-- 128
constant OSD_H_OFF	: std_logic_vector(9 downto 0) := "0110000000";	-- 384
constant OSD_V_ON	: std_logic_vector(9 downto 0) := "0010110000";	-- 176
constant OSD_V_OFF	: std_logic_vector(9 downto 0) := "0100110000";	-- 304

begin

u0: entity work.spi
port map(
	RESET		=> I_RESET,
	CLK		=> I_CLK_CPU,
	SCK		=> I_CLK,
	DI		=> cpu_do,
	DO		=> spi_do,
	WR		=> spi_wr,
	BUSY		=> spi_busy,
	SCLK		=> O_SPI_CLK,
	MOSI		=> O_SPI_MOSI,
	MISO		=> I_SPI_MISO);

u1: entity work.nz80cpu
port map(
	CLK		=> I_CLK_CPU,
	CLKEN		=> '1',
	RESET		=> I_RESET,
	NMI		=> '0',
	INT		=> int,
	DI		=> cpu_di,
	DO		=> cpu_do,
	ADDR		=> cpu_addr,
	WR		=> cpu_wr,
	MREQ		=> cpu_mreq,
	IORQ		=> cpu_iorq,
	HALT		=> open,
	M1		=> m1);
	
u2: entity work.ram
port map(
	address_a 	=> cpu_addr(13 downto 0),
	address_b	=> "111" & osd_vcnt(6 downto 4) & osd_hcnt(7 downto 0),
	clock_a	 	=> I_CLK,
	clock_b		=> I_CLK_CPU,
	data_a	 	=> cpu_do,
	data_b		=> (others => '0'),
	wren_a	 	=> ram_wr,
	wren_b		=> '0',
	q_a	 	=> ram_do,
	q_b		=> osd_byte);

-------------------------------------------------------------------------------
-- CPU
process (I_CLK, I_RESET, cpu_addr, cpu_iorq, cpu_wr)
begin
	if (I_RESET = '1') then
		reg_0 <= (others => '1');
		buttons <= (others => '0');
		switches <= (others => '0');
	elsif (I_CLK'event and I_CLK = '1') then
		if cpu_addr(7 downto 0) = X"00" and cpu_iorq = '1' and cpu_wr = '1' then reg_0 <= cpu_do; end if;
		if cpu_addr(7 downto 0) = X"03" and cpu_iorq = '1' and cpu_wr = '1' then buttons <= cpu_do(1 downto 0); end if;
		if cpu_addr(7 downto 0) = X"04" and cpu_iorq = '1' and cpu_wr = '1' then djoy1 <= cpu_do; end if;
		if cpu_addr(7 downto 0) = X"07" and cpu_iorq = '1' and cpu_wr = '1' then switches <= cpu_do(2 downto 0); end if;
		if cpu_addr(7 downto 0) = X"0F" and cpu_iorq = '1' and cpu_wr = '1' then djoy2 <= cpu_do; end if;
		
	end if;
end process;

-- 00 - SPI SC#
-- 01 - SPI0 DATA I/O
-- 02 - SPI0 STATUS
-- 03 - BUTTONS
-- 04 - DJOY1
-- 05 - DOWNLOAD DATA/STATUS
-- 06 - 
-- 07 - SWITCHES W	KEY R
-- 0F - DJOY2

cpu_di <=	ram_do when cpu_addr(15) = '0' and cpu_mreq = '1' and cpu_wr = '0' else
		reg_0 when cpu_addr(7 downto 0) = X"00" and cpu_iorq = '1' and cpu_wr = '0' else
		spi_do when cpu_addr(7 downto 0) = X"01" and cpu_iorq = '1' and cpu_wr = '0' else
		spi_busy & "0000000" when cpu_addr(7 downto 0) = X"02" and cpu_iorq = '1' and cpu_wr = '0' else
		I_DOWNLOAD_OK & "0000000" when cpu_addr(7 downto 0) = X"05" and cpu_iorq = '1' and cpu_wr = '0' else
		I_KEY0 when cpu_addr = X"0007" and cpu_iorq = '1' and cpu_wr = '0' else
		I_KEY1 when cpu_addr = X"0107" and cpu_iorq = '1' and cpu_wr = '0' else
		I_KEY2 when cpu_addr = X"0207" and cpu_iorq = '1' and cpu_wr = '0' else
		I_KEY3 when cpu_addr = X"0307" and cpu_iorq = '1' and cpu_wr = '0' else
		I_KEY4 when cpu_addr = X"0407" and cpu_iorq = '1' and cpu_wr = '0' else
		I_KEY5 when cpu_addr = X"0507" and cpu_iorq = '1' and cpu_wr = '0' else
		I_KEY6 when cpu_addr = X"0607" and cpu_iorq = '1' and cpu_wr = '0' else
		X"FF";

ram_wr <= '1' when cpu_addr(15) = '0' and cpu_mreq = '1' and cpu_wr = '1' else '0';
spi_wr <= '1' when cpu_addr(7 downto 0) = X"01" and cpu_iorq = '1' and cpu_wr = '1' else '0';

-- INT
process (I_CLK, cpu_iorq, m1, I_VCNT)
begin
	if (cpu_iorq = '1' and m1 = '1') then
		int <= '0';
	elsif (I_CLK'event and I_CLK = '1') then
		if (I_VCNT = "0000000000") then
			int <= '1';
		end if;
	end if;
end process;

O_SPI_CS_N  <= reg_0(0);
O_SPI1_CS_N <= reg_0(1);

O_DOWNLOAD_WR <= '1' when cpu_addr(7 downto 0) = X"05" and cpu_iorq = '1' and cpu_wr = '1' else '0';
O_DOWNLOAD_ON <= not reg_0(2);
O_DOWNLOAD_DO <= cpu_do;

O_BUTTONS <= buttons;
O_SWITCHES <= switches;
O_JOYPAD_KEYS <= djoy2 & djoy1;

-------------------------------------------------------------------------------
-- OSD
process (I_CLK_CPU)
begin
	if (I_CLK_CPU'event and I_CLK_CPU = '1') then
		if (I_HCNT = OSD_H_ON) then osd_h_active <= '1'; end if;
		if (I_HCNT = OSD_H_OFF) then osd_h_active <= '0'; end if;
		if (I_VCNT = OSD_V_ON) then osd_v_active <= '1'; end if;
		if (I_VCNT = OSD_V_OFF) then osd_v_active <= '0'; end if;
	end if;
end process;

osd_de <= not switches(0) and osd_h_active and osd_v_active;
osd_hcnt <= I_HCNT - OSD_H_ON;
osd_vcnt <= I_VCNT - OSD_V_ON;

process (osd_vcnt, osd_byte)
begin
	case osd_vcnt(3 downto 1) is
		when "000" => osd_pixel <= osd_byte(0);
		when "001" => osd_pixel <= osd_byte(1);
		when "010" => osd_pixel <= osd_byte(2);
		when "011" => osd_pixel <= osd_byte(3);
		when "100" => osd_pixel <= osd_byte(4);
		when "101" => osd_pixel <= osd_byte(5);
		when "110" => osd_pixel <= osd_byte(6);
		when "111" => osd_pixel <= osd_byte(7);
		when others => null;
	end case;
end process;
		
O_RED <= (others => OSD_INK(2)) when osd_pixel = '1' and osd_de = '1' else '0' & OSD_PAPER(2) & I_RED(4 downto 0) & '0' when osd_de = '1' else I_RED & "000";
O_GREEN <= (others => OSD_INK(1)) when osd_pixel = '1' and osd_de = '1' else '0' & OSD_PAPER(1) & I_GREEN(4 downto 0) & '0' when osd_de = '1' else I_GREEN & "000";
O_BLUE <= (others => OSD_INK(0)) when osd_pixel = '1' and osd_de = '1' else '0' & OSD_PAPER(0) & I_BLUE(4 downto 0) & '0' when osd_de = '1' else I_BLUE & "000";

end rtl;