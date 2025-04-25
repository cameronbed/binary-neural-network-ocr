`timescale 1ns / 1ps
module image_buffer (
    input logic clk,
    input logic rst_n,

    //
    input logic clear_buffer,
    input logic [7:0] data_in,
    input logic write_enable,
    output logic full,
    output logic empty,
    output logic [9:0] write_addr,
    output logic [903:0] img_out
);
  parameter int IMG_WIDTH = 30;
  parameter int IMG_HEIGHT = 30;
  parameter int ADDR_INC = 8;
  parameter int TOTAL_BITS = 904;

  logic [TOTAL_BITS-1:0] img_buffer;

  logic [31:0] write_ptr, next_ptr;
  assign next_ptr = write_ptr + ADDR_INC;

`ifdef SYNTHESIS
  logic [31:0] cycle_cnt;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) cycle_cnt <= 32'd0;
    else cycle_cnt <= cycle_cnt + 1;
  end
`endif

  // ----------------------- Image Buffer Write Logic -----------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      write_ptr  <= 32'd0;
      img_buffer <= '0;
    end else if (clear_buffer) begin
      write_ptr  <= 32'd0;
      img_buffer <= '0;
    end else if (write_enable) begin
      if ((write_ptr + ADDR_INC) <= TOTAL_BITS) begin
        // Map the byte directly: data_in[7] at msb end of slice
        img_buffer[write_ptr+:ADDR_INC] <= data_in;
        write_ptr <= next_ptr;  // Increment the write pointer
      end

`ifdef SYNTHESIS
      $display("[IMG Buffer] Cycle %0d: Wrote %b to addr %0d (write_ptr=%0d)", cycle_cnt, data_in,
               write_ptr, write_ptr);
      //      $display("[IMG Buffer Debug] Current img_buffer state: %b", img_buffer);
`endif
    end
  end

`ifdef SYNTHESIS
  always_ff @(posedge clk) begin
    if (write_enable) begin
      $display("[IMG Buffer Debug] Cycle %0d: Writing %b at write_ptr=%0d", cycle_cnt, data_in,
               write_ptr);
      //$display("[IMG Buffer Debug] Current img_buffer state: %b", img_buffer);
    end
  end

  // Catch pointer overflow in simulation
  always_ff @(posedge clk) begin
    assert (write_ptr < TOTAL_BITS + ADDR_INC)
    else $error("ImageBuffer write_ptr OOR: %0d (max %0d)", write_ptr, TOTAL_BITS + ADDR_INC - 1);
  end
`endif

  // -------------------- Status Flags --------------------
  logic full_flag, empty_flag;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n || clear_buffer) begin
      full_flag  <= 1'b0;
      empty_flag <= 1'b1;
    end else begin
      full_flag  <= (write_ptr >= TOTAL_BITS);
      empty_flag <= (write_ptr == 32'd0);
    end
  end

  // -------------------- Outputs --------------------
  assign img_out    = img_buffer;  // Ensure widths match
  assign write_addr = write_ptr[9:0];
  assign full       = full_flag;
  assign empty      = empty_flag;

endmodule
