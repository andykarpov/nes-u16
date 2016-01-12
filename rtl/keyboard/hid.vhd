-------------------------------------------------------------------[11.11.2015]
-- USB HID
-------------------------------------------------------------------------------
-- Engineer:	MVV
--
-- 11.11.2015	USB HID Keyboard

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use ieee.std_logic_unsigned.all;

entity hid is
port (
	I_CLK		: in std_logic;
	I_RESET		: in std_logic;
	I_RX		: in std_logic;
	I_NEWFRAME	: in std_logic;
	I_JOYPAD_KEYS	: in std_logic_vector(15 downto 0);
	I_JOYPAD_CLK1	: in std_logic;
	I_JOYPAD_CLK2	: in std_logic;
	I_JOYPAD_LATCH	: in std_logic;
	O_JOYPAD_DATA1	: out std_logic;
	O_JOYPAD_DATA2	: out std_logic;
	O_KEY0		: out std_logic_vector(7 downto 0);
	O_KEY1		: out std_logic_vector(7 downto 0);
	O_KEY2		: out std_logic_vector(7 downto 0);
	O_KEY3		: out std_logic_vector(7 downto 0);
	O_KEY4		: out std_logic_vector(7 downto 0);
	O_KEY5		: out std_logic_vector(7 downto 0);
	O_KEY6		: out std_logic_vector(7 downto 0));
end hid;

architecture rtl of hid is

signal data		: std_logic_vector(7 downto 0);
signal cnt1		: std_logic_vector(2 downto 0);
signal cnt2		: std_logic_vector(2 downto 0);
signal ready		: std_logic;
signal device_id	: std_logic_vector(3 downto 0);
signal count		: integer range 0 to 8;
signal key0		: std_logic_vector(7 downto 0);
signal key1		: std_logic_vector(7 downto 0);
signal key2		: std_logic_vector(7 downto 0);
signal key3		: std_logic_vector(7 downto 0);
signal key4		: std_logic_vector(7 downto 0);
signal key5		: std_logic_vector(7 downto 0);
signal key6		: std_logic_vector(7 downto 0);

begin

	u0 : entity work.receiver
	port map (
		I_CLK		=> I_CLK,
		I_RESET		=> I_RESET,
		I_RX		=> I_RX,
		O_DATA		=> data,
		O_READY		=> ready);

	
	process (I_RESET, I_CLK, I_NEWFRAME, data, ready)
	begin
		if I_RESET = '1' then
			key0 <= (others => '0');
			key1 <= (others => '0');
			key2 <= (others => '0');
			key3 <= (others => '0');
			key4 <= (others => '0');
			key5 <= (others => '0');
			key6 <= (others => '0');
		elsif I_NEWFRAME = '0' then
			count <= 0;
		elsif (I_CLK'event and I_CLK = '1' and ready = '1') then
			-- Инициализация
			if (count = 0) then
				count <= 1;
				device_id <= data(3 downto 0);
			else
				count <= count + 1;
				case device_id is
--					when x"2" =>	-- Mouse
--						case count is
--							when 1 => mouse0 <= data;	-- клавиши модификаторы
--							when 2 => mouse1 <= data;	-- код клавиши 1
--							when 3 => mouse2 <= data;	-- код клавиши 2
--							when 4 => mouse3 <= data;	-- код клавиши 3
--							when others => null;
--						end case;
					when x"6" =>	-- Keyboard
						case count is
							when 1 => key0 <= data;	-- клавиши модификаторы
							when 3 => key1 <= data;	-- код клавиши 1
							when 4 => key2 <= data;	-- код клавиши 2
							when 5 => key3 <= data;	-- код клавиши 3
							when 6 => key4 <= data;	-- код клавиши 4
							when 7 => key5 <= data;	-- код клавиши 5
							when 8 => key6 <= data;	-- код клавиши 6
							when others => null;
						end case;
					when others => null;
				end case;
			end if;
		end if;
	end process;

O_KEY0 <= key0;
O_KEY1 <= key1;
O_KEY2 <= key2;
O_KEY3 <= key3;
O_KEY4 <= key4;
O_KEY5 <= key5;
O_KEY6 <= key6;	
	
	process (I_JOYPAD_CLK1, I_JOYPAD_LATCH)
	begin
		if (I_JOYPAD_LATCH = '1') then
			cnt1 <= (others => '0');
		elsif (I_JOYPAD_CLK1'event and I_JOYPAD_CLK1 = '0') then
			cnt1 <= cnt1 + 1;
		end if;
	end process;

	process (cnt1, I_JOYPAD_KEYS)
	begin
		case cnt1 is
			when "000" => O_JOYPAD_DATA1 <= I_JOYPAD_KEYS(7);	-- A
			when "001" => O_JOYPAD_DATA1 <= I_JOYPAD_KEYS(6);	-- B
			when "010" => O_JOYPAD_DATA1 <= I_JOYPAD_KEYS(5);	-- Select
			when "011" => O_JOYPAD_DATA1 <= I_JOYPAD_KEYS(4);	-- Start
			when "100" => O_JOYPAD_DATA1 <= I_JOYPAD_KEYS(3);	-- Up
			when "101" => O_JOYPAD_DATA1 <= I_JOYPAD_KEYS(2);	-- Down
			when "110" => O_JOYPAD_DATA1 <= I_JOYPAD_KEYS(1);	-- Left
			when "111" => O_JOYPAD_DATA1 <= I_JOYPAD_KEYS(0);	-- Right
			when others => null;
		end case;
	end process;

	process (I_JOYPAD_CLK2, I_JOYPAD_LATCH)
	begin
		if (I_JOYPAD_LATCH = '1') then
			cnt2 <= (others => '0');
		elsif (I_JOYPAD_CLK2'event and I_JOYPAD_CLK2 = '0') then
			cnt2 <= cnt2 + 1;
		end if;
	end process;

	process (cnt2, I_JOYPAD_KEYS)
	begin
		case cnt2 is
			when "000" => O_JOYPAD_DATA2 <= I_JOYPAD_KEYS(8);	-- A
			when "001" => O_JOYPAD_DATA2 <= I_JOYPAD_KEYS(9);	-- B
			when "010" => O_JOYPAD_DATA2 <= I_JOYPAD_KEYS(10);	-- Select
			when "011" => O_JOYPAD_DATA2 <= I_JOYPAD_KEYS(11);	-- Start
			when "100" => O_JOYPAD_DATA2 <= I_JOYPAD_KEYS(12);	-- Up
			when "101" => O_JOYPAD_DATA2 <= I_JOYPAD_KEYS(13);	-- Down
			when "110" => O_JOYPAD_DATA2 <= I_JOYPAD_KEYS(14);	-- Left
			when "111" => O_JOYPAD_DATA2 <= I_JOYPAD_KEYS(15);	-- Right
			when others => null;
		end case;
	end process;
	
end architecture;
