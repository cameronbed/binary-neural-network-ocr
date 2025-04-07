`timescale 1ns/1ps
module spi_peripheral #(
    parameter [7:0] INITIAL_TX = 8'hA5
)(
    input  logic clk,      // System clock (e.g., 50 MHz)
    input  logic rst_n,    // Active-low reset
    input  logic SCLK,     // SPI clock from master
    input  logic CS,       // Chip Select (active low)
    input  logic SDI,      // Serial Data In (from master)
    output logic SDO,      // Serial Data Out (to master)
    output logic [7:0] rx_data, // Received 8-bit data
    output logic rx_valid      // Asserted one clock cycle when data is valid
);

  // Synchronize asynchronous SCLK and CS to the system clock domain
  logic SCLK_sync, SCLK_sync_prev;
  logic CS_sync,   CS_sync_prev;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      SCLK_sync      <= 0;
      SCLK_sync_prev <= 0;
      CS_sync        <= 1;
      CS_sync_prev   <= 1;
    end else begin
      SCLK_sync_prev <= SCLK_sync;
      SCLK_sync      <= SCLK;
      CS_sync_prev   <= CS_sync;
      CS_sync        <= CS;
    end
  end

  wire SCLK_rising  = (SCLK_sync && !SCLK_sync_prev);
  wire SCLK_falling = (!SCLK_sync && SCLK_sync_prev);
  wire cs_active    = ~CS_sync;  // Active when CS is low

  // Internal registers for shifting data and counting bits
  logic [7:0] rx_shift;
  logic [7:0] tx_shift;
  logic [3:0] bit_cnt;  // Counts from 0 to 8
  logic       transaction_active;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      transaction_active <= 0;
      bit_cnt            <= 0;
      rx_shift           <= 8'b0;
      tx_shift           <= INITIAL_TX;
      SDO                <= 1'b0;
      rx_valid           <= 1'b0;
      rx_data            <= 8'b0;
    end else begin
      if (!cs_active) begin
        // When chip select is inactive, clear transaction state
        transaction_active <= 0;
        bit_cnt            <= 0;
        rx_valid           <= 0;
      end else begin
        if (!transaction_active) begin
          // Start a new SPI transaction
          transaction_active <= 1;
          bit_cnt            <= 0;
          tx_shift           <= INITIAL_TX;  // Preload TX register
          SDO                <= INITIAL_TX[7]; // Output MSB immediately
          rx_valid           <= 0;
          rx_shift           <= 8'b0;
        end else begin
          rx_valid <= 0; // Default
          // On SCLK rising edge, sample SDI into the shift register
          if (SCLK_rising) begin
            rx_shift <= {rx_shift[6:0], SDI};
            bit_cnt  <= bit_cnt + 1;
          end
          // On falling edge, shift out TX data to SDO
          if (SCLK_falling && (bit_cnt != 0)) begin
            tx_shift <= {tx_shift[6:0], 1'b0};
            SDO      <= tx_shift[6]; // Next bit becomes MSB
          end
          // When 8 bits have been transferred, capture the received byte
          if (bit_cnt == 8) begin
            rx_data         <= {rx_shift[6:0], SDI}; // Final bit from last rising edge
            rx_valid        <= 1;
            transaction_active <= 0;  // End of transaction
          end
        end
      end
    end
  end

endmodule
