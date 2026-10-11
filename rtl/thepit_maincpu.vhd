-- SPDX-License-Identifier: GPL-3.0-or-later
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
entity thepit_maincpu is
 generic(WATCHDOG_CYCLES:integer:=75000000;RAM_INIT_MODE:integer:=0);
 port(clk,reset:in std_logic;
      hs_busrq_n:in std_logic:='1';hs_owns:in std_logic:='0';
      hs_a:in std_logic_vector(15 downto 0):=(others=>'0');
      hs_do:in std_logic_vector(7 downto 0):=(others=>'0');
      hs_rd_n,hs_wr_n:in std_logic:='1';hs_busak_n:out std_logic;
      pixel_ce,frame_event:in std_logic;
      rom_q:in std_logic_vector(7 downto 0);
      rom_req:out std_logic;rom_addr:out std_logic_vector(14 downto 0);
      observe:out std_logic_vector(7 downto 0);
      debug_a:out std_logic_vector(15 downto 0);
      debug_di,debug_do:out std_logic_vector(7 downto 0);
      debug_reg:out std_logic_vector(211 downto 0);
      debug_bus:out std_logic_vector(9 downto 0);
      display_req:in std_logic:='0';
      display_addr:in std_logic_vector(9 downto 0):=(others=>'0');
      display_code,display_colour:out std_logic_vector(7 downto 0);
      object_display_req:in std_logic:='0';
      object_display_addr:in std_logic_vector(7 downto 0):=(others=>'0');
      object_display_data:out std_logic_vector(7 downto 0);
      player0:in std_logic_vector(7 downto 0):=x"ff";
      player1:in std_logic_vector(7 downto 0):=x"ff";
      inputs1:in std_logic_vector(7 downto 0):=x"00";
      dips:in std_logic_vector(7 downto 0):=x"00";
      flip_x,flip_y:out std_logic;
      sound_write,sound_mute,sound_reset:out std_logic;
      sound_data:out std_logic_vector(7 downto 0));
end;
architecture rtl of thepit_maincpu is
 component thepit_mainbus is
 generic(WATCHDOG_CYCLES:integer:=75000000;RAM_INIT_MODE:integer:=0);
 port(clk,reset:in std_logic;a:in std_logic_vector(15 downto 0);dout:in std_logic_vector(7 downto 0);
 mreq_n,rd_n,wr_n,rfsh_n:in std_logic;rom_q:in std_logic_vector(7 downto 0);
 rom_req:out std_logic;rom_addr:out std_logic_vector(14 downto 0);din:out std_logic_vector(7 downto 0);
 frame_event:in std_logic;player0,player1,inputs1,dips:in std_logic_vector(7 downto 0);
 control,sound_command:out std_logic_vector(7 downto 0);sound_events:out std_logic_vector(15 downto 0);
 nmi_n,watchdog_reset,watchdog_armed:out std_logic;read_select:out std_logic_vector(8 downto 0);write_select:out std_logic_vector(6 downto 0);
 display_req:in std_logic;display_addr:in std_logic_vector(9 downto 0);
 display_code,display_colour:out std_logic_vector(7 downto 0);
 object_display_req:in std_logic;object_display_addr:in std_logic_vector(7 downto 0);
 object_display_data:out std_logic_vector(7 downto 0);sound_write:out std_logic);
 end component;
 signal phase,cp,cn,ce:std_logic:='0';
 signal wdreset,machine_reset,nmi:std_logic;
 signal a:std_logic_vector(15 downto 0);
 signal di,dout,control,command:std_logic_vector(7 downto 0);
 signal events:std_logic_vector(15 downto 0);
 signal m1,mreq,io,rd,wr,rf,halt,busak:std_logic;
 signal regs:std_logic_vector(211 downto 0);
 signal cpu_reset_n:std_logic;
 signal ba:std_logic_vector(15 downto 0);signal bd:std_logic_vector(7 downto 0);signal bm,br,bw,bf:std_logic;
 begin
 hs_busak_n<=busak;
 ba<=hs_a when hs_owns='1' else a;bd<=hs_do when hs_owns='1' else dout;
 bm<=hs_rd_n and hs_wr_n when hs_owns='1' else mreq;
 br<=hs_rd_n when hs_owns='1' else rd;bw<=hs_wr_n when hs_owns='1' else wr;
 bf<='1' when hs_owns='1' else rf;
 machine_reset<=reset or wdreset;
 cpu_reset_n<=not machine_reset;
 ce<=pixel_ce and not machine_reset;
 cp<=ce and not phase;cn<=ce and phase;
 process(clk) begin
  if rising_edge(clk) then
   if machine_reset='1' then phase<='0';
   elsif ce='1' then phase<=not phase;end if;
  end if;
 end process;
 cpu:entity work.T80pa generic map(Mode=>0)
 port map(RESET_n=>cpu_reset_n,CLK=>clk,CEN_p=>cp,CEN_n=>cn,WAIT_n=>'1',INT_n=>'1',NMI_n=>nmi,BUSRQ_n=>hs_busrq_n,
 M1_n=>m1,MREQ_n=>mreq,IORQ_n=>io,RD_n=>rd,WR_n=>wr,RFSH_n=>rf,HALT_n=>halt,BUSAK_n=>busak,
 OUT0=>'0',A=>a,DI=>di,DO=>dout,R800_mode=>'0',REG=>regs,DIRSet=>'0',DIR=>(others=>'0'));
 bus_interface:thepit_mainbus generic map(WATCHDOG_CYCLES=>WATCHDOG_CYCLES,RAM_INIT_MODE=>RAM_INIT_MODE)
 port map(clk=>clk,reset=>machine_reset,a=>ba,dout=>bd,mreq_n=>bm,rd_n=>br,wr_n=>bw,rfsh_n=>bf,
 rom_q=>rom_q,rom_req=>rom_req,rom_addr=>rom_addr,din=>di,frame_event=>frame_event,
 player0=>player0,player1=>player1,inputs1=>inputs1,dips=>dips,
 control=>control,sound_command=>command,sound_events=>events,nmi_n=>nmi,watchdog_reset=>wdreset,
 watchdog_armed=>open,read_select=>open,write_select=>open,
 display_req=>display_req,display_addr=>display_addr,display_code=>display_code,display_colour=>display_colour,
 object_display_req=>object_display_req,object_display_addr=>object_display_addr,
 object_display_data=>object_display_data,sound_write=>sound_write);
 sound_data<=command;sound_mute<=not control(3);sound_reset<=machine_reset;
 flip_x<=control(6);flip_y<=control(7);
 observe<=regs(71 downto 64) xor control xor command xor events(7 downto 0);
 debug_a<=a;debug_di<=di;debug_do<=dout;debug_reg<=regs;
 debug_bus<=machine_reset & cp & cn & m1 & mreq & rd & wr & rf & halt & nmi;
end;
