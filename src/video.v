// Copyright (c) 2012-2013 Ludvig Strigeus
// This program is GPL Licensed. See COPYING for the full license.

module video(
	input  clk, // 21Mhz
	input [5:0] color,
	input [8:0] count_h,
	input [8:0] count_v,
	input smoothing, // !status[1]
	
	output       VGA_HS,
	output       VGA_VS,
	output [5:0] VGA_R, 
	output [5:0] VGA_G, 
	output [5:0] VGA_B,
  output       VGA_BLANK,
  output [10:0] VGA_HCOUNTER,
  output [10:0] VGA_VCOUNTER
);

// NES Palette -> RGB555 conversion
reg [15:0] pallut[0:63];
initial $readmemh("nes_palette.txt", pallut);
wire [14:0] pixel = pallut[color][14:0];

// Horizontal and vertical counters
reg [10:0] h, v;
wire hpicture  = (h < 512);             // 512 lines of picture
wire hend = (h == 681);                 // End of line, 682 pixels.
wire vpicture = (v < 480);    // 480 lines of picture
wire vend = (v == 523);       // End of picture, 524 lines. (Should really be 525 according to NTSC spec)

wire [14:0] doubler_pixel;
wire doubler_sync;

Hq2x hq2x(
	clk, 
	pixel, 
	smoothing,        // enabled 
    count_v[8],                 // reset_frame
    (count_h[8:3] == 42),       // reset_line
    {v[0], h[9] ? 9'd0 : h[8:0] + 9'd1}, // 0-511 for line 1, or 512-1023 for line 2.
    doubler_sync,               // new frame has just started
    doubler_pixel
);             // pixel is outputted

reg [8:0] old_count_v;
wire sync_frame = (old_count_v == 9'd511) && (count_v == 9'd0);
always @(posedge clk) begin
  h <= (hend || doubler_sync) ? 10'd0 : h + 10'd1;
  if(doubler_sync) v <= 0;
    else if (hend) v <= vend ? 10'd0 : v + 10'd1;

  old_count_v <= count_v;
end

wire inpicture = hpicture && vpicture;
wire [14:0] pixel_v = inpicture ? doubler_pixel : 15'd0;

// ------------- VGA output assignments ---------------

wire         sync_h = ((h >= (512 + 23 + 35)) && (h < (512 + 23 + 35 + 80)));
wire         sync_v = ((v >= (480 + 10))  && (v < (480 + 10 + 2)));

assign       VGA_HS = ~sync_h;
assign       VGA_VS = ~sync_v;

assign       VGA_R 	= pixel_v[4:0];
assign       VGA_G 	= pixel_v[9:5];
assign       VGA_B 	= pixel_v[14:10];

assign       VGA_BLANK 	  = !inpicture;
assign       VGA_HCOUNTER = h;
assign       VGA_VCOUNTER = v;

endmodule
