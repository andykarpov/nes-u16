-------------------------------------------------------------------[09.12.2014]
-- KEYBOARD CONTROLLER USB HID scancode to Spectrum matrix conversion
-------------------------------------------------------------------------------
-- Engineer:	MVV
--
-- 24.07.2014	USB HID Keyboard

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use ieee.std_logic_unsigned.all;

entity keyboard is
port (
	I_CLK		: in std_logic;
	I_RESET		: in std_logic;
	I_RX		: in std_logic;
	I_NEWFRAME	: in std_logic;	
	O_JOYPAD_DATA1	: out std_logic;
	O_JOYPAD_DATA2	: out std_logic;
	I_JOYPAD_CLK1	: in std_logic;
	I_JOYPAD_CLK2	: in std_logic;
	I_JOYPAD_LATCH	: in std_logic;
	O_KEYSCAN	: out std_logic_vector(7 downto 0));
end keyboard;

architecture rtl of keyboard is

signal data		: std_logic_vector(7 downto 0);
signal key		: std_logic_vector(15 downto 0) := "0000000000000000";
signal cnt1		: std_logic_vector(2 downto 0);
signal cnt2		: std_logic_vector(2 downto 0);
signal keycode		: std_logic_vector(7 downto 0);
signal ready		: std_logic;

begin

	inst_rx : entity work.receiver
	port map (
		I_CLK		=> I_CLK,
		I_RESET		=> I_RESET,
		I_RX		=> I_RX,
		O_DATA		=> data,
		O_READY		=> ready);

	
	process (I_RESET, I_CLK, I_NEWFRAME, keyb_data, ready)
	begin
		if I_RESET = '1' then
			key <= (others => '0');
		elsif I_NEWFRAME = '0' then
			count <= 0;
		elsif I_CLK'event and I_CLK = '1' and ready = '1' then
			if count = 0 then
				count <= 1;
				device_id <= data(3 downto 0);
		
		
			case keyb_data is
				when X"02" => 
					key <= (others => '0');
					keycode <= X"FF";
				-- JOY 1
				when X"04" => key(0) <= '1'; keycode <= X"04";	-- [A] 		(A)
				when X"16" => key(1) <= '1'; keycode <= X"16";	-- [S]		(B)
				when X"E5" => key(2) <= '1'; keycode <= X"E5";	-- [RSHIFT]	(Select)
				when X"28" => key(3) <= '1'; keycode <= X"28";	-- [ENTER]	(Start)
				when X"52" => key(4) <= '1'; keycode <= X"52";	-- [up]		(Up)
				when X"51" => key(5) <= '1'; keycode <= X"51";	-- [down]	(Down)
				when X"50" => key(6) <= '1'; keycode <= X"50";	-- [left]	(Left)
				when X"4F" => key(7) <= '1'; keycode <= X"4F";	-- [right] 	(Right)
				-- JOY 2
				when X"1E" => key(8) <= '1'; keycode <= X"1E";	-- [1]	 	(A)
				when X"1F" => key(9) <= '1'; keycode <= X"1F";	-- [2]		(B)
				when X"20" => key(10) <= '1'; keycode <= X"20";	-- [3]		(Select)
				when X"21" => key(11) <= '1'; keycode <= X"21";	-- [4]		(Start)
				when X"60" => key(12) <= '1'; keycode <= X"60";	-- [up]		(Up)
				when X"5D" => key(13) <= '1'; keycode <= X"5D";	-- [down]	(Down)
				when X"5C" => key(14) <= '1'; keycode <= X"5C";	-- [left]	(Left)
				when X"5E" => key(15) <= '1'; keycode <= X"5E";	-- [right]	(Right)
				
				when X"29" => keycode <= X"29";	-- Esc
				when X"3A" => keycode <= X"3A";	-- F1
				when X"3B" => keycode <= X"3B";	-- F2

				when others => null;
			end case;
		end if;
	end process;

	process (I_JOYPAD_CLK1, I_JOYPAD_LATCH)
	begin
		if (I_JOYPAD_LATCH = '1') then
			cnt1 <= (others => '0');
		elsif (I_JOYPAD_CLK1'event and I_JOYPAD_CLK1 = '1') then
			cnt1 <= cnt1 + 1;
		end if;
	end process;

	process (cnt1, key)
	begin
		case cnt1 is
			when "001" => 	O_JOYPAD_DATA1 <= key(0);	-- A
			when "010" => 	O_JOYPAD_DATA1 <= key(1);	-- B
			when "011" => 	O_JOYPAD_DATA1 <= key(2);	-- Select
			when "100" => 	O_JOYPAD_DATA1 <= key(3);	-- Start
			when "101" => 	O_JOYPAD_DATA1 <= key(4);	-- Up
			when "110" => 	O_JOYPAD_DATA1 <= key(5);	-- Down
			when "111" => 	O_JOYPAD_DATA1 <= key(6);	-- Left
			when "000" => 	O_JOYPAD_DATA1 <= key(7);	-- Right
			when others => null;
		end case;
	end process;

	process (I_JOYPAD_CLK2, I_JOYPAD_LATCH)
	begin
		if (I_JOYPAD_LATCH = '1') then
			cnt2 <= (others => '0');
		elsif (I_JOYPAD_CLK2'event and I_JOYPAD_CLK2 = '1') then
			cnt2 <= cnt2 + 1;
		end if;
	end process;

	process (cnt2, key)
	begin
		case cnt2 is
			when "001" =>	O_JOYPAD_DATA2 <= key(8);		-- A
			when "010" => 	O_JOYPAD_DATA2 <= key(9);		-- B
			when "011" => 	O_JOYPAD_DATA2 <= key(10);	-- Select
			when "100" => 	O_JOYPAD_DATA2 <= key(11);	-- Start
			when "101" => 	O_JOYPAD_DATA2 <= key(12);	-- Up
			when "110" => 	O_JOYPAD_DATA2 <= key(13);	-- Down
			when "111" => 	O_JOYPAD_DATA2 <= key(14);	-- Left
			when "000" => 	O_JOYPAD_DATA2 <= key(15);	-- Right
			when others => null;
		end case;
	end process;

	O_KEYSCAN   <= keycode;
	
end architecture;
