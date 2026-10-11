// SPDX-License-Identifier: GPL-3.0-or-later
// Bundled-data mono mailbox. Hold payload until ack has crossed back.
// Reset is cold/global/PLL only; ordinary mute/warm reset sends zero as data.
module thepit_audio_cdc(input wire source_clk,audio_clk,reset,
 input wire [15:0] sample_in,output reg [15:0] sample_out=0);
 wire sr,ar;
 thepit_reset source_reset(source_clk,reset,sr);
 thepit_reset audio_reset(audio_clk,reset,ar);
 reg [15:0] held=0;
 reg request=0,ack=0;
 (* altera_attribute="-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *) reg ack1=0,ack2=0,req1=0,req2=0;
 // Third control stage grants another destination edge for bundled data.
 reg req3=0;
 always @(posedge source_clk)begin
  if(sr)begin ack1<=0;ack2<=0;request<=0;held<=0;end
  else begin
   ack1<=ack;ack2<=ack1;
   if(ack2==request)begin held<=sample_in;request<=!request;end
  end
 end
 always @(posedge audio_clk)begin
  if(ar)begin req1<=0;req2<=0;req3<=0;ack<=0;sample_out<=0;end
  else begin
   req1<=request;req2<=req1;req3<=req2;
   if(req3!=ack)begin sample_out<=held;ack<=req3;end
  end
 end
endmodule
