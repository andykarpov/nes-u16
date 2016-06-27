// Copyright (c) 2012-2013 Ludvig Strigeus
// This program is GPL Licensed. See COPYING for the full license.
// VGA upconverter by Andy Karpov (c) 2016

module video(
	input  clk, // 21Mhz
	input  clk_vga, // 25 MHz
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
reg [10:0] h, v, vga_h, vga_v;
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
  if (hend || doubler_sync) begin
  	if (wrlinecnt == 1) 
		wrlinecnt <= 0;
	else 
		wrlinecnt <= 1;
  end
  if(doubler_sync) v <= 0;
    else if (hend) v <= vend ? 10'd0 : v + 10'd1;

  old_count_v <= count_v;
end

wire [14:0] pixel_v = (!hpicture || !vpicture) ? 15'd0 : doubler_pixel;
wire inpicture = hpicture && vpicture;

// ------------- converting from 512x480 to 640x480 --------------

wire [14:0] vga_pixel_v; // color data readed from line buffer
wire [9:0] wraddr;		 // write address to line buffer
wire [9:0] rdaddr;		 // read address from line buffer
reg wrlinecnt = 1'b0;	 // line number (0 or 1) for write
reg rdlinecnt = 1'b1;	 // line number (0 or 1) for read

// line buffer instance (2 port ram with separate clocks for read / write)
linebuf linebuf(
	.wrclock(clk),
	.wraddress(wraddr),
	.data(pixel_v),
	.wren(inpicture),

	.rdclock(clk_vga),
	.rdaddress(rdaddr),
	.q(vga_pixel_v)
);

wire vga_h_maxed = (vga_h==799); // horizontal limit 
wire vga_v_maxed = (vga_v==523); // vertical limit
wire vga_vend; // translated vend value to vga_clk clock domain

// clock domain translation for vend
crossdomain cx1(
	.clkA(clk),
	.clkB(clk_vga),
	.inA(vend),
	.outB(vga_vend)
);

// vga H counter
always @(posedge clk_vga) begin
    if(vga_h_maxed) begin
        vga_h <= 0;
	    if (rdlinecnt == 1) 
			rdlinecnt <= 0;
		else 
			rdlinecnt <= 1;
	end
    else
        vga_h <= vga_h + 1;
end

// vga V counter
always @(posedge clk_vga) begin
    if(vga_h_maxed)
    begin
        if (vga_vend)
            vga_v <= 0;
        else
            vga_v <= vga_v + 1;
    end
end

assign wraddr = h + (wrlinecnt ? 512 : 0); // write address to linebuffer
assign rdaddr = (vga_inpicture) ? vga_h - 64 + (rdlinecnt ? 512 : 0) : 9'd0; // read address from linebuffer

// ------------- VGA output assignments ---------------

wire  [4:0]   vga_r = (vga_inpicture) ? vga_pixel_v[4:0] : 5'd0;
wire  [4:0]   vga_g = (vga_inpicture) ? vga_pixel_v[9:5] : 5'd0;
wire  [4:0]   vga_b = (vga_inpicture) ? vga_pixel_v[14:10] : 5'd0;
wire         sync_h = ((vga_h >= (640 + 16)) && (vga_h < (640 + 16 + 96)));
wire         sync_v = ((vga_v >= (480 + 11))  && (vga_v < (480 + 11 + 2)));
wire   vga_hpicture = (vga_h >= 64 && vga_h < 512+64);             // 512px in line
wire   vga_vpicture = (vga_v >= 1 && vga_v < 479); // 480 lines
wire  vga_inpicture = vga_hpicture && vga_vpicture;

assign       VGA_HS = ~sync_h;
assign       VGA_VS = ~sync_v;

assign       VGA_R 	= vga_r;
assign       VGA_G 	= vga_g;
assign       VGA_B 	= vga_b;

assign       VGA_BLANK 	  = (vga_h >= 640 || vga_v >= 480);
assign       VGA_HCOUNTER = vga_h;
assign       VGA_VCOUNTER = vga_v;

endmodule
