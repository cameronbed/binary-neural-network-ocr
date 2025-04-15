`timescale 1ns / 1ps
//`include "system_controller.sv"
module top (
    input logic clk,
    input logic rst_n,
    input logic SCLK,
    COPI,
    CS,
    output logic CIPO,
    output logic [3:0] result_out,
    input logic debug_trigger
);

  system_controller u_system_controller (
      .clk(clk),
      .rst_n(rst_n),
      .SCLK(SCLK),
      .COPI(COPI),
      .CS(CS),
      .CIPO(CIPO),
      .result_out(result_out),
      .debug_trigger(debug_trigger)
  );

endmodule
