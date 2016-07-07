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
     output        HDMI_D0,
     output        HDMI_D1, HDMI_D1N,
     output        HDMI_D2,
     output        HDMI_CLK,

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

	// hdmi video
	wire [4:0]	hdmi_r;
	wire [4:0]	hdmi_g;	
	wire [4:0]	hdmi_b;
	wire 		hdmi_hs;
	wire 		hdmi_vs;
	wire 		hdmi_blank;	
	wire [10:0] hdmi_h, hdmi_v;

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
	wire 		clk_21;
	wire 		clk_42;
	wire 		clk_27;
	wire 		clk_dvi;
	wire 		clk_sdram;
	wire 		clock_locked;

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

	clk21 cl1(
		.inclk0 (CLK_50MHZ),
		.c0 (clk_sdram),
		.c1 (clk_42),
		.c2 (clk_21),
		.locked (clock_locked)
	);

	clk27 cl0(
		.inclk0 (CLK_50MHZ),
		.c0 (clk_27),
		.c1 (clk_dvi)
	);

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
		.O_KEY6		(key6)
	);
		
	GameLoader loader(
		.clk(clk_21),
		.reset(loader_reset),
		.indata(loader_input),
		.indata_clk(loader_clk),
		.mem_addr(loader_addr),
		.mem_data(loader_write_data),
		.mem_write(loader_write),
		.mapper_flags(mapper_flags),
		.done(loader_done)
	);

	NES nes(
		.clk(clk_21),
		.reset(reset_nes),
		.ce(run_nes),
		.mapper_flags(mapper_flags),
		.sample(sample),
		.color(color),
		.joypad_strobe(joypad_strobe),
		.joypad_clock(joypad_clock),
		.joypad_data({joypad_bits2, joypad_bits}),
		.audio_channels(5'b11111),	// enable all channels
		.memory_addr(memory_addr),
		.memory_read_cpu(memory_read_cpu),
		.memory_din_cpu (memory_din_cpu),
		.memory_read_ppu(memory_read_ppu),
		.memory_din_ppu (memory_din_ppu),
		.memory_write   (memory_write),
		.memory_dout    (memory_dout),
		.cycle          (cycle),
		.scanline       (scanline)
	);

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

	fb_video fb_video (
		.clk (clk_21),
		.clk_vga (clk_27),

		.pixel (color),
		.count_h (cycle),
		.count_v (scanline),

		.VGA_R (hdmi_r),
		.VGA_G (hdmi_g),
		.VGA_B (hdmi_b),
		.VGA_HS (hdmi_hs),
		.VGA_VS (hdmi_vs),
		.VGA_HCOUNTER (hdmi_h),
		.VGA_VCOUNTER (hdmi_v),
		.VGA_BLANK (hdmi_blank)
	);

	osd cocpu(
		.I_RESET	(!USB_NRESET),
		.I_CLK		(clk_42),	// 42MHz
		.I_CLK_CPU	(clk_21),		// 21MHz
		.I_KEY0		(key0),
		.I_KEY1		(key1),
		.I_KEY2		(key2),
		.I_KEY3		(key3),
		.I_KEY4		(key4),
		.I_KEY5		(key5),
		.I_KEY6		(key6),
		.I_SPI_MISO	(DATA0),
		.I_SPI1_MISO	(spi1_do),
		//.I_RED		(nes_r),
		//.I_GREEN	(nes_g),
		//.I_BLUE		(nes_b),
		.I_HCNT		(hdmi_h),
		.I_VCNT		(hdmi_v),
		.I_DOWNLOAD_OK	(loader_done),
		//.O_RED		(osd_r),
		//.O_GREEN	(osd_g),
		//.O_BLUE		(osd_b),
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

	av_hdmi av_hdmi(
		.I_CLK_PIXEL(clk_27), // 27
		.I_CLK_PIXEL_x5(clk_dvi), // 135
		.I_R({hdmi_r[4:0], 3'b000}),
		.I_G({hdmi_g[4:0], 3'b000}),
		.I_B({hdmi_b[4:0], 3'b000}),
		.I_BLANK(hdmi_blank), 
		.I_HSYNC(hdmi_hs),
		.I_VSYNC(hdmi_vs),

		.I_AUDIO_PCM_R({1'b0, sample[15:8], 7'b0000000}),
		.I_AUDIO_PCM_L({1'b0, sample[15:8], 7'b0000000}),

		.O_TMDS_D0 (HDMI_D0),
		.O_TMDS_D1 (HDMI_D1),
		.O_TMDS_D2 (HDMI_D2),
		.O_TMDS_CLK (HDMI_CLK)
	);
	 
	// todo: switch to 84 MHz, 16 bit full sample, etc
	sigma_delta_dac sigma_delta_dac (
		.DACout		(audio),
		.DACin		(sample[15:8]),
		.CLK		(clk_21),
		.RESET		(reset_nes)
	);

	// hold machine in reset until first download starts
	always @(posedge CLK_50MHZ) begin
		if(!clock_locked)
			init_reset <= 1'b1;
		else if(downloading)
			init_reset <= 1'b0;
	end

	// NES is clocked at every 4th cycle.
	always @(posedge clk_21)
		nes_ce <= nes_ce + 1;

	// loader_write -> clock when data available
	always @(posedge clk_21) begin
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

	// assignments
	assign DN = audio;
	assign DP = audio;
	assign SDRAM_CLK = clk_sdram;
	assign USB_NCS = 1'b0;
	assign HDMI_D1N = 1'b0;
	assign loader_reset = !downloading;
	assign reset_nes = (init_reset || buttons[0] || !USB_NRESET || downloading);
	assign run_nes = (nes_ce == 3) && !reset_nes;

endmodule
