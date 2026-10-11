// SPDX-License-Identifier: GPL-3.0-or-later
// Stage H line-ahead sprite scheduler. Native coordinates retain Stage E's
// DOCUMENTED-APPROXIMATION; ROT90 and the later solid-tile strata are external.
module thepit_sprite_video(
 input wire clk,reset,enabled,pixel_ce,hs,vs,de,
 input wire [8:0] raw_x,raw_y,
 input wire flip_x,flip_y,
 output wire object_display_req,
 output wire [7:0] object_display_addr,
 input wire [7:0] object_display_data,
 output wire display_req,
 output wire [9:0] display_addr,
 input wire [7:0] display_code,display_colour,
 output wire graphics_req,
 output wire [10:0] graphics_addr,
 input wire [7:0] p9_q,p8_q,
 output wire palette_req,
 output wire [4:0] palette_addr,
 input wire [7:0] palette_q,
 output wire out_ce,out_hs,out_vs,out_de,
 output wire [7:0] red,green,blue
);
 wire blank=raw_x>=9'd256;
 wire boundary=pixel_ce && raw_x==9'd383;
 wire abort=reset || !enabled;
 reg blank_previous=0;
 reg [2:0] drain=0;
 reg owner=0,started=0,blank_armed=0;
 reg descriptor_response_valid=0,graphics_response_valid=0;
 reg object_response_owner=0,graphics_response_owner=0;
 reg deadline_error=0;
 wire bg_object_req,bg_graphics_req;
 wire [7:0] bg_object_addr;
 wire [10:0] bg_graphics_addr;
 wire sprite_object_req,sprite_graphics_req;
 wire [7:0] sprite_object_addr;
 wire [10:0] sprite_graphics_addr;
 wire busy,done,evaluator_error;
 wire [8:0] scheduled_edges;
 wire read_bank,build_bank;
 wire [15:0] sprite_tokens;
 wire sprite_valid;
 // Three drain edges cover the accepted background attribute/VRAM/graphics
 // request chain. Requests remain BG-owned until both response tags drain.
 wire start=enabled && blank && blank_armed && !started && drain==3 &&
            !bg_object_req && !bg_graphics_req &&
            !descriptor_response_valid && !graphics_response_valid;
 assign object_display_req=!abort && (owner ? sprite_object_req : bg_object_req);
 assign object_display_addr=owner ? sprite_object_addr : bg_object_addr;
 assign graphics_req=!abort && (owner ? sprite_graphics_req : bg_graphics_req);
 assign graphics_addr=owner ? sprite_graphics_addr : bg_graphics_addr;
 wire [7:0] sprite_descriptor=descriptor_response_valid && object_response_owner ? object_display_data : 8'd0;
 wire [7:0] sprite_p9=graphics_response_valid && graphics_response_owner ? p9_q : 8'd0;
 wire [7:0] sprite_p8=graphics_response_valid && graphics_response_owner ? p8_q : 8'd0;
 wire [8:0] next_y=raw_y==9'd263 ? 9'd0 : raw_y+9'd1;
 always @(posedge clk) begin
  if(abort) begin
   blank_previous<=blank;drain<=0;owner<=0;started<=0;blank_armed<=0;
   descriptor_response_valid<=0;graphics_response_valid<=0;
   object_response_owner<=0;graphics_response_owner<=0;deadline_error<=0;
  end else begin
   blank_previous<=blank;
   descriptor_response_valid<=object_display_req;
   graphics_response_valid<=graphics_req;
   object_response_owner<=owner;
   graphics_response_owner<=owner;
   if(!blank) begin drain<=0;started<=0;blank_armed<=0;end
   else if(drain<3) drain<=drain+1'b1;
   if(blank && !blank_previous) blank_armed<=1;
   if(start) begin owner<=1;started<=1;end
   if(done) owner<=0;
   // A partial bank must never become visible. Hold the sprite engine reset
   // after an overrun until reset/download changes the enabled contract.
   if(boundary && blank_armed && (busy || !started)) deadline_error<=1;
  end
 end
 thepit_sprite_evaluator sprites(
  .clk(clk),.reset(abort || deadline_error),.start(start && !deadline_error),
  .line_boundary(boundary),.target_y(next_y[7:0]),.flip_x(flip_x),.flip_y(flip_y),
  .descriptor_req(sprite_object_req),.descriptor_address(sprite_object_addr),.descriptor_q(sprite_descriptor),
  .graphics_req(sprite_graphics_req),.graphics_address(sprite_graphics_addr),.p9_q(sprite_p9),.p8_q(sprite_p8),
  .display_read(enabled && de),.display_x(raw_x[7:0]),.display_data(sprite_tokens),.display_valid(sprite_valid),
  .busy(busy),.done(done),.deadline_error(evaluator_error),.scheduled_edges(scheduled_edges),
  .read_bank(read_bank),.build_bank(build_bank));
 thepit_background #(.SPRITES(1)) tiles(
  .clk(clk),.reset(reset),.enabled(enabled),.pixel_ce(pixel_ce),.hs(hs),.vs(vs),.de(de),
  .raw_x(raw_x),.raw_y(raw_y),.flip_x(flip_x),.flip_y(flip_y),
  .object_display_req(bg_object_req),.object_display_addr(bg_object_addr),
  .object_display_data(descriptor_response_valid && !object_response_owner ? object_display_data : 8'd0),
  .display_req(display_req),.display_addr(display_addr),.display_code(display_code),.display_colour(display_colour),
  .graphics_req(bg_graphics_req),.graphics_addr(bg_graphics_addr),
  .p9_q(graphics_response_valid && !graphics_response_owner ? p9_q : 8'd0),
  .p8_q(graphics_response_valid && !graphics_response_owner ? p8_q : 8'd0),
  .palette_req(palette_req),.palette_addr(palette_addr),.palette_q(palette_q),
  .sprite_tokens(sprite_tokens),.sprite_valid(sprite_valid),
  .out_ce(out_ce),.out_hs(out_hs),.out_vs(out_vs),.out_de(out_de),.red(red),.green(green),.blue(blue));
endmodule
