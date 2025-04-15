`timescale 1ns / 1ps
module image_buffer (
    input logic clk,
    input logic rst_n,
    input logic clear_buffer,
    input logic [7:0] data_in,
    input logic write_enable,
    output logic full,
    output logic empty,
    output logic [9:0] write_addr,
    output logic image_flat[0:783]
);
  logic image_buffer_flat[0:783];  // 784 bits for 28x28 image
  logic buffer_full, buffer_empty;
  logic [9:0] prev_write_addr, write_addr_counter;

  // ----------------------- Image Buffer Write Logic -----------------------
  // ----------------------- Buffer Status Logic -----------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n || clear_buffer) begin
      buffer_full <= 1'b0;
      buffer_empty <= 1'b1;
      write_addr_counter <= 10'd0;

      // Clear entire image buffer
      for (int i = 0; i < 784; i++) begin
        image_buffer_flat[i] = 1'b0;  // Use blocking assignment to avoid delayed assignment error
      end
    end else if (write_enable && !buffer_full) begin
      if (write_addr_counter < 10'd784) begin
        image_buffer_flat[write_addr_counter] <= data_in[0];  // Use only the LSB of data_in
        write_addr_counter <= write_addr_counter + 1;
      end
      if (write_addr_counter == 10'd784) begin
        buffer_full <= 1'b1;
      end else begin
        buffer_empty <= 1'b0;
      end
    end else begin
      buffer_full  <= (write_addr_counter == 10'd784);
      buffer_empty <= (write_addr_counter == 10'd0);
    end
  end

endmodule
