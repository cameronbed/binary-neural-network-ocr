// BNN Controller
// bnn_controller.sv
`timescale 1ns / 1ps
//`include "spi_peripheral.sv"
//`include "image_buffer.sv"
//`include "bnn_module.sv"
module bnn_controller (
    input logic clk,   // System clock
    input logic rst_n, // Active-low rst_n

    // SPI inputs
    input  logic SCLK,  // SPI clock
    input  logic COPI,  // Controller-out-Peripheral-In
    input  logic CS,    // Chip Select
    // SPI Outputs
    output logic CIPO,  // Controller-in-Peripheral-Out

    // Debug outputs
    output logic [2:0] debug_state,         // Debug: current state
    output logic [7:0] debug_rx_byte,       // Debug: received byte
    output logic       debug_buffer_full,   // Debug: buffer full status
    output logic       debug_buffer_empty,  // Debug: buffer empty status
    output logic       debug_result_ready,  // Debug: result ready status

    // Additional debug outputs needed by test
    output logic [3:0] debug_bit_count,     // Debug: SPI bit counter
    output logic [9:0] debug_write_addr,    // Debug: Image buffer write address
    output logic [7:0] debug_result_out,    // Debug: BNN result value
    output logic       debug_write_enable,  // New debug output for write enable
    output logic       debug_byte_valid     // New debug output for byte_valid
);
  // DEBUG remains as an int
  parameter int DEBUG = 1;  // Debug flag: 0 = off, non-zero = on

  typedef enum logic [2:0] {
    IDLE,
    IMG_RX,
    INFERENCE,
    RESULT_TX,
    CLEAR
  } bnn_state_t;
  bnn_state_t state, next_state;
  // Add a new register to track previous state for debugging
  logic [2:0] prev_state;  // New debug tracking variable

  // SPI signals
  logic [7:0] rx_byte;  // Captured received byte
  logic byte_valid;  // Indicates that a byte has been received
  logic [7:0] tx_byte;  // Byte to be transmitted
  logic spi_error;  // Error indication

  // Add signals for image buffer status
  logic buffer_full;
  logic buffer_empty;
  logic result_ready;
  logic [7:0] result_out;  // Result from BNN module
  logic image_buffer_flat[0:783];  // Flattened image buffer for compatibility
  logic clear_buffer;  // Signal to clear the image buffer

  // Add row and col as module-level signals instead of static local variables
  logic [4:0] row;
  logic [4:0] col;

  // Extra debug signals
  logic [7:0] byte_count;  // Count received bytes

  // Debug wire declarations
  logic [1:0] spi_debug_state;
  logic [3:0] spi_debug_bit_count;
  logic [7:0] spi_debug_rx_byte;
  logic [9:0] buf_debug_write_addr;
  logic buf_debug_buffer_full;
  logic buf_debug_buffer_empty;
  logic buf_debug_write_enable;  // New debug signal for write enable
  logic [7:0] bnn_debug_data_in;
  logic bnn_debug_write_enable;
  logic bnn_debug_result_ready;
  logic [7:0] bnn_debug_result_out;

  // New internal signals for image buffer connection
  logic image_write_enable;
  logic [7:0] image_write_data;

  // Internal signals to track previous values for debug printing
  logic prev_image_write_enable;
  logic prev_byte_valid;

  spi_peripheral spi_peripheral_inst (
      .clk            (clk),
      .rst_n          (rst_n),
      .SCLK           (SCLK),
      .COPI           (COPI),
      .CS             (CS),
      .CIPO           (CIPO),
      .tx_byte        (tx_byte),              // Byte to be transmitted
      .rx_byte        (rx_byte),              // PI data output
      .byte_valid     (byte_valid),           // valid indicator
      .spi_error      (spi_error),            // Error indication
      // Add debug connections
      .debug_state    (spi_debug_state),
      .debug_bit_count(spi_debug_bit_count),
      .debug_rx_byte  (spi_debug_rx_byte)
  );

  // Use our new signals when instantiating image_buffer
  image_buffer image_buffer_inst (
      .clk               (clk),
      .rst_n             (rst_n),
      .clear_buffer      (clear_buffer),
      .data_in           (image_write_data),        // changed from rx_byte to image_write_data
      .write_enable      (image_write_enable),      // changed signal name
      .data_out          (image_buffer_flat),       // Connect flattened buffer
      .buffer_full       (buffer_full),
      .buffer_empty      (buffer_empty),
      .debug_write_addr  (buf_debug_write_addr),
      .debug_buffer_full (buf_debug_buffer_full),
      .debug_buffer_empty(buf_debug_buffer_empty),
      .debug_write_enable(buf_debug_write_enable)
  );

  bnn_module bnn_module_inst (
      .clk(clk),
      .rst_n(rst_n),
      .data_in(rx_byte),
      .write_enable(byte_valid),
      .result_ready(result_ready),
      .result_out(result_out),
      .img_in(image_buffer_flat),  // Use unpacked array
      .debug_data_in(bnn_debug_data_in),
      .debug_write_enable(bnn_debug_write_enable),
      .debug_result_ready(bnn_debug_result_ready),
      .debug_result_out(bnn_debug_result_out)
  );

  // Connect additional debug signals to top level
  assign debug_bit_count = spi_debug_bit_count;
  assign debug_write_addr = buf_debug_write_addr;
  assign debug_result_out = result_out;  // Use the actual result output
  assign debug_write_enable = image_write_enable;  // expose internal image_write_enable
  assign debug_byte_valid = byte_valid;  // Connect byte_valid to top-level output

  // State machine implementation
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      row <= 5'd0;
      col <= 5'd0;
      clear_buffer <= 1'b0;
      tx_byte <= 8'h00;
      byte_count <= 8'd0;

      // rst_n debug signals
      debug_state <= 3'b000;
      debug_rx_byte <= 8'd0;
      debug_buffer_full <= 1'b0;
      debug_buffer_empty <= 1'b0;
      debug_result_ready <= 1'b0;

      // rst_n previous values for debug tracking
      prev_image_write_enable <= 1'b0;
      prev_byte_valid <= 1'b0;

      prev_state <= IDLE;  // Initialize prev_state
      if (DEBUG != 0) $display("[BNN_CTRL] Reset: state set to IDLE at time=%0t", $time);
    end else begin
      // Update debug signals immediately
      debug_state <= state;
      debug_rx_byte <= rx_byte;
      debug_buffer_full <= buffer_full;
      debug_buffer_empty <= buffer_empty;
      debug_result_ready <= result_ready;

      // State machine logic
      case (state)
        IDLE: begin
          clear_buffer <= 1'b0;  // Make sure clear is inactive
          row <= 5'd0;
          col <= 5'd0;
          byte_count <= 8'd0;

          if (!CS) begin  // CS is active low
            state <= IMG_RX;
            if (DEBUG != 0) $display("[BNN_CTRL] Transition IDLE -> IMG_RX at time=%0t", $time);
          end
        end

        IMG_RX: begin
          if (DEBUG != 0 && state != IMG_RX)
            $display("[BNN_CTRL] In IMG_RX state at time=%0t", $time);

          // Handle received bytes
          if (byte_valid) begin
            byte_count <= byte_count + 8'd1;
            $display("[BNN_CTRL] Received byte #%0d: %h at time=%0t", byte_count, rx_byte, $time);
            // New: capture byte for image buffer
            image_write_data <= rx_byte;
            if (DEBUG != 0)
              $display(
                  "[BNN_CTRL] Asserting image_buffer write enable with data: %h at time=%0t",
                  rx_byte,
                  $time
              );

            // Update row/col indices for display only
            if (col == 5'd27) begin
              col <= 5'd0;
              if (row == 5'd27) begin
                row <= 5'd0;
              end else begin
                row <= row + 5'd1;
              end
            end else begin
              col <= col + 5'd1;
            end
          end

          // Check if buffer is full and move to INFERENCE
          if (buffer_full) begin
            state <= INFERENCE;
            if (DEBUG != 0)
              $display(
                  "[BNN_CTRL] Transition IMG_RX -> INFERENCE (buffer full) at time=%0t", $time
              );
          end
        end

        INFERENCE: begin
          if (DEBUG != 0) $display("[BNN_CTRL] In INFERENCE state at time=%0t", $time);

          if (result_ready) begin
            state   <= RESULT_TX;
            tx_byte <= result_out;  // Prepare output byte
            if (DEBUG != 0)
              $display(
                  "[BNN_CTRL] Transition INFERENCE -> RESULT_TX (result ready) at time=%0t", $time
              );
          end
        end

        RESULT_TX: begin
          if (DEBUG != 0) $display("[BNN_CTRL] In RESULT_TX state at time=%0t", $time);

          // Continuously output the result
          tx_byte <= result_out;

          // Move to CLEAR when CS is deasserted
          if (CS) begin
            state <= CLEAR;
            clear_buffer <= 1'b1;  // Start buffer clearing
            if (DEBUG != 0)
              $display("[BNN_CTRL] Transition RESULT_TX -> CLEAR (CS inactive) at time=%0t", $time);
          end
        end

        CLEAR: begin
          if (DEBUG != 0) $display("[BNN_CTRL] In CLEAR state at time=%0t", $time);

          // Keep clearing until buffer is empty
          clear_buffer <= 1'b1;

          if (buffer_empty) begin
            clear_buffer <= 1'b0;
            state <= IDLE;
            if (DEBUG != 0)
              $display("[BNN_CTRL] Transition CLEAR -> IDLE (buffer empty) at time=%0t", $time);
          end
        end

        default: begin
          state <= IDLE;
          if (DEBUG != 0)
            $display("[BNN_CTRL] Default state reached, transitioning to IDLE at time=%0t", $time);
        end
      endcase

      if (prev_state != state) begin
        $display("[BNN_CTRL] State changed: %0d -> %0d at time=%0t", prev_state, state, $time);
      end
      prev_state <= state;

      // Update previous values for debug tracking
      prev_image_write_enable <= image_write_enable;
      prev_byte_valid <= byte_valid;
    end
  end

  // Updated image buffer control logic based on state
  always_comb begin
    image_write_enable = (state == IMG_RX) && byte_valid;  // Assert write_enable only during IMG_RX with valid byte

    // Print debug message only when values change
    if (DEBUG != 0 && (image_write_enable != prev_image_write_enable ||
                       byte_valid != prev_byte_valid)) begin
      $display("BNN_CONTROLLER: image_write_enable=%b, byte_valid=%b", image_write_enable,
               byte_valid);
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset previous values for debug tracking
      prev_image_write_enable <= 1'b0;
      prev_byte_valid <= 1'b0;
    end else begin
      // Update previous values for debug tracking
      prev_image_write_enable <= image_write_enable;
      prev_byte_valid <= byte_valid;
    end
  end

endmodule
