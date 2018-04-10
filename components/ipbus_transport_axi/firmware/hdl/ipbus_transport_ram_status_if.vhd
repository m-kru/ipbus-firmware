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


-- Tom Williams, June 2018


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity ipbus_transport_ram_status_if is
  generic (
  	NUM_PAGES : natural;
    PAGE_SIZE : natural
  );
  port (
  	clk : in std_logic;

    rx_page_idx : in std_logic_vector(1 downto 0);
    tx_page_count : in std_logic_vector(31 downto 0);

    addr : in std_logic_vector(0 downto 0);
  	data : out std_logic_vector(63 downto 0)
  );
end entity ipbus_transport_ram_status_if;


architecture rtl of ipbus_transport_ram_status_if is

  constant C_NUM_PAGES : std_logic_vector(31 downto 0) := std_logic_vector(to_unsigned(NUM_PAGES, 32));
  constant C_PAGE_SIZE : std_logic_vector(31 downto 0) := std_logic_vector(to_unsigned(PAGE_SIZE, 32));

  signal rx_page_idx_i : std_logic_vector(31 downto 0);

begin

  rx_page_idx_i(31 downto 2) <= (Others => '0');
  rx_page_idx_i(1 downto 0) <= rx_page_idx;

  process (clk)
  begin
    if rising_edge(clk) then
      case addr is
        when "0" => 
          data <= C_PAGE_SIZE & C_NUM_PAGES;
        when "1" =>
          data <= tx_page_count & rx_page_idx_i;
        when others =>
          null;
      end case;
    end if;
  end process;

end rtl;