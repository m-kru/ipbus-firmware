-- Generic control / status register block
--
-- Provides 2**n control registers (32b each), rw
-- Provides 2**m status registers (32b each), ro
--
-- Bottom part of read address space is control, top is status
--
-- Useful for misc control of firmware block
-- Unused registers should be optimised away
--
-- Dave Newbold, July 2012

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use work.ipbus.all;
use work.ipbus_reg_types.all;

entity ipbus_ctrlreg_v is
	generic(
		ctrl_addr_width : natural := 0;
		stat_addr_width : natural := 0
	);
	port(
		clk: in std_logic;
		reset: in std_logic;
		ipbus_in: in ipb_wbus;
		ipbus_out: out ipb_rbus;
		d: in ipb_reg_v(2 ** stat_addr_width - 1 downto 0);
		q: out ipb_reg_v(2 ** ctrl_addr_width - 1 downto 0)
	);
	
end ipbus_ctrlreg_v;

architecture rtl of ipbus_ctrlreg_v is

	signal reg: ipb_reg_v(2 ** ctrl_addr_width - 1 downto 0);
	signal ctrl_sel, stat_sel: integer;
	signal addr_width_max: natural;
	signal ack: std_logic;

begin

	addr_width_max <= ctrl_addr_width when ctrl_addr_width > stat_addr_width else stat_addr_width;
	ctrl_sel <= to_integer(unsigned(ipbus_in.ipb_addr(ctrl_addr_width - 1 downto 0))) when ctrl_addr_width > 0 else 0;
	stat_sel <= to_integer(unsigned(ipbus_in.ipb_addr(stat_addr_width - 1 downto 0))) when stat_addr_width > 0 else 0;

	process(clk)
	begin
		if rising_edge(clk) then
			if reset='1' then
				reg <= (others=>(others=>'0'));
			elsif ipbus_in.ipb_strobe='1' and ipbus_in.ipb_write='1' then
				reg(ctrl_sel) <= ipbus_in.ipb_wdata;
			end if;

			if ipbus_in.ipb_addr(addr_width_max) = '0' then
				ipbus_out.ipb_rdata <= reg(ctrl_sel);
			else
				ipbus_out.ipb_rdata <= d(stat_sel); 
			end if;
			
			ack <= ipbus_in.ipb_strobe and not ack;

		end if;
	end process;
	
	ipbus_out.ipb_ack <= ack;
	ipbus_out.ipb_err <= '0';

	q <= reg;
	
end rtl;