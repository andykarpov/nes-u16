// Copyright (c) 2012-2013 Ludvig Strigeus
// This program is GPL Licensed. See COPYING for the full license.
//
// Modified for ReVerSE-U16 By MVV (build 20160217)
// Modified for ReVerSE-U16 revA by andy.karpov

//`timescale 1ns / 1ps
module NES_u16(	

	// clock input
	input		CLK_50MHZ, // 50 MHz
	input       USB_NRESET,

	// HDMI
	output  [7:0] TMDS,
	
	// USB HOST	
	input		USB_TX,
	input		USB_SI,
	output		USB_NCS,

	// SPI FLASH
	output		ASDO, //SPI_DI
	input		DATA0, //SPI_DO
	output		DCLK, //SPI_SCK
	output		NCSO, //SPI_CSn
	
	// SDRAM				 
	inout  [ 15:0]	SDRAM_DQ,	// SDRAM Data bus 16 Bits											
	output [ 12:0]	SDRAM_A,	// SDRAM Address bus 13 Bits										
	output		SDRAM_DQML,	// SDRAM Low-byte Data Mask												
	output		SDRAM_DQMH,	// SDRAM High-byte Data Mask											
	output		SDRAM_NWE,	// SDRAM Write Enable													
	output		SDRAM_NCAS,	// SDRAM Column Address Strobe											
	output		SDRAM_NRAS,	// SDRAM Row Address Strobe												
	output [ 1:0]	SDRAM_BA,	// SDRAM Bank Address												
	output		SDRAM_CLK,	// SDRAM Clock															

	// audio
	output		DN,
	output		DP
);

	// virtual buttons and switches
	wire [1:0]	buttons;
	wire [2:0]	switches;
	 
	// spi
	wire 		spi1_clk;
	wire 		spi1_do;
	wire 		spi1_di;

	// vga
	wire [7:0]	vga_red;
	wire [7:0]	vga_green;	
	wire [7:0]	vga_blue;
	wire [4:0] 	nes_r;
	wire [4:0] 	nes_g;
	wire [4:0] 	nes_b;
	wire 		nes_hs;
	wire 		nes_vs;
	wire 		blank;
	wire [10:0]      vga_hcounter, vga_vcounter;

	// kbd
	wire [15:0] joypad_keys;
	wire [7:0] 	key0;
	wire [7:0] 	key1;
	wire [7:0] 	key2;
	wire [7:0] 	key3;
	wire [7:0] 	key4;
	wire [7:0] 	key5;
	wire [7:0] 	key6;

	// clk
	wire 		clk_sdram;
	wire 		clk;
	wire 		clk21;
	wire 		clk42;
	wire 		clk25;
	wire 		clk125;
	wire 		clk250;
	wire 		clk_vga;
	wire 		clk_dvi;
	wire 		clock_locked;
	reg [63:0]	acc;

	// reset
	reg 		init_reset;

	// pwm audio
	wire 		audio;

	// spi
	wire 		spi2_cs_n;
	wire 		spi3_cs_n;
	wire 		spi4_cs_n;
	
	// loader
	wire [7:0] 	loader_input;
	wire		loader_clk;
	reg [7:0]	loader_btn, loader_btn_2;
	wire [21:0]	loader_addr;
	wire [7:0]	loader_write_data;
	wire 		downloading;
	wire		loader_reset;
	wire		loader_write;
	wire		loader_done;
	reg			loader_write_mem;
	reg [7:0]	loader_write_data_mem;
	reg [21:0]	loader_addr_mem;
	reg			loader_write_triggered;

	// nes signals
	wire [8:0]	cycle;
	wire [8:0]	scanline;
	wire [15:0]	sample;
	wire [5:0]	color;
	wire		joypad_strobe;
	wire [1:0]	joypad_clock;
	wire [21:0] memory_addr;
	wire		memory_read_cpu, memory_read_ppu;
	wire		memory_write;
	wire [7:0]	memory_din_cpu, memory_din_ppu;
	wire [7:0]	memory_dout;
	wire		joypad_bits, joypad_bits2;
	reg [1:0]	last_joypad_clock;
	reg [1:0]	nes_ce;
	wire [31:0]	mapper_flags;
	wire reset_nes;
	wire run_nes;

	// -- components --

	clk clock_21mhz(
		.inclk0		(CLK_50MHZ),
		.c0		(clk_sdram), // 84
		.c2		(clk), // 21
		.c3		(clk42), // 42
		.locked		(clock_locked));

	clk_vga clock_25mhz(
		.inclk0		(CLK_50MHZ),
		.c0		(clk_vga), // 25
		.c1		(clk_dvi), // 125
		.c2 	(clk250)); // 250

	hid hid(
		.I_CLK		(CLK_50MHZ),
		.I_RESET	(!USB_NRESET),
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

	sdram sdram (
		// interface to the MT48LC16M16 chip
		.sd_data	(SDRAM_DQ),
		.sd_addr	(SDRAM_A),
		.sd_dqm		({SDRAM_DQMH, SDRAM_DQML}),
		.sd_cs		(/*SDRAM_NCS*/),
		.sd_ba		(SDRAM_BA),
		.sd_we		(SDRAM_NWE),
		.sd_ras		(SDRAM_NRAS),
		.sd_cas		(SDRAM_NCAS),
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

	video video (
		.clk(clk),
		.clk_vga(clk_vga),
			
		.color(color),
		.count_v(scanline),
		.count_h(cycle),
		.smoothing(switches[1]),

		.VGA_HS(nes_hs),
		.VGA_VS(nes_vs),
		.VGA_R(nes_r),
		.VGA_G(nes_g),
		.VGA_B(nes_b),
		.VGA_BLANK(blank),
		.VGA_HCOUNTER(vga_hcounter),
		.VGA_VCOUNTER(vga_vcounter)
	);

	osd cocpu(
		.I_RESET	(!USB_NRESET),
		.I_CLK		(clk42),	// 42MHz
		.I_CLK_CPU	(clk),		// 21MHz
		.I_KEY0		(key0),
		.I_KEY1		(key1),
		.I_KEY2		(key2),
		.I_KEY3		(key3),
		.I_KEY4		(key4),
		.I_KEY5		(key5),
		.I_KEY6		(key6),
		.I_SPI_MISO	(DATA0),
		.I_SPI1_MISO	(spi1_do),
		.I_RED		(nes_r),
		.I_GREEN	(nes_g),
		.I_BLUE		(nes_b),
		.I_HCNT		(vga_hcounter),
		.I_VCNT		(vga_vcounter),
		.I_DOWNLOAD_OK	(loader_done),
//		.O_RED		(vga_red),
//		.O_GREEN	(vga_green),
//		.O_BLUE		(vga_blue),
		.O_BUTTONS	(buttons),
		.O_SWITCHES	(switches),
		.O_JOYPAD_KEYS	(joypad_keys),
		.O_SPI_CLK	(DCLK),
		.O_SPI_MOSI	(ASDO),
		.O_SPI_CS_N	(NCSO),	// SPI FLASH
		.O_SPI1_CS_N	(),		// SD Card
		.O_DOWNLOAD_DO	(loader_input),
		.O_DOWNLOAD_WR	(loader_clk),
		.O_DOWNLOAD_ON	(downloading)
	);

	hdmi hdmi(
		.I_CLK_PIXEL(clk_vga), // 25
		.I_CLK_TMDS(clk_dvi), // 125
		.I_RED({nes_r[4:0], 3'b0}),
		.I_GREEN({nes_g[4:0], 3'b0}),
		.I_BLUE({nes_b[4:0], 3'b0}),
		.I_BLANK(blank), 
		.I_HSYNC(nes_hs),
		.I_VSYNC(nes_vs),
		.O_TMDS(TMDS)
	);
	 
	sigma_delta_dac sigma_delta_dac (
		.DACout		(audio),
		.DACin		(sample[15:8]),
		.CLK		(clk),
		.RESET		(reset_nes)
	);

	// hold machine in reset until first download starts
	always @(posedge CLK_50MHZ) begin
		if(!clock_locked)
			init_reset <= 1'b1;
		else if(downloading)
			init_reset <= 1'b0;
	end

	// calculated by http://electronicsfun.net/archives/699
	// phase accumulator to produce 21.312499999999999 MHz
	//always @(posedge clk250) begin
	//	acc <= acc + 1572584932283739400;
	//end
	//assign clk = acc[63];

	// NES is clocked at every 4th cycle.
	always @(posedge clk)
		nes_ce <= nes_ce + 1;

	// loader_write -> clock when data available
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

	assign DN = audio;
	assign DP = audio;
	assign SDRAM_CLK = clk_sdram;
	assign USB_NCS = 1'b0;
	assign loader_reset = !downloading;
	assign reset_nes = (init_reset || buttons[0] || !USB_NRESET || downloading);
	assign run_nes = (nes_ce == 3) && !reset_nes;

endmodule
