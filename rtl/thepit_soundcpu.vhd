-- SPDX-License-Identifier: GPL-3.0-or-later
library ieee;use ieee.std_logic_1164.all;
entity thepit_soundcpu is port(
 clk,reset,cold_reset,mute,command_write,irq_event:in std_logic;
 rom_q:in std_logic_vector(7 downto 0);rom_read:out std_logic;rom_address:out std_logic_vector(10 downto 0);
 command_data:in std_logic_vector(7 downto 0);
 audio:out std_logic_vector(15 downto 0);
 debug_a:out std_logic_vector(15 downto 0);
 debug_di,debug_do,command:out std_logic_vector(7 downto 0);
 debug_bus:out std_logic_vector(7 downto 0);
 command_events,ay2_events,irq_acks:out std_logic_vector(15 downto 0);
 pending,irq:out std_logic);
end;
architecture rtl of thepit_soundcpu is
 component thepit_sound_clocks port(clk,reset:in std_logic;cp,cn,ay_ce:out std_logic);end component;
 component thepit_sound_ram port(clk,read_enable,write_enable:in std_logic;address:in std_logic_vector(9 downto 0);data:in std_logic_vector(7 downto 0);q:out std_logic_vector(7 downto 0));end component;
 component thepit_sound_bus port(clk,reset,cold_reset,ay_ce,irq_event,command_write:in std_logic;command_data:in std_logic_vector(7 downto 0);mute:in std_logic;a:in std_logic_vector(15 downto 0);cpu_do:in std_logic_vector(7 downto 0);m1_n,mreq_n,iorq_n,rd_n,wr_n,rfsh_n:in std_logic;rom_q,ram_q:in std_logic_vector(7 downto 0);rom_read,ram_read,ram_write:out std_logic;cpu_di:out std_logic_vector(7 downto 0);irq:out std_logic;command:out std_logic_vector(7 downto 0);pending:out std_logic;command_events,ay2_events,irq_acks:out std_logic_vector(15 downto 0);audio:out std_logic_vector(15 downto 0));end component;
 signal rst,cp,cn,ayce,evt,intline:std_logic;
 signal a:std_logic_vector(15 downto 0);signal di,dout,rq,mq:std_logic_vector(7 downto 0);
 signal m1,mreq,io,rd,wr,rf,halt,ba,rr,mr,mw:std_logic;
 signal regs:std_logic_vector(211 downto 0);
begin
 rst<=reset or cold_reset;
 clocks:thepit_sound_clocks port map(clk,rst,cp,cn,ayce);
 cpu:entity work.T80pa generic map(Mode=>0) port map(RESET_n=>not rst,CLK=>clk,CEN_p=>cp,CEN_n=>cn,WAIT_n=>'1',INT_n=>not intline,NMI_n=>'1',BUSRQ_n=>'1',M1_n=>m1,MREQ_n=>mreq,IORQ_n=>io,RD_n=>rd,WR_n=>wr,RFSH_n=>rf,HALT_n=>halt,BUSAK_n=>ba,OUT0=>'0',A=>a,DI=>di,DO=>dout,R800_mode=>'0',REG=>regs,DIRSet=>'0',DIR=>(others=>'0'));
 mem:thepit_sound_ram port map(clk,mr,mw,a(9 downto 0),dout,mq);
 rom_read<=rr;rom_address<=a(10 downto 0);
 busif:thepit_sound_bus port map(clk,rst,cold_reset,ayce,irq_event,command_write,command_data,mute,a,dout,m1,mreq,io,rd,wr,rf,rom_q,mq,rr,mr,mw,di,intline,command,pending,command_events,ay2_events,irq_acks,audio);
 debug_a<=a;debug_di<=di;debug_do<=dout;debug_bus<=cp & cn & m1 & mreq & io & rd & wr & halt;
 irq<=intline;
end;
