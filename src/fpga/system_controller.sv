`timescale 1ns / 1ps
//`include "spi_peripheral.sv"
//`include "bnn_interface.sv"
//`include "debug_module.sv"
//`include "fsm_controller.sv"
//`include "image_buffer.sv"
module system_controller (
    input logic clk,
    input logic rst_n,
    input logic SCLK,
    input logic COPI,
    input logic CS,
    output logic CIPO,
    output logic [3:0] result_out,
    input logic debug_trigger
);
  // ------------------------ FSM Controller ---------------
  logic [2:0] fsm_current_state;
  logic rx_enable;  // Define rx_enable
  logic tx_enable;  // Define tx_enable

  // ------------------------ SPI Peripheral ---------------
  // SPI Data
  logic [7:0] rx_byte;
  logic [7:0] tx_byte;  // Byte to be transmitted
  // SPI Control Signals
  logic byte_valid;
  logic byte_ready;
  logic buffer_full;
  logic buffer_empty;
  logic clear_buffer;
  logic result_ready;
  logic spi_error;

  // ---------------------- Image Buffer ---------------
  logic image_flat[0:783];  // 784 bits for 28x28 image
  logic [9:0] image_write_addr;  // 10 bits for 1024 address space
  logic buffer_write_enable;  // Buffer write enable signal

  // ---------------------- Debug Module ---------------

  // ---------------------- bnn_interface ---------------

  // ----------------------- FSM Controller Instantiation -----------------------
  controller_fsm u_controller_fsm (
      .clk  (clk),
      .rst_n(rst_n),

      // Inputs from submodules / external
      .CS(CS),
      .byte_valid(byte_valid),
      .byte_ready(byte_ready),
      .spi_error(spi_error),
      .buffer_full(buffer_full),
      .buffer_empty(buffer_empty),
      .result_ready(result_ready),

      // Outputs to control other modules
      .rx_enable(rx_enable),
      .tx_enable(tx_enable),
      .clear_buffer(clear_buffer),
      .buffer_write_enable(buffer_write_enable),

      // Expose current state for debug
      .current_state(fsm_current_state)
  );

  // ----------------------- Submodule Instantiations -----------------------
  spi_peripheral spi_peripheral_inst (
      .clk  (clk),
      .rst_n(rst_n),
      .SCLK (SCLK),
      .COPI (COPI),
      .CS   (CS),
      .CIPO (CIPO),

      // Control signals input
      .byte_ready(byte_ready),  // Byte ready signal
      .rx_enable (rx_enable),   // Enable for receiving data
      .tx_enable (tx_enable),   // Enable for transmitting data

      // Control signals output
      .tx_byte   (tx_byte),     // Byte to be transmitted
      .rx_byte   (rx_byte),     // PI data output
      .byte_valid(byte_valid),  // valid indicator
      .spi_error (spi_error)
  );

  bnn_interface u_bnn_interface (
      .clk  (clk),
      .rst_n(rst_n),

      // Data
      .img_in(image_flat),  // Use unpacked array
      .result_out(result_out),  // 8 bits

      // Control signals
      .img_buffer_full(buffer_full),
      .result_ready(result_ready)
  );

  // -------------- Image Buffer Instantiation --------------
  image_buffer u_image_buffer (
      .clk         (clk),
      .rst_n       (rst_n),
      .clear_buffer(clear_buffer),
      .write_addr  (image_write_addr),
      .data_in     (rx_byte),
      .full        (buffer_full),
      .empty       (buffer_empty),
      .write_enable(buffer_write_enable),
      .image_flat  (image_flat)
  );

  // ----------------- Debug Module Instantiation -----------------
  debug_module u_debug_module (
      .clk(clk),
      .debug_enable(debug_trigger),

      // FSM
      .fsm_state(fsm_current_state),
      .spi_error(spi_error),

      // SPI
      .spi_byte_valid(byte_valid),
      .spi_byte_ready(byte_ready),
      .spi_rx_byte(rx_byte),
      .spi_tx_byte(tx_byte),

      // Image buffer
      .buffer_full (buffer_full),
      .buffer_empty(buffer_empty),
      .write_addr  (image_write_addr),

      // BNN
      .bnn_result_ready(result_ready),
      .bnn_result_out  (result_out)
  );

endmodule
