// SPDX-License-Identifier: GPL-3.0-or-later
// MAME-functional tile/sprite composition. The accepted raw raster is
// unchanged. Five sampling edges: attribute RAM, video/colour RAM, graphics
// ROM, PROM/solid selection, RGB. Sync/DE/CE follow the identical latency.
module thepit_background #(parameter SPRITES=0)(
 input wire clk, reset, enabled, pixel_ce, hs, vs, de,
 input wire [8:0] raw_x, raw_y,
 input wire flip_x, flip_y,
 output wire object_display_req,
 output wire [7:0] object_display_addr,
 input wire [7:0] object_display_data,
 output wire display_req,
 output wire [9:0] display_addr,
 input wire [7:0] display_code, display_colour,
 output wire graphics_req,
 output wire [10:0] graphics_addr,
 input wire [7:0] p9_q, p8_q,
 output wire palette_req,
 output wire [4:0] palette_addr,
 input wire [7:0] palette_q,
 input wire [15:0] sprite_tokens,
 input wire sprite_valid,
 output wire out_ce, out_hs, out_vs, out_de,
 output reg [7:0] red=0, green=0, blue=0
);
 reg [4:0] ce_pipe=0, hs_pipe=5'h1f, vs_pipe=5'h1f, de_pipe=0;
 reg [3:0] valid_pipe=0;
 reg [7:0] x1=0,y1=0;
 reg flip_x1=0,flip_y1=0;
 reg [2:0] row2=0,bit2=0,bit3=0;
 reg [7:0] colour3=0;
 reg solid4=0,prom4=0;
 reg [2:0] solid_colour4=0;
 reg [15:0] sprites2=0,sprites3=0;
 // H flip reverses both tile/pixel X and the scroll-column lookup. Only the
 // even byte of each two-byte attribute pair is rendered.
 wire [7:0] input_source_x=flip_x ? (8'hff-raw_x[7:0]) : raw_x[7:0];
 assign object_display_addr={input_source_x[7:3],1'b0};
 assign object_display_req=enabled && de && !reset;
 // The synchronous attribute response belongs to x1/y1. Eight-bit addition
 // provides modulo-256 wrap. The visible y origin is deliberately not removed.
 wire [7:0] source_x1=flip_x1 ? (8'hff-x1) : x1;
 wire [7:0] source_y1=(flip_y1 ? (8'hff-y1) : y1)+object_display_data;
 assign display_addr={source_y1[7:3],source_x1[7:3]};
 assign display_req=valid_pipe[0];
 assign graphics_addr={display_code,row2};
 assign graphics_req=valid_pipe[1];
 wire [1:0] pen={p8_q[bit3],p9_q[bit3]};
 wire [7:0] low_sprite=sprites3[7:0];
 wire [7:0] high_sprite=sprites3[15:8];
 wire low_sprite_valid=SPRITES && low_sprite[7] && low_sprite[1:0]!=0;
 wire high_sprite_valid=SPRITES && high_sprite[7] && high_sprite[1:0]!=0;
 wire front_solid=colour3[6:4]!=0 && !colour3[7];
 // Pinned MAME order, top first: high sprite, front solid, low sprite,
 // transparent foreground, rear solid. Pen zero is transparency by number;
 // a nonzero pen remains opaque even when its PROM colour happens to be black.
 wire select_prom=high_sprite_valid ||
                  (!front_solid && (low_sprite_valid || pen!=0));
 wire [4:0] selected_prom_addr=high_sprite_valid ? high_sprite[4:0] :
                               low_sprite_valid ? low_sprite[4:0] :
                               {colour3[2:0],pen};
 assign palette_addr=select_prom ? selected_prom_addr : 5'd0;
 assign palette_req=valid_pipe[2];
 assign out_ce=ce_pipe[4] && !reset;
 assign out_hs=hs_pipe[4] || reset;
 assign out_vs=vs_pipe[4] || reset;
 assign out_de=de_pipe[4] && !reset;
 function automatic [7:0] weighted(input [2:0] bits_in);
  begin
   weighted=(bits_in[0] ? 8'h21 : 8'h00) +
            (bits_in[1] ? 8'h47 : 8'h00) +
            (bits_in[2] ? 8'h97 : 8'h00);
  end
 endfunction
 always @(posedge clk) begin
  if(reset) begin
   ce_pipe<=0;hs_pipe<=5'h1f;vs_pipe<=5'h1f;de_pipe<=0;valid_pipe<=0;
   x1<=0;y1<=0;flip_x1<=0;flip_y1<=0;
   row2<=0;bit2<=0;bit3<=0;colour3<=0;
   solid4<=0;prom4<=0;solid_colour4<=0;
   sprites2<=0;sprites3<=0;
   red<=0;green<=0;blue<=0;
  end else begin
   ce_pipe<={ce_pipe[3:0],pixel_ce};hs_pipe<={hs_pipe[3:0],hs};
   vs_pipe<={vs_pipe[3:0],vs};de_pipe<={de_pipe[3:0],de};
   valid_pipe<={valid_pipe[2:0],object_display_req};
   x1<=raw_x[7:0];y1<=raw_y[7:0];flip_x1<=flip_x;flip_y1<=flip_y;
   row2<=source_y1[2:0];bit2<=3'd7-source_x1[2:0];
   bit3<=bit2;colour3<=display_colour;
   solid4<=!select_prom;prom4<=select_prom;solid_colour4<=colour3[6:4];
   sprites2<=SPRITES && sprite_valid ? sprite_tokens : 16'd0;
   sprites3<=sprites2;
   red<=0;green<=0;blue<=0;
   if(valid_pipe[3] && solid4) begin
    // MAME-COMPATIBILITY-APPROXIMATION: these eight digital primary colours
    // are generated separately. They are not PROM contents or a claim about
    // the schematic resistor network or physical PCB colour levels.
    red<=solid_colour4[2] ? 8'hff : 8'h00;
    green<=solid_colour4[1] ? 8'hff : 8'h00;
    blue<=solid_colour4[0] ? 8'hff : 8'h00;
   end else if(valid_pipe[3] && prom4) begin
    red<=weighted(palette_q[2:0]);green<=weighted(palette_q[5:3]);
    blue<=weighted({palette_q[7:6],1'b0});
   end
  end
 end
endmodule
