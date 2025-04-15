`timescale 1ns / 1ps
module debug_module (
    input logic clk,
    input logic debug_enable,

    // FSM
    input logic [2:0] fsm_state,
    input logic       spi_error,

    // SPI
    input logic       spi_byte_valid,
    input logic       spi_byte_ready,
    input logic [7:0] spi_rx_byte,
    input logic [7:0] spi_tx_byte,

    // Image buffer
    input logic       buffer_full,
    input logic       buffer_empty,
    input logic [9:0] write_addr,

    // BNN
    input logic       bnn_result_ready,
    input logic [3:0] bnn_result_out
);

  always_ff @(posedge clk) begin
    if (debug_enable) begin
      $display(
          "[DEBUG] FSM state: %0d | SPI byte_valid: %0b SPI byte_ready: %0b rx: %02x tx: %02x | buf_full: %0b empty: %0b addr: %0d | result_ready: %0b result: %02x",
          fsm_state, spi_byte_valid, spi_rx_byte, spi_byte_ready, spi_tx_byte, buffer_full,
          buffer_empty, write_addr, bnn_result_ready, bnn_result_out);
    end
  end

endmodule
