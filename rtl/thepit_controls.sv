// SPDX-License-Identifier: GPL-3.0-or-later
// MiSTer transport to The Pit board-level input polarity and bit order.
module thepit_controls(
 input wire [31:0] joystick_0,
 input wire [31:0] joystick_1,
 input wire [7:0] dip_options,
 output wire [7:0] player0,
 output wire [7:0] player1,
 output wire [7:0] inputs1,
 output wire [7:0] dips
);
 // MiSTer D-pad: R,L,D,U in bits 0..3. Board port: L,R,D,U,fire
 // active low in bits 0..4. Movement and fire remain player-local.
 assign player0={3'b111,~joystick_0[4],~joystick_0[3],~joystick_0[2],~joystick_0[0],~joystick_0[1]};
 assign player1={3'b111,~joystick_1[4],~joystick_1[3],~joystick_1[2],~joystick_1[0],~joystick_1[1]};

 // MiSTer convenience: cabinet-wide coin/start may be used from either pad.
 // Requested buttons are Fire,Start 1P,Start 2P,Coin in bits 4..7.
 assign inputs1={5'b00000,
                 joystick_0[5] | joystick_1[5],
                 joystick_0[6] | joystick_1[6],
                 joystick_0[7] | joystick_1[7]};
 assign dips=dip_options;
endmodule
