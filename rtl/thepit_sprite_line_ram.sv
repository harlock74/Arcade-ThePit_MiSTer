// SPDX-License-Identifier: GPL-3.0-or-later
// Stage H production wrapper: exact primitive body from reviewed probe 0506353.
// One 512x16 M10K is requested: byte-enabled writes on A, synchronous reads on
// B, and OLD_DATA for a simultaneous mixed-port access to the same address.
module thepit_sprite_line_ram(
 input  wire        clk,
 input  wire        write,
 input  wire [1:0]  byteena,
 input  wire [8:0]  write_address,
 input  wire [15:0] write_data,
 input  wire        read,
 input  wire [8:0]  read_address,
 output wire [15:0] read_data
);
 altsyncram #(
  .intended_device_family("Cyclone V"), .lpm_type("altsyncram"),
  .operation_mode("DUAL_PORT"), .ram_block_type("M10K"),
  .width_a(16), .widthad_a(9), .numwords_a(512),
  .width_b(16), .widthad_b(9), .numwords_b(512),
  .width_byteena_a(2), .width_byteena_b(1), .byte_size(8),
  .address_reg_b("CLOCK0"), .rdcontrol_reg_b("CLOCK0"),
  .outdata_reg_b("UNREGISTERED"),
  .clock_enable_input_a("BYPASS"), .clock_enable_input_b("BYPASS"),
  .clock_enable_output_b("BYPASS"),
  .read_during_write_mode_mixed_ports("OLD_DATA"),
  .power_up_uninitialized("TRUE")
 ) memory (
  .clock0(clk),
  .clocken0(1'b1), .clocken1(1'b1), .clocken2(1'b1), .clocken3(1'b1),
  .aclr0(1'b0), .aclr1(1'b0),
  .address_a(write_address), .data_a(write_data), .wren_a(write),
  .rden_a(1'b0), .byteena_a(byteena), .addressstall_a(1'b0), .q_a(),
  .address_b(read_address), .data_b(16'b0), .wren_b(1'b0),
  .rden_b(read), .byteena_b(1'b1), .addressstall_b(1'b0),
  .q_b(read_data), .eccstatus()
 );
endmodule
