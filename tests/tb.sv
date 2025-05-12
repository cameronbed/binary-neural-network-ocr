`ifndef SYNTHESIS
`include "../src/fpga/system_controller.sv"
`endif`timescale 1ns/1ps

module tb (
    // DUT ports
    output logic       clk,
    input  logic       rst_n_pin,
    input  logic       SCLK,
    input  logic       COPI,
    input  logic       spi_cs_n,
    output logic [3:0] status_code_reg,
    output logic [6:0] seg,
    output logic       decimalPoint,
    output logic       heartbeat,
    input  logic       debugTrigger
);

  import "DPI-C" task c_external(input bit is_posedge);

  // ------------------------------------------------------------------
  // 1) Clock generator (100 MHz → 10 ns period)
  // ------------------------------------------------------------------
  initial clk = 0;
  always #5 begin
    clk = ~clk;
    c_external(clk);
  end

  // ------------------------------------------------------------------
  // 2) DUT instantiation
  // ------------------------------------------------------------------
  system_controller dut (
      .clk            (clk),
      .rst_n_pin      (rst_n_pin),
      .SCLK           (SCLK),
      .COPI           (COPI),
      .spi_cs_n       (spi_cs_n),
      .status_code_reg(status_code_reg),
      .seg            (seg),
      .decimalPoint   (decimalPoint),
      .heartbeat      (heartbeat),
      .debug_trigger  (debugTrigger)
  );

  // ------------------------------------------------------------------
  // 3) Termination: watch the done flags and finish
  // ------------------------------------------------------------------
  always @(posedge clk) begin
    if (status_code_reg == 4'hF) begin
      $display("[%0t] Done state reached, finishing", $time);
      #1 $finish;
    end
    if (debugTrigger) begin
      $display("[%0t] debugTrigger asserted, finishing", $time);
      #1 $finish;
    end
  end

endmodule
