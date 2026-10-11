// SPDX-License-Identifier: GPL-3.0-or-later
// Shared object/attribute store. CPU port is continuous-read/NEW_DATA; the
// synchronous display port holds its response and returns OLD_DATA on a
// same-address CPU write. Stage G consumes only even attribute addresses;
// the complete 256-byte display address leaves Stage H descriptor access open.
module thepit_object_ram #(parameter INIT_FILE="rtl/thepit_object_zero.mif")(
 input wire clk, cpu_write, display_read,
 input wire [7:0] cpu_address, display_address,
 input wire [7:0] cpu_data,
 output wire [7:0] cpu_q, display_q
);
 altsyncram #(
  .intended_device_family("Cyclone V"), .lpm_type("altsyncram"),
  .operation_mode("BIDIR_DUAL_PORT"), .ram_block_type("M10K"),
  .width_a(8), .widthad_a(8), .numwords_a(256),
  .width_b(8), .widthad_b(8), .numwords_b(256),
  .width_byteena_a(1), .width_byteena_b(1), .byte_size(8),
  .address_reg_b("CLOCK0"), .indata_reg_b("CLOCK0"),
  .wrcontrol_wraddress_reg_b("CLOCK0"), .rdcontrol_reg_b("CLOCK0"),
  .byteena_reg_b("CLOCK0"),
  .outdata_reg_a("UNREGISTERED"), .outdata_reg_b("UNREGISTERED"),
  .clock_enable_input_a("BYPASS"), .clock_enable_input_b("BYPASS"),
  .clock_enable_output_a("BYPASS"), .clock_enable_output_b("BYPASS"),
  .read_during_write_mode_port_a("NEW_DATA_NO_NBE_READ"),
  .read_during_write_mode_port_b("NEW_DATA_NO_NBE_READ"),
  .read_during_write_mode_mixed_ports("OLD_DATA"),
  .power_up_uninitialized("FALSE"), .init_file(INIT_FILE)
 ) memory (
  .clock0(clk),
  .clocken0(1'b1), .clocken1(1'b1), .clocken2(1'b1), .clocken3(1'b1),
  .aclr0(1'b0), .aclr1(1'b0),
  .address_a(cpu_address), .data_a(cpu_data), .wren_a(cpu_write),
  .rden_a(1'b1), .byteena_a(1'b1), .addressstall_a(1'b0), .q_a(cpu_q),
  .address_b(display_address), .data_b(8'b0), .wren_b(1'b0),
  .rden_b(display_read), .byteena_b(1'b1), .addressstall_b(1'b0),
  .q_b(display_q), .eccstatus()
 );
endmodule
