// SPDX-License-Identifier: GPL-3.0-or-later
// Single-clock synchronous read/write store. No payload initialization/reset loop.
module thepit_rom_store #(
    parameter integer DEPTH=2048, AW=11
)(
    input wire clk, we, read_enable,
    input wire [AW-1:0] write_address, read_address,
    input wire [7:0] write_data,
    output wire [7:0] read_data
);
    (* ramstyle = "M10K" *) reg [7:0] mem [0:DEPTH-1];
    reg [7:0] memory_q;
    reg read_valid = 0;
    always @(posedge clk) begin
        if (we) mem[write_address] <= write_data;
        if (read_enable) memory_q <= mem[read_address];
        read_valid <= read_enable;
    end
    // Keep the idle-zero mux outside the RAM output register. A conditional
    // synchronous clear on that register prevented main-ROM inference in the
    // returned Quartus 17.0.2 Stage D build. Interface latency is unchanged.
    assign read_data = read_valid ? memory_q : 8'd0;
endmodule
