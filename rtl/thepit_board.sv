// SPDX-License-Identifier: GPL-3.0-or-later
// Stage D storage/download boundary. CPU execution is a sibling in emu.
// No renderer, sound CPU or AY is implemented here.
module thepit_board(
    input wire clk, reset, download, wr,
    input wire [15:0] index,
    input wire [26:0] address,
    input wire [7:0] data,
    output wire ready, load_error,
    output reg [7:0] readback = 0,
    input wire main_read_request,
    input wire [14:0] main_read_address,
    input wire [7:0] cpu_observe,
    output wire [7:0] main_read_data,
    input wire graphics_req, palette_req,
    input wire [10:0] graphics_addr,
    input wire [4:0] palette_addr,
    output wire [7:0] p9_q, p8_q, palette_q,
    input wire sound_read_request,
    input wire [10:0] sound_read_address,
    output wire [7:0] sound_read_data
);
    wire [4:0] we;
    wire [14:0] wa;
    wire [7:0] wd;
    thepit_loader loader(.clk(clk),.reset(reset),.download(download),.wr(wr),.index(index),
        .address(address),.data(data),.ready(ready),.error(load_error),.bank_we(we),
        .bank_address(wa),.bank_data(wd),.next_address());
    reg [14:0] scan_address = 0;
    wire reading = ready && !download && !reset;
    wire [7:0] q_main, q_audio, q_gfx0, q_gfx1, q_prom;
    always @(posedge clk) begin
        if (!reading) begin scan_address <= 0; readback <= 0; end
        else begin
            scan_address <= scan_address == 15'h4fff ? 15'd0 : scan_address + 15'd1;
            readback <= q_main ^ q_audio ^ q_gfx0 ^ q_gfx1 ^ q_prom ^ cpu_observe;
        end
    end
    thepit_rom_store #(.DEPTH(20480),.AW(15)) main_rom(clk,we[0],reading && main_read_request,wa,main_read_address,wd,q_main);
    assign main_read_data=q_main;
    thepit_rom_store audio_rom(clk,we[1],reading && sound_read_request,wa[10:0],sound_read_address,wd,q_audio);
    assign sound_read_data=q_audio;
    thepit_rom_store gfx0_rom(clk,we[2],reading && graphics_req,wa[10:0],graphics_addr,wd,q_gfx0);
    thepit_rom_store gfx1_rom(clk,we[3],reading && graphics_req,wa[10:0],graphics_addr,wd,q_gfx1);
    thepit_rom_store #(.DEPTH(32),.AW(5)) colour_prom(clk,we[4],reading && palette_req,wa[4:0],palette_addr,wd,q_prom);
    assign p9_q=q_gfx0;
    assign p8_q=q_gfx1;
    assign palette_q=q_prom;
endmodule
