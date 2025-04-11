// BNN Controller
// bnn_controller.sv
`timescale 1ns / 1ps
//`include "spi_peripheral.sv"
//`include "image_buffer.sv"
//`include "bnn_module.sv`
module bnn_controller (
    input logic clk,  // System clock
    input logic rst,  // Active-low reset

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
    output logic [3:0] debug_bit_count,   // Debug: SPI bit counter
    output logic [9:0] debug_write_addr,  // Debug: Image buffer write address
    output logic [7:0] debug_result_out   // Debug: BNN result value
);
  typedef enum logic [2:0] {
    IDLE,
    IMG_RX,
    INFERENCE,
    RESULT_TX,
    CLEAR
  } bnn_state_t;
  bnn_state_t state, next_state;

  // SPI signals
  logic [7:0] rx_byte;  // Captured received byte
  logic byte_valid;  // Indicates that a byte has been received
  logic [7:0] tx_byte;  // Byte to be transmitted

  // Add signals for image buffer status
  logic buffer_full;
  logic buffer_empty;
  logic result_ready;
  logic [7:0] result_out;  // Result from BNN module
  logic [7:0] image_buffer[0:27][0:27];  // Image buffer to store the received image
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
  logic [7:0] bnn_debug_data_in;
  logic bnn_debug_write_enable;
  logic bnn_debug_result_ready;
  logic [7:0] bnn_debug_result_out;

  spi_peripheral spi_peripheral_inst (
      .clk            (clk),
      .rst            (rst),
      .SCLK           (SCLK),
      .COPI           (COPI),
      .CS             (CS),
      .CIPO           (CIPO),
      .tx_byte        (tx_byte),              // Byte to be transmitted
      .rx_byte        (rx_byte),              // PI data output
      .byte_valid     (byte_valid),           // valid indicator
      // Add debug connections
      .debug_state    (spi_debug_state),
      .debug_bit_count(spi_debug_bit_count),
      .debug_rx_byte  (spi_debug_rx_byte)
  );

  // Connect image_buffer outputs (buffer_full, buffer_empty)
  image_buffer image_buffer_inst (
      .clk(clk),
      .reset(rst),
      .clear_buffer(clear_buffer),
      .data_in(rx_byte),
      .write_enable(byte_valid),
      .read_enable(1'b0),
      .data_out(image_buffer),
      .buffer_full(buffer_full),
      .buffer_empty(buffer_empty),
      .debug_write_addr(buf_debug_write_addr),
      .debug_buffer_full(buf_debug_buffer_full),
      .debug_buffer_empty(buf_debug_buffer_empty)
  );

  bnn_module bnn_module_inst (
      .clk(clk),
      .reset(rst),
      .data_in(rx_byte),
      .write_enable(byte_valid),
      .result_ready(result_ready),
      .result_out(result_out),
      .img_in(image_buffer),  // Connect to the image buffer
      .debug_data_in(bnn_debug_data_in),
      .debug_write_enable(bnn_debug_write_enable),
      .debug_result_ready(bnn_debug_result_ready),
      .debug_result_out(bnn_debug_result_out)
  );

  // Connect additional debug signals to top level
  assign debug_bit_count  = spi_debug_bit_count;
  assign debug_write_addr = buf_debug_write_addr;
  assign debug_result_out = result_out;  // Use the actual result output

  // State machine implementation
  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      state <= IDLE;
      row <= 5'd0;
      col <= 5'd0;
      clear_buffer <= 1'b0;
      tx_byte <= 8'h00;
      byte_count <= 8'd0;

      // Reset debug signals
      debug_state <= 3'b000;
      debug_rx_byte <= 8'd0;
      debug_buffer_full <= 1'b0;
      debug_buffer_empty <= 1'b0;
      debug_result_ready <= 1'b0;
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
            $display("CONTROLLER: Transition IDLE -> IMG_RX");
          end
        end

        IMG_RX: begin
          // Handle received bytes
          if (byte_valid) begin
            byte_count <= byte_count + 8'd1;
            $display("CONTROLLER: Received byte #%d: %h", byte_count, rx_byte);

            // Store the byte in the image buffer at current row/col
            // Note: image_buffer writing is handled in image_buffer module

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
            $display("CONTROLLER: Transition IMG_RX -> INFERENCE (buffer full)");
          end
        end

        INFERENCE: begin
          if (result_ready) begin
            state   <= RESULT_TX;
            tx_byte <= result_out;  // Prepare output byte
            $display("CONTROLLER: Transition INFERENCE -> RESULT_TX (result ready)");
          end
        end

        RESULT_TX: begin
          // Continuously output the result
          tx_byte <= result_out;

          // Move to CLEAR when CS is deasserted
          if (CS) begin
            state <= CLEAR;
            clear_buffer <= 1'b1;  // Start buffer clearing
            $display("CONTROLLER: Transition RESULT_TX -> CLEAR (CS inactive)");
          end
        end

        CLEAR: begin
          // Keep clearing until buffer is empty
          clear_buffer <= 1'b1;

          if (buffer_empty) begin
            clear_buffer <= 1'b0;
            state <= IDLE;
            $display("CONTROLLER: Transition CLEAR -> IDLE (buffer empty)");
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule
