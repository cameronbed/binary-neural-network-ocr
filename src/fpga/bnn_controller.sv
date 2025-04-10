// BNN Controller
// bnn_controller.sv
`timescale 1ns / 1ps
`include "spi_peripheral.sv"
`include "image_buffer.sv"
module bnn_controller (
    input logic clk,  // System clock
    input logic rst,  // Active-low reset

    // SPI inputs
    input  logic SCLK,  // SPI clock
    input  logic COPI,  // Controller-out-Peripheral-In
    input  logic CS,    // Chip Select
    // SPI Outputs
    output logic CIPO   // Controller-in-Peripheral-Out
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

  logic [7:0] image_buffer[0:27][0:27];  // Image buffer to store the received image

  logic curr_row, curr_col;  // Current row and column for image writing

  spi_peripheral spi_peripheral_inst (
      .clk       (clk),
      .rst       (rst),
      .SCLK      (SCLK),
      .COPI      (COPI),
      .CS        (CS),
      .CIPO      (CIPO),
      .rx_byte   (rx_byte),    // Added connection for SPI data output
      .byte_valid(byte_valid)  // Added connection for valid indicator
  );

  // Connect image_buffer outputs (buffer_full, buffer_empty)
  image_buffer image_buffer_inst (
      .clk(clk),
      .reset(rst),
      .data_in(rx_byte),
      .write_enable(byte_valid),
      .read_enable(1'b0),  // Not used in this example
      .data_out(image_buffer),
      .buffer_full(buffer_full),
      .buffer_empty(buffer_empty)
  );

  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      state <= IDLE;
    end else begin
      // Integrated FSM transitions
      case (state)
        IDLE: begin
          if (CS == 1'b0) state <= IMG_RX;
          else state <= IDLE;
        end

        IMG_RX: begin
          if (buffer_full) state <= INFERENCE;
          else begin
            if (byte_valid) begin
              // Manage the write address for the image buffer
              static logic [4:0] row = 0;  // Row address (5 bits for 28 rows)
              static logic [4:0] col = 0;  // Column address (5 bits for 28 columns)

              // Store the received byte in the image buffer
              image_buffer[row][col] <= rx_byte;

              // Increment the column address
              if (col == 27) begin
                col <= 0;  // Reset column and move to the next row
                if (row == 27) begin
                  row <= 0;  // Reset row when the entire buffer is filled
                end else begin
                  row <= row + 1;
                end
              end else begin
                col <= col + 1;
              end
            end
            state <= IMG_RX;
          end
        end

        INFERENCE: begin
          // Perform inference here (not implemented)
          state <= RESULT_TX;
        end

        RESULT_TX: begin
          if (CS == 1'b1) state <= CLEAR;
          else state <= RESULT_TX;
        end

        CLEAR: begin
          state <= IDLE;
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule
