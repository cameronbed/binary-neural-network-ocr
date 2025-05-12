`timescale 1ns / 1ps
module image_buffer (
    input logic clk,
    input logic rst_n,

    input logic clear_buffer,
    input logic [7:0] data_in,

    input  logic write_request,
    output logic write_ready,

    output logic buffer_full,
    output logic buffer_empty,

    output logic [899:0] img_out
);
  parameter int IMG_WIDTH = 30;
  parameter int IMG_HEIGHT = 30;
  parameter int TOTAL_BITS = 904;
  parameter int IMG_BITS = 900;
  parameter logic [6:0] IMG_BYTE_SIZE = 7'd113;

  logic [899:0] internal_image_buffer;

  logic [6:0] write_addr_internal;
  logic [6:0] next_addr_ff;

  logic buffer_empty_reg;

  //===================================================
  // Write Logic + next‐addr tracking
  //===================================================
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      write_addr_internal <= 7'd0;
      next_addr_ff        <= 7'd0;
      buffer_empty_reg    <= 1'b1;
    end else if (clear_buffer) begin
      write_addr_internal <= 7'd0;
      next_addr_ff        <= 7'd0;
      buffer_empty_reg    <= 1'b1;
    end else begin
      next_addr_ff <= write_addr_internal;

      if (write_request && (write_addr_internal < IMG_BYTE_SIZE)) begin

        if (write_addr_internal == IMG_BYTE_SIZE - 1) begin
          internal_image_buffer[TOTAL_BITS-8+:4] <= data_in[3:0]; // Only the lower four bits on the last byte
        end else begin
          internal_image_buffer[write_addr_internal*8+:8] <= data_in; // Writing the data to the image buffer
        end

        write_addr_internal <= write_addr_internal + 1;  // Advancing the write address
        next_addr_ff <= write_addr_internal + 1;  // Setting the next write address
      end

      buffer_empty_reg <= (write_addr_internal == 0);
    end
  end

  //===================================================
  // Status Flag and outputs
  //===================================================
  assign write_ready = (write_addr_internal < IMG_BYTE_SIZE);
  assign buffer_full = (write_addr_internal >= IMG_BYTE_SIZE);
  assign buffer_empty = buffer_empty_reg;
  assign img_out = internal_image_buffer;

endmodule
