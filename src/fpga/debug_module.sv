`ifndef SYNTHESIS

`timescale 1ns / 1ps
module debug_module (
    input logic clk,
    input logic rst_n,        // <<< added rst_n input
    input logic debug_enable,

    // FSM
    input logic [2:0] fsm_state,

    // SPI
    input logic       spi_byte_valid,
    input logic [7:0] spi_rx_byte,

    // Image buffer
    input logic         buffer_full,
    input logic         buffer_empty,
    input logic [  9:0] write_addr,
    input logic         buffer_write_enable,
    input logic [  7:0] buffer_data_in,
    input logic [903:0] img_in,

    // BNN
    input logic       bnn_result_ready,
    input logic [3:0] bnn_result_out

    // Top Level

);

  // Registers to track previous values for change detection
  logic [2:0] prev_fsm_state;
  logic [9:0] prev_write_addr;
  logic prev_buffer_full, prev_buffer_empty;
  logic        prev_spi_byte_valid;  // Previous state tracking

  logic [31:0] cycle_cnt;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) cycle_cnt <= 32'd0;
    else cycle_cnt <= cycle_cnt + 1;
  end

  // Declare variables outside procedural block
  logic any_row_non_zero;

  always_ff @(posedge clk) begin
    if (debug_enable) begin
      // Print FSM state only if it changes
      if (fsm_state != prev_fsm_state) begin
        $display("[DEBUG %0d] FSM state changed: %s -> %s", cycle_cnt, prev_fsm_state, fsm_state);
        prev_fsm_state <= fsm_state;
      end

      // Print SPI byte valid only if it changes
      if (spi_byte_valid != prev_spi_byte_valid) begin
        $display("[DEBUG %0d] SPI spi_byte_valid changed: %b -> %b", cycle_cnt,
                 prev_spi_byte_valid, spi_byte_valid);
        prev_spi_byte_valid <= spi_byte_valid;
      end
      // Print SPI rx byte if valid goes high
      if (spi_byte_valid && !prev_spi_byte_valid) begin
        $display("[DEBUG %0d] SPI spi_rx_byte received: 0x%02X", cycle_cnt, spi_rx_byte);
      end

      // Print buffer status only if it changes
      if (buffer_full != prev_buffer_full || buffer_empty != prev_buffer_empty) begin
        $display("[DEBUG %0d] Buffer status changed: full %b->%b, empty %b->%b", cycle_cnt,
                 prev_buffer_full, buffer_full, prev_buffer_empty, buffer_empty);
        prev_buffer_full  <= buffer_full;
        prev_buffer_empty <= buffer_empty;
      end

      // Print write address only if it changes
      if (write_addr != prev_write_addr) begin
        $display("[DEBUG %0d] Buffer Write Addr changed: %0d -> %0d", cycle_cnt, prev_write_addr,
                 write_addr);
        prev_write_addr <= write_addr;
      end

      // Print SPI and BNN debug information
      // $display("[DEBUG Module]:  On Cycle %0d, SPI byte_valid: %0b, rx: %02x", cycle_cnt,
      //          spi_byte_valid, spi_rx_byte);
      // $display("[DEBUG Module]:  On Cycle %0d, BNN result_ready: %0b, result: %02x", cycle_cnt,
      //          bnn_result_ready, bnn_result_out);
      any_row_non_zero = 0;  // Track if any row is non-zero
      $write("[DEBUG Module]:  On Cycle %0d, Image data (binary):\n", cycle_cnt);
      // Print full image buffer, row by row
      $display("[DEBUG Module]:  On Cycle %0d, Image data (binary):", cycle_cnt);
      for (int row = 0; row < 30; row++) begin
        for (int col = 0; col < 30; col++) begin
          $write("%b", img_in[row*30+col]);
        end
        $write("\n");
      end
      if (!any_row_non_zero) begin
        $write("[DEBUG Module]: All image data rows are zero.\n");
      end
    end
  end

endmodule

`endif
