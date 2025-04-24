`timescale 1ns / 1ps
// `include "system_controller.sv"
module top (
    input logic clk,
    input logic rst_n_pin,
    input logic rst_n_btn,
    // SPI
    input logic SCLK,
    input logic COPI,
    input logic spi_cs_n,
    // BNN Data
    output logic [3:0] result_out,  // Ensure 4-bit width
    // Control
    output logic result_ready_pin,
    output logic send_image_pin,
    output logic status_ready_pin,

    output logic result_ready_led,
    output logic send_image_led,
    output logic status_ready_led,
    // DEBUG
`ifndef SYNTHESIS
    input  logic debug_trigger
`endif
);

  logic rst_n;
  logic result_ready_int;
  logic send_image_int;
  logic status_ready_int;

  assign rst_n = rst_n_pin && rst_n_btn;

  assign result_ready_pin = result_ready_int;
  assign result_ready_led = result_ready_int;

  assign send_image_led = send_image_int;
  assign send_image_pin = send_image_int;

  assign status_ready_led = status_ready_int;
  assign status_ready_pin = status_ready_int;

  system_controller u_system_controller (
      .clk  (clk),
      .rst_n(rst_n),

      // SPI
      .SCLK(SCLK),
      .COPI(COPI),
      .spi_cs_n(spi_cs_n),

      // BNN Data
      .result_out(result_out),  // Match 4-bit width

      // Control
      .result_ready(result_ready_int),
      .send_image  (send_image_int),
      .status_ready(status_ready_int),

      // DEBUG
`ifndef SYNTHESIS
      .debug_trigger(debug_trigger)
`endif
  );

endmodule
