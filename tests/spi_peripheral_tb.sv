`timescale 1ns/1ps
module spi_peripheral_tb;
  // Testbench signals
  logic clk;
  logic rst_n;
  logic SCLK;
  logic CS;
  logic SDI;
  wire SDO;
  wire [7:0] rx_data;
  wire rx_valid;
  
  // Instantiate the SPI peripheral module
  spi_peripheral uut (
    .clk(clk),
    .rst_n(rst_n),
    .SCLK(SCLK),
    .CS(CS),
    .SDI(SDI),
    .SDO(SDO),
    .rx_data(rx_data),
    .rx_valid(rx_valid)
  );
  
  // Generate system clock (10 ns period)
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end
  
  // Initialize the SPI clock
  initial begin
    SCLK = 0;
  end
  
  // Task to send a byte over SPI (MSB first)
  task send_spi_byte(input [7:0] data);
    integer i;
    begin
      for (i = 7; i >= 0; i = i - 1) begin
        // Drive SDI with the current bit
        SDI = data[i];
        #10;         // Wait before clock edge
        SCLK = 1;    // Rising edge (peripheral samples SDI)
        #10;
        SCLK = 0;    // Falling edge (peripheral shifts TX)
        #10;
      end
    end
  endtask
  
  // Test stimulus
  initial begin
    // Initialize signals
    rst_n = 0;
    CS    = 1;   // Inactive (active low)
    SDI   = 0;
    #20;
    rst_n = 1;
    #20;
    
    // Begin SPI transaction
    CS = 0;  // Assert CS (active low)
    // Send 0x3C as example data from master to peripheral
    send_spi_byte(8'h3C);
    CS = 1;  // Deassert CS
    #50;
    
    if (rx_valid)
      $display("SPI peripheral received: %0h", rx_data);
    else
      $display("No valid data received.");
    
    $finish;
  end

endmodule
