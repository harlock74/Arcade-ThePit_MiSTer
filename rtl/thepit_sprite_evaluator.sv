// SPDX-License-Identifier: GPL-3.0-or-later
// Stage H production evaluator, derived from reviewed probe 0506353.
// Shared-port ownership and response validation are in thepit_sprite_video.
// Default parameters implement the real path; fault/test parameters are zero
// in the production instance and retained for discriminating local tests.
module thepit_sprite_evaluator #(
 parameter TEST_TOKENS=0,
 parameter FAULT_EARLY_SWAP=0,
 parameter FAULT_SKIP_CLEAR=0
)(
 input wire clk, reset,
 input wire start, line_boundary,
 input wire [7:0] target_y,
 input wire flip_x, flip_y,
 output reg descriptor_req,
 output reg [7:0] descriptor_address,
 input wire [7:0] descriptor_q,
 output reg graphics_req,
 output reg [10:0] graphics_address,
 input wire [7:0] p9_q, p8_q,
 input wire display_read,
 input wire [7:0] display_x,
 output wire [15:0] display_data,
 output reg display_valid=0,
 output reg busy=0, done=0, deadline_error=0,
 output reg [8:0] scheduled_edges=0,
 output reg read_bank=0, build_bank=1
);
 reg [8:0] step=0;
 reg [7:0] captured_y=0;
 reg captured_h=0,captured_v=0;
 reg prepared=0,prepared_bank=0;
 reg [1:0] bank_valid=0;
 reg [7:0] descriptor[0:7][0:3];
 reg [7:0] row_p9[0:7][0:1];
 reg [7:0] row_p8[0:7][0:1];

 reg lb_write;
 reg [1:0] lb_byteena;
 reg [8:0] lb_write_address;
 reg [15:0] lb_write_data;
 wire [15:0] lb_read_data;
 thepit_sprite_line_ram buffer(
  .clk(clk),.write(lb_write),.byteena(lb_byteena),
  .write_address(lb_write_address),.write_data(lb_write_data),
  .read(display_read),.read_address({read_bank,display_x}),
  .read_data(lb_read_data));
 assign display_data=display_valid ? lb_read_data : 16'd0;

 integer ds,db,gs,ga,ws,wx;
 reg [7:0] yb,flags,colour,xb;
 reg [7:0] origin_x,origin_y;
 reg [8:0] origin_y9,target_y9;
 reg active_row;
 reg [3:0] local_y,source_y,source_x;
 reg [10:0] row_base;
 reg [7:0] screen_x;
 reg [2:0] bit_select;
 reg [1:0] pen;
 reg [7:0] token;

 function automatic [1:0] direct_pen(input integer slot,input integer x);
  begin direct_pen=(slot*3+x+1)&3; end
 endfunction

 always_comb begin
  descriptor_req=0;descriptor_address=0;
  graphics_req=0;graphics_address=0;
  lb_write=0;lb_byteena=0;lb_write_address=0;lb_write_data=0;
  ds=0;db=0;gs=0;ga=0;ws=0;wx=0;
  yb=0;flags=0;colour=0;xb=0;origin_x=0;origin_y=0;
  origin_y9=0;target_y9={1'b0,captured_y};active_row=0;
  local_y=0;source_y=0;source_x=0;row_base=0;screen_x=0;
  bit_select=0;pen=0;token=0;
  if(busy) begin
   if(step<256) begin
    if(!FAULT_SKIP_CLEAR) begin
     lb_write=1;lb_byteena=2'b11;
     lb_write_address={build_bank,step[7:0]};lb_write_data=0;
    end
   end else if(step<320) begin
    ds=(step-256)>>3;db=((step-256)>>1)&3;
    descriptor_address=8'h40+ds*4+db;
    descriptor_req=~step[0];
   end else if(step<352) begin
    gs=7-((step-320)>>2);ga=((step-320)>>1)&1;
    yb=descriptor[gs][0];flags=descriptor[gs][1];colour=descriptor[gs][2];xb=descriptor[gs][3];
    origin_y=(captured_v ? yb : (8'd240-yb))+(gs<4);
    origin_y9={1'b0,origin_y};
    active_row=yb!=0 && xb!=0 && target_y9>=origin_y9 && target_y9<=origin_y9+9'd15;
    local_y=captured_y-origin_y;
    source_y=(flags[7]^captured_v) ? 4'd15-local_y : local_y;
    row_base={flags[5:0],5'b0}+((source_y>=8)?11'd16:11'd0)+source_y[2:0];
    graphics_address=row_base+(ga?11'd8:11'd0);
    graphics_req=~step[0] && active_row;
   end else if(step<480) begin
    ws=7-((step-352)>>4);wx=(step-352)&15;
    yb=descriptor[ws][0];flags=descriptor[ws][1];colour=descriptor[ws][2];xb=descriptor[ws][3];
    origin_x=captured_h ? (8'd241-xb) : (xb+8'd1);
    origin_y=(captured_v ? yb : (8'd240-yb))+(ws<4);
    origin_y9={1'b0,origin_y};
    active_row=yb!=0 && xb!=0 && target_y9>=origin_y9 && target_y9<=origin_y9+9'd15;
    local_y=captured_y-origin_y;
    source_x=(flags[6]^captured_h) ? 4'd15-wx[3:0] : wx[3:0];
    screen_x=origin_x+wx[7:0];
    bit_select=3'd7-source_x[2:0];
    if(TEST_TOKENS) pen=direct_pen(ws,wx);
    else if(source_x<8) pen={row_p8[ws][0][bit_select],row_p9[ws][0][bit_select]};
    else pen={row_p8[ws][1][bit_select],row_p9[ws][1][bit_select]};
    token={1'b1,2'b00,colour[2:0],pen};
    if(active_row && pen!=0 && ((!captured_h && screen_x>=8'd17) || (captured_h && screen_x<=8'd238))) begin
     lb_write=1;lb_write_address={build_bank,screen_x};
     if(colour[3]) begin lb_byteena=2'b10;lb_write_data={token,8'h00};end
     else begin lb_byteena=2'b01;lb_write_data={8'h00,token};end
    end
   end
  end
 end

 integer i,j;
 always @(posedge clk) begin
  done<=0;
  display_valid<=display_read && bank_valid[read_bank];
  if(reset) begin
   busy<=0;step<=0;done<=0;deadline_error<=0;scheduled_edges<=0;
   read_bank<=0;build_bank<=1;prepared<=0;prepared_bank<=0;bank_valid<=0;
   display_valid<=0;captured_y<=0;captured_h<=0;captured_v<=0;
   for(i=0;i<8;i=i+1)for(j=0;j<4;j=j+1)descriptor[i][j]<=0;
   for(i=0;i<8;i=i+1)for(j=0;j<2;j=j+1)begin row_p9[i][j]<=0;row_p8[i][j]<=0;end
  end else begin
   if(start) begin
    if(busy || prepared) deadline_error<=1;
    else begin
     busy<=1;step<=0;scheduled_edges<=0;
     captured_y<=target_y;captured_h<=flip_x;captured_v<=flip_y;
     bank_valid[build_bank]<=0;
    end
   end else if(busy) begin
    scheduled_edges<=scheduled_edges+1'b1;
    if(step>=256 && step<320 && step[0]) descriptor[(step-256)>>3][((step-256)>>1)&3]<=descriptor_q;
    if(step>=320 && step<352 && step[0]) begin
     row_p9[7-((step-320)>>2)][((step-320)>>1)&1]<=p9_q;
     row_p8[7-((step-320)>>2)][((step-320)>>1)&1]<=p8_q;
    end
    if(step==495) begin
     busy<=0;done<=1;prepared<=1;prepared_bank<=build_bank;
     if(FAULT_EARLY_SWAP) begin read_bank<=build_bank;bank_valid[build_bank]<=1;end
    end else step<=step+1'b1;
   end
   if(line_boundary) begin
    if(prepared) begin
     read_bank<=prepared_bank;bank_valid[prepared_bank]<=1;
     build_bank<=~prepared_bank;prepared<=0;
    end else begin bank_valid[read_bank]<=0;deadline_error<=1;end
   end
  end
 end
endmodule
