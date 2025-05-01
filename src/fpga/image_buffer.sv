`timescale 1ns / 1ps
module image_buffer (
    input logic clk,
    input logic rst_n,

    input logic clear_buffer,
    input logic [7:0] data_in,

    input logic write_request,
    output logic write_ready,
    output logic [6:0] write_addr,

    output logic buffer_full,
    output logic buffer_empty,

    output logic [903:0] img_out
);
  parameter int IMG_WIDTH = 30;
  parameter int IMG_HEIGHT = 30;
  parameter int TOTAL_BITS = 904;
  parameter logic [6:0] IMG_BYTE_SIZE = 7'd113;

  (* ram_style = "block" *) logic [7:0] image_buffer[0:112];

  logic [6:0] write_addr_internal;
  logic [6:0] next_addr_ff;

  //===================================================
  // Write Logic + next‐addr tracking
  //===================================================
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      write_addr_internal <= 7'd0;
      next_addr_ff        <= 7'd0;
      // img_buffer          <= '0;
    end else if (clear_buffer) begin
      write_addr_internal <= 7'd0;
      next_addr_ff        <= 7'd0;
      // img_buffer          <= '0;
    end else begin
      // default: don’t advance pointer
      next_addr_ff <= write_addr_internal;

      if (write_request && (write_addr_internal < IMG_BYTE_SIZE)) begin
        image_buffer[write_addr_internal] <= data_in;
        write_addr_internal <= write_addr_internal + 1;
        next_addr_ff <= write_addr_internal + 1;
      end
    end
  end

  //===================================================
  // Constructing img_out as flattened output
  //===================================================
  genvar i;
  generate
    for (i = 0; i < 113; i++) begin : PACK_IMAGE
      assign img_out[i*8+:8] = image_buffer[i];
    end
  endgenerate

  //===================================================
  // Status Flag and outputs
  //===================================================
  assign write_ready  = (write_addr_internal < IMG_BYTE_SIZE);
  assign buffer_full  = (next_addr_ff >= IMG_BYTE_SIZE);
  assign buffer_empty = (write_addr_internal == 0);
  assign write_addr   = write_addr_internal;
  // assign img_out = img_buffer;

endmodule
