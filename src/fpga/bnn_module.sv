// BNN Module
// bnn_module.sv
`timescale 1ns / 1ps
module bnn_module (
    input logic clk,
    input logic reset,
    input logic [7:0] data_in,
    input logic write_enable,
    output logic result_ready,
    output logic [7:0] result_out,
    input logic [7:0] img_in[0:27][0:27],

    // Debug outputs
    output logic [7:0] debug_data_in,       // Debug: input data
    output logic       debug_write_enable,  // Debug: write enable signal
    output logic       debug_result_ready,  // Debug: result ready signal
    output logic [7:0] debug_result_out     // Debug: result output
);

  // Add a module-level counter
  logic [31:0] counter;

  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      // Debug: Reset debug signals
      debug_data_in <= 8'd0;
      debug_write_enable <= 1'b0;
      debug_result_ready <= 1'b0;
      debug_result_out <= 8'd0;
    end else begin
      // Debug: Update debug signals
      debug_data_in <= data_in;
      debug_write_enable <= write_enable;
      debug_result_ready <= result_ready;
      debug_result_out <= result_out;
    end
  end

  // For testing only - add dummy logic to provide a result
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      result_out <= 8'd0;
      result_ready <= 1'b0;
      counter <= 32'd0;  // Reset counter in reset block
    end else begin
      // Simple test implementation - just return a value after some cycles
      if (counter < 20) begin
        counter <= counter + 32'd1;
      end else begin
        result_ready <= 1'b1;
        result_out   <= 8'd7;  // Example classification result
      end
    end
  end

endmodule
