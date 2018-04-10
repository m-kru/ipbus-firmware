-- k800_infra: Clocks & control I/O module for HTG K800 (KU115 framework firmware)
--
-- Raghunandan Shukla (TIFR), Kristian Harder (RAL), Tom Williams (RAL)
-- based on code from Dave Newbold

library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;

use work.ipbus.all;
use work.ipbus_trans_decl.all;
use work.pcie_decl.all;
use work.ipbus_axi_decl.all;

library UNISIM;
use UNISIM.VComponents.all;

entity k800_infra is
  port (
      -- PCIe clock and reset (active low)
      pcie_sys_clk_p : in std_logic;
      pcie_sys_clk_n : in std_logic;
      pcie_sys_rst_n : in std_logic;
      -- PCIe lanes
      pcie_rxp : in std_logic_vector(C_PCIE_LANES-1 downto 0);
      pcie_rxn : in std_logic_vector(C_PCIE_LANES-1 downto 0);
      pcie_txp : out std_logic_vector(C_PCIE_LANES-1 downto 0);
      pcie_txn : out std_logic_vector(C_PCIE_LANES-1 downto 0);
      -- IPbus clock and reset
      ipb_clk : out std_logic;
      ipb_rst : out std_logic;
      -- The signals of doom and lesser doom
      nuke: in std_logic;
      soft_rst: in std_logic;
      -- status LEDs
      leds: out std_logic_vector(1 downto 0);
      -- IPbus (from / to slaves)
      ipb_in  : in ipb_rbus;
      ipb_out : out ipb_wbus
  );
end k800_infra;


architecture rtl of k800_infra is

  signal clk_ipb, clk_ipb_i : std_logic;
  signal locked, clk_locked, axi_locked, rst125, rst_ipb, rst_ipb_ctrl, rst_axi, onehz : std_logic;

  signal pcie_sys_rst_n_c : std_logic;

  signal axi_ms: axi4mm_ms(araddr(12 downto 0), awaddr(12 downto 0), wdata(63 downto 0));
  signal axi_sm: axi4mm_sm(rdata(63 downto 0));
  signal h2c0_dsc_done : std_logic;

  signal ipb_req : std_logic;
  signal trans_in : ipbus_trans_in;
  signal trans_out : ipbus_trans_out;

  signal ipb_clk_startup_count : std_logic_vector(3 downto 0) := (Others => '0');
  signal rst_ipb_i : std_logic;

begin

  sys_rst_n_ibuf: IBUF
    port map (
      O => pcie_sys_rst_n_c,
      I => pcie_sys_rst_n
    );



  --  DCM clock generation for internal bus, ethernet
  -- TODO : Replace use of AXI clock here with external oscillator
  clocks: entity work.clocks_us_serdes
    port map(
      clki_fr => axi_ms.aclk,
      clki_125 => axi_ms.aclk,
      clko_ipb => clk_ipb_i,
      eth_locked => axi_locked,
      locked => clk_locked,
      nuke => nuke,
      soft_rst => soft_rst,
      rsto_125 => rst125,
      rsto_ipb => rst_ipb,
      rsto_eth => rst_axi,
      rsto_ipb_ctrl => rst_ipb_ctrl,
      onehz => onehz
    );

  clk_ipb <= clk_ipb_i;
  ipb_clk <= clk_ipb_i;
  ipb_rst <= rst_ipb;

  locked <= clk_locked and axi_locked;

  -- TODO: Add equivalent of 'stretched' "pkt" signal from ku105 design
  leds <= '0' & (locked and onehz);


  dma: entity work.pcie_xdma_axi_if
    port map (
      pci_sys_clk_p => pcie_sys_clk_p,
      pci_sys_clk_n => pcie_sys_clk_n,
      pci_exp_txp => pcie_txp,
      pci_exp_txn => pcie_txn,
      pci_exp_rxp => pcie_rxp,
      pci_exp_rxn => pcie_rxn,
      pci_sys_rst_n_c => pcie_sys_rst_n_c,

      axi_ms => axi_ms,
      axi_sm => axi_sm,

      h2c0_dsc_done => h2c0_dsc_done,
      pcie_int_event0 => trans_out.pkt_done
    );


  process (clk_ipb)
  begin
    if rising_edge(clk_ipb) then
      if (ipb_clk_startup_count /= "1111") then
        ipb_clk_startup_count <= std_logic_vector(unsigned(ipb_clk_startup_count) + 1);
      end if;
    end if;
  end process;

  rst_ipb_i <= rst_ipb when (ipb_clk_startup_count = "1111") else '1';

  ipbus_transport_axi: entity work.ipbus_transport_axi_if
    port map (
      ipb_clk => clk_ipb,
      rst_ipb => rst_ipb_i,
      axi_in => axi_ms,
      axi_out => axi_sm,

      h2c0_dsc_done => h2c0_dsc_done,

      ipb_trans_rx => trans_in,
      ipb_trans_tx => trans_out
    );


  ipbus_transactor: entity work.transactor
    port map (
      clk => clk_ipb,
      rst => rst_ipb_i,
      ipb_out => ipb_out,
      ipb_in => ipb_in,
      ipb_req => ipb_req, 
      ipb_grant => '1',
      trans_in => trans_in,
      trans_out => trans_out,
      cfg_vector_in => (Others => '0'),
      cfg_vector_out => open
    );

end rtl;
