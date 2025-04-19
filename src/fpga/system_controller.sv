`timescale 1ns / 1ps
// `include "spi_peripheral.sv"
// `include "bnn_interface.sv"
// `include "debug_module.sv"
// `include "fsm_controller.sv"
// `include "image_buffer.sv"
module system_controller (
    input logic clk,
    input logic rst_n,

    // SPI
    input logic SCLK,
    input logic COPI,
    input logic spi_cs_n,
    output logic [3:0] result_out,  // Change from 8 bits to 4 bits

    // Control
    output logic result_ready,
    output logic send_image,
    output logic status_ready,

    // DEBUG
    input logic debug_trigger
);

  // ------------------------ FSM Controller ---------------

  logic rx_enable;  // Define rx_enable
  logic infer_start;  // Added inference start signal
  logic buffer_full, buffer_empty, clear_buffer;  // Declare missing signals
  logic [  2:0] fsm_state;  // Match FSM state width

  // ------------------------ SPI Peripheral ---------------
  // SPI Data
  logic [  7:0] spi_rx_data;  // Byte to be transmitted
  logic         spi_byte_valid;
  logic         byte_taken;

  // ---------------------- Image Buffer ---------------
  logic [903:0] image_flat;
  logic [  9:0] write_addr;
  logic         buffer_write_enable;

  // ------------------- BNN Interface
  logic         bnn_start;

  // ----------------------- FSM Controller Instantiation -----------------------
  controller_fsm u_controller_fsm (
      .clk  (clk),
      .rst_n(rst_n),

      // SPI
      .spi_cs_n(spi_cs_n),
      .spi_byte_valid(spi_byte_valid),
      .spi_rx_data(spi_rx_data),  // Byte received from SPI
      .rx_enable(rx_enable),
      .byte_taken(byte_taken),

      // Commands
      .send_image  (send_image),
      .status_ready(status_ready),

      // Image Buffer
      .buffer_full(buffer_full),
      .buffer_empty(buffer_empty),
      .clear_buffer(clear_buffer),  // Drive clear_buffer from FSM
      .buffer_write_enable(buffer_write_enable),

      // BNN Interface
      .result_ready(result_ready),
      .result_out(result_out),
      .bnn_start(bnn_start),

      .fsm_state(fsm_state)
  );

  // ----------------------- Submodule Instantiations -----------------------
  spi_peripheral spi_peripheral_inst (
      .clk(clk),
      .rst_n(rst_n),
      // SPI Pins
      .SCLK(SCLK),
      .COPI(COPI),
      .spi_cs_n(spi_cs_n),

      // Data Interface
      .spi_rx_data(spi_rx_data),  // Byte to send over SPI

      // Control Signals
      .rx_enable(rx_enable),  // Enable shift-in
      .spi_byte_valid(spi_byte_valid),  // Peripheral has a new spi_rx_data
      .byte_taken(byte_taken)
  );

  bnn_interface u_bnn_interface (
      .clk  (clk),
      .rst_n(rst_n),

      // Data
      .img_in(image_flat),  // Packed vector matches declaration
      .result_out(result_out),  // Match 4-bit width

      // Control signals
      .img_buffer_full(buffer_full),
      .result_ready(result_ready),
      .bnn_start(bnn_start)
  );

  // -------------- Image Buffer Instantiation --------------
  image_buffer u_image_buffer (
      .clk         (clk),
      .rst_n       (rst_n),
      //
      .clear_buffer(clear_buffer),         // Pass clear_buffer to image_buffer
      .write_addr  (write_addr),
      .data_in     (spi_rx_data),
      .full        (buffer_full),
      .empty       (buffer_empty),
      .write_enable(buffer_write_enable),
      .img_out     (image_flat)            // Packed vector matches declaration
  );

`ifndef SYNTHESIS
  // ----------------- Debug Module Instantiation -----------------
  debug_module u_debug_module (
      .clk         (clk),
      .rst_n       (rst_n),         // <<< added rst_n connection
      .debug_enable(debug_trigger),

      // FSM
      .fsm_state(fsm_state),

      // SPI
      .spi_byte_valid(spi_byte_valid),
      .spi_rx_byte(spi_rx_data),

      // Image buffer
      .buffer_full        (buffer_full),
      .buffer_empty       (buffer_empty),
      .write_addr         (write_addr),
      .buffer_write_enable(buffer_write_enable),
      .buffer_data_in     (spi_rx_data),
      .img_in             (image_flat),

      // BNN
      .bnn_result_ready(result_ready),
      .bnn_result_out  (result_out)
  );
`endif

endmodule
