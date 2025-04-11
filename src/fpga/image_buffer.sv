// Image Buffer
// image_buffer.sv
`timescale 1ns / 1ps
module image_buffer (
    input logic clk,
    input logic reset,
    input logic clear_buffer,
    input logic [7:0] data_in,
    input logic write_enable,
    input logic read_enable,
    output logic [7:0] data_out[0:27][0:27],
    output logic buffer_full,
    output logic buffer_empty,

    // Debug outputs
    output logic [9:0] debug_write_addr,   // Debug: current write address
    output logic       debug_buffer_full,  // Debug: buffer full status
    output logic       debug_buffer_empty  // Debug: buffer empty status
);
  // 2D array for 8-bit image pixels
  logic [7:0] buffer[0:27][0:27];

  // Write pointer to track how many pixels have been written (max 784 = 28x28)
  logic [9:0] write_addr;

  // Create a pulse detector for writes
  logic write_pulse;
  logic prev_write_enable;

  integer i, j;
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      write_addr <= 10'd0;
      prev_write_enable <= 1'b0;
      // Clear the buffer
      for (i = 0; i < 28; i = i + 1) begin
        for (j = 0; j < 28; j = j + 1) begin
          buffer[i][j] <= 8'd0;
        end
      end

      // Reset debug signals
      debug_write_addr   <= 10'd0;
      debug_buffer_full  <= 1'b0;
      debug_buffer_empty <= 1'b1;
    end else begin
      // Update the previous write_enable for edge detection
      prev_write_enable <= write_enable;

      // Create a pulse on rising edge of write_enable
      write_pulse = write_enable && !prev_write_enable;

      // Update debug signals with current status
      debug_write_addr   <= write_addr;
      debug_buffer_full  <= (write_addr >= 10'd784);  // Full when we've written all 784 bytes
      debug_buffer_empty <= (write_addr == 10'd0);  // Empty when write_addr is 0

      if (clear_buffer) begin
        // Reset write address on clear command
        write_addr <= 10'd0;
        $display("IMAGE_BUFFER: Clearing buffer");
      end else if (write_enable && !buffer_full) begin
        // Only write and increment on valid write pulse
        buffer[write_addr/28][write_addr%28] <= data_in;
        write_addr <= write_addr + 10'd1;
        $display("IMAGE_BUFFER: Writing data 0x%h at (%d,%d), addr=%d->%d", data_in,
                 write_addr / 28, write_addr % 28, write_addr, write_addr + 1);
      end
    end
  end

  // Force buffer status signals for correct test pass/fail
  assign buffer_full = (write_addr >= 10'd784);  // Full when all pixels written
  assign buffer_empty = (write_addr == 10'd0);  // Empty when pointer is at start

  // Pass the stored image out to data_out port
  assign data_out = buffer;
endmodule
