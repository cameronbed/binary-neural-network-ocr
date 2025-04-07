`timescale 1ns / 1ps
module blinky_tb;

  reg clk = 0;
  wire led;

  // Instantiate DUT (Device Under Test)
  blinky uut (
    .clk(clk),
    .led(led)
  );

  // Generate a 100 MHz clock
  always #5 clk = ~clk;

    initial begin
    $dumpfile("build/blinky_tb.vcd");
    $dumpvars(0, blinky_tb);
    #1000000;  // 1 ms
    $finish;
    end


endmodule
