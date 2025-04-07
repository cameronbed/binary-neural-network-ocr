`timescale 1ns / 1ps

module bnn_controller(
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
