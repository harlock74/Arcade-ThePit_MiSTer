// SPDX-License-Identifier: GPL-3.0-or-later
// Asynchronous assertion, two-clock synchronous release in the baseline domain.
module thepit_reset(input wire clk, input wire async_reset, output wire reset);
    (* ASYNC_REG = "TRUE", altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
    reg [1:0] sync = 2'b11;
    always @(posedge clk or posedge async_reset)
        if (async_reset) sync <= 2'b11;
        else sync <= {sync[0], 1'b0};
    assign reset = sync[1];
endmodule
