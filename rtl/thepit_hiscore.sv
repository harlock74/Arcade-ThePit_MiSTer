// SPDX-License-Identifier: GPL-3.0-or-later
module thepit_hiscore(
 input wire clk,cold_reset,game_reset,ready,invalidated,diagnostic,
 input wire download,upload,wr,rd,save_action,autosave_on,
 input wire [15:0] index,
 input wire [26:0] address,
 input wire [7:0] data,
 output wire [7:0] upload_data,
 output wire upload_request,valid,reset_needed,fault,
 input wire [15:0] cpu_a,
 input wire [7:0] cpu_di,cpu_do,
 input wire [9:0] cpu_bus,
 input wire busak_n,
 output wire busrq_n,owns,manager_rd_n,manager_wr_n,
 output wire [15:0] manager_a,
 output wire [7:0] manager_do
);
 reg rom_previous=0,qualified=0,rom_bad=0;
 reg [26:0] rom_count=0;
 reg [31:0] rom_crc=32'hffffffff;
 wire rom_selected=download && index==0;
 function [31:0] crc_byte(input [31:0] c,input [7:0] b);
  integer j;reg [31:0] v;
  begin v=c^{24'd0,b};for(j=0;j<8;j=j+1)v=v[0] ? (v>>1)^32'hedb88320 : v>>1;crc_byte=v;end
 endfunction
 always @(posedge clk)begin
  rom_previous<=rom_selected;
  if(cold_reset || invalidated)begin qualified<=0;rom_bad<=0;rom_count<=0;rom_crc<=32'hffffffff;rom_previous<=0;end
  else begin
   if(rom_selected && !rom_previous)begin qualified<=0;rom_bad<=0;rom_count<=0;rom_crc<=32'hffffffff;end
   if(rom_selected && wr)begin
    if(address==(rom_previous ? rom_count : 0) && address<26656)begin
     rom_count<=(rom_previous ? rom_count : 0)+1'b1;
     rom_crc<=crc_byte(rom_previous ? rom_crc : 32'hffffffff,data);
    end else rom_bad<=1;
   end
   if(rom_previous && !rom_selected)qualified<=!download && !rom_bad && rom_count==26656 && ~rom_crc==32'h2f09f15e;
  end
 end
 wire restore_lock,init_epoch,capture_begin,capture_write,capture_end,staging_busy;
 wire [3:0] restore_address,capture_address;
 wire [7:0] restore_data,capture_data;
 thepit_hiscore_packet packet(.clk(clk),.cold_reset(cold_reset),
  .download(download),.upload(upload),.wr(wr),.rd(rd),.index(index),.address(address),.data(data),
  .save_action(save_action),.autosave_on(autosave_on),.restore_lock(restore_lock),.init_epoch(init_epoch),.cancel_capture(game_reset || cpu_bus[9] || !ready),
  .capture_begin(capture_begin),.capture_write(capture_write),.capture_end(capture_end),
  .capture_address(capture_address),.capture_data(capture_data),.staging_busy(staging_busy),
  .restore_address(restore_address),.restore_data(restore_data),.upload_data(upload_data),
  .upload_request(upload_request),.valid(valid),.pending_load(),.generation(),.local_changed());
 thepit_hiscore_manager manager(.clk(clk),.reset(game_reset || cpu_bus[9]),
  .qualified(qualified && ready && !rom_selected),.diagnostic(diagnostic),
  .cpu_a(cpu_a),.cpu_di(cpu_di),.cpu_do(cpu_do),.m1_n(cpu_bus[6]),.mreq_n(cpu_bus[5]),
  .rd_n(cpu_bus[4]),.wr_n(cpu_bus[3]),.rfsh_n(cpu_bus[2]),.busak_n(busak_n),
  .published_valid(valid),.staging_busy(staging_busy),.restore_data(restore_data),
  .restore_address(restore_address),.capture_begin(capture_begin),.capture_write(capture_write),
  .capture_end(capture_end),.capture_address(capture_address),.capture_data(capture_data),.init_epoch(init_epoch),
  .busrq_n(busrq_n),.owns(owns),.restore_lock(restore_lock),.manager_a(manager_a),.manager_do(manager_do),
  .manager_rd_n(manager_rd_n),.manager_wr_n(manager_wr_n),.reset_needed(reset_needed),.fault(fault));
endmodule
