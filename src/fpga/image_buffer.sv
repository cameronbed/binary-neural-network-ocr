// Image Buffer
// image_buffer.sv
`timescale 1ns / 1ps
module image_buffer (
    input logic clk,
    input logic reset,
    input logic [7:0] data_in,
    input logic write_enable,
    input logic read_enable,
    output logic [7:0] data_out[0:27][0:27],
    output logic buffer_full,
    output logic buffer_empty
);
  // 2D array for 8-bit image pixels
  logic [7:0] buffer[0:27][0:27];

  // Write pointer to track how many pixels have been written (max 784 = 28x28)
  logic [9:0] write_addr;

  integer i, j;
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      write_addr <= 0;
      // Clear the entire buffer
      for (i = 0; i < 28; i = i + 1) begin
        for (j = 0; j < 28; j = j + 1) begin
          buffer[i][j] <= 8'd0;
        end
      end
    end else if (write_enable && !buffer_full) begin
      buffer[write_addr/28][write_addr%28] <= data_in;
      write_addr <= write_addr + 1;
    end
  end

  assign buffer_full = (write_addr == 784);
  assign buffer_empty = (write_addr == 0);

  // Pass the stored image out to data_out port
  // (In many designs you may not need to output the entire image through a port.)
  assign data_out = buffer;
endmodule
