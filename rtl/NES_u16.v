// Copyright (c) 2012-2013 Ludvig Strigeus
// This program is GPL Licensed. See COPYING for the full license.
//
// Modified for ReVerSE-U16 By MVV (build 20160217)

//`timescale 1ns / 1ps


// Module reads bytes and writes to proper address in ram.
// Done is asserted when the whole game is loaded.
// This parses iNES headers too.
module GameLoader(
	input			clk,
	input			reset,
	input [7:0]		indata,
	input			indata_clk,
	output reg [21:0]	mem_addr,
	output [7:0]		mem_data,
	output			mem_write,
	output [31:0]		mapper_flags,
	output reg		done);
	
	reg [ 1:0] state = 0;
	reg [ 7:0] prgsize;
	reg [ 3:0] ctr;
	reg [ 7:0] ines[0:15];	// 16 bytes of iNES header
	reg [21:0] bytes_left;
	
//	assign error = (state == 3);
	assign mem_data = indata;
	assign mem_write = (bytes_left != 0) && (state == 1 || state == 2) && indata_clk;
	
	wire [2:0] prg_size =	ines[4] <= 1 ? 0 :
				ines[4] <= 2 ? 1 : 
				ines[4] <= 4 ? 2 : 
				ines[4] <= 8 ? 3 : 
				ines[4] <= 16 ? 4 : 
				ines[4] <= 32 ? 5 : 
				ines[4] <= 64 ? 6 : 7;
												
	wire [2:0] chr_size = 	ines[5] <= 1 ? 0 : 
				ines[5] <= 2 ? 1 : 
				ines[5] <= 4 ? 2 : 
				ines[5] <= 8 ? 3 : 
				ines[5] <= 16 ? 4 : 
				ines[5] <= 32 ? 5 : 
				ines[5] <= 64 ? 6 : 7;
	
	wire has_chr_ram = (ines[5] == 0);
	assign mapper_flags = {16'b0, has_chr_ram, ines[6][0], chr_size, prg_size, ines[7][7:4], ines[6][7:4]};
	
	always @(posedge clk) begin
		if (reset) begin
			state <= 0;
			done <= 0;
			ctr <= 0;
			mem_addr <= 0;	// Address for PRG
		end else begin
			case(state)
			// Read 16 bytes of ines header
			0: if (indata_clk) begin
				ctr <= ctr + 1;
				ines[ctr] <= indata;
				bytes_left <= {ines[4], 14'b0};
				if (ctr == 4'b1111)
					state <= (ines[0] == 8'h4E) && (ines[1] == 8'h45) && (ines[2] == 8'h53) && (ines[3] == 8'h1A) && !ines[6][2] && !ines[6][3] ? 1 : 3;
				end
			1, 2: begin // Read the next |bytes_left| bytes into |mem_addr|
				if (bytes_left != 0) begin
					if (indata_clk) begin
						bytes_left <= bytes_left - 1;
						mem_addr <= mem_addr + 1;
					end
				end else if (state == 1) begin
					state <= 2;
					mem_addr <= 22'b10_0000_0000_0000_0000_0000; // Address for CHR
					bytes_left <= {1'b0, ines[5], 13'b0};
				end else if (state == 2) begin
				done <= 1;
				end
				end
			endcase
		end
	end
endmodule


module NES_u16(	
	// clock input
	input		CLOCK_50, // 50 MHz
	input		KEY_RESET,
	// HDMI
	output		HDMI_D0,
	output		HDMI_D1, HDMI_D1N,
	output		HDMI_D2,
	output		HDMI_CLK,
	// USB HOST	
	input		USB_TX,
	input		USB_SI,
	output		USB_NCS,
	// SPI FLASH
	output		SPI_DI,
	input		SPI_DO,
	output		SPI_SCK,
	output		SPI_CSn,
	// SDRAM																																																																												 
	inout  [ 15:0]	SDRAM_DQ,	// SDRAM Data bus 16 Bits																																																				
	output [ 12:0]	SDRAM_A,	// SDRAM Address bus 13 Bits																																																			
	output		SDRAM_DQML,	// SDRAM Low-byte Data Mask																																																		
	output		SDRAM_DQMH,	// SDRAM High-byte Data Mask																																																	 
	output		SDRAM_nWE,	// SDRAM Write Enable																																																					 
	output		SDRAM_nCAS,	// SDRAM Column Address Strobe																																																 
	output		SDRAM_nRAS,	// SDRAM Row Address Strobe																																																		
	output [ 1:0]	SDRAM_BA,	// SDRAM Bank Address																																																						
	output		SDRAM_CLK,	// SDRAM Clock																																																									
	// audio
	output		AUDIO_L,
	output		AUDIO_R
);
 
	// VGA
	wire [7:0]	vga_red;
	wire [7:0]	vga_green;	
	wire [7:0]	vga_blue;	
	wire [2:0]	tmds_d;
	
//	wire [7:0]	joyA;
//	wire [7:0]	joyB;
	wire [1:0]	buttons;
	wire [2:0]	switches;
	 

	wire spi1_clk;
	wire spi1_do;
	wire spi1_di;
	
	wire [4:0] nes_r;
	wire [4:0] nes_g;
	wire [4:0] nes_b;
	wire nes_hs;
	wire nes_vs;

	hdmidirect tmds(
		.pixclk		(clk),
		.pixclk72	(clk_dvi),
		.red		(vga_red),
		.green		(vga_green),
		.blue		(vga_blue),
		.hSync		(nes_hs),
		.vSync		(nes_vs),
		.CounterX	(vga_hcounter),
		.CounterY	(vga_vcounter),
		.DrawArea	(blank),
		.SampleL	({sample[15:8],4'b0000}),
		.SampleR	({sample[15:8],4'b0000}),
		.tmds_d		(tmds_d)
	);
	
	
	assign HDMI_D0 = tmds_d[0];
	assign HDMI_D1 = tmds_d[1];
	assign HDMI_D2 = tmds_d[2];
	assign HDMI_CLK = clk;
	
	wire blank;
	assign HDMI_D1N = 1'b0;
	assign USB_NCS = 1'b0;

	// =======================================================
	osd cocpu(
		.I_RESET	(!KEY_RESET),
		.I_CLK		(clk42),	// 42MHz
		.I_CLK_CPU	(clk),		// 21MHz
		.I_KEY0		(key0),
		.I_KEY1		(key1),
		.I_KEY2		(key2),
		.I_KEY3		(key3),
		.I_KEY4		(key4),
		.I_KEY5		(key5),
		.I_KEY6		(key6),
		.I_SPI_MISO	(SPI_DO),
		.I_SPI1_MISO	(spi1_do),
		.I_RED		(nes_r),
		.I_GREEN	(nes_g),
		.I_BLUE		(nes_b),
		.I_HCNT		(vga_hcounter),
		.I_VCNT		(vga_vcounter),
		.I_DOWNLOAD_OK	(loader_done),
		.O_RED		(vga_red),
		.O_GREEN	(vga_green),
		.O_BLUE		(vga_blue),
		.O_BUTTONS	(buttons),
		.O_SWITCHES	(switches),
		.O_JOYPAD_KEYS	(joypad_keys),
		.O_SPI_CLK	(SPI_SCK),
		.O_SPI_MOSI	(SPI_DI),
		.O_SPI_CS_N	(SPI_CSn),	// SPI FLASH
		.O_SPI1_CS_N	(),		// SD Card
		.O_DOWNLOAD_DO	(loader_input),
		.O_DOWNLOAD_WR	(loader_clk),
		.O_DOWNLOAD_ON	(downloading)
	);

	wire [15:0] joypad_keys;
	wire [7:0] key0;
	wire [7:0] key1;
	wire [7:0] key2;
	wire [7:0] key3;
	wire [7:0] key4;
	wire [7:0] key5;
	wire [7:0] key6;
		
	hid hid(
		.I_CLK		(CLOCK_50),
		.I_RESET	(!KEY_RESET),
		.I_RX		(USB_TX),
		.I_NEWFRAME	(USB_SI),
		.I_JOYPAD_KEYS	(joypad_keys),
		.I_JOYPAD_CLK1	(joypad_clock[0]),
		.I_JOYPAD_CLK2	(joypad_clock[1]),
		.I_JOYPAD_LATCH	(joypad_strobe),
		.O_JOYPAD_DATA1	(joypad_bits),
		.O_JOYPAD_DATA2	(joypad_bits2),
		.O_KEY0		(key0),
		.O_KEY1		(key1),
		.O_KEY2		(key2),
		.O_KEY3		(key3),
		.O_KEY4		(key4),
		.O_KEY5		(key5),
		.O_KEY6		(key6));

	
	
	// =======================================================

	
	wire clock_locked;
	wire clk_sdram;
	wire clk_dvi;
	wire clk42;
	assign SDRAM_CLK = clk_sdram;
	
	clk clock_21mhz(
		.inclk0		(CLOCK_50),
		.c0		(clk_sdram),
		.c1		(clk_dvi),
		.c2		(clk),
		.c3		(clk42),
		.locked		(clock_locked));

	// hold machine in reset until first download starts
	reg init_reset;
	always @(posedge CLOCK_50) begin
	if(!clock_locked)
		init_reset <= 1'b1;
	else if(downloading)
		init_reset <= 1'b0;
	end
	
	wire clk;
	wire spi2_cs_n;
	wire spi3_cs_n;
	wire spi4_cs_n;
	
	// Loader
	wire [7:0] 	loader_input;
	wire		loader_clk;
	reg [7:0]	loader_btn, loader_btn_2;

	// NES Palette -> RGB332 conversion
	reg [15:0]	pallut[0:63];
	initial $readmemh("../src/nes_palette.txt", pallut);

	wire [8:0]	cycle;
	wire [8:0]	scanline;
	wire [15:0]	sample;
	wire [5:0]	color;
	wire		joypad_strobe;
	wire [1:0]	joypad_clock;
	wire [21:0] 	memory_addr;
	wire		memory_read_cpu, memory_read_ppu;
	wire		memory_write;
	wire [7:0]	memory_din_cpu, memory_din_ppu;
	wire [7:0]	memory_dout;
	wire		joypad_bits, joypad_bits2;
	reg [1:0]	last_joypad_clock;
	reg [1:0]	nes_ce;
	wire [21:0]	loader_addr;
	wire [7:0]	loader_write_data;
	wire		loader_reset = !downloading; //loader_conf[0];
	wire		loader_write;
	wire [31:0]	mapper_flags;
	wire		loader_done;
	
	GameLoader loader(
		clk,
		loader_reset,
		loader_input,
		loader_clk,
		loader_addr,
		loader_write_data,
		loader_write,
		mapper_flags,
		loader_done);

//TH	wire reset_nes = (buttons[1] || !loader_done);
//	wire reset_nes = (init_reset || buttons[1] || status[0] || status[4] || downloading);
	wire reset_nes = (init_reset || buttons[0] || !KEY_RESET || downloading);
//	wire run_mem = (nes_ce == 0) && !reset_nes;
	wire run_nes = (nes_ce == 3) && !reset_nes;

	// NES is clocked at every 4th cycle.
	always @(posedge clk)
//	always @(negedge clk)
		nes_ce <= nes_ce + 2'b1;
		
	NES nes(
		clk,
		reset_nes,
		run_nes,
		mapper_flags,
		sample,
		color,
		joypad_strobe,
		joypad_clock,
		{joypad_bits2, joypad_bits},
		5'b11111,	// enable all channels
		memory_addr,
		memory_read_cpu,
		memory_din_cpu,
		memory_read_ppu,
		memory_din_ppu,
		memory_write,
		memory_dout,
		cycle,
		scanline);
		//dbgadr,
		//dbgctr);

	//assign SDRAM_CKE = 1'b1;

	// loader_write -> clock when data available
	reg		loader_write_mem;
	reg [7:0]	loader_write_data_mem;
	reg [21:0]	loader_addr_mem;
	reg		loader_write_triggered;

	always @(posedge clk) begin
		if(loader_write) begin
			loader_write_triggered	<= 1'b1;
			loader_addr_mem		<= loader_addr;
			loader_write_data_mem	<= loader_write_data;
		end
	
		if(nes_ce == 3) begin
			loader_write_mem <= loader_write_triggered;
			if(loader_write_triggered)
				loader_write_triggered <= 1'b0;
			end
		end

	sdram sdram (
		// interface to the MT48LC16M16 chip
		.sd_data	(SDRAM_DQ),
		.sd_addr	(SDRAM_A),
		.sd_dqm		({SDRAM_DQMH, SDRAM_DQML}),
		.sd_cs		(/*SDRAM_nCS*/),
		.sd_ba		(SDRAM_BA),
		.sd_we		(SDRAM_nWE),
		.sd_ras		(SDRAM_nRAS),
		.sd_cas		(SDRAM_nCAS),
		// system interface
		.clk		(clk_sdram),
		.clkref		(nes_ce[1]),
		.init		(!clock_locked),
		// cpu/chipset interface
		.addr		(downloading ? {3'b000, loader_addr_mem} : {3'b000, memory_addr}),
		.we		(memory_write || loader_write_mem),
		.din		(downloading ? loader_write_data_mem : memory_dout),
		.oeA		(memory_read_cpu),
		.doutA		(memory_din_cpu),
		.oeB		(memory_read_ppu),
		.doutB		(memory_din_ppu)
	);

	wire downloading;
	
	wire [14:0] 	doubler_pixel;
	wire		doubler_sync;
	wire [9:0]	vga_hcounter, doubler_x;
	wire [9:0]	vga_vcounter;
	
	VgaDriver vga(
		clk,
		nes_hs,
		nes_vs,
		nes_r,
		nes_g,
		nes_b,
		vga_hcounter,
		vga_vcounter,
		doubler_x,
		blank,
		doubler_pixel,
		doubler_sync,
		1'b0);
	
	wire [14:0] pixel_in = pallut[color];
	
	Hq2x hq2x(
		clk,
		pixel_in,
		switches[1],		// enabled 
		scanline[8],		// reset_frame
		(cycle[8:3] == 42),	// reset_line
		doubler_x,		// 0-511 for line 1, or 512-1023 for line 2.
		doubler_sync,		// new frame has just started
		doubler_pixel);		// pixel is outputted

assign AUDIO_R = audio;
assign AUDIO_L = audio;
wire audio;
	 
	sigma_delta_dac sigma_delta_dac (
		.DACout		(audio),
		.DACin		(sample[15:8]),
		.CLK		(clk),
		.RESET		(reset_nes)
	);

endmodule
