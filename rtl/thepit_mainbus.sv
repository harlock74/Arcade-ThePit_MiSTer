// SPDX-License-Identifier: GPL-3.0-or-later
// Stage D MAME-functional CPU bus. No renderer or sound processor.
module thepit_mainbus #(parameter integer WATCHDOG_CYCLES=75000000, parameter integer RAM_INIT_MODE=0)(
 input wire clk, reset,
 input wire [15:0] a,
 input wire [7:0] dout,
 input wire mreq_n, rd_n, wr_n, rfsh_n,
 input wire [7:0] rom_q,
 output wire rom_req,
 output wire [14:0] rom_addr,
 output reg [7:0] din=0,
 input wire frame_event,
 input wire [7:0] player0,player1,inputs1,dips,
 output reg [7:0] control=0, sound_command=0,
 output reg [15:0] sound_events=0,
 output reg nmi_n=1, watchdog_reset=0,
 output reg watchdog_armed=0,
 output wire [8:0] read_select,
 output wire [6:0] write_select,
 input wire display_req,
 input wire [9:0] display_addr,
 output wire [7:0] display_code, display_colour,
 input wire object_display_req,
 input wire [7:0] object_display_addr,
 output wire [7:0] object_display_data,
 output reg sound_write=0
);
 wire reading=!mreq_n && !rd_n && wr_n && rfsh_n;
 wire writing=!mreq_n && !wr_n && rd_n && rfsh_n;
 wire rom=a<=16'h4fff;
 wire workram=(a & 16'hf800)==16'h8000;
 wire colour=(a & 16'hf800)==16'h8800;
 wire video=(a & 16'hf800)==16'h9000;
 wire attr=(a & 16'hf8c0)==16'h9800;
 wire object=attr || (a>=16'h9840 && a<=16'h98ff);
 wire [7:0] object_address=attr ? {2'b00,a[5:0]} : a[7:0];
 wire input0=a==16'ha000, input1=a==16'ha800;
 wire dip=a==16'hb000, latch=(a & 16'hfff8)==16'hb000;
 wire watchdog=a==16'hb800;
 assign read_select={9{reading}} & {watchdog,dip,input1,input0,object,video,colour,workram,rom};
 assign write_select={7{writing}} & {input0,watchdog,latch,object,video,colour,workram};
 reg old_read=0,old_write=0,pending=0,rom_pending=0,old_frame=0;
 wire read_start=reading && !old_read;
 wire write_start=writing && !old_write;
 assign rom_req=read_start && rom && !reset;
 assign rom_addr=rom ? a[14:0] : 15'd0;
 (* ramstyle="M10K" *) reg [7:0] work_mem[0:2047];
 // Configuration-time RAM contents match MAME's cold zero allocation. CPU,
 // watchdog and loader resets never clear these arrays. Modes 1/2 are used
 // only by initial-state validation; the production default is mode 0.
 function [7:0] powerup_byte(input integer address);
  integer pattern;
  begin
   pattern=(address*37)^(address>>3)^32'h96;
   if(RAM_INIT_MODE==1) powerup_byte=8'hff;
   else if(RAM_INIT_MODE==2) powerup_byte=pattern[7:0];
   else powerup_byte=0;
  end
 endfunction
 generate if(RAM_INIT_MODE>=0) begin: configuration_contents
  integer i;
  initial begin
   for(i=0;i<2048;i=i+1) work_mem[i]=powerup_byte(32'h8000+i);
  end
 end endgenerate
 reg [7:0] response=0;
 // Explicit shared-clock RAMs: same-port CPU NEW_DATA, mixed-port display
 // OLD_DATA. CPU pending/held-response logic below is unchanged.
 // Nonzero initialization modes are simulation fixtures, never production MIFs.
 localparam RAM_INIT_FILE = RAM_INIT_MODE==1 ? "rtl/test_ff.mif" :
                            RAM_INIT_MODE==2 ? "rtl/test_pattern.mif" :
                            "rtl/thepit_ram_zero.mif";
 reg [7:0] work_q;
 wire [7:0] object_q;
 wire [7:0] colour_q,video_q;
 thepit_video_ram #(.INIT_FILE(RAM_INIT_FILE)) colour_mem(
  .clk(clk),.cpu_write(!reset && write_start && colour),
  .display_read(display_req),.cpu_address(a[9:0]),.display_address(display_addr),
  .cpu_data(dout),.cpu_q(colour_q),.display_q(display_colour));
 thepit_video_ram #(.INIT_FILE(RAM_INIT_FILE)) video_mem(
  .clk(clk),.cpu_write(!reset && write_start && video),
  .display_read(display_req),.cpu_address(a[9:0]),.display_address(display_addr),
  .cpu_data(dout),.cpu_q(video_q),.display_q(display_code));
 localparam OBJECT_INIT_FILE = RAM_INIT_MODE==1 ? "rtl/test_object_ff.mif" :
                                   RAM_INIT_MODE==2 ? "rtl/test_object_pattern.mif" :
                                   "rtl/thepit_object_zero.mif";
 // The full 256-byte second port remains addressable so Stage H can schedule
 // sprite descriptor reads without replacing or duplicating this store.
 thepit_object_ram #(.INIT_FILE(OBJECT_INIT_FILE)) object_store(
  .clk(clk),.cpu_write(!reset && write_start && object),
  .display_read(object_display_req),.cpu_address(object_address),
  .display_address(object_display_addr),.cpu_data(dout),
  .cpu_q(object_q),.display_q(object_display_data));
 reg [3:0] ram_pending=0;
 reg [26:0] watchdog_count=0;
 localparam integer WATCHDOG_RELOAD=WATCHDOG_CYCLES-1;
 // Memories are not reset. Each request captures a synchronous result, which
 // is transferred to the held CPU response one system edge later.
 always @(posedge clk) begin
  if(!reset) begin
   if(write_start) begin
    if(workram) work_mem[a[10:0]]<=dout;
   end
   // Separate registered outputs preserve the synchronous inference pattern
   // for each physical RAM. Selection is after these registers.
   if(read_start && workram) work_q<=work_mem[a[10:0]];
   if(read_start) begin
    if(input0) response<=~(control[6] ? player1 : player0);
    else if(input1) response<=inputs1;
    else if(dip) response<=dips;
    else response<=0; // functional MAME default, not physical open bus
   end
  end
 end
 always @(posedge clk) begin
  if(reset) begin
   old_read<=0;old_write<=0;old_frame<=0;pending<=0;rom_pending<=0;ram_pending<=0;din<=0;
   control<=0;sound_command<=0;sound_events<=0;nmi_n<=1;sound_write<=0;
   watchdog_armed<=0;watchdog_count<=0;watchdog_reset<=0;
  end else begin
   old_read<=reading;old_write<=writing;old_frame<=frame_event;
   sound_write<=0;
   pending<=read_start;rom_pending<=read_start && rom;
   ram_pending<={4{read_start}} & {object,video,colour,workram};
   if(pending) din<=rom_pending ? rom_q :
                   ram_pending[0] ? work_q : ram_pending[1] ? colour_q :
                   ram_pending[2] ? video_q : ram_pending[3] ? object_q : response;
   if(frame_event && !old_frame && control[0]) nmi_n<=0;
   if(write_start && latch) begin
    control[a[2:0]]<=dout[0];
    if(a[2:0]==0 && !dout[0]) nmi_n<=1;
   end
   if(write_start && watchdog) begin
    sound_command<=dout;sound_events<=sound_events+16'd1;sound_write<=1;
   end
   watchdog_reset<=0;
   if(read_start && watchdog) begin
    watchdog_armed<=1;watchdog_count<=WATCHDOG_RELOAD[26:0];
   end else if(watchdog_armed) begin
    if(watchdog_count==0) begin watchdog_reset<=1;watchdog_armed<=0;end
    else watchdog_count<=watchdog_count-27'd1;
   end
  end
 end
endmodule
