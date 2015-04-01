-------------------------------------------------------------------[09.12.2014]
-- KEYBOARD CONTROLLER USB HID scancode to Spectrum matrix conversion
-------------------------------------------------------------------------------
-- V1.0		24.07.2014	USB HID Keyboard

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use ieee.std_logic_unsigned.all;

entity keyboard is
port (
	CLK		: in std_logic;
	RESET		: in std_logic;
	JOYPAD_DATA1	: out std_logic;
	JOYPAD_DATA2	: out std_logic;
	JOYPAD_CLK1	: in std_logic;
	JOYPAD_CLK2	: in std_logic;
	JOYPAD_LATCH	: in std_logic;
	KEYSCAN		: out std_logic_vector(7 downto 0);
	RX		: in std_logic);
end keyboard;

architecture rtl of keyboard is

signal keyb_data	: std_logic_vector(7 downto 0);
signal key		: std_logic_vector(15 downto 0) := "0000000000000000";
signal cnt1		: std_logic_vector(2 downto 0);
signal cnt2		: std_logic_vector(2 downto 0);
signal keycode		: std_logic_vector(7 downto 0);

begin

	inst_rx : entity work.receiver
	port map (
		CLK		=> CLK,
		RESET		=> RESET,
		RX		=> RX,
		DATA		=> keyb_data);

	
	process (RESET, CLK, keyb_data)
	begin
		if RESET = '1' then
			key <= (others => '0');

		elsif CLK'event and CLK = '1' then
			case keyb_data is
				when X"02" => 
					key <= (others => '0');
					keycode <= X"FF";
				-- JOY 1
				when X"04" => key(0) <= '1';	-- [A] 		(A)
				when X"16" => key(1) <= '1';	-- [S]		(B)
				when X"E5" => key(2) <= '1';	-- [RSHIFT]	(Select)
				when X"28" => key(3) <= '1';	-- [ENTER]	(Start)
				when X"52" => key(4) <= '1';	-- [up]		(Up)
				when X"51" => key(5) <= '1';	-- [down]	(Down)
				when X"50" => key(6) <= '1';	-- [left]	(Left)
				when X"4F" => key(7) <= '1';	-- [right] 	(Right)
				-- JOY 2
				when X"1E" => key(8) <= '1';	-- [1]	 	(A)
				when X"1F" => key(9) <= '1';	-- [2]		(B)
				when X"20" => key(10) <= '1';	-- [3]		(Select)
				when X"21" => key(11) <= '1';	-- [4]		(Start)
				when X"60" => key(12) <= '1';	-- [up]		(Up)
				when X"5D" => key(13) <= '1';	-- [down]	(Down)
				when X"5C" => key(14) <= '1';	-- [left]	(Left)
				when X"5E" => key(15) <= '1';	-- [right]	(Right)
				
				when X"47" => keycode <= X"47";	-- Scroll
				when X"29" => keycode <= X"29";	-- Esc
				when X"3A" => keycode <= X"3A";	-- F1

				when others => null;
			end case;
		end if;
	end process;

	process (JOYPAD_CLK1, JOYPAD_LATCH)
	begin
		if (JOYPAD_LATCH = '1') then
			cnt1 <= (others => '0');
		elsif (JOYPAD_CLK1'event and JOYPAD_CLK1 = '1') then
			cnt1 <= cnt1 + 1;
		end if;
	end process;

	process (cnt1, key)
	begin
		case cnt1 is
			when "001" => 	JOYPAD_DATA1 <= key(0);	-- A
			when "010" => 	JOYPAD_DATA1 <= key(1);	-- B
			when "011" => 	JOYPAD_DATA1 <= key(2);	-- Select
			when "100" => 	JOYPAD_DATA1 <= key(3);	-- Start
			when "101" => 	JOYPAD_DATA1 <= key(4);	-- Up
			when "110" => 	JOYPAD_DATA1 <= key(5);	-- Down
			when "111" => 	JOYPAD_DATA1 <= key(6);	-- Left
			when "000" => 	JOYPAD_DATA1 <= key(7);	-- Right
			when others => null;
		end case;
	end process;

	process (JOYPAD_CLK2, JOYPAD_LATCH)
	begin
		if (JOYPAD_LATCH = '1') then
			cnt2 <= (others => '0');
		elsif (JOYPAD_CLK2'event and JOYPAD_CLK2 = '1') then
			cnt2 <= cnt2 + 1;
		end if;
	end process;

	process (cnt2, key)
	begin
		case cnt2 is
			when "001" =>	JOYPAD_DATA2 <= key(8);	-- A
			when "010" => 	JOYPAD_DATA2 <= key(9);	-- B
			when "011" => 	JOYPAD_DATA2 <= key(10);	-- Select
			when "100" => 	JOYPAD_DATA2 <= key(11);	-- Start
			when "101" => 	JOYPAD_DATA2 <= key(12);	-- Up
			when "110" => 	JOYPAD_DATA2 <= key(13);	-- Down
			when "111" => 	JOYPAD_DATA2 <= key(14);	-- Left
			when "000" => 	JOYPAD_DATA2 <= key(15);	-- Right
			when others => null;
		end case;
	end process;

	KEYSCAN   <= keycode;
	
end architecture;
