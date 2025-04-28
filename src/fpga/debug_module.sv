// `ifndef SYNTHESIS

`timescale 1ns / 1ps
module debug_module (
    input logic clk,
    input logic rst_n,
    input logic debug_enable,

    // FSM
    input logic [7:0] spi_rx_data,
    input logic spi_byte_valid,
    input logic byte_taken,
    input logic spi_rx_enable,
    input logic [3:0] status_code_reg,
    input logic clear_internal,
    input logic buffer_full,
    input logic buffer_empty,
    input logic [7:0] buffer_write_data,
    input logic [6:0] buffer_write_addr,

    // SPI
    input logic SCLK,
    input logic COPI,
    input logic spi_cs_n,

    // Image buffer
    input logic clear_buffer,
    input logic [7:0] data_in,
    input logic result_ready,
    input logic bnn_enable,

    // BNN
    input logic [903:0] img_in,
    input logic [  3:0] result_out,

    // Control signals
    input logic img_buffer_full,
    input logic bnn_clear,

    // Sync
    input logic src_clk,
    input logic src_pulse,
    input logic dst_clk,
    input logic dst_pulse,

    // Cycle counter
    output logic [31:0] main_cycle_cnt,
    output logic [31:0] sclk_cycle_cnt
);

  logic [3:0] remaining_bits;  // Declare outside the procedural block

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset logic
      main_cycle_cnt <= 32'd0;
      sclk_cycle_cnt <= 32'd0;
    end else if (debug_enable) begin
      // Main cycle counter
      main_cycle_cnt <= main_cycle_cnt + 1;

      // SPI clock cycle counter
      if (!spi_cs_n) begin
        sclk_cycle_cnt <= sclk_cycle_cnt + 1;
      end

      // Debug output
      $display("========== DEBUG MODULE OUTPUT ==========");

      // FSM Section
      $display("[FSM][%0d] SPI RX Data: %h, SPI Byte Valid: %b, SPI RX Enable: %b, Byte Taken: %b",
               main_cycle_cnt, spi_rx_data, spi_byte_valid, spi_rx_enable, byte_taken);
      $display("[FSM][%0d] Status Code Register: %h, Clear Internal: %b, BNN Enable: %b",
               main_cycle_cnt, status_code_reg, clear_internal, bnn_enable);

      // $display(
      //     "[FSM][%0d] Buffer Full: %b, Buffer Empty: %b, Buffer Write Data: %h, Buffer Write Address: %h",
      //     main_cycle_cnt, buffer_full, buffer_empty, buffer_write_data,
      //     buffer_write_addr);

      // $display("[FSM][%0d] Result Ready: %b, Result Out: %h", main_cycle_cnt, result_ready,
      //          result_out);

      // SPI Section
      $display("[SPI][%0d] SCLK: %b, COPI: %b, SPI CS_N: %b", sclk_cycle_cnt, SCLK, COPI, spi_cs_n);

      // Sync Section
      $display(
          "[SYNC][%0d] Source Clock: %b, Source Pulse: %b, Destination Clock: %b, Destination Pulse: %b",
          main_cycle_cnt, src_clk, src_pulse, dst_clk, dst_pulse);

      // Image Buffer Section
      $display("[IMAGE BUFFER][%0d] Clear Buffer: %b, Data In: %h", main_cycle_cnt, clear_buffer,
               data_in);

      if (|img_in) begin  // Check if any bit in img_in is set
        $display("[IMAGE BUFFER][%0d] Full Binary Array:", main_cycle_cnt);
        for (int i = 0; i < 904; i++) begin
          if (i % 30 == 0) begin
            // Start a new line every 30 bits for readability
            if (i > 0) $display("");  // Print a newline after each row
            $write("[%0d-%0d]: ", i, i + 29);
          end
          $write("%b", img_in[i]);
        end
        $display("");  // Final newline after printing all bits
      end else begin
        $display("[IMAGE BUFFER][%0d] Binary Array is empty.", main_cycle_cnt);
      end

      // // BNN Section
      $display("[BNN][%0d] Image Buffer Full: %b, BNN Clear: %b", main_cycle_cnt, img_buffer_full,
               bnn_clear);

      // BNN Inference Section
      $display("[BNN INFERENCE][%0d] Result Ready: %b, BNN Enable: %b", main_cycle_cnt,
               result_ready, bnn_enable);

      if (result_ready) begin
        $display("[BNN INFERENCE][%0d] Result Output: %h", main_cycle_cnt, result_out);
      end else begin
        $display("[BNN INFERENCE][%0d] Result Output: Not Ready", main_cycle_cnt);
      end

      // Cycle Counters
      $display("[CYCLE COUNTERS][%0d] Main Cycle Count: %d, SCLK Cycle Count: %d", main_cycle_cnt,
               main_cycle_cnt, sclk_cycle_cnt);

      $display("=========================================");
    end
  end

endmodule

// `endif
