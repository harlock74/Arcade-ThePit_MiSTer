// SPDX-License-Identifier: GPL-3.0-or-later
// Enables only; IRQ comes from the accepted production raster, not this block.
module thepit_sound_clocks(input wire clk,reset,output wire cp,cn,ay_ce);
 reg [3:0] cpu_phase=0;reg [11:0] aa=0;
 assign cp=!reset && cpu_phase==0;
 assign cn=!reset && cpu_phase==5;
 assign ay_ce=!reset && aa>=12'd2933;
 always @(posedge clk) begin
  if(reset)begin cpu_phase<=0;aa<=0;end
  else begin
   cpu_phase<=cpu_phase==9?4'd0:cpu_phase+4'd1;
   aa<=ay_ce?aa-12'd2933:aa+12'd192;
  end
 end
endmodule
