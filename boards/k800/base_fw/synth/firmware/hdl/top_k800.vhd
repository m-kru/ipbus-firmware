-- Top-level design for KU115 framework firmware
--
-- Raghunandan Shukla (TIFR), Kristian Harder (RAL)
-- based on code from Dave Newbold

library IEEE;
use IEEE.std_logic_1164.all;

use work.ipbus.all;
use work.pcie_decl.all;

library UNISIM;
use UNISIM.VComponents.all;

entity top is
  port(
        -- PCIe clock and reset
      pcie_sys_clk_p : in std_logic;
      pcie_sys_clk_n : in std_logic;
      pcie_sys_rst   : in std_logic;  -- active high reset derived from the
                                      -- active low reset from the pcie edge connector
      -- PCIe lanes
      pcie_rxp       : in std_logic_vector(C_PCIE_LANES-1 downto 0);
      pcie_rxn       : in std_logic_vector(C_PCIE_LANES-1 downto 0);
      pcie_txp       : out std_logic_vector(C_PCIE_LANES-1 downto 0);
      pcie_txn       : out std_logic_vector(C_PCIE_LANES-1 downto 0);

      -- status LEDs
      leds: out std_logic_vector(3 downto 0)
  );

end top;

architecture rtl of top is

  signal ipb_clk, ipb_rst, nuke, soft_rst, userled: std_logic;
  signal pcie_sys_rst_n : std_logic;
  
  signal ipb_out: ipb_wbus;
  signal ipb_in: ipb_rbus;
  

begin

-- Infrastructure

  pcie_sys_rst_n <= not pcie_sys_rst;
  
  k800_infra: entity work.k800_infra
    port map(
      pcie_sys_clk_p => pcie_sys_clk_p,
      pcie_sys_clk_n => pcie_sys_clk_n,
      pcie_sys_rst_n => pcie_sys_rst_n,
      pcie_rxp       => pcie_rxp,
      pcie_rxn       => pcie_rxn,
      pcie_txp       => pcie_txp,
      pcie_txn       => pcie_txn,
      ipb_clk        => ipb_clk,
      ipb_rst        => ipb_rst,
      nuke           => nuke,
      soft_rst       => soft_rst,
      leds           => leds(1 downto 0),
      ipb_in         => ipb_in,
      ipb_out        => ipb_out
      );
      
  leds(3 downto 2) <= '0' & userled;

-- ipbus slaves live in the entity below, and can expose top-level ports.
-- The ipbus fabric is instantiated within.

  slaves: entity work.ipbus_example
    port map(
      ipb_clk => ipb_clk,
      ipb_rst => ipb_rst,
      ipb_in => ipb_out,
      ipb_out => ipb_in,
      nuke => nuke,
      soft_rst => soft_rst,
      userled => userled
      );


end rtl;
