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


-- ...
-- ...
-- Tom Williams, June 2018

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.ipbus_trans_decl.all;


entity ipbus_transport_ram_if is
  generic (
  -- Number of address bits to select RX or TX buffer
  -- Number of RX and TX buffers is 2 ** INTERNALWIDTH
  BUFWIDTH: natural := 2;

  -- Number of address bits within each buffer
  -- Size of each buffer is 2**ADDRWIDTH
  ADDRWIDTH: natural := 9
  );
  port (
  	ram_clk: in std_logic;
  	ipb_clk: in std_logic;
  	rst_ipb: in std_logic;

    rx_addr : in std_logic_vector(BUFWIDTH + ADDRWIDTH - 2 downto 0);
    rx_data : in std_logic_vector(63 downto 0);
    rx_we   : in std_logic;

    tx_addr : in std_logic_vector(BUFWIDTH + ADDRWIDTH - 1 downto 0);
    tx_data : out std_logic_vector(63 downto 0);
--    tx_we   : out std_logic; 

    trans_out : in ipbus_trans_out;
    trans_in  : out ipbus_trans_in
  );

end ipbus_transport_ram_if;



architecture rtl of ipbus_transport_ram_if is

  signal page_idx_ram : unsigned(BUFWIDTH - 1 downto 0) := (Others => '0');
  signal page_idx_transactor : unsigned(BUFWIDTH - 1 downto 0) := (Others => '0');

  signal page_idx_next_to_empty : unsigned(BUFWIDTH - 1 downto 0) := (Others => '0');
  signal page_count_ram : unsigned(31 downto 0);

  signal ram_page_filled_ramclk : std_logic_vector(2**BUFWIDTH - 1 downto 0) := (Others => '0');
  signal ram_page_filled_ipbclk, ram_page_filled_ipbclk_d : std_logic_vector(2**BUFWIDTH - 1 downto 0) := (Others => '0');
  signal ram_page_processed : std_logic_vector(2**BUFWIDTH - 1 downto 0) := (Others => '0');

  signal rx_we_i : std_logic;
  signal rx_addr_end_pkt : std_logic_vector(BUFWIDTH + ADDRWIDTH - 2 downto 0);
  signal rx_addr_end_pkt_i : std_logic_vector(BUFWIDTH + ADDRWIDTH - 1 downto 0);

  signal tx_data_i_ctrl, tx_data_i_stat : std_logic_vector(63 downto 0);
  signal tx_addr_ram_ctrl : std_logic_vector(BUFWIDTH + ADDRWIDTH - 1 downto 0);

  type state_type is (FSM_RESET, FSM_IDLE, FSM_TRANSFER_PACKET);
  signal state : state_type := FSM_RESET;
  signal next_state : state_type;

  signal rx_ram_addrb, tx_ram_addra : std_logic_vector(BUFWIDTH + ADDRWIDTH - 1 downto 0);

  signal pkt_done_cdc1, pkt_done_cdc2, pkt_done_ramclk, pkt_done_ramclk_d : std_logic;

  constant addr_zero : std_logic_vector(ADDRWIDTH - 2 downto 0) := (Others => '0');
  ----

  signal ram_page_filled_cdc1, ram_page_filled_cdc2 : std_logic_vector(2**BUFWIDTH - 1 downto 0) := (Others => '0');
  signal rst_cdc1, rst_cdc2, rst_ramclk : std_logic;


  attribute ASYNC_REG: string;

  attribute ASYNC_REG of rst_cdc1 : signal is "TRUE";
  attribute ASYNC_REG of rst_cdc2 : signal is "TRUE";
  --attribute ASYNC_REG of rst_ramclk : signal is "TRUE";
  attribute ASYNC_REG of pkt_done_cdc1 : signal is "TRUE";
  attribute ASYNC_REG of pkt_done_cdc2 : signal is "TRUE";
  --attribute ASYNC_REG of pkt_done_ramclk : signal is "TRUE";
  attribute ASYNC_REG of ram_page_filled_cdc1 : signal is "TRUE";
  attribute ASYNC_REG of ram_page_filled_cdc2 : signal is "TRUE";
  --attribute ASYNC_REG of ram_page_filled_ipbclk : signal is "TRUE";


begin

  ----------------
  --   RX RAM   --
  ----------------

  rx_we_i <= rx_we when ((rx_addr(BUFWIDTH + ADDRWIDTH - 2 downto ADDRWIDTH - 1) = std_logic_vector(page_idx_ram)) and ram_page_filled_ramclk(to_integer(page_idx_ram)) = '0') else '0';

  rx_ram_addrb <= std_logic_vector(page_idx_transactor) & trans_out.raddr(ADDRWIDTH - 1 downto 0);
  rx_ram : entity work.ipbus_transport_ram_rx_dpram
    generic map (
      ADDRWIDTH => ADDRWIDTH + BUFWIDTH
    )
    port map (
      clka => ram_clk,
      wea => rx_we_i,
      addra => rx_addr,
      dia => rx_data,

      clkb => ipb_clk,
      addrb => rx_ram_addrb,
      dob => trans_in.rdata
    );

  rx_increment_pkt_idx : process (ram_clk)
  begin
    if rising_edge(ram_clk) then
      if (rst_ramclk = '1') then
        page_idx_ram <= (Others => '0');
      elsif ((rx_we_i = '1') and (rx_addr = rx_addr_end_pkt)) then
        page_idx_ram <= page_idx_ram + 1;
      end if;
    end if;
  end process;

  rx_addr_end_pkt_i <= std_logic_vector(page_idx_ram & resize(unsigned(rx_data(15 downto 0)) + 1, ADDRWIDTH));
  rx_extract_page_size : process (ram_clk)
  begin
    if rising_edge(ram_clk) then
      if (rst_ramclk = '1') then
        rx_addr_end_pkt <= (Others => '1');
      elsif (rx_addr = (std_logic_vector(page_idx_ram) & addr_zero)) and (rx_we = '1') then
        rx_addr_end_pkt <= rx_addr_end_pkt_i(BUFWIDTH + ADDRWIDTH - 1 downto 1);
      end if;
    end if;
  end process;

  update_filled_ram_pages : for i in 0 to 2**BUFWIDTH - 1 generate
    process (ram_clk)
    begin
      if rising_edge(ram_clk) then
        if (rst_ramclk = '1') then
          ram_page_filled_ramclk(i) <= '0';
        elsif (to_integer(page_idx_next_to_empty) = i) and (pkt_done_ramclk = '1' and pkt_done_ramclk_d = '0') then
          ram_page_filled_ramclk(i) <= '0';
        elsif (to_integer(page_idx_ram) = i) then
          if ((rx_we_i = '1') and (rx_addr = rx_addr_end_pkt)) then
            ram_page_filled_ramclk(i) <= '1';
          end if;
        end if;
      end if;
    end process;
  end generate update_filled_ram_pages;

  process (ram_clk)
  begin
    if rising_edge(ram_clk) then
      if (rst_ramclk = '1') then
        page_idx_next_to_empty <= (Others => '0');
        page_count_ram <= (Others => '0');
     elsif (pkt_done_ramclk = '1' and pkt_done_ramclk_d = '0') then
        page_idx_next_to_empty <= page_idx_next_to_empty + 1;
        page_count_ram <= page_count_ram + 1;
      end if;
    end if;
  end process;


  ----------------
  --   TX RAM   --
  ----------------

  tx_data <= tx_data_i_stat when (unsigned(tx_addr) < 2) else tx_data_i_ctrl;

  tx_addr_ram_ctrl <= std_logic_vector(unsigned(tx_addr) - 2);
  tx_ram_addra <= std_logic_vector(page_idx_transactor) & trans_out.waddr(ADDRWIDTH - 1 downto 0);
  tx_ram : entity work.ipbus_transport_ram_tx_dpram
    generic map (
      ADDRWIDTH => ADDRWIDTH + BUFWIDTH
    )
    port map (
      clka => ipb_clk,
      wea => trans_out.we,
      addra => tx_ram_addra,
      dia => trans_out.wdata,

      clkb => ram_clk,
      addrb => tx_addr_ram_ctrl(BUFWIDTH + ADDRWIDTH - 2 downto 0),
      dob => tx_data_i_ctrl
    );

  tx_status_if : entity work.ipbus_transport_ram_status_if
    generic map (
      NUM_PAGES => 2**BUFWIDTH,
      PAGE_SIZE => 2**ADDRWIDTH
    )
    port map (
      clk => ram_clk,
      rx_page_idx => std_logic_vector(page_idx_ram),
      tx_page_count => std_logic_vector(page_count_ram),
      addr => tx_addr(0 downto 0),
      data => tx_data_i_stat
    );


  -----------------------------------
  --   MAIN FINITE STATE MACHINE   --
  -----------------------------------

  process (ipb_clk)
  begin
    if rising_edge(ipb_clk) then
      if rst_ipb = '1' then
        state <= FSM_RESET;
      else
        state <= next_state;
      end if;
    end if;
  end process;

  -- Combinatorial process for next state
  process (state, page_idx_transactor, ram_page_filled_ipbclk, ram_page_processed, trans_out.pkt_done)
  begin
    case state is
      when FSM_RESET =>
        next_state <= FSM_IDLE;
      when FSM_IDLE =>
        if (ram_page_filled_ipbclk(to_integer(page_idx_transactor)) = '0') or (ram_page_processed(to_integer(page_idx_transactor)) = '1') then
          next_state <= FSM_IDLE;
        else
          next_state <= FSM_TRANSFER_PACKET;
        end if;
      when FSM_TRANSFER_PACKET =>
        if (trans_out.pkt_done = '0') then
          next_state <= FSM_TRANSFER_PACKET;
        else
          next_state <= FSM_IDLE;
        end if;
    end case;
  end process;

  process (ipb_clk)
  begin
    if rising_edge(ipb_clk) then
      if (next_state = FSM_TRANSFER_PACKET) then
        trans_in.pkt_rdy <= '1';
        trans_in.busy <= '0';
      else
        trans_in.pkt_rdy <= '0';
        trans_in.busy <= '1';
      end if;
    end if;
  end process;

  process (ipb_clk)
  begin
    if rising_edge(ipb_clk) then
      if rst_ipb = '1' then
        page_idx_transactor <= (Others => '0');
      elsif (state = FSM_TRANSFER_PACKET and next_state /= FSM_TRANSFER_PACKET) then
        page_idx_transactor <= page_idx_transactor + 1;
      end if;
    end if;
  end process;


  update_processed_ram_pages : for i in 0 to 2**BUFWIDTH - 1 generate
    process (ipb_clk)
    begin
      if rising_edge(ipb_clk) then
        if rst_ipb = '1' then
          ram_page_processed(i) <= '0';
        elsif ram_page_filled_ipbclk(i) = '1' and ram_page_filled_ipbclk_d(i) = '0' then
          ram_page_processed(i) <= '0';
        elsif (state = FSM_TRANSFER_PACKET and next_state /= FSM_TRANSFER_PACKET and to_integer(page_idx_transactor) = i) then
          ram_page_processed(i) <= '1';
        end if;
      end if;
    end process;
  end generate;


  --------------------------------
  --   CLOCK DOMAIN CROSSINGS   --
  --------------------------------

  process (ram_clk)
  begin
    if rising_edge(ram_clk) then
      -- IPbus reset (target domain)
      rst_cdc2 <= rst_cdc1;
      rst_ramclk <= rst_cdc2;

      -- Trasactor 'packet done' signal (target domain)
      pkt_done_cdc2 <= pkt_done_cdc1;
      pkt_done_ramclk <= pkt_done_cdc2;
      pkt_done_ramclk_d <= pkt_done_ramclk;

      -- RAM page filled flags (source domain)
      ram_page_filled_cdc1 <= ram_page_filled_ramclk;
    end if;
  end process;


  process (ipb_clk)
  begin
    if rising_edge(ipb_clk) then
      -- IPbus reset (start domain)
      rst_cdc1 <= rst_ipb;

      -- Transactor 'packet done' signal (start domain)
      pkt_done_cdc1 <= trans_out.pkt_done;

      -- RAM page filled flags (target domain)
      ram_page_filled_cdc2 <= ram_page_filled_cdc1;
      ram_page_filled_ipbclk <= ram_page_filled_cdc2;
      ram_page_filled_ipbclk_d <= ram_page_filled_ipbclk;
    end if;
  end process;

end rtl;