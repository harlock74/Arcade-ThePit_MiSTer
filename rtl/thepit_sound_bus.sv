// SPDX-License-Identifier: GPL-3.0-or-later
module thepit_sound_bus(input wire clk,reset,cold_reset,ay_ce,irq_event,
 input wire command_write,input wire [7:0] command_data,input wire mute,
 input wire [15:0] a,input wire [7:0] cpu_do,
 input wire m1_n,mreq_n,iorq_n,rd_n,wr_n,rfsh_n,
 input wire [7:0] rom_q,ram_q,output wire rom_read,ram_read,ram_write,
 output reg [7:0] cpu_di=0,output reg irq=0,
 output reg [7:0] command=0,output reg pending=0,
 output reg [15:0] command_events=0,ay2_events=0,irq_acks=0,
 output reg signed [15:0] audio=0);
 wire mr=!mreq_n && !rd_n && rfsh_n;
 wire mw=!mreq_n && !wr_n && rfsh_n;
 wire ir=!iorq_n && !rd_n && m1_n;
 wire iw=!iorq_n && !wr_n && m1_n;
 wire ia=!iorq_n && !m1_n;
 reg old_mr=0,old_mw=0,old_ir=0,old_iw=0,old_ia=0;
 wire rs=mr&&!old_mr;wire ws=mw&&!old_mw;
 wire irs=ir&&!old_ir;wire iws=iw&&!old_iw;wire ias=ia&&!old_ia;
 wire ram_sel=a>=16'h3800 && a<=16'h3bff;
 assign rom_read=rs && a<16'h0800 && !reset;
 assign ram_read=rs && ram_sel && !reset;
 assign ram_write=ws && ram_sel && !reset;
 wire ay1sel=a[7:1]==7'h47,ay2sel=a[7:1]==7'h46;
 wire [7:0] q1,q2;wire ack1,ack2;
 wire [7:0] c1a,c1b,c1c,c2a,c2b,c2c;
 thepit_ay ay1(.clk(clk),.reset(reset),.cold_reset(cold_reset),.ay_ce(ay_ce),
 .address_write(iws&&ay1sel&&!a[0]),.data_write(iws&&ay1sel&&a[0]),.din(cpu_do),
 .port_a(command),.external_a(1'b1),.dout(q1),.acknowledge_a(ack1),.channel_a(c1a),.channel_b(c1b),.channel_c(c1c),.active(),.selected(),.envelope_level(),.noise_bit());
 thepit_ay ay2(.clk(clk),.reset(reset),.cold_reset(cold_reset),.ay_ce(ay_ce),
 .address_write(iws&&ay2sel&&!a[0]),.data_write(iws&&ay2sel&&a[0]),.din(cpu_do),
 .port_a(8'd0),.external_a(1'b0),.dout(q2),.acknowledge_a(ack2),.channel_a(c2a),.channel_b(c2b),.channel_c(c2c),.active(),.selected(),.envelope_level(),.noise_bit());
 wire [10:0] sum={3'd0,c1a}+{3'd0,c1b}+{3'd0,c1c}+{3'd0,c2a}+{3'd0,c2b}+{3'd0,c2c};
 reg read_pending=0,rom_pending=0,ram_pending=0;
 always @(posedge clk) begin
  if(reset) begin
   old_mr<=0;old_mw<=0;old_ir<=0;old_iw<=0;old_ia<=0;
   read_pending<=0;rom_pending<=0;ram_pending<=0;cpu_di<=0;
   pending<=0;irq<=0;command_events<=0;ay2_events<=0;irq_acks<=0;audio<=0;
   if(cold_reset) command<=0;
  end else begin
   old_mr<=mr;old_mw<=mw;old_ir<=ir;old_iw<=iw;old_ia<=ia;
   read_pending<=rom_read||ram_read;rom_pending<=rom_read;ram_pending<=ram_read;
   if(rs) cpu_di<=0; // mapped zero extension and unmapped both zero
   if(read_pending) cpu_di<=rom_pending?rom_q:ram_q;
   if(irs) begin
    cpu_di<=ay1sel&&a[0]?q1:ay2sel&&a[0]?q2:8'd0;
    if(ay1sel&&a[0]&&ack1) pending<=0;
   end
   if(iws && a[7:0]==0) command<=0;
   // Deferred main write after sound-side access: data and pending win.
   if(command_write) begin command<=command_data;pending<=1;command_events<=command_events+16'd1;end
   if((irs&&ay2sel&&a[0]) || (iws&&ay2sel)) ay2_events<=ay2_events+16'd1;
   if(ias) begin irq<=0;cpu_di<=8'hff;irq_acks<=irq_acks+16'd1;end
   if(irq_event) irq<=1;
   audio<=mute?16'sd0:$signed({1'b0,sum,4'd0});
  end
 end
endmodule
