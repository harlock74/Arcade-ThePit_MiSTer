// SPDX-License-Identifier: GPL-3.0-or-later
// Stage E bounded functional raster; see Docs/stage_e_timing_contract.md.
// All state is clocked by the existing 25 MHz clock, never by pixel_ce.
module thepit_raster (
 input wire clk, reset,
 output wire pixel_ce, frame_event,
 output reg [8:0] x=9'd0, y=9'd0,
 output wire hblank, vblank, hs, vs, cs, de,
 output reg [7:0] red, green, blue
);
 reg [11:0] accumulator=12'd0;
 assign pixel_ce=!reset && accumulator>=12'd2357;
 // Assert at the edge that advances into the first vertically blank line.
 assign frame_event=pixel_ce && x==9'd383 && y==9'd239;
 always @(posedge clk) begin
  if(reset) begin accumulator<=12'd0; x<=9'd0; y<=9'd0; end
  else begin
   if(pixel_ce) begin
    accumulator<=accumulator-12'd2357;
    if(x==9'd383) begin x<=9'd0; y<=y==9'd263 ? 9'd0 : y+9'd1; end
    else x<=x+9'd1;
   end else accumulator<=accumulator+12'd768;
  end
 end
 assign hblank=reset || x>=9'd256;
 assign vblank=reset || y<9'd16 || y>=9'd240;
 assign de=!(hblank || vblank);
 assign hs=reset || !(x>=9'd368);
 assign vs=reset || !(y>=9'd256);
 assign cs=hs && vs;
 // Diagnostic RGB is deliberately independent of ROM, palette and CPU state.
 always_comb begin
  red=8'd0; green=8'd0; blue=8'd0;
  if(de) begin
   red=8'h20; green=8'h20; blue=8'h40;
   if(x[4:0]==0 || y[4:0]==0) begin red=8'h60; green=8'h60; blue=8'h80; end
   if(x<9'd16 && y<9'd32) begin red=8'hff; green=8'h00; blue=8'h00; end
   if(x>=9'd240 && y<9'd32) begin red=8'h00; green=8'hff; blue=8'h00; end
   if(x<9'd16 && y>=9'd224) begin red=8'h00; green=8'h00; blue=8'hff; end
   if(x>=9'd240 && y>=9'd224) begin red=8'hff; green=8'hff; blue=8'h00; end
   if(x==9'd0 || x==9'd255 || y==9'd16 || y==9'd239) begin red=8'hff; green=8'hff; blue=8'hff; end
  end
 end
endmodule
