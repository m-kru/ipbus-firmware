---------------------------------------------------------------------------------
--
--   Copyright 2017 - Rutherford Appleton Laboratory and University of Bristol
--
--   Licensed under the Apache License, Version 2.0 (the "License");
--   you may not use this file except in compliance with the License.
--   You may obtain a copy of the License at
--
--       http://www.apache.org/licenses/LICENSE-2.0
--
--   Unless required by applicable law or agreed to in writing, software
--   distributed under the License is distributed on an "AS IS" BASIS,
--   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
--   See the License for the specific language governing permissions and
--   limitations under the License.
--
--                                     - - -
--
--   Additional information about ipbus-firmare and the list of ipbus-firmware
--   contacts are available at
--
--       https://ipbus.web.cern.ch/ipbus
--
---------------------------------------------------------------------------------


-- ipbus_transactor_axi_if
--
-- Bridges AXI interface for IPbus 'pages' to the IPbus transactor interface
--
-- Tom Williams, April 2018


library ieee;
use ieee.std_logic_1164.all;

use work.ipbus_trans_decl.all;
use work.ipbus_axi_decl.all;


entity ipbus_transport_axi_if is
    -- TODO: Add generics ...
--	generic(
		-- TODO: AXI data width 
		-- TODO: Number of packets in flight
		-- TODO: Size of RX/TX buffers
--	);
	port(
		ipb_clk : in std_logic;
		rst_ipb : in std_logic;

		axi_in  : in axi4mm_ms(araddr(12 downto 0), awaddr(12 downto 0), wdata(63 downto 0));
		axi_out : out axi4mm_sm(rdata(63 downto 0));

		-- descriptor status
		h2c0_dsc_done: in std_logic;

		-- IPbus (from / to slaves)
		ipb_trans_rx : out ipbus_trans_in;
		ipb_trans_tx : in ipbus_trans_out
	);

end ipbus_transport_axi_if;

architecture rtl of ipbus_transport_axi_if is

	component buffer_trans_if
		port (
			user_clk : in std_logic;
			ipb_clk : in std_logic;
			sys_rst_n : in std_logic;

			h2c0_dsc_done : in std_logic;

			ram_wr_addr : in std_logic_vector(10 downto 0);
			ram_wr_data : in std_logic_vector(63 downto 0);
			ram_wr_en : in std_logic;
			ram_wr_we : in std_logic;

			ram_rd_en : in std_logic;
			ram_rd_addr : in std_logic_vector(10 downto 0);
			ram_rd_data : out std_logic_vector(63 downto 0);

			trans_in_pkt_rdy : out std_logic;
			trans_in_rdata : out std_logic_vector(31 downto 0);
			trans_in_busy : out std_logic;

			trans_out_raddr : in std_logic_vector(11 downto 0);
			trans_out_pkt_done : in std_logic;
			trans_out_we : in std_logic;
			trans_out_waddr : in std_logic_vector(11 downto 0);
			trans_out_wdata : in std_logic_vector(31 downto 0);

			ipb_rst : out std_logic
		);
	end component;

	COMPONENT axi_bram_ctrl_0 IS
		PORT (
			s_axi_aclk : IN STD_LOGIC;
			s_axi_aresetn : IN STD_LOGIC;
			s_axi_awid : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
			s_axi_awaddr : IN STD_LOGIC_VECTOR(12 DOWNTO 0);
			s_axi_awlen : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
			s_axi_awsize : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
			s_axi_awburst : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
			s_axi_awlock : IN STD_LOGIC;
			s_axi_awcache : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
			s_axi_awprot : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
			s_axi_awvalid : IN STD_LOGIC;
			s_axi_awready : OUT STD_LOGIC;
			s_axi_wdata : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
			s_axi_wstrb : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
			s_axi_wlast : IN STD_LOGIC;
			s_axi_wvalid : IN STD_LOGIC;
			s_axi_wready : OUT STD_LOGIC;
			s_axi_bid : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
			s_axi_bresp : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
			s_axi_bvalid : OUT STD_LOGIC;
			s_axi_bready : IN STD_LOGIC;
			s_axi_arid : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
			s_axi_araddr : IN STD_LOGIC_VECTOR(12 DOWNTO 0);
			s_axi_arlen : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
			s_axi_arsize : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
			s_axi_arburst : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
			s_axi_arlock : IN STD_LOGIC;
			s_axi_arcache : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
			s_axi_arprot : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
			s_axi_arvalid : IN STD_LOGIC;
			s_axi_arready : OUT STD_LOGIC;
			s_axi_rid : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
			s_axi_rdata : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
			s_axi_rresp : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
			s_axi_rlast : OUT STD_LOGIC;
			s_axi_rvalid : OUT STD_LOGIC;
			s_axi_rready : IN STD_LOGIC;
			bram_rst_a : OUT STD_LOGIC;
			bram_clk_a : OUT STD_LOGIC;
			bram_en_a : OUT STD_LOGIC;
			bram_we_a : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
			bram_addr_a : OUT STD_LOGIC_VECTOR(12 DOWNTO 0);
			bram_wrdata_a : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
			bram_rddata_a : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
			bram_rst_b : OUT STD_LOGIC;
			bram_clk_b : OUT STD_LOGIC;
			bram_en_b : OUT STD_LOGIC;
			bram_we_b : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
			bram_addr_b : OUT STD_LOGIC_VECTOR(12 DOWNTO 0);
			bram_wrdata_b : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
			bram_rddata_b : IN STD_LOGIC_VECTOR(63 DOWNTO 0)
		);
	END COMPONENT;

	signal bram_addr_a, bram_addr_b : std_logic_vector(12 downto 0);
	signal ram_wr_en, ram_we, ram_rd_en : std_logic;
	signal ram_wr_we : std_logic_vector(7 downto 0);
	signal ram_wr_addr, ram_rd_addr : std_logic_vector(10 downto 0);
	signal ram_wr_data, ram_rd_data : std_logic_vector(63 downto 0);


begin

	axi_bram_ctrl: axi_bram_ctrl_0
		port map (
			s_axi_aclk       => axi_in.aclk,

			s_axi_aresetn    => axi_in.aresetn,
			s_axi_awid       => axi_in.awid,
			s_axi_awaddr     => axi_in.awaddr,
			s_axi_awlen      => axi_in.awlen,
			s_axi_awsize     => axi_in.awsize,
			s_axi_awburst    => axi_in.awburst,

			s_axi_awlock     => axi_in.awlock,
			s_axi_awcache    => axi_in.awcache,
			s_axi_awprot     => axi_in.awprot,

			s_axi_awvalid    => axi_in.awvalid,
			s_axi_awready    => axi_out.awready,
			s_axi_wdata      => axi_in.wdata,
			s_axi_wstrb      => axi_in.wstrb,
			s_axi_wlast      => axi_in.wlast,
			s_axi_wvalid     => axi_in.wvalid,
			s_axi_wready     => axi_out.wready,
			s_axi_bid        => axi_out.bid,
			s_axi_bresp      => axi_out.bresp,
			s_axi_bvalid     => axi_out.bvalid,
			s_axi_bready     => axi_in.bready,
			s_axi_arid       => axi_in.arid,
			s_axi_araddr     => axi_in.araddr,
			s_axi_arlen      => axi_in.arlen,
			s_axi_arsize     => axi_in.arsize,
			s_axi_arburst    => axi_in.arburst,

			s_axi_arlock     => axi_in.arlock,
			s_axi_arcache    => axi_in.arcache,
			s_axi_arprot     => axi_in.arprot,

			s_axi_arvalid    => axi_in.arvalid,
			s_axi_arready    => axi_out.arready,
			s_axi_rid        => axi_out.rid,
			s_axi_rdata      => axi_out.rdata,
			s_axi_rresp      => axi_out.rresp,
			s_axi_rlast      => axi_out.rlast,
			s_axi_rvalid     => axi_out.rvalid,
			s_axi_rready     => axi_in.rready,

			bram_rst_a       => open,
			bram_clk_a       => open,
			bram_en_a        => ram_wr_en,
			bram_we_a        => ram_wr_we,
			bram_addr_a      => bram_addr_a,
			bram_wrdata_a    => ram_wr_data,
			bram_rddata_a    => X"0000000000000000",

			bram_rst_b       => open,
			bram_clk_b       => open,
			bram_en_b        => ram_rd_en,
			bram_we_b        => open,
			bram_addr_b      => bram_addr_b,
			bram_wrdata_b    => open,
			bram_rddata_b    => ram_rd_data
		);

	ram_wr_addr <= '0' & bram_addr_a (12 downto 3);
	ram_rd_addr <= '0' & bram_addr_b (12 downto 3);

    ram_we <= ram_wr_en and ram_wr_we(0);
	ram_to_trans : entity work.ipbus_transport_ram_if
		generic map (
			BUFWIDTH => 2,
			ADDRWIDTH => 8
		)
		port map (
			ram_clk => axi_in.aclk,
			--rst_pcieclk => not axi_in.aresetn,
		  	ipb_clk => ipb_clk,
		  	rst_ipb => rst_ipb,
		  	rx_addr => bram_addr_a (11 downto 3),
		  	rx_data => ram_wr_data,
		  	rx_we => ram_we,

		  	tx_addr => bram_addr_b (12 downto 3),
		  	tx_data => ram_rd_data,

		  	trans_in => ipb_trans_rx,
		  	trans_out => ipb_trans_tx
		);

	--ram_to_trans_converter: buffer_trans_if
	--	port map (
	--		user_clk => axi_in.aclk,
	--		ipb_clk => ipb_clk,
	--		sys_rst_n => axi_in.aresetn,

	--		h2c0_dsc_done => h2c0_dsc_done,

	--		ram_wr_addr => ram_wr_addr,
	--		ram_wr_data => ram_wr_data,
	--		ram_wr_en => ram_wr_en,
	--		ram_wr_we => ram_wr_we(0),

	--		ram_rd_en => ram_rd_en,
	--		ram_rd_addr => ram_rd_addr,
	--		ram_rd_data => ram_rd_data,

	--		trans_in_pkt_rdy => ipb_trans_rx.pkt_rdy,
	--		trans_in_rdata => ipb_trans_rx.rdata,
	--		trans_in_busy => ipb_trans_rx.busy,

	--		trans_out_raddr => ipb_trans_tx.raddr,
	--		trans_out_pkt_done => ipb_trans_tx.pkt_done,
	--		trans_out_we => ipb_trans_tx.we,
	--		trans_out_waddr => ipb_trans_tx.waddr,
	--		trans_out_wdata => ipb_trans_tx.wdata,

	--		ipb_rst => open
	--	);



end rtl;