`timescale 1ns / 1ps

module bnn_controller #(
    parameter [7:0] INITIAL_TX = 8'hA5
)(
    // System I/O
    input  logic clk,       // System clock
    input  logic rst_n,     // Active-low reset
    output logic led,

    // SPI Interface from Master
    input  logic SCLK,      // SPI clock
    input  logic CS,        // SPI chip select (active low)
    input  logic SDI,       // SPI data in
    output logic SDO        // SPI data out
);

    // Example instantiation of the SPI Peripheral
    spi_peripheral #(
        .INITIAL_TX(INITIAL_TX)
    ) spi_inst (
        .clk(clk),
        .rst_n(rst_n),
        .SCLK(SCLK),
        .CS(CS),
        .SDI(SDI),
        .SDO(SDO),
        // Received data here, if you need it
        .rx_data(/* unused here */),
        .rx_valid(/* unused here */)
    );

    // Example LED logic to show other internal tasks
    reg [24:0] counter;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            counter <= 0;
        else
            counter <= counter + 1;
    end
    assign led = counter[24];

endmodule
