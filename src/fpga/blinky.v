`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/06/2025 06:21:20 PM
// Design Name: 
// Module Name: blinky
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module blinky(
    input clk,
    output led
);
    reg [24:0] counter = 0;
    reg led_reg = 0;
    
    assign led = led_reg;
    
    always @(posedge clk) begin
        counter <= counter + 1;
        led_reg <= counter[24];
    end


endmodule

