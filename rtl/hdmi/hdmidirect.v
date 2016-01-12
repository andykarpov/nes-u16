// Charlie Cole 2015
// HDMI output for Neo Geo MVS
//   Originally based on fpga4fun.com HDMI/DVI sample code (c) fpga4fun.com & KNJN LLC 2013
//   Added Neo Geo MVS input, scan doubling, HDMI data packets and audio

module hdmidirect(
	input pixclk,	// 27MHz
	input pixclk72,	// 135MHz

	input [7:0] red,
	input [7:0] green,
	input [7:0] blue,
	input hSync,
	input vSync,
	input [9:0] CounterX,
	input [9:0] CounterY,
	input DrawArea,
	
	input [15:0] SampleL,
	input [15:0] SampleR,
	
	output [2:0] tmds_d
);

// Defines to do with video signal generation
localparam DISPLAY_WIDTH	=720;
localparam DISPLAY_HEIGHT	=480;
localparam FULL_WIDTH		=858;
localparam FULL_HEIGHT		=525;
localparam H_FRONT_PORCH	=16;
localparam H_SYNC		=62; 
localparam V_FRONT_PORCH	=9;
localparam V_SYNC 		=6;

// Defines to do with data packet sending
localparam DATA_START		=DISPLAY_WIDTH+4; // Need 4 cycles of control data first
localparam DATA_PREAMBLE	=8;
localparam DATA_GUARDBAND	=2;
localparam DATA_SIZE		=32;
localparam VIDEO_PREAMBLE	=8;
localparam VIDEO_GUARDBAND	=2;
localparam CTL_END		=FULL_WIDTH-VIDEO_PREAMBLE-VIDEO_GUARDBAND;

////////////////////////////////////////////////////////////////////////
// HDMI audio packet generator
////////////////////////////////////////////////////////////////////////

// Timing for 32KHz audio at 27MHz
localparam AUDIO_TIMER_ADDITION	=4;
localparam AUDIO_TIMER_LIMIT	=3375;

localparam [191:0] channelStatus = 192'hC203004004; // 32KHz 16-bit LPCM audio
reg [23:0] audioPacketHeader;
reg [55:0] audioSubPacket[3:0];
reg [7:0] channelStatusIdx;
reg [11:0] audioTimer;
reg [9:0] audioSamples;
reg [1:0] samplesHead;
reg sendRegenPacket;
reg [15:0] curSampleL, curSampleR;

initial
begin
	audioPacketHeader=0;
	audioSubPacket[0]=0;
	audioSubPacket[1]=0;
	audioSubPacket[2]=0;
	audioSubPacket[3]=0;
	channelStatusIdx=0;
	audioTimer=0;
	audioSamples=0;
	samplesHead=0;
	sendRegenPacket=0;
	curSampleL=0;
	curSampleR=0;

end


////////////////////////////////////////////////////////////////////////
// Error correction code generator
// Generates error correction codes needed for verifying HDMI packets
////////////////////////////////////////////////////////////////////////

function [7:0] ECCcode;	// Cycles the error code generator
	input [7:0] code;
	input bita;
	input passthroughData;
	begin
		ECCcode = (code<<1) ^ (((code[7]^bita) && passthroughData)?(1+(1<<6)+(1<<7)):0);
	end
endfunction

task ECCu;
	output outbit;
	inout [7:0] code;
	input bita;
	input passthroughData;
	begin
		outbit <= passthroughData?bita:code[7];
		code <= ECCcode(code, bita, passthroughData);
	end
endtask

task ECC2u;
	output outbita;
	output outbitb;
	inout [7:0] code;
	input bita;
	input bitb;
	input passthroughData;
	begin
		outbita <= passthroughData?bita:code[7];
		outbitb <= passthroughData?bitb:(code[6]^(((code[7]^bita) && passthroughData)?1'b1:1'b0));
		code <= ECCcode(ECCcode(code, bita, passthroughData), bitb, passthroughData);
	end
endtask

////////////////////////////////////////////////////////////////////////
// Packet sending
// During hsync periods send audio data and infoframe data packets
////////////////////////////////////////////////////////////////////////

reg [3:0] dataChannel0;
reg [3:0] dataChannel1;
reg [3:0] dataChannel2;
reg [23:0] packetHeader;
reg [55:0] subpacket[3:0];
reg [7:0] bchHdr;
reg [7:0] bchCode [3:0];
reg [4:0] dataOffset;
reg [3:0] preamble;
reg tercData;
reg dataGuardBand;
reg videoGuardBand;

initial
begin
	dataChannel0=0;
	dataChannel1=0;
	dataChannel2=0;
	packetHeader=0;
	subpacket[0]=0;
	subpacket[1]=0;
	subpacket[2]=0;
	subpacket[3]=0;
	bchHdr=0;
	bchCode[0]=0;
	bchCode[1]=0;
	bchCode[2]=0;
	bchCode[3]=0;
	dataOffset=0;
	preamble=0;
	tercData=0;
	dataGuardBand=0;
	videoGuardBand=0;
end

task SendPacket;
	inout [32:0] pckHeader;
	inout [55:0] pckData0;
	inout [55:0] pckData1;
	inout [55:0] pckData2;
	inout [55:0] pckData3;
	input firstPacket;
begin
	dataChannel0[0]=hSync;
	dataChannel0[1]=vSync;
	dataChannel0[3]=(!firstPacket || dataOffset)?1'b1:1'b0;
	ECCu(dataChannel0[2], bchHdr, pckHeader[0], dataOffset<24?1'b1:1'b0);
	ECC2u(dataChannel1[0], dataChannel2[0], bchCode[0], pckData0[0], pckData0[1], dataOffset<28?1'b1:1'b0);
	ECC2u(dataChannel1[1], dataChannel2[1], bchCode[1], pckData1[0], pckData1[1], dataOffset<28?1'b1:1'b0);
	ECC2u(dataChannel1[2], dataChannel2[2], bchCode[2], pckData2[0], pckData2[1], dataOffset<28?1'b1:1'b0);
	ECC2u(dataChannel1[3], dataChannel2[3], bchCode[3], pckData3[0], pckData3[1], dataOffset<28?1'b1:1'b0);
	pckHeader<=pckHeader[23:1];
	pckData0<=pckData0[55:2];
	pckData1<=pckData1[55:2];
	pckData2<=pckData2[55:2];
	pckData3<=pckData3[55:2];
	dataOffset<=dataOffset+5'b1;
end
endtask





always @(posedge pixclk)
begin
		// Buffer up an audio sample every 750 pixel clocks (32KHz output from 24MHz pixel clock)
		// Don't add to the audio output if we're currently sending that packet though
		if (!(
			CounterX>=(DATA_START+DATA_PREAMBLE+DATA_GUARDBAND+DATA_SIZE) &&
			CounterX<(DATA_START+DATA_PREAMBLE+DATA_GUARDBAND+DATA_SIZE+DATA_SIZE)
		)) begin
			if (audioTimer >= AUDIO_TIMER_LIMIT) begin
				audioTimer <= audioTimer - AUDIO_TIMER_LIMIT + AUDIO_TIMER_ADDITION;
				audioPacketHeader<=audioPacketHeader|24'h000002|((channelStatusIdx==0?24'h100100:24'h000100)<<samplesHead);
				audioSubPacket[samplesHead]<=((curSampleL<<8)|(curSampleR<<32)
									|((^curSampleL)?56'h08000000000000:56'h0)	// parity bit for left channel
									|((^curSampleR)?56'h80000000000000:56'h0))	// parity bit for right channel
									^(channelStatus[channelStatusIdx]?56'hCC000000000000:56'h0); // And channel status bit and adjust parity
				if (channelStatusIdx<191)
					channelStatusIdx<=channelStatusIdx+1;
				else
					channelStatusIdx<=0;
				samplesHead<=samplesHead+1;
				audioSamples<=audioSamples+1;
				if (audioSamples[4:0]==0)
					sendRegenPacket<=1;
			end else begin
				audioTimer <= audioTimer + AUDIO_TIMER_ADDITION;
				curSampleL <= SampleL;
				curSampleR <= SampleR;
			end
		end else begin
			audioTimer<=audioTimer+AUDIO_TIMER_ADDITION;
			samplesHead<=0;
		end

	// Start sending audio data if we're in the right part of the hsync period
	if (CounterX>=DATA_START)
	begin
		if (CounterX<(DATA_START+DATA_PREAMBLE))
		begin
			// Send the data period preamble
			// A nice "feature" of my test monitor (GL2450) is if you comment out
			// this line you see your data next to your image which is useful for
			// debugging
			preamble<='b0101;
		end
		else if (CounterX<(DATA_START+DATA_PREAMBLE+DATA_GUARDBAND))
		begin
			// Start sending leading data guard band
			tercData<=1;
			dataGuardBand<=1;
			dataChannel0<={1'b1, 1'b1, vSync, hSync};
			preamble<=0;
			// Set up the first of the packets we'll send
			if (sendRegenPacket) begin
				packetHeader<=24'h000001;	// audio clock regeneration packet
				subpacket[0]<=56'h00100078690000;	// N=0x1000 CTS=0x6978 (27MHz pixel clock -> 32KHz audio clock)
				subpacket[1]<=56'h00100078690000;
				subpacket[2]<=56'h00100078690000;
				subpacket[3]<=56'h00100078690000;
				if (CounterX==(DATA_START+DATA_PREAMBLE+DATA_GUARDBAND-1))
					sendRegenPacket<=0;
			end else begin
//				if (!CounterY[0]) begin
//					packetHeader<=24'h0D0282;	// infoframe AVI packet
//					// Byte0: Checksum
//					// Byte1: 10 = 0(Y1:Y0=0 RGB)(A0=1 No active format)(B1:B0=00 No bar info)(S1:S0=00 No scan info)
//					// Byte2: 2A = (C1:C0=0 No colorimetry)(M1:M0=2 16:9)(R3:R0=A 16:9)
//					// Byte3: 00 = 0(SC1:SC0=0 No scaling)
//					// Byte4: 03 = 0(VIC6:VIC0=3 720x480p)
//					// Byte5: 00 = 0(PR5:PR0=0 No repeation)
//					subpacket[0]<=56'h000003002A1032;
//					subpacket[1]<=56'h00000000000000;
//				end else begin
					packetHeader<=24'h0A0184;	// infoframe audio packet
					// Byte0: Checksum
					// Byte1: 11 = (CT3:0=1 PCM)0(CC2:0=1 2ch)
					// Byte2: 00 = 000(SF2:0=0 As stream)(SS1:0=0 As stream)
					// Byte3: 00 = LPCM doesn't use this
					// Byte4-5: 00 Multichannel only (>2ch)
					subpacket[0]<=56'h00000000001160;
					subpacket[1]<=56'h00000000000000;
//				end
				subpacket[2]<=56'h00000000000000;
				subpacket[3]<=56'h00000000000000;
			end
		end
		else if (CounterX<(DATA_START+DATA_PREAMBLE+DATA_GUARDBAND+DATA_SIZE))
		begin
			dataGuardBand<=0;
			// Send first data packet (Infoframe or audio clock regen)
			SendPacket(packetHeader, subpacket[0], subpacket[1], subpacket[2], subpacket[3], 1);
		end
		else if (CounterX<(DATA_START+DATA_PREAMBLE+DATA_GUARDBAND+DATA_SIZE+DATA_SIZE))
		begin
			// Send second data packet (audio data)
			SendPacket(audioPacketHeader, audioSubPacket[0], audioSubPacket[1], audioSubPacket[2], audioSubPacket[3], 0);
		end
		else if (CounterX<(DATA_START+DATA_PREAMBLE+DATA_GUARDBAND+DATA_SIZE+DATA_SIZE+DATA_GUARDBAND))
		begin
			// Trailing guardband for data period
			dataGuardBand<=1;
			dataChannel0<={1'b1, 1'b1, vSync, hSync};	
		end
		else
		begin
			// Back to normal DVI style control data
			tercData<=0;
			dataGuardBand<=0;
		end
	end
	// After we've sent data packets we need to do the video preamble and
	// guardband just before sending active video data
	if (CounterX>=(CTL_END+VIDEO_PREAMBLE))
	begin
		preamble<=0;
		videoGuardBand<=1;
	end
	else if (CounterX>=(CTL_END))
	begin
		preamble<='b0001;
	end
	else
	begin
		videoGuardBand<=0;
	end
end

////////////////////////////////////////////////////////////////////////
// HDMI encoder
// Encodes video data (TMDS) or packet data (TERC4) ready for sending
////////////////////////////////////////////////////////////////////////

reg tercDataDelayed [1:0];
reg videoGuardBandDelayed [1:0];
reg dataGuardBandDelayed [1:0];

initial
begin
	tercDataDelayed[0]=0;
	tercDataDelayed[1]=0;
	videoGuardBandDelayed[0]=0;
	videoGuardBandDelayed[1]=0;
	dataGuardBandDelayed[0]=0;
	dataGuardBandDelayed[1]=0;
end

always @(posedge pixclk)
begin
	// Cycle 1
	tercDataDelayed[0]<=tercData;	// To account for delay through encoder
	videoGuardBandDelayed[0]<=videoGuardBand;
	dataGuardBandDelayed[0]<=dataGuardBand;
	// Cycle 2
	tercDataDelayed[1]<=tercDataDelayed[0];
	videoGuardBandDelayed[1]<=videoGuardBandDelayed[0];
	dataGuardBandDelayed[1]<=dataGuardBandDelayed[0];
end

////////////////////////////////////////////////////////////////////////
// TMDS encoder
// Used to encode HDMI/DVI video data
////////////////////////////////////////////////////////////////////////

wire [9:0] TMDS_red, TMDS_green, TMDS_blue;
encoder encode_R(.CLK(pixclk), .DATA(red  ), .C(preamble[3:2]), .BLANK(DrawArea), .ENCODED(TMDS_red));
encoder encode_G(.CLK(pixclk), .DATA(green), .C(preamble[1:0]), .BLANK(DrawArea), .ENCODED(TMDS_green));
encoder encode_B(.CLK(pixclk), .DATA(blue ), .C({vSync,hSync}), .BLANK(DrawArea), .ENCODED(TMDS_blue));

wire [9:0] TERC4_red, TERC4_green, TERC4_blue;
TERC4_encoder encode_R4(.clk(pixclk), .data(dataChannel2), .TERC(TERC4_red));
TERC4_encoder encode_G4(.clk(pixclk), .data(dataChannel1), .TERC(TERC4_green));
TERC4_encoder encode_B4(.clk(pixclk), .data(dataChannel0), .TERC(TERC4_blue));

////////////////////////////////////////////////////////////////////////
// HDMI data serialiser
// Outputs the encoded video data as serial data across the HDMI bus
////////////////////////////////////////////////////////////////////////

serializer tmds (
	.tx_in		({TMDS_shift_red_delay[0],TMDS_shift_red_delay[1],TMDS_shift_red_delay[2],TMDS_shift_red_delay[3],TMDS_shift_red_delay[4],TMDS_shift_red_delay[5],TMDS_shift_red_delay[6],TMDS_shift_red_delay[7],TMDS_shift_red_delay[8],TMDS_shift_red_delay[9],
                          TMDS_shift_green_delay[0],TMDS_shift_green_delay[1],TMDS_shift_green_delay[2],TMDS_shift_green_delay[3],TMDS_shift_green_delay[4],TMDS_shift_green_delay[5],TMDS_shift_green_delay[6],TMDS_shift_green_delay[7],TMDS_shift_green_delay[8],TMDS_shift_green_delay[9],
	                  TMDS_shift_blue_delay[0],TMDS_shift_blue_delay[1],TMDS_shift_blue_delay[2],TMDS_shift_blue_delay[3],TMDS_shift_blue_delay[4],TMDS_shift_blue_delay[5],TMDS_shift_blue_delay[6],TMDS_shift_blue_delay[7],TMDS_shift_blue_delay[8],TMDS_shift_blue_delay[9]}),
	.tx_inclock	(pixclk72),
	.tx_syncclock	(pixclk),
	.tx_out		(tmds_d)
);


reg [9:0] TMDS_shift_red_delay, TMDS_shift_green_delay, TMDS_shift_blue_delay;

initial
begin
  TMDS_shift_red_delay=0;
  TMDS_shift_green_delay=0;
  TMDS_shift_blue_delay=0;
end

always @(posedge pixclk)
begin
	TMDS_shift_red_delay<=videoGuardBandDelayed[1] ? 10'b1011001100 : (dataGuardBandDelayed[1] ? 10'b0100110011 : (tercDataDelayed[1] ? TERC4_red : TMDS_red));
	TMDS_shift_green_delay<=(dataGuardBandDelayed[1] || videoGuardBandDelayed[1]) ? 10'b0100110011 : (tercDataDelayed[1] ? TERC4_green : TMDS_green);
	TMDS_shift_blue_delay<=videoGuardBandDelayed[1] ? 10'b1011001100 : (tercDataDelayed[1] ? TERC4_blue : TMDS_blue);
end

endmodule

////////////////////////////////////////////////////////////////////////
// TERC4 Encoder
// Used to encode the HDMI data packets such as audio
////////////////////////////////////////////////////////////////////////

module TERC4_encoder(
	input clk,
	input [3:0] data,
	output reg [9:0] TERC
);

reg [9:0] TERC_pre;

initial
begin
	TERC_pre=0;
end

always @(posedge clk)
begin
	// Cycle 1
	case (data)
		4'b0000: TERC_pre <= 10'b1010011100;
		4'b0001: TERC_pre <= 10'b1001100011;
		4'b0010: TERC_pre <= 10'b1011100100;
		4'b0011: TERC_pre <= 10'b1011100010;
		4'b0100: TERC_pre <= 10'b0101110001;
		4'b0101: TERC_pre <= 10'b0100011110;
		4'b0110: TERC_pre <= 10'b0110001110;
		4'b0111: TERC_pre <= 10'b0100111100;
		4'b1000: TERC_pre <= 10'b1011001100;
		4'b1001: TERC_pre <= 10'b0100111001;
		4'b1010: TERC_pre <= 10'b0110011100;
		4'b1011: TERC_pre <= 10'b1011000110;
		4'b1100: TERC_pre <= 10'b1010001110;
		4'b1101: TERC_pre <= 10'b1001110001;
		4'b1110: TERC_pre <= 10'b0101100011;
		4'b1111: TERC_pre <= 10'b1011000011;
	endcase
	// Cycle 2
	TERC <= TERC_pre;
end

endmodule

////////////////////////////////////////////////////////////////////////

//endmodule
