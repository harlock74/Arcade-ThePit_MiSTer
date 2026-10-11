// SPDX-License-Identifier: GPL-3.0-or-later
// thepitu1 version-1 packet. Publication is independent of game reset.
module thepit_hiscore_packet(
 input wire clk, cold_reset, download, upload, wr, rd,
 input wire [15:0] index,
 input wire [26:0] address,
 input wire [7:0] data,
 input wire save_action, autosave_on, restore_lock, init_epoch, cancel_capture,
 input wire capture_begin, capture_write, capture_end,
 input wire [3:0] capture_address,
 input wire [7:0] capture_data,
 output wire staging_busy,
 input wire [3:0] restore_address,
 output wire [7:0] restore_data,
 output wire [7:0] upload_data,
 output reg upload_request=0, valid=0, pending_load=0,
 output reg [31:0] generation=0,
 output reg local_changed=0
);
 reg [7:0] staged[0:31],published[0:31],upload_snapshot[0:31],captured[0:14],completed_capture[0:14];
 reg capture_pending=0,capture_bad=0;reg [4:0] capture_count=0;
 reg prev_download=0,prev_upload=0,prev_save=0;
 reg receive=0,bad=0,capturing=0,checking=0,waiting=0;
 reg [5:0] count=0,check_pos=0;
 reg [31:0] crc=32'hffffffff;
 reg [15:0] score=0,previous_score=16'hffff;
 reg check_ok=0,from_host=0,different=0;
 reg [31:0] uploaded_generation=0;
 reg [5:0] delivered=0;
 reg upload_bad=0,upload_valid=0;
 // Automatic requests are policy-gated; a valid-only manual retry is independent.
 // Neither path reads live work RAM or changes the published upload bank.
 reg dirty=0,request_sent=0,manual_pending=0;
 wire locked=restore_lock;
 assign staging_busy=receive || capturing || capture_pending || checking || waiting;
 assign restore_data=valid && restore_address<15 ? published[8+restore_address] : 0;
 assign upload_data=index==4 && address<32 ?
  ((upload && prev_upload) ? (upload_valid ? upload_snapshot[address[4:0]] : 8'd0) :
   (valid ? published[address[4:0]] : 8'd0)) : 8'd0;
 function [31:0] crc_byte(input [31:0] c,input [7:0] b);
  integer j; reg [31:0] v;
  begin v=c^{24'd0,b};for(j=0;j<8;j=j+1)v=v[0] ? (v>>1)^32'hedb88320 : v>>1;crc_byte=v;end
 endfunction
 function [7:0] fixed_byte(input [5:0] n);
  begin case(n)
  0:fixed_byte="P";1:fixed_byte="T";2:fixed_byte="H";3:fixed_byte="S";
  4,5,7:fixed_byte=1;6:fixed_byte=15;23:fixed_byte=0;
  28:fixed_byte="D";29:fixed_byte="O";30:fixed_byte="N";31:fixed_byte="E";
  default:fixed_byte=0;endcase end
 endfunction
 integer k;
 always @(posedge clk) begin
  prev_download<=download;prev_upload<=upload;prev_save<=save_action;upload_request<=0;
  // Only a platform/PLL reset clears publication. Host status[0], watchdog
  // and ordinary Reset are deliberately NOT connected to cold_reset.
  if(cold_reset) begin
   capture_pending<=0;capture_count<=0;capture_bad<=0;
   valid<=0;pending_load<=0;local_changed<=0;generation<=0;dirty<=0;manual_pending<=0;
   receive<=0;capturing<=0;checking<=0;waiting<=0;bad<=1;
   prev_download<=download;prev_upload<=upload;request_sent<=0;
   upload_bad<=1;delivered<=0;
  end else begin
   if(init_epoch) pending_load<=0;
   if(save_action && !prev_save && valid) begin manual_pending<=1;request_sent<=0;end
   if(valid && ((dirty && autosave_on) || manual_pending) && !request_sent && !upload) begin
    upload_request<=1;request_sent<=1;manual_pending<=0;
   end
   if(upload && !prev_upload) begin
    uploaded_generation<=generation;upload_valid<=valid;
    for(k=0;k<32;k=k+1)upload_snapshot[k]<=published[k];
    delivered<=0;upload_bad<=index!=4;
   end
   if(upload && index!=4)upload_bad<=1;
   // Address zero is prefetch; after each delivered byte hps_io presents
   // the next address, 1..32. Data output remains combinational at that address.
   if(upload && rd && address!=0)begin
    if(index==4 && address=={21'd0,delivered}+1 && delivered<32)delivered<=delivered+1'b1;
    else upload_bad<=1;
   end
   if(!upload && prev_upload)begin
    request_sent<=0;
    if(upload_valid && !upload_bad && delivered==32 && uploaded_generation==generation)dirty<=0;
   end
   if(download && !prev_download)begin
    receive<=index==4 && !staging_busy && !local_changed;
    bad<=index!=4 || staging_busy || local_changed;count<=0;
   end
   if(receive && download && index!=4)bad<=1;
   if(download && wr && (receive || (!prev_download && index==4 && !staging_busy && !local_changed)))begin
    if(index!=4 || address!={21'd0,(prev_download ? count : 6'd0)} || address>=32)bad<=1;
    else begin staged[address[4:0]]<=data;count<=(prev_download ? count : 6'd0)+1'b1;end
   end
   if(!download && prev_download && receive)begin
    receive<=0;
    if(!bad && count==32)begin checking<=1;check_pos<=0;crc<=32'hffffffff;check_ok<=1;previous_score<=16'hffff;from_host<=1;different<=0;end
   end
   // Capture has its own 15-byte staging so an arbitrarily slow host cannot
   // hold the CPU bus. A newer complete capture can replace only this pending
   // staging, never the immutable published/uploaded generation.
   if(capture_begin)begin capturing<=1;capture_count<=0;capture_bad<=0;end
   if(capturing && capture_write)begin
    if({1'b0,capture_address}==capture_count && capture_count<15)begin
     captured[capture_address]<=capture_data;capture_count<=capture_count+1'b1;
    end else capture_bad<=1;
   end
   if(capturing && capture_end)begin
    capturing<=0;
    if(!capture_bad && capture_count==15)begin
     for(k=0;k<15;k=k+1)completed_capture[k]<=captured[k];
     capture_pending<=1;
     // A completed local transaction supersedes a concurrent late host load.
     receive<=0;bad<=1;
     if(from_host)begin checking<=0;waiting<=0;end
    end
   end
   if(capture_pending && !capturing && !capture_begin && !capture_end && !receive && (!download || index!=0) && !checking && !waiting)begin
    for(k=0;k<32;k=k+1)if(k>=8 && k<=22)staged[k]<=completed_capture[k-8];else staged[k]<=fixed_byte(k[5:0]);
    capture_pending<=0;checking<=1;check_pos<=0;crc<=32'hffffffff;
    check_ok<=1;previous_score<=16'hffff;from_host<=0;different<=0;
   end
   if(cancel_capture)begin capturing<=0;capture_bad<=1;end
   if(checking && !(capturing && capture_end))begin
    if(check_pos<24)crc<=crc_byte(crc,staged[check_pos[4:0]]);
    if(check_pos<8 || check_pos==23 || check_pos>=28)
     if(staged[check_pos[4:0]]!=fixed_byte(check_pos))check_ok<=0;
    if(check_pos>=8 && check_pos<=22)begin
     if(valid && staged[check_pos[4:0]]!=published[check_pos[4:0]])different<=1;
     if((check_pos-8)%5<3)begin
      if(staged[check_pos[4:0]]!=255 && (staged[check_pos[4:0]]<10 || staged[check_pos[4:0]]>35))check_ok<=0;
     end else begin
      if(staged[check_pos[4:0]][3:0]>9 || staged[check_pos[4:0]][7:4]>9)check_ok<=0;
      if((check_pos-8)%5==3)score[7:0]<=staged[check_pos[4:0]];
      else begin
       if({staged[check_pos[4:0]],score[7:0]}>previous_score)check_ok<=0;
       previous_score<={staged[check_pos[4:0]],score[7:0]};
      end
     end
    end
    if(check_pos==24)begin
     if(from_host)begin if({staged[27],staged[26],staged[25],staged[24]}!=~crc)check_ok<=0;end
     else begin staged[24]<=~crc[7:0];staged[25]<=~crc[15:8];staged[26]<=~crc[23:16];staged[27]<=~crc[31:24];end
    end
    if(check_pos==31)begin checking<=0;waiting<=check_ok && staged[31]=="E";end
    else check_pos<=check_pos+1'b1;
   end
   if(waiting && !locked && (!download || !receive) && !(capturing && capture_end))begin
    waiting<=0;
    if(from_host)begin
     if(!local_changed)begin
      for(k=0;k<32;k=k+1)published[k]<=staged[k];
      valid<=1;pending_load<=1;generation<=generation+1'b1;
     end
    end else if((valid && different) || (!valid && {staged[12],staged[11]}!=0))begin
     for(k=0;k<32;k=k+1)published[k]<=staged[k];
     valid<=1;generation<=generation+1'b1;dirty<=1;request_sent<=0;local_changed<=1;
    end
   end
  end
 end
endmodule
