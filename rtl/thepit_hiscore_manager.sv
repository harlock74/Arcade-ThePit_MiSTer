// SPDX-License-Identifier: GPL-3.0-or-later
// Exclusive existing CPU-port ownership; no additional work-RAM port.
module thepit_hiscore_manager(
 input wire clk,reset,qualified,diagnostic,
 input wire [15:0] cpu_a,
 input wire [7:0] cpu_di,cpu_do,
 input wire m1_n,mreq_n,rd_n,wr_n,rfsh_n,busak_n,
 input wire published_valid,staging_busy,
 input wire [7:0] restore_data,
 output wire [3:0] restore_address,
 output reg capture_begin=0,capture_write=0,capture_end=0,init_epoch=0,
 output reg [3:0] capture_address=0,
 output reg [7:0] capture_data=0,
 output wire busrq_n,owns,restore_lock,
 output wire [15:0] manager_a,
 output wire [7:0] manager_do,
 output wire manager_rd_n,manager_wr_n,
 output reg reset_needed=0,fault=0
);
 wire reading=!mreq_n && !rd_n && wr_n && rfsh_n;
 wire writing=!mreq_n && !wr_n && rd_n && rfsh_n;
 reg was_read=0,was_write=0;
 reg [15:0] read_address=0,instruction_pc=0;
 reg read_opcode=0;
 // Prefix state: 0 ordinary; 1 DD/FD; 2 ED/CB opcode; 3 indexed-CB
 // displacement; 4 indexed-CB operation. Only first fetch emits an event.
 reg [2:0] prefix=0;
 reg init_armed=0,initialized=0;
 reg [4:0] init_count=0;
 reg transaction=0,p1_return=0,p2_return=0;
 reg [1:0] comparisons=0;
 reg [7:0] game_mode=0;
 reg [4:0] state=0;
 reg [3:0] pos=0;
 reg [9:0] budget=0;
 reg restoring=0;
 localparam IDLE=0,GRANT=1,DRAIN1=2,DRAIN2=3,BEGIN=4,
  READ1=5,READ2=6,READ3=7,READ4=8,WRITE1=9,WRITE2=10,WRITE3=11,
  CHECK1=12,CHECK2=13,CHECK3=14,CHECK4=15,END1=16,END2=17,END3=18;
 assign busrq_n=state==IDLE;
 assign owns=state>=BEGIN && state<=END1;
 assign restore_lock=state!=IDLE && restoring;
 assign manager_a=16'h8039+{12'd0,pos};
 assign manager_do=restore_data;
 assign restore_address=pos;
 assign manager_rd_n=!(state==READ1 || state==READ2 || state==CHECK1 || state==CHECK2);
 assign manager_wr_n=state!=WRITE1;
 function [7:0] default_byte(input [3:0] n);
  begin case(n%5)0:default_byte=16;1:default_byte=10;2:default_byte=22;default:default_byte=0;endcase end
 endfunction
 function [15:0] default_pc(input [4:0] n);
  begin case(n%5)0:default_pc=16'h4bd6;1:default_pc=16'h4bd9;2:default_pc=16'h4bdc;3:default_pc=16'h4bdf;default:default_pc=16'h4be2;endcase end
 endfunction
 always @(posedge clk)begin
  capture_begin<=0;capture_write<=0;capture_end<=0;init_epoch<=0;
  was_read<=reading;was_write<=writing;
  if(reset || !qualified)begin
   was_read<=0;was_write<=0;prefix<=0;state<=IDLE;budget<=0;
   init_armed<=0;initialized<=0;init_count<=0;transaction<=0;
   comparisons<=0;p1_return<=0;p2_return<=0;game_mode<=0;fault<=0;
   // Quarantine is cleared only by the original complete initialization.
  end else begin
   if(state!=IDLE)begin
    budget<=budget+1'b1;
    if(budget==1023)fault<=1;
   end else budget<=0;
   if(diagnostic)begin transaction<=0;initialized<=0;end
   if(!owns && busak_n)begin
    if(reading && !was_read)begin read_address<=cpu_a;read_opcode<=!m1_n;end
    // Held CPU response is valid before read deassertion at this CPU rate.
    if(!reading && was_read)begin
     if(read_address==16'h8001)game_mode<=cpu_di;
     if(read_opcode)begin
      if(prefix==0)begin
       instruction_pc<=read_address;
       if(read_address==16'h4bc7)begin init_armed<=1;init_count<=0;initialized<=0;transaction<=0;end
       if(read_address==16'h4be7)begin
        init_armed<=0;
        if(init_armed && init_count==15)begin
         initialized<=1;reset_needed<=0;init_epoch<=1;
         if(published_valid)begin restoring<=1;state<=GRANT;pos<=0;end
        end
       end
       if(read_address==16'h0371 && initialized && !reset_needed && !diagnostic)begin
        transaction<=1;comparisons<=0;p1_return<=0;p2_return<=0;
       end
       if(read_address==16'h4d3a && transaction)begin
        if(comparisons<2)comparisons<=comparisons+1'b1;else transaction<=0;
       end
       if(read_address==16'h0398 && comparisons==1 && transaction)p1_return<=1;
       if(read_address==16'h03a5 && comparisons==2 && transaction)p2_return<=1;
       if((read_address==16'h021c || read_address==16'h022d) && transaction && comparisons!=0)begin
        transaction<=0;reset_needed<=1;
       end
       if(read_address==16'h03ac)begin
        transaction<=0;
        if(transaction && !reset_needed && p1_return && !diagnostic &&
          ((game_mode==1 && comparisons==1)||(game_mode==2 && comparisons==2 && p2_return)))begin
         // Acquire immediately; staging may finish while CPU is held, but
         // never defer a snapshot until gameplay has resumed.
         state<=GRANT;restoring<=0;pos<=0;
        end
       end
      end
      if(prefix==2)prefix<=0;
      else if(cpu_di==8'hdd || cpu_di==8'hfd)prefix<=1;
      else if(cpu_di==8'hcb && prefix==1)prefix<=3;
      else if(cpu_di==8'hcb || cpu_di==8'hed)prefix<=2;
      else prefix<=0;
     end else if(prefix==3)prefix<=4;
     else if(prefix==4)prefix<=0;
    end
    if(writing && !was_write)begin
     if(cpu_a==16'h8001)game_mode<=cpu_do;
     if(init_armed && cpu_a>=16'h8039 && cpu_a<=16'h8047)begin
      if(init_count<15 && cpu_a==16'h8039+{11'd0,init_count} && cpu_do==default_byte(init_count[3:0]) && instruction_pc==default_pc(init_count))init_count<=init_count+1'b1;
      else begin init_armed<=0;init_count<=0;end
     end
    end
   end
   if(!fault)case(state)
    IDLE:;
    GRANT:if(!busak_n && rd_n && wr_n && mreq_n)state<=DRAIN1;
    DRAIN1:state<=DRAIN2;
    DRAIN2:state<=BEGIN;
    BEGIN:begin if(!restoring)capture_begin<=1;state<=READ1;end
    READ1:state<=READ2;
    READ2:state<=READ3;
    READ3:begin
     if(restoring)begin if(cpu_di!=default_byte(pos))fault<=1;end
     else begin capture_write<=1;capture_address<=pos;capture_data<=cpu_di;end
     state<=READ4;
    end
    READ4:if(pos==14)begin pos<=0;state<=restoring ? WRITE1 : END1;end
          else begin pos<=pos+1'b1;state<=READ1;end
    WRITE1:state<=WRITE2;
    WRITE2:state<=WRITE3;
    WRITE3:if(pos==14)begin pos<=0;state<=CHECK1;end
           else begin pos<=pos+1'b1;state<=WRITE1;end
    CHECK1:state<=CHECK2;
    CHECK2:state<=CHECK3;
    CHECK3:begin if(cpu_di!=restore_data)fault<=1;state<=CHECK4;end
    CHECK4:if(pos==14)state<=END1;else begin pos<=pos+1'b1;state<=CHECK1;end
    END1:begin if(!restoring)capture_end<=1;state<=END2;end
    END2:state<=END3;
    END3:state<=IDLE;
    default:begin fault<=1;end
   endcase
  end
 end
endmodule
