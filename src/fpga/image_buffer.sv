// Image Buffer
// image_buffer.sv
`timescale 1ns / 1ps
module image_buffer (
    input logic clk,
    input logic rst_n,  // Active Low
    input logic clear_buffer,
    input logic [7:0] data_in,
    input logic write_enable,
    output logic data_out[0:783],  // Change to unpacked array
    output logic buffer_full,
    output logic buffer_empty,  // Declare as logic for procedural assignment

    // Debug outputs
    output logic [9:0] debug_write_addr,    // Changed from [0:783] to [9:0]
    output logic       debug_buffer_full,   // Debug: buffer full status
    output logic       debug_buffer_empty,  // Debug: buffer empty status
    output logic       debug_write_enable
);
  // DEBUG remains as an int
  parameter int DEBUG = 1;  // Debug flag: 0 = off, non-zero = on

  // 2D array for 1-bit image pixels
  parameter int ROWS = 28;
  parameter int COLS = 28;
  // Directly assign TOTAL_PIXELS as a constant value
  localparam logic [9:0] TOTAL_PIXELS = 10'd784;

  logic [TOTAL_PIXELS-1:0] buffer;
  // Write pointer to track how many pixels have been written (max 784 = 28x28)
  logic [9:0] write_addr;  // Fixed width for TOTAL_PIXELS

  integer i;  // Declare loop variable as integer for proper comparison

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      write_addr <= '0;
      for (i = 0; i < TOTAL_PIXELS; i = i + 1) begin
        // Use blocking assignment in reset branch
        buffer[i] <= 1'b0;
      end
      if (DEBUG != 0) $display("IMAGE_BUFFER: Reset applied, write_addr set to 0");
    end else if (clear_buffer) begin
      write_addr <= '0;
      for (i = 0; i < TOTAL_PIXELS; i = i + 1) begin
        buffer[i] <= 1'b0;
      end
      if (DEBUG != 0) $display("IMAGE_BUFFER: Clear buffer applied, write_addr set to 0");
    end else if (write_enable && !buffer_full) begin
      if (write_addr < TOTAL_PIXELS) begin
        buffer[write_addr] <= (data_in != 8'd0);
        write_addr <= write_addr + 1;
        if (DEBUG != 0)
          $display(
              "IMAGE_BUFFER: Writing data %b at addr=%d, write_enable=%b",
              (data_in != 8'd0),
              write_addr,
              write_enable
          );
      end
    end
  end

  always_ff @(posedge clk) begin
    if (write_addr > TOTAL_PIXELS) $fatal("Write address exceeded TOTAL_PIXELS!");
  end


  always_comb begin
    debug_write_addr   = write_addr;
    debug_buffer_full  = (write_addr == TOTAL_PIXELS);
    debug_buffer_empty = (write_addr == 0);
    debug_write_enable = write_enable;
  end

  assign buffer_full  = (write_addr == TOTAL_PIXELS);
  assign buffer_empty = (write_addr == 0);

  always_comb begin
    for (int i = 0; i < TOTAL_PIXELS; i++) begin
      data_out[i] = buffer[i];  // Assign each bit of the buffer to the unpacked array
    end
  end

endmodule
