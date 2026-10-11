// SPDX-License-Identifier: GPL-3.0-or-later
// Qualified AY register/noise/envelope adapter around the restricted tone engine.
module thepit_ay(input wire clk,reset,cold_reset,ay_ce,
 input wire address_write,data_write,input wire [7:0] din,port_a,
 input wire external_a,
 output reg [7:0] dout,output wire acknowledge_a,
 output wire [7:0] channel_a,channel_b,channel_c,
 output reg active=0,output reg [3:0] selected=0,
 output wire [3:0] envelope_level,output wire noise_bit);
 reg [7:0] r[0:15]; integer i;
 initial for(i=0;i<16;i=i+1) r[i]=0;
 function [7:0] mask(input [3:0] a);
 case(a) 1,3,5,13:mask=8'h0f;6,8,9,10:mask=8'h1f;default:mask=8'hff;endcase endfunction
 always @* begin
  if(!active) dout=8'hff;
  else if(selected==14 && external_a) dout=port_a;
  else dout=r[selected]&mask(selected);
 end
 assign acknowledge_a=active && selected==14 && external_a;
 wire write_ok=data_write && active && !reset;
 wire shape_write=write_ok && selected==13;
 always @(posedge clk) begin
  if(cold_reset) begin for(i=0;i<16;i=i+1) r[i]<=0;active<=0;selected<=0;end
  else if(reset) begin for(i=0;i<14;i=i+1) r[i]<=0;active<=0;selected<=0;end
  else begin
   if(address_write) begin active<=din[7:4]==0;if(din[7:4]==0) selected<=din[3:0];end
   if(write_ok) r[selected]<=din;
  end
 end
 // JT49 internal mixer used only as three tone gates. Separate AY functions
 // below avoid adopting YM32 envelopes or JT49's differently phased noise.
 wire [7:0] raw_a,raw_b,raw_c;wire [7:0] unused;
 // Prime the bypass after reset, before any active data transaction can occur.
 reg jt_init=1;
 always @(posedge clk) if(reset) jt_init<=1;else jt_init<=0;
 wire [3:0] jt_address=jt_init?4'd7:selected;
 wire jt_write=write_ok||jt_init;
 wire [7:0] jt_data=jt_init?8'h38:selected==7 ? (din|8'h38) :
                    (selected>=8 && selected<=10) ? 8'h0f : din;
 thepit_tone #(.MUTE_NULL_PERIOD(0)) tone_chip(.clk(clk),.rst_n(!reset),.clk_en(ay_ce),
 .addr(jt_address),.write(jt_write),.din(jt_data),.A(raw_a),.B(raw_b),.C(raw_c));
 reg [2:0] divider=0;
 wire tick=ay_ce && divider==7;
 reg [4:0] noise_count=0;reg noise_prescale=0;reg [16:0] rng=17'd1;
 reg [16:0] env_count=0;reg [3:0] step=15,attack=0;reg holding=0,hold=1,alternate=0;
 wire [16:0] ep={r[12],r[11],1'b0};
 assign envelope_level=step^attack;assign noise_bit=rng[0];
 always @(posedge clk) begin
  if(reset) begin
   divider<=0;noise_count<=0;noise_prescale<=0;rng<=17'd1;
   env_count<=0;step<=15;attack<=0;holding<=0;hold<=1;alternate<=0;
  end else begin
   if(ay_ce) divider<=divider+3'd1;
   if(tick) begin
    if({1'b0,noise_count}+6'd1 >= {1'b0,r[6][4:0]}) begin
     noise_count<=0;noise_prescale<=!noise_prescale;
     if(noise_prescale) rng<={rng[0]^rng[3],rng[16:1]};
    end else noise_count<=noise_count+5'd1;
    if(!holding) begin
     if(env_count+17'd1 >= ep) begin
      env_count<=0;
      if(step!=0) step<=step-4'd1;
      else if(hold) begin
       holding<=1;if(alternate) attack<=~attack;
      end else begin step<=15;if(alternate) attack<=~attack;end
     end else env_count<=env_count+17'd1;
    end
   end
   // Preserve count on shape write, as pinned envelope_t::set_shape does.
   if(shape_write) begin
    step<=15;holding<=0;attack<=din[2]?4'hf:0;
    hold<=!din[3] || din[0];alternate<=!din[3]?din[2]:din[1];
   end
  end
 end
 function [7:0] level(input [3:0] v);
 case(v)
 0:level=0;1:level=1;2:level=2;3:level=3;4:level=4;5:level=6;6:level=9;7:level=13;
 8:level=22;9:level=31;10:level=45;11:level=63;12:level=90;13:level=127;14:level=180;15:level=255;
 endcase endfunction
 assign channel_a=reset || raw_a==0 || !(r[7][3] || rng[0]) ? 8'd0 : level(r[8][4]?envelope_level:r[8][3:0]);
 assign channel_b=reset || raw_b==0 || !(r[7][4] || rng[0]) ? 8'd0 : level(r[9][4]?envelope_level:r[9][3:0]);
 assign channel_c=reset || raw_c==0 || !(r[7][5] || rng[0]) ? 8'd0 : level(r[10][4]?envelope_level:r[10][3:0]);
endmodule
