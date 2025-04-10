// BNN Module
// bnn_module.sv
`timescale 1ns / 1ps
module bnn_module (
    input logic clk,
    input logic reset,
    input logic [7:0] data_in,
    input logic write_enable,
    input logic read_enable,
    output logic [7:0] data_out[0:27][0:27]
);


endmodule
