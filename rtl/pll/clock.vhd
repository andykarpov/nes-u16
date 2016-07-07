library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;

entity clock is
	port (
		I_CLK     :  in std_logic; -- 50.0000 MHz

		O_CLK84 	: out std_logic; -- 84.0000 MHz  sdram
		O_CLK42  	: out std_logic; -- 42.0000 MHz  osd
		O_CLK21  	: out std_logic; -- 21.0000 MHz  21000000 / (682 * 524) = 58.7629558326

		O_CLK27  	: out std_logic; -- 27.0000 MHz	 27000000 / (524 * 58.7629558326) = 876.857142858 px / line
		O_CLK135 	: out std_logic; -- 135.000 MHz	 27 * 5 for hdmi

		O_LOCKED  : out std_logic -- locked signal
	);
end;

architecture rtl of clock is
	signal clk_84: std_logic;
	signal clk_42: std_logic;
	signal clk_21: std_logic;
	signal clk_27: std_logic;
	signal clk_135: std_logic;
	signal clock_locked: std_logic;
begin

	c0 : entity work.clk27
	port map (
		inclk0  => I_CLK,
		c0 		=> clk_27,
		c1 		=> clk_135
	);

	c1 : entity work.clk21
	port map (
		inclk0 	=> I_CLK,
		c0 		=> clk_84,
		c1 		=> clk_42,
		c2 		=> clk_21,
		locked 	=> clock_locked
	);

	-- output assignments

	O_CLK84  <= clk_84;
	O_CLK42  <= clk_42;
	O_CLK21  <= clk_21;

	O_CLK27  <= clk_27;
	O_CLK135 <= clk_135;

	O_LOCKED <= clock_locked;

end rtl;
