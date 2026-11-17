// SPDX-License-Identifier: GPL-3.0-or-later
// Enables only; IRQ comes from the accepted production raster, not this block.
module thepit_sound_clocks(input wire clk,reset,output wire cp,cn,ay_ce);
 localparam [13:0] CPU_PERIOD=14'd9216;
 localparam [13:0] CPU_STEP=14'd625;
 localparam [13:0] CPU_MIDPOINT=CPU_PERIOD/2;

 reg [13:0] cpu_phase=0;
 reg [4:0] ay_phase=0;
 wire [13:0] cpu_sum=cpu_phase+CPU_STEP;

 // Each STEP-wide window contains one sample per phase revolution.
 // Phase zero issues cp on the first clock after reset release.
 assign cp=!reset && cpu_phase<CPU_STEP;
 assign cn=!reset && cpu_phase>=CPU_MIDPOINT && cpu_phase<CPU_MIDPOINT+CPU_STEP;
 assign ay_ce=!reset && ay_phase==5'd23;

 always @(posedge clk) begin
  if(reset) begin
   cpu_phase<=0;
   ay_phase<=0;
  end else begin
   cpu_phase<=cpu_sum>=CPU_PERIOD ? cpu_sum-CPU_PERIOD : cpu_sum;
   ay_phase<=ay_ce ? 5'd0 : ay_phase+1'b1;
  end
 end
endmodule
