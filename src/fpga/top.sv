`timescale 1ns / 1ps
// `include "system_controller.sv"
module top (
    input logic clk,
    input logic rst_n,
    // SPI
    input logic SCLK,
    input logic COPI,
    input logic spi_cs_n,
    // BNN Data
    output logic [3:0] result_out,  // Ensure 4-bit width
    // Control
    output logic result_ready,
    output logic send_image,
    output logic status_ready,
    // DEBUG
    input logic debug_trigger
);

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
      .result_ready(result_ready),
      .send_image  (send_image),
      .status_ready(status_ready),

      // DEBUG
      .debug_trigger(debug_trigger)
  );

endmodule
