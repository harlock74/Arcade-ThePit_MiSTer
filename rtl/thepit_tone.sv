// SPDX-License-Identifier: GPL-3.0-or-later
// Reduced-function JT49 tone implementation derived from Jose Tejada Gomez's JT49.
// Upstream components: jt49_cen and jt49_div; upstream licence: GPL-3.0-or-later.
// Upstream revision: 47301ed51374d6d41db4db846b7643fecf75e417.
// Attribution/documentation updated 2026-10-11; this is not a historical modification date.
// Only used behind the AY adapter: R7 noise bypass, R8..10 forced to 0f.
// Preserve its CE, divider and gate publication latency; no exponential ROM,
// internal noise/envelope, accumulator, readback or port-output machinery.
module thepit_tone #(parameter MUTE_NULL_PERIOD=0)(
 input wire clk,rst_n,clk_en,write,
 input wire [3:0] addr,input wire [7:0] din,
 output wire [7:0] A,B,C);
 reg [7:0] regarray[0:10];
 integer i;
 always @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin for(i=0;i<11;i=i+1)regarray[i]<=0;end
  else if(write && addr<=10)regarray[addr]<=din;
 end
 wire cen16,bitA,bitB,bitC;
 jt49_cen u_cen(.clk(clk),.rst_n(rst_n),.cen(clk_en),.sel(1'b1),.cen16(cen16),.cen256());
 // Named connections make the one-edge-delayed divider enable explicit.
 jt49_div #(.MUTE_NULL_PERIOD(MUTE_NULL_PERIOD)) divA(.clk(clk),.rst_n(rst_n),.cen(cen16),.period({regarray[1][3:0],regarray[0]}),.div(bitA));
 jt49_div #(.MUTE_NULL_PERIOD(MUTE_NULL_PERIOD)) divB(.clk(clk),.rst_n(rst_n),.cen(cen16),.period({regarray[3][3:0],regarray[2]}),.div(bitB));
 jt49_div #(.MUTE_NULL_PERIOD(MUTE_NULL_PERIOD)) divC(.clk(clk),.rst_n(rst_n),.cen(cen16),.period({regarray[5][3:0],regarray[4]}),.div(bitC));
 reg am,bm,cm,la,lb,lc,log_gate,linear_gate;
 reg [3:0] phase;
 reg ga,gb,gc;
 // The reference mixer/log stages have no reset and are CE qualified.
 // Volume is either zero (reset) or 15 (adapter write); all other modes are
 // handled outside this module. Bypass is primed before an active write.
 always @(posedge clk) begin
  linear_gate<=log_gate;
  if(clk_en) begin
   am<=(bitA|regarray[7][0]);
   bm<=(bitB|regarray[7][1]);
   cm<=(bitC|regarray[7][2]);
   la<=am && |regarray[8][3:0];
   lb<=bm && |regarray[9][3:0];
   lc<=cm && |regarray[10][3:0];
  end
 end
 always @(posedge clk or negedge rst_n) begin
  if(!rst_n)begin phase<=1;ga<=0;gb<=0;gc<=0;end
  else if(clk_en)begin
   phase<={phase[2:0],phase[3]};
   case(phase)
    1:log_gate<=la;
    2:begin ga<=linear_gate;log_gate<=lb;end
    4:begin gb<=linear_gate;log_gate<=lc;end
    8:gc<=linear_gate;
    default:;
   endcase
  end
 end
 assign A={8{ga}};assign B={8{gb}};assign C={8{gc}};
endmodule
