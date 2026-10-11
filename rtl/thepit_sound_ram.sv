// SPDX-License-Identifier: GPL-3.0-or-later
// One 1024x8 single-clock M10K. Bus read/write cycles are mutually exclusive;
// simultaneous requests (test-only) read OLD_DATA. Runtime reset retains RAM.
module thepit_sound_ram(input wire clk,read_enable,write_enable,
 input wire [9:0] address,input wire [7:0] data,output reg [7:0] q=0);
 (* ramstyle="M10K" *) reg [7:0] ram[0:1023];
 integer i;initial for(i=0;i<1024;i=i+1)ram[i]=0;
 always @(posedge clk)begin
  if(write_enable)ram[address]<=data;
  if(read_enable)q<=ram[address];
 end
endmodule
