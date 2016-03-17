-------------------------------------------------------------------------------
-- Title      : Logic Analyzer Top Module
-- Project    : fpga_logic_analyzer
-------------------------------------------------------------------------------
-- File       : la_top.vhd
-- Created    : 2016-02-22
-- Last update: 2016-03-17
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description: This is the top instatiting modue of the logic analyzer. This
-- will define the generic I/O interfaces to the system. Ideally, all modules
-- below this will be portable to whatever your target hardware will be.
--
-- Stucture:
--         -----------
--    RX   |   UART  |
--    -----|         |
--         |         |
--    TX   |         |
--    -----|         |
--         |         |
--         |         |
--         ----------- 
-------------------------------------------------------------------------------
-- Copyright (c) 2016 Ashton Johnson, Paul Henny, Ian Swepston, David Hurt
-------------------------------------------------------------------------------
-- This program is free software; you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation; either version 2 of the License, or
-- (at your option) any later version.

-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.

-- You should have received a copy of the GNU General Public License along
-- with this program; if not, write to the Free Software Foundation, Inc.,
-- 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version      Author      Description
-- 2016-02-22      1.0      ashton      Created
-- 2016-03-09      1.1      ashton      Added sample_storage_block and
--                                      DATA_WIDTH and SAMPLE_DEPTH generics.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity la_top is

  generic (
    INPUT_CLK_RATE_HZ : positive range 10_000_000 to 200_000_000 := 100_000_000;
    DATA_WIDTH        : positive range 1 to 32                   := 8;
    SAMPLE_DEPTH      : positive range 1 to 2**18                := 2**8);
  port (
    --COMMON INTERFACES
    clk     : in  std_logic;            --clock
    rst     : in  std_logic                     := '0';  --reset, (async high/ sync low)
    --data input. defaulte to zeroes so you don't have to hook all 32 lines up.
    din     : in  std_logic_vector(31 downto 0) := (others => '0');
    --UART INTERFACES
    uart_rx : in  std_logic;            -- UART Receive Data
    uart_tx : out std_logic);           -- UART Transmit Data
begin


  --entity-wide checks
  assert IS_X(clk) = false report "clk is undefined" severity error;
  assert IS_X(din) = false report "din is undefined" severity error;
  assert IS_X(uart_rx) = false report "uart_rx is undefined" severity error;


end entity la_top;

architecture structural of la_top is


  signal armed           : std_logic;
  signal triggered       : std_logic;
  signal rst_cmd         : std_logic                       := '0';
  signal arm_cmd         : std_logic;
  signal sample_enable   : std_logic                       := '1';
  signal sample_cnt_rst  : std_logic;
  signal delay_cnt_4x    : std_logic_vector(16-1 downto 0) := (others => '0');
  signal read_cnt_4x     : std_logic_vector(16-1 downto 0) := (others => '1');
  signal par_trig_msk    : std_logic_vector(32-1 downto 0) := (others => '0');
  signal par_trig_val    : std_logic_vector(32-1 downto 0) := (others => '1');
  signal capture_rdy     : std_logic;
  --
  signal in_fifo_tdata   : std_logic_vector(31 downto 0);
  signal in_fifo_tvalid  : std_logic;
  signal in_fifo_tlast   : std_logic;
  signal in_fifo_tready  : std_logic;
  signal in_fifo_tfull   : std_logic;
  signal in_fifo_tempty  : std_logic;
  signal in_fifo_tflush  : std_logic;
  --
  signal out_fifo_tdata  : std_logic_vector(7 downto 0);
  signal out_fifo_tvalid : std_logic;
  signal out_fifo_tlast  : std_logic;
  signal out_fifo_tready : std_logic;

begin  -- ARCHITECTURE structural

  capture_control_block : entity work.capture_ctrl
    generic map (
      DATA_WIDTH => DATA_WIDTH)
    port map (
      clk            => clk,
      rst            => rst,
      --
      din            => din(7 downto 0),
      armed          => armed,
      triggered      => triggered,
      rst_cmd        => rst_cmd,
      arm_cmd        => arm_cmd,
      sample_enable  => sample_enable,
      sample_cnt_rst => sample_cnt_rst,
      delay_cnt_4x   => delay_cnt_4x,
      read_cnt_4x    => read_cnt_4x,
      par_trig_msk   => par_trig_msk,
      par_trig_val   => par_trig_val,
      capture_rdy    => capture_rdy,
      --
      fifo_tdata     => in_fifo_tdata,
      fifo_tvalid    => in_fifo_tvalid,
      fifo_tlast     => in_fifo_tlast,
      fifo_tready    => in_fifo_tready,
      fifo_tfull     => in_fifo_tfull,
      fifo_tempty    => in_fifo_tempty,
      fifo_aresetn   => in_fifo_tflush);

  sample_storage_block : entity work.storage
    generic map (
      FIFO_SIZE => SAMPLE_DEPTH)
    port map (
      clk             => clk,
      reset           => rst,
      --
      in_fifo_tdata   => in_fifo_tdata,
      in_fifo_tvalid  => in_fifo_tvalid,
      in_fifo_tlast   => in_fifo_tlast,
      in_fifo_tready  => in_fifo_tready,
      in_fifo_tfull   => in_fifo_tfull,
      in_fifo_tempty  => in_fifo_tempty,
      in_fifo_tflush  => in_fifo_tflush,
      --
      out_fifo_tdata  => out_fifo_tdata,
      out_fifo_tvalid => out_fifo_tvalid,
      out_fifo_tlast  => out_fifo_tlast,
      out_fifo_tready => '1');


  SUMP_UART_block : SUMPComms
    port map (
      clk               => clk,
      rst               => rst,
      rx                => uart_rx,
      tx                => uart_tx,
      tx_command        => tx_command,
      ready_for_command => ready_for_command,
      command_ready     => command_ready,
      data_ready        => data_ready,
      data_sent         => data_sent,
      command           => command);

  Message_processing_block : msg_prog
    port map (
      clk               => clk,
      rst               => rst,
      --
      command_valid     => command_ready,
      command           => command,
      data              => command_data,
      --
      ready_for_command => ready_for_command,
      comand_ready      => command_ready,
      --outputs
      arm_cmd           => arm_cmd,
      rst_cmd           => rst_cmd,
      sample_enable     => sample_enable,
      sample_cnt_rst    => sample_cnt_rst,
      delay_cnt_4x      => delay_cnt_4x,
      read_cnt_4x       => read_cnt_4x,
      par_trig_msk      => par_trig_msk,
      par_trig_val      => par_trig_val,
      capture_rdy       => capture_rdy,
      )

end architecture structural;

