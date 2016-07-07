// Copyright (c) 2016 Andy Karpov

module fb_video (
	input  			 clk, // 21Mhz
	input  			 clk_vga, // 27 MHz

	input [5:0] 	 pixel,
	input [8:0] 	 count_h,
	input [8:0] 	 count_v,

	output 	[4:0] 	 VGA_R,
	output  [4:0] 	 VGA_G,
	output  [4:0] 	 VGA_B,
	output 			 VGA_HS,
	output 			 VGA_VS,
	output [10:0] 	 VGA_HCOUNTER,
	output [10:0] 	 VGA_VCOUNTER,
	output 			 VGA_BLANK
);

// Horizontal and vertical counters
reg [10:0] h, v; // full
reg [10:0] v2, h2; // half

// pixel data
wire [5:0] pixel_i;
wire [5:0] pixel_o;
//reg [14:0] pixel_v;

wire [15:0] rdaddress, wraddress; // rd / wr addresses
wire wren; // write enable

wire h_maxed = (h == 857); // 858 pixels
wire v_maxed = (v == 524); // 525 lines

framebuffer framebuffer(
	.wrclock(clk),
	.wraddress(wraddress),
	.wren(wren),
	.data(pixel),
	
	.rdclock(clk_vga),
	.rdaddress(rdaddress),
	.q(pixel_o)
);

assign wraddress = (wren) ? count_h + (count_v * 256) : 15'b0;
assign wren = ((count_h < 256) && (count_v < 240));
assign rdaddress = (hdmi_inpicture) ? ((h2 - 52) + (v2 * 256)) : 15'b0;

// NES Palette -> RGB555 conversion
reg [15:0] pallut[0:63];
initial $readmemh("nes_palette.txt", pallut);
wire [14:0] pixel_v = pallut[pixel_o][14:0];
// no memory for pallette conversion :(

//always @(posedge clk_vga) begin
//	pixel_v <= {pixel_o[5:4], 3'b000, pixel_o[3:2], 3'b000, pixel_o[1:0], 3'b000};
//end

always @(posedge clk_vga) begin
  if (h_maxed)
  	h <= 0;
  else
  	h <= h + 1;
end

always @(posedge clk_vga) begin
  if (h_maxed) begin
 	 if (v_maxed) 
 	 	v <= 0;
 	 else 
 	 	v <= v + 1;
  end;
end

always @(posedge clk_vga) begin
	h2 <= (h >> 1); //h / 2; 
	v2 <= (v >> 1); //v / 2;
end

// ------------- hdmi output assignments ---------------
// 720	480	60 Hz	31.4685 kHz	
// ModeLine "720x480" 27.00 720 736 798 858 480 489 495 525 -HSync -VSync

wire         sync_h 	= ((h >= 736) && (h < 798));
wire         sync_v 	= ((v >= 489)  && (v < 495));
wire 		 inpicture 	= ((h < 720) && (v < 480));
wire 		 hdmi_inpicture = (inpicture && (h >= 104) && (h < (720 - 104)));

assign 		 VGA_R 			= (hdmi_inpicture) ? pixel_v[4:0]   : 5'b0;
assign 		 VGA_G 			= (hdmi_inpicture) ? pixel_v[9:5]   : 5'b0;
assign 		 VGA_B 			= (hdmi_inpicture) ? pixel_v[14:10] : 5'b0;	
assign       VGA_BLANK 		= !inpicture;
assign 		 VGA_HS 		= ~sync_h;
assign 		 VGA_VS 		= ~sync_v;
assign 		 VGA_HCOUNTER 	= h;
assign 		 VGA_VCOUNTER 	= v;

endmodule
