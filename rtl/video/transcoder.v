// Copyright (c) 2016 Andy Karpov

module transcoder (
	input  		clk, // 21Mhz
	input  		clk_vga, // 27 MHz

	input [7:0]	i_r,
	input [7:0] i_g,
	input [7:0] i_b,
	input [10:0] i_h,
	input [10:0] i_v,
	input 		i_hs,
	input 		i_vs,

	output [7:0] o_r,
	output [7:0] o_g,
	output [7:0] o_b,
	output o_hs,
	output o_vs,
	output o_blank
);

// Horizontal and vertical counters
reg [10:0] h, v;

// pixel data
wire [31:0] pixel_i;
wire [31:0] pixel_o;

// rd / wr addresses
wire [8:0] rdaddress, wraddress;
wire wren;

linebuf linebuf(
	.wrclock(clk),
	.wraddress(wraddress),
	.wren(wren),
	.data(pixel_i),
	
	.rdclock(clk_vga),
	.rdaddress(rdaddress),
	.q(pixel_o)
);

assign wraddress = i_h[8:0];
assign wren = ((i_h < 512) && (i_v < 480));
assign rdaddress = (hdmi_inpicture) ? (h - 104) : 9'b0;
assign pixel_i = {8'b0, i_b[7:0], i_g[7:0], i_r[7:0]};

// counters
//wire h_maxed = (h == 857);
wire h_maxed = (h == 876); // 877 actually
wire v_maxed = ((v == 523) || (i_v == 523));
//wire v_maxed = (v == 523);

// todo: притянуть i_v в клок 21

always @(posedge clk_vga) begin
	if (h_maxed)
		h <= 0;
	else
		h <= h + 1;
end

always @(posedge clk_vga) begin
	if (h_maxed)
	begin
		if (v_maxed)
			v <= 0;
		else
			v <= v + 1;
	end
end

// ------------- hdmi output assignments ---------------
// 720	480	60 Hz	31.4685 kHz	
// ModeLine "720x480" 27.00 720 736 798 858 480 489 495 525 -HSync -VSync

wire         sync_h 	= ((h >= 736) && (h < 798));
wire         sync_v 	= ((v >= 489)  && (v < 495));
wire 		 inpicture 	= ((h < 720) && (v < 480));
wire 		 hdmi_inpicture = ((h >= 104) && (h < (720 - 104)) && (v < 480));
wire 		 border = ((h == 104) || (h == (720 - 104 - 1)) || (v == 0) || (v == (480 - 1)));

assign       o_r 		= (hdmi_inpicture) ? ((border) ? 8'b1 : pixel_o[7:0]  ) : 8'b0;
assign       o_g 	 	= (hdmi_inpicture) ? ((border) ? 8'b1 : pixel_o[15:8] ) : 8'b0;
assign       o_b 		= (hdmi_inpicture) ? ((border) ? 8'b1 : pixel_o[23:16]) : 8'b0;
assign       o_blank 	= !inpicture;
assign 		 o_hs 		= ~sync_h;
assign 		 o_vs 		= ~sync_v;

endmodule
