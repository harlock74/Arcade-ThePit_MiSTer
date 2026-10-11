//============================================================================
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//
//============================================================================

// Locally adapted for The Pit Stage E raw raster diagnostic.
module emu (
    `include "sys/emu_ports.vh"
);
assign ADC_BUS = 'z;
assign USER_OUT = 7'h7f;
assign {UART_RTS,UART_TXD,UART_DTR} = 3'b000;
assign {SD_SCK,SD_MOSI,SD_CS} = 3'bzzz;
assign SDRAM_DQ = 16'hzzzz;
assign SDRAM_A=13'd0;
assign SDRAM_BA=2'd0;
assign SDRAM_CLK=1'b0;
assign SDRAM_CKE=1'b0;
assign {SDRAM_DQML,SDRAM_DQMH,SDRAM_nWE,SDRAM_nCAS,SDRAM_nRAS,SDRAM_nCS}=6'b111111;
`ifndef MISTER_FB
assign {DDRAM_CLK,DDRAM_BURSTCNT,DDRAM_ADDR,DDRAM_DIN,DDRAM_BE,DDRAM_RD,DDRAM_WE} = '0;
`endif
assign VGA_SL=2'd0;
assign VGA_F1=0;
assign VGA_SCALER=0;
assign VGA_DISABLE=0;
assign HDMI_FREEZE=0;
assign HDMI_BLACKOUT=0;
assign HDMI_BOB_DEINT=0;
assign VIDEO_ARX=video_rotated ? 13'd3 : 13'd4;
assign VIDEO_ARY=video_rotated ? 13'd4 : 13'd3;
assign AUDIO_S=1'b1;
assign AUDIO_MIX=2'd0;
assign LED_DISK=2'd0;
assign LED_POWER=2'd0;
assign BUTTONS=2'd0;

localparam CONF_STR = {"ThePit;;","-;",
                      "R[0],Reset;","-;",
                      "O[3:2],Coinage,1 Coin/1 Credit,3 Coins/2 Credits,2 Coins/1 Credit,Free Play;",
                      "O[4],Game Speed,Fast,Slow;","O[5],Time Limit,Long,Short;",
                      "O[6],Flip Screen,Off,On;","O[7],Cabinet,Upright,Cocktail;",
                      "O[8],Lives,3,4;","O[9],Diagnostic Tests,Off,Loop Tests;",
                      "O[10],Orientation,Native,Rotate CW;",
                      "h0-,Hi-Score: Reset needed;","h1-,Hi-Score: Readback fault;",
                      "O[12],Autosave High Scores,On,Off;",
                      "d2T[11],Save High Scores Now;",
                      "-;","J1,Fire,Start 1P,Start 2P,Coin;",
                      "v,1;","V,Stage K menu correction;"};
wire clk_sys, pll_locked, core_reset;
wire download, wr, upload, upload_rd;
wire [7:0] hs_upload_data;
wire hs_upload_request,hs_valid,hs_reset_needed,hs_fault;
wire [15:0] index;
wire [26:0] address;
wire [7:0] data;
wire [127:0] status;
wire [1:0] buttons;
wire [31:0] joystick_0,joystick_1;
wire [35:0] ext_bus;
assign ext_bus[32] = 1'b0;
assign ext_bus[15:0] = 16'd0;
wire [21:0] gamma_bus;
assign gamma_bus[21]=1'b0;
wire [31:0] no_lba[1];
wire [5:0] no_blocks[1];
wire [7:0] no_sd_data[1];
assign no_lba[0]=32'd0;
assign no_blocks[0]=6'd0;
assign no_sd_data[0]=8'd0;
pll pll(.refclk(CLK_50M),.rst(1'b0),.outclk_0(clk_sys),.locked(pll_locked));
thepit_reset reset_sync(.clk(clk_sys),.async_reset(RESET || !pll_locked),.reset(core_reset));
hps_io #(.CONF_STR(CONF_STR),.WIDE(0)) hps_io (
 .clk_sys(clk_sys),.HPS_BUS(HPS_BUS),.EXT_BUS(ext_bus),.gamma_bus(gamma_bus),
 .status(status),.buttons(buttons),.joystick_0(joystick_0),.joystick_1(joystick_1),
 .ioctl_download(download),.ioctl_wr(wr),.ioctl_index(index),.ioctl_addr(address),.ioctl_dout(data),
 .ioctl_wait(1'b0),.ioctl_upload(upload),.ioctl_rd(upload_rd),
 .ioctl_upload_req(hs_upload_request),.ioctl_upload_index(8'd4),.ioctl_din(hs_upload_data),
 .status_in(128'd0),.status_set(1'b0),.status_menumask({13'd0,hs_valid,hs_fault,hs_reset_needed}),.info_req(1'b0),.info(8'd0),
 .video_rotated(video_rotated),.new_vmode(1'b0),
 .sd_lba(no_lba),.sd_blk_cnt(no_blocks),.sd_rd(1'b0),.sd_wr(1'b0),.sd_buff_din(no_sd_data),
 .joystick_0_rumble(16'd0),.joystick_1_rumble(16'd0),.joystick_2_rumble(16'd0),
 .joystick_3_rumble(16'd0),.joystick_4_rumble(16'd0),.joystick_5_rumble(16'd0),
 .ps2_kbd_clk_in(1'b1),.ps2_kbd_data_in(1'b1),.ps2_mouse_clk_in(1'b1),.ps2_mouse_data_in(1'b1),
 .ps2_kbd_led_status(3'd0),.ps2_kbd_led_use(3'd0)
);
// Presentation rotation taps the final native pixels. It never changes board
// coordinates, Flip Screen DIP, sprite scheduling, or native VGA outputs.
wire video_rotated;
`ifdef MISTER_FB
assign FB_FORCE_BLANK=1'b0;
screen_rotate presentation (
 .CLK_VIDEO(CLK_VIDEO),.CE_PIXEL(CE_PIXEL),
 .VGA_R(VGA_R),.VGA_G(VGA_G),.VGA_B(VGA_B),.VGA_HS(VGA_HS),.VGA_VS(VGA_VS),.VGA_DE(VGA_DE),
 .rotate_ccw(1'b0),.no_rotate(!status[10]),.flip(1'b0),.video_rotated(video_rotated),
 .FB_EN(FB_EN),.FB_FORMAT(FB_FORMAT),.FB_WIDTH(FB_WIDTH),.FB_HEIGHT(FB_HEIGHT),
 .FB_BASE(FB_BASE),.FB_STRIDE(FB_STRIDE),.FB_VBL(FB_VBL),.FB_LL(FB_LL),
 .DDRAM_CLK(DDRAM_CLK),.DDRAM_BUSY(DDRAM_BUSY),.DDRAM_BURSTCNT(DDRAM_BURSTCNT),
 .DDRAM_ADDR(DDRAM_ADDR),.DDRAM_DIN(DDRAM_DIN),.DDRAM_BE(DDRAM_BE),.DDRAM_WE(DDRAM_WE),.DDRAM_RD(DDRAM_RD));
`else
assign video_rotated=1'b0;
`endif
wire ready,load_error;
wire [7:0] readback,main_rom_q,cpu_observe;
wire main_rom_req;wire [14:0] main_rom_address;
wire game_reset=status[0] || buttons[1];
wire board_reset=core_reset || game_reset;
// The private development invalidation action is retired. Status bit 1 stays
// reserved; ordinary Reset still preserves the downloaded ROM.
wire loader_invalidate=1'b0;
wire storage_reset=core_reset || loader_invalidate;
wire [7:0] player0,player1,inputs1,dips;
thepit_controls controls(.joystick_0(joystick_0),.joystick_1(joystick_1),
 .dip_options(status[9:2]),.player0(player0),.player1(player1),.inputs1(inputs1),.dips(dips));
wire pixel_ce, raster_frame;
wire display_req,object_display_req,graphics_req,palette_req;
wire [9:0] display_addr;
wire [7:0] object_display_addr;
wire [10:0] graphics_addr;
wire [4:0] palette_addr;
wire [7:0] display_code,display_colour,object_display_data,p9_q,p8_q,palette_q;
wire flip_x,flip_y;
wire [8:0] raw_x,raw_y;
wire raw_hs,raw_vs,raw_de;
wire sound_write,sound_mute,sound_reset,sound_rom_req;
wire [7:0] sound_data,sound_rom_q;
wire [10:0] sound_rom_address;
wire [15:0] sound_audio,audio_sample;
(* keep *) wire [15:0] sound_command_events,sound_ay2_events,sound_irq_acks;
wire rom_download=download && index==0;
wire [15:0] hs_cpu_a,hs_a;wire [7:0] hs_di,hs_do,hs_bus_do;wire [9:0] hs_cpu_bus;
wire hs_busrq_n,hs_busak_n,hs_owns,hs_rd_n,hs_wr_n;
thepit_maincpu cpu_core(.clk(clk_sys),.reset(board_reset || !ready || rom_download || load_error),
 .hs_busrq_n(hs_busrq_n),.hs_busak_n(hs_busak_n),.hs_owns(hs_owns),
 .hs_a(hs_a),.hs_do(hs_do),.hs_rd_n(hs_rd_n),.hs_wr_n(hs_wr_n),
 .pixel_ce(pixel_ce),.frame_event(raster_frame),
 .rom_q(main_rom_q),.rom_req(main_rom_req),.rom_addr(main_rom_address),.observe(cpu_observe),
 .debug_a(hs_cpu_a),.debug_di(hs_di),.debug_do(hs_bus_do),.debug_reg(),.debug_bus(hs_cpu_bus),
 .display_req(display_req),.display_addr(display_addr),.display_code(display_code),.display_colour(display_colour),
 .object_display_req(object_display_req),.object_display_addr(object_display_addr),
 .object_display_data(object_display_data),.flip_x(flip_x),.flip_y(flip_y),
 .player0(player0),.player1(player1),.inputs1(inputs1),.dips(dips),
 .sound_write(sound_write),.sound_data(sound_data),.sound_mute(sound_mute),.sound_reset(sound_reset));
thepit_hiscore scores(.clk(clk_sys),.cold_reset(core_reset),.game_reset(board_reset),
 .ready(ready),.invalidated(loader_invalidate),.diagnostic(dips[7]),
 .download(download),.upload(upload),.wr(wr),.rd(upload_rd),.save_action(status[11]),.autosave_on(!status[12]),
 .index(index),.address(address),.data(data),.upload_data(hs_upload_data),.upload_request(hs_upload_request),
 .valid(hs_valid),.reset_needed(hs_reset_needed),.fault(hs_fault),
 .cpu_a(hs_cpu_a),.cpu_di(hs_di),.cpu_do(hs_bus_do),.cpu_bus(hs_cpu_bus),
 .busak_n(hs_busak_n),.busrq_n(hs_busrq_n),.owns(hs_owns),
 .manager_a(hs_a),.manager_do(hs_do),.manager_rd_n(hs_rd_n),.manager_wr_n(hs_wr_n));
thepit_soundcpu sound_cpu(.clk(clk_sys),.reset(sound_reset),.cold_reset(core_reset),
 .mute(sound_mute),.command_write(sound_write),.command_data(sound_data),
 .irq_event(pixel_ce && raw_x==9'd383 && raw_y==9'd255),
 .rom_q(sound_rom_q),.rom_read(sound_rom_req),.rom_address(sound_rom_address),
 .audio(sound_audio),.debug_a(),.debug_di(),.debug_do(),.debug_bus(),.command(),.pending(),.irq(),
 .command_events(sound_command_events),.ay2_events(sound_ay2_events),.irq_acks(sound_irq_acks));
thepit_audio_cdc audio_bridge(.source_clk(clk_sys),.audio_clk(CLK_AUDIO),.reset(core_reset),
 .sample_in(sound_audio),.sample_out(audio_sample));
assign AUDIO_L=audio_sample;
assign AUDIO_R=audio_sample;
// Status/button invalidation does not interrupt diagnostic sync generation.
thepit_board board(.clk(clk_sys),.reset(storage_reset),
 .download(download),.wr(wr),.index(index),.address(address),.data(data),
 .ready(ready),.load_error(load_error),.readback(readback),
 .main_read_request(main_rom_req),.main_read_address(main_rom_address),
 .cpu_observe(cpu_observe),.main_read_data(main_rom_q),
 .graphics_req(graphics_req),.graphics_addr(graphics_addr),.palette_req(palette_req),.palette_addr(palette_addr),
 .p9_q(p9_q),.p8_q(p8_q),.palette_q(palette_q),
 .sound_read_request(sound_rom_req),.sound_read_address(sound_rom_address),.sound_read_data(sound_rom_q));
thepit_raster video(.clk(clk_sys),.reset(core_reset),.pixel_ce(pixel_ce),.frame_event(raster_frame),
 .x(raw_x),.y(raw_y),.hblank(),.vblank(),.cs(),
 .red(),.green(),.blue(),.hs(raw_hs),.vs(raw_vs),.de(raw_de));
thepit_sprite_video background(.clk(clk_sys),.reset(core_reset),
 .enabled(ready && !board_reset && !rom_download && !load_error),
 .pixel_ce(pixel_ce),.hs(raw_hs),.vs(raw_vs),.de(raw_de),.raw_x(raw_x),.raw_y(raw_y),
 .flip_x(flip_x),.flip_y(flip_y),.object_display_req(object_display_req),
 .object_display_addr(object_display_addr),.object_display_data(object_display_data),
 .display_req(display_req),.display_addr(display_addr),.display_code(display_code),.display_colour(display_colour),
 .graphics_req(graphics_req),.graphics_addr(graphics_addr),.p9_q(p9_q),.p8_q(p8_q),
 .palette_req(palette_req),.palette_addr(palette_addr),.palette_q(palette_q),
 .out_ce(CE_PIXEL),.out_hs(VGA_HS),.out_vs(VGA_VS),.out_de(VGA_DE),.red(VGA_R),.green(VGA_G),.blue(VGA_B));
assign CLK_VIDEO=clk_sys;
// Keep all loaded stores and bounded CPU observations live without colouring video.
assign LED_USER=ready && !load_error && ^{readback,sound_command_events,sound_ay2_events,sound_irq_acks};
endmodule
